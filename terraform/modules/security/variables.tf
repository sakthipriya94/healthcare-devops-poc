variable "project" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }
variable "ssh_allowed_cidr" {
  type    = string
  default = ""
}
