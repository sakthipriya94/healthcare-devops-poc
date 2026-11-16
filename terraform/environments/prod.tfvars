# Production profile (documented; NOT applied for the POC to avoid cost).
environment       = "prod"
aws_region        = "ap-south-1"
github_repository = "YOUR_GITHUB_USER/healthcare-multitenant-poc" # <-- change

manage_ecr = false

vpc_cidr             = "10.30.0.0/16"
public_subnet_cidrs  = ["10.30.0.0/24", "10.30.1.0/24"]
private_subnet_cidrs = ["10.30.10.0/24", "10.30.11.0/24"]

instance_type            = "t3.medium"
db_instance_class        = "db.t4g.medium"
db_allocated_storage     = 100
db_multi_az              = true # standby in a second AZ
db_backup_retention_days = 35
protect_data             = true # deletion protection + final snapshot

# Production must use HTTPS with a real certificate and domain
domain_name     = "healthcare.example.com"
route53_zone_id = "Z_REPLACE_ME"
certificate_arn = "arn:aws:acm:ap-south-1:111111111111:certificate/REPLACE-ME"
alert_email     = "oncall@example.com"
