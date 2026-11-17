variable "project" {
  type    = string
  default = "healthcare"
}

variable "environment" {
  description = "dev | staging | prod"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "aws_region" {
  type    = string
  default = "ap-south-1" # Mumbai
}

# ---- networking
variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}
variable "availability_zones" {
  type    = list(string)
  default = ["ap-south-1a", "ap-south-1b"]
}
variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.0.0/24", "10.10.1.0/24"]
}
variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.10.0/24", "10.10.11.0/24"]
}
variable "ssh_allowed_cidr" {
  description = "Single trusted CIDR allowed to SSH. Empty = SSH closed (use SSM Session Manager)."
  type        = string
  default     = ""
}

# ---- compute
variable "instance_type" {
  type    = string
  default = "t3.small"
}

# ---- database
variable "tenants" {
  description = "tenant id => env var carrying its DB password. Keep in sync with database/tenants/tenants.json."
  type        = map(string)
  default = {
    hospital_a = "HOSPITAL_A_DB_PASSWORD"
    hospital_b = "HOSPITAL_B_DB_PASSWORD"
  }
}
variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}
variable "db_allocated_storage" {
  type    = number
  default = 20
}
variable "db_multi_az" {
  type    = bool
  default = false
}
variable "db_backup_retention_days" {
  type    = number
  default = 7
}
variable "protect_data" {
  description = "Deletion protection, final snapshot and secret recovery window (true for prod)."
  type        = bool
  default     = false
}

# ---- edge / DNS / TLS
variable "certificate_arn" {
  description = "ACM certificate (wildcard) in this region. Empty = HTTP only (demo, synthetic data only)."
  type        = string
  default     = ""
}
variable "domain_name" {
  description = "Base domain, e.g. example.com. Tenants are served at <tenant>.<domain>."
  type        = string
  default     = ""
}
variable "route53_zone_id" {
  type    = string
  default = ""
}

# ---- registry / CI
variable "manage_ecr" {
  description = "Create the shared ECR repositories in this environment (true in exactly one: dev)."
  type        = bool
  default     = false
}
variable "github_repository" {
  description = "owner/repo allowed to deploy to this environment via OIDC."
  type        = string
}

# ---- monitoring
variable "alert_email" {
  type    = string
  default = ""
}
variable "log_retention_days" {
  type    = number
  default = 14
}

variable "manage_github" {
  description = "Also write the GitHub Actions variables the deploy workflow needs (INSTANCE_ID, ARTIFACTS_BUCKET, APP_URL, ...). Needs a GITHUB_TOKEN with repo scope in the environment."
  type        = bool
  default     = false
}
