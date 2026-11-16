data "aws_caller_identity" "current" {}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  name = "${var.project}-${var.environment}"
}

# Role assumed by GitHub Actions (OIDC - no long-lived AWS keys in GitHub).
# The trust policy only accepts jobs that run in the matching GitHub
# *environment*, so production deploys must pass the environment's approval gate.
data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:environment:${var.environment}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name                 = "${local.name}-github-deploy"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "UploadDeployBundle"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
    resources = ["${var.artifacts_bucket_arn}/*"]
  }
  statement {
    sid       = "ListDeployBundle"
    actions   = ["s3:ListBucket"]
    resources = [var.artifacts_bucket_arn]
  }
  statement {
    sid     = "RunDeployOnTheHost"
    actions = ["ssm:SendCommand"]
    resources = [
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/${var.instance_id}",
      "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
    ]
  }
  statement {
    sid       = "ReadCommandResult"
    actions   = ["ssm:GetCommandInvocation", "ssm:ListCommandInvocations"]
    resources = ["*"]
  }
  statement {
    sid       = "DeployState"
    actions   = ["ssm:GetParameter", "ssm:PutParameter"]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/${var.environment}/*"]
  }
  statement {
    sid       = "VerifyImageExists"
    actions   = ["ecr:DescribeImages"]
    resources = var.ecr_repository_arns
  }
  statement {
    sid       = "PostDeployChecks"
    actions   = ["elasticloadbalancing:DescribeTargetHealth"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
