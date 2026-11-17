# One-time, per AWS account. Creates:
#   * the encrypted, versioned S3 bucket that holds Terraform state
#   * the GitHub OIDC identity provider (so Actions needs no AWS access keys)
#   * a role GitHub uses to push images to ECR (push only)
#   * a read-only role GitHub uses for `terraform plan` on pull requests
# Apply this stack with local state, from your own admin credentials:
#   cd terraform/bootstrap && terraform init && terraform apply -var github_repository=OWNER/REPO
terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.80" }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = { Project = var.project, ManagedBy = "terraform", Stack = "bootstrap" }
  }
}

variable "project" {
  type    = string
  default = "healthcare"
}
variable "aws_region" {
  type    = string
  default = "ap-south-1"
}
variable "github_repository" {
  description = "owner/repo"
  type        = string
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  state_bkt  = "${var.project}-tfstate-${local.account_id}-${var.aws_region}"
}

# ------------------------------------------------------ remote state ------
resource "aws_s3_bucket" "state" {
  bucket = local.state_bkt
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------- GitHub OIDC ---------
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "trust_ci" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:sakthipriya94@299290563/healthcare-devops-poc@1460570506:ref:refs/heads/main",
        "repo:sakthipriya94@299290563/healthcare-devops-poc@1460570506:ref:refs/heads/develop",
        "repo:sakthipriya94@299290563/healthcare-devops-poc@1460570506:environment:dev",
        "repo:sakthipriya94@299290563/healthcare-devops-poc@1460570506:environment:staging",
        "repo:sakthipriya94@299290563/healthcare-devops-poc@1460570506:environment:prod",
      ]
    }
  }
}

# --- push-only role for image builds (branches main/develop only) ----------
resource "aws_iam_role" "ecr_push" {
  name               = "${var.project}-github-ecr-push"
  assume_role_policy = data.aws_iam_policy_document.trust_ci.json
}

data "aws_iam_policy_document" "ecr_push" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:DescribeImages",
      "ecr:DescribeImageScanFindings",
    ]
    resources = ["arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${var.project}-*"]
  }
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "ecr-push"
  role   = aws_iam_role.ecr_push.id
  policy = data.aws_iam_policy_document.ecr_push.json
}

# --- read-only role for `terraform plan` on pull requests ------------------
data "aws_iam_policy_document" "trust_plan" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:sakthipriya94@299290563/healthcare-devops-poc@1460570506:pull_request",
        "repo:sakthipriya94@299290563/healthcare-devops-poc@1460570506:ref:refs/heads/*",
      ]
    }
  }
}

resource "aws_iam_role" "tf_plan" {
  name               = "${var.project}-github-terraform-plan"
  assume_role_policy = data.aws_iam_policy_document.trust_plan.json
}

resource "aws_iam_role_policy_attachment" "tf_plan_readonly" {
  role       = aws_iam_role.tf_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "tf_plan_state" {
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"] # .tflock file for state locking
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }
}

resource "aws_iam_role_policy" "tf_plan_state" {
  name   = "state-access"
  role   = aws_iam_role.tf_plan.id
  policy = data.aws_iam_policy_document.tf_plan_state.json
}

output "state_bucket" { value = aws_s3_bucket.state.bucket }
output "ecr_push_role_arn" { value = aws_iam_role.ecr_push.arn }
output "terraform_plan_role_arn" { value = aws_iam_role.tf_plan.arn }
