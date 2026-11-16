output "repository_urls" { value = local.repos }
output "repository_arns" { value = local.arns }
output "registry" {
  description = "<account>.dkr.ecr.<region>.amazonaws.com"
  value       = split("/", values(local.repos)[0])[0]
}
