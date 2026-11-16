output "artifacts_bucket" { value = aws_s3_bucket.this["artifacts"].bucket }
output "artifacts_bucket_arn" { value = aws_s3_bucket.this["artifacts"].arn }
output "backups_bucket" { value = aws_s3_bucket.this["db-backups"].bucket }
output "backups_bucket_arn" { value = aws_s3_bucket.this["db-backups"].arn }
