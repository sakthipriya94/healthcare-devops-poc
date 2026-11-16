variable "project" { type = string }
variable "environment" { type = string }
variable "force_destroy" {
  type    = bool
  default = false
}
variable "backup_retention_days" {
  type    = number
  default = 90
}
