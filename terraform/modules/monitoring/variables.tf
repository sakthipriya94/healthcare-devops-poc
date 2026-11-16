variable "project" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "instance_id" { type = string }
variable "alb_arn_suffix" { type = string }
variable "target_group_arn_suffix" { type = string }
variable "db_identifier" { type = string }
variable "container_log_group" { type = string }
variable "alert_email" {
  type    = string
  default = ""
}
variable "db_connections_threshold" {
  type    = number
  default = 60
}
