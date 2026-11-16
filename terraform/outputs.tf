output "alb_dns_name" {
  description = "Public entry point. Tenants: hospital-a.<domain> / hospital-b.<domain> (or curl -H 'Host: hospital-a.<alb-dns>')."
  value       = module.compute.alb_dns_name
}
output "instance_id" {
  description = "Application host (connect with: aws ssm start-session --target <id>)"
  value       = module.compute.instance_id
}
output "ecr_repository_urls" { value = module.ecr.repository_urls }
output "ecr_registry" { value = module.ecr.registry }
output "artifacts_bucket" { value = module.storage.artifacts_bucket }
output "backups_bucket" { value = module.storage.backups_bucket }
output "rds_address" { value = module.database.address }
output "rds_master_secret_arn" { value = module.database.master_secret_arn }
output "github_deploy_role_arn" {
  description = "Set as the AWS_DEPLOY_ROLE_ARN variable of the matching GitHub environment"
  value       = module.cicd.deploy_role_arn
}
output "dashboard" { value = module.monitoring.dashboard_name }
output "alerts_topic_arn" { value = module.monitoring.alerts_topic_arn }
