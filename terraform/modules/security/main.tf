locals {
  name = "${var.project}-${var.environment}"
}

# ---- ALB: the only thing exposed to the internet --------------------------
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "Public load balancer"
  vpc_id      = var.vpc_id
  tags        = { Name = "${local.name}-alb-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP (redirects to HTTPS when a certificate is configured)"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Forward to the application host"
}

# ---- Application host -----------------------------------------------------
resource "aws_security_group" "app" {
  name        = "${local.name}-app"
  description = "Application host: reachable only from the ALB"
  vpc_id      = var.vpc_id
  tags        = { Name = "${local.name}-app-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "HTTP from ALB only"
}

# SSH is OFF by default. Administration uses AWS Systems Manager Session Manager
# (no open port, IAM-authenticated, audited). If SSH is ever needed, set
# ssh_allowed_cidr to a single /32 (e.g. a VPN/bastion address) - never 0.0.0.0/0.
resource "aws_vpc_security_group_ingress_rule" "app_ssh" {
  count             = var.ssh_allowed_cidr == "" ? 0 : 1
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = var.ssh_allowed_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH from one trusted address"
}

resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "ECR, S3, Secrets Manager, SSM, CloudWatch, package repos"
}

resource "aws_vpc_security_group_egress_rule" "app_db" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  description       = "PostgreSQL inside the VPC"
}

resource "aws_vpc_security_group_egress_rule" "app_dns_udp" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  description       = "VPC DNS resolver"
}

resource "aws_vpc_security_group_egress_rule" "app_dns_tcp" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  description       = "VPC DNS resolver (TCP)"
}
