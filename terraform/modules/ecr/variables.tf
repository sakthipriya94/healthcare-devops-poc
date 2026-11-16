variable "project" { type = string }
variable "create" {
  type        = bool
  description = "Create the repositories (true in exactly one environment) or look up existing ones."
}
variable "force_delete" {
  type    = bool
  default = false
}
variable "keep_images" {
  type    = number
  default = 20
}
