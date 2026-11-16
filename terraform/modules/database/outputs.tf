output "address" { value = aws_db_instance.this.address }
output "identifier" { value = aws_db_instance.this.identifier }
output "master_secret_arn" { value = aws_db_instance.this.master_user_secret[0].secret_arn }
output "tenant_secret_arn" { value = aws_secretsmanager_secret.tenant_db.arn }
output "django_secret_arn" { value = aws_secretsmanager_secret.django.arn }
output "secret_arns" {
  value = [
    aws_db_instance.this.master_user_secret[0].secret_arn,
    aws_secretsmanager_secret.tenant_db.arn,
    aws_secretsmanager_secret.django.arn,
  ]
}
