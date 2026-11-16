variable "project" { type = string }
variable "environment" { type = string }
variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "log_retention_days" {
  type    = number
  default = 14
}
