variable "project" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "app_security_group_id" { type = string }
variable "alb_security_group_id" { type = string }

variable "instance_type" {
  type    = string
  default = "t3.small"
}
variable "root_volume_gb" {
  type    = number
  default = 20
}
variable "compose_version" {
  type    = string
  default = "v2.32.4"
}

variable "db_address" { type = string }
variable "db_master_secret_arn" { type = string }
variable "secret_arns" { type = list(string) }
variable "ecr_registry" { type = string }
variable "ecr_repository_arns" { type = list(string) }
variable "artifacts_bucket" { type = string }
variable "artifacts_bucket_arn" { type = string }
variable "backups_bucket" { type = string }
variable "backups_bucket_arn" { type = string }

variable "certificate_arn" {
  type    = string
  default = ""
}
variable "domain_name" {
  type    = string
  default = ""
}
variable "route53_zone_id" {
  type    = string
  default = ""
}
variable "extra_allowed_hosts" {
  type    = list(string)
  default = []
}
variable "log_retention_days" {
  type    = number
  default = 14
}
