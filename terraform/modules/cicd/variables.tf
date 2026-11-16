variable "project" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "github_repository" {
  description = "owner/repo that may assume the deploy role"
  type        = string
}
variable "instance_id" { type = string }
variable "artifacts_bucket_arn" { type = string }
variable "ecr_repository_arns" { type = list(string) }
