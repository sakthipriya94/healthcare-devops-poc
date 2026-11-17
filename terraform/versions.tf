terraform {
  required_version = ">= 1.10.0" # S3 native state locking (use_lockfile)

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  # Partial configuration: supply the bucket/key per environment at init time
  #   terraform init -backend-config=environments/dev.backend.hcl
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Used only when manage_github = true. Authenticates with the GITHUB_TOKEN environment variable
# (a personal access token with "repo" scope - never put it in a tfvars file).
provider "github" {
  owner = split("/", var.github_repository)[0]
}
