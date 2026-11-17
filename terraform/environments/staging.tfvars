environment       = "staging"
aws_region        = "ap-south-1"
github_repository = "sakthipriya94/healthcare-devops-poc"

manage_ecr = false # uses the repositories created by the dev environment

# Distinct, non-overlapping address space (allows VPC peering / VPN later)
vpc_cidr             = "10.20.0.0/16"
public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24"]
private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24"]

instance_type            = "t3.small"
db_instance_class        = "db.t4g.micro"
db_allocated_storage     = 20
db_multi_az              = false
db_backup_retention_days = 7
protect_data             = false
