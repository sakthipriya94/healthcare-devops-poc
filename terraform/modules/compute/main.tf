data "aws_caller_identity" "current" {}

locals {
  name      = "${var.project}-${var.environment}"
  has_cert  = var.certificate_arn != ""
  has_dns   = var.domain_name != "" && var.route53_zone_id != ""
  ssm_param = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/${var.environment}/*"
}

# Latest Amazon Linux 2023 (patched base image, SSM agent preinstalled)
data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ------------------------------------------------- container logs ----------
resource "aws_cloudwatch_log_group" "containers" {
  name              = "/${var.project}/${var.environment}/containers"
  retention_in_days = var.log_retention_days
}

# --------------------------------------------- IAM (least privilege) -------
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${local.name}-app-host"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Session Manager / Run Command (replaces SSH)
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "app" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid       = "EcrPull"
    actions   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
    resources = var.ecr_repository_arns
  }
  statement {
    sid       = "ReadOwnSecrets"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = var.secret_arns
  }
  statement {
    sid       = "ReadDeployBundle"
    actions   = ["s3:GetObject"]
    resources = ["${var.artifacts_bucket_arn}/*"]
  }
  statement {
    sid       = "ListDeployBundle"
    actions   = ["s3:ListBucket"]
    resources = [var.artifacts_bucket_arn]
  }
  statement {
    sid       = "WriteDatabaseBackups"
    actions   = ["s3:PutObject", "s3:AbortMultipartUpload"]
    resources = ["${var.backups_bucket_arn}/*"]
  }
  statement {
    sid       = "DeployState"
    actions   = ["ssm:GetParameter", "ssm:PutParameter"]
    resources = [local.ssm_param]
  }
  statement {
    sid       = "ContainerLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.containers.arn}:*"]
  }
  statement {
    sid       = "CustomMetrics"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["CWAgent", "Healthcare"]
    }
  }
}

resource "aws_iam_role_policy" "app" {
  name   = "app-host"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app.json
}

resource "aws_iam_instance_profile" "app" {
  name = "${local.name}-app-host"
  role = aws_iam_role.app.name
}

# ------------------------------------------------------ EC2 host -----------
resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.app_security_group_id]
  iam_instance_profile        = aws_iam_instance_profile.app.name
  associate_public_ip_address = true # outbound only; no inbound rule allows direct access

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 2          # containers may reach the metadata service
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_gb
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    environment          = var.environment
    project              = var.project
    aws_region           = var.aws_region
    ecr_registry         = var.ecr_registry
    db_host              = var.db_address
    db_master_secret_arn = var.db_master_secret_arn
    artifacts_bucket     = var.artifacts_bucket
    backups_bucket       = var.backups_bucket
    compose_version      = var.compose_version
    allowed_hosts = join(",", compact(concat(
      ["localhost", ".${aws_lb.this.dns_name}"],
      var.domain_name == "" ? [] : [".${var.domain_name}"],
      var.extra_allowed_hosts,
    )))
  })

  tags = { Name = "${local.name}-app", Role = "app", Environment = var.environment }

  lifecycle {
    ignore_changes = [ami, user_data] # patch by replacing the host deliberately, not on every AMI release
  }
}

# --------------------------------------------------------- ALB ------------
resource "aws_lb" "this" {
  name                       = "${local.name}-alb"
  load_balancer_type         = "application"
  security_groups            = [var.alb_security_group_id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true
  idle_timeout               = 60
}

resource "aws_lb_target_group" "app" {
  name                 = "${local.name}-app"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    path                = "/api/live/"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  port             = 80
}

# HTTP: redirect to HTTPS when a certificate is configured, otherwise serve
# (demo mode - use only with synthetic data).
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = local.has_cert ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
  dynamic "default_action" {
    for_each = local.has_cert ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.app.arn
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = local.has_cert ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Wildcard DNS so hospital-a.<domain>, hospital-b.<domain>, ... all hit the ALB
resource "aws_route53_record" "wildcard" {
  count   = local.has_dns ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "*.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}
