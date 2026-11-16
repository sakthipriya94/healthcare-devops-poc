module "network" {
  source               = "./modules/network"
  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  azs                  = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  log_retention_days   = var.log_retention_days
}

module "security" {
  source           = "./modules/security"
  project          = var.project
  environment      = var.environment
  vpc_id           = module.network.vpc_id
  vpc_cidr         = module.network.vpc_cidr
  ssh_allowed_cidr = var.ssh_allowed_cidr
}

module "ecr" {
  source       = "./modules/ecr"
  project      = var.project
  create       = var.manage_ecr
  force_delete = !var.protect_data
}

module "storage" {
  source        = "./modules/storage"
  project       = var.project
  environment   = var.environment
  force_destroy = !var.protect_data
}

module "database" {
  source                = "./modules/database"
  project               = var.project
  environment           = var.environment
  vpc_id                = module.network.vpc_id
  private_subnet_ids    = module.network.private_subnet_ids
  app_security_group_id = module.security.app_security_group_id
  tenants               = var.tenants
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
  deletion_protection   = var.protect_data
}

module "compute" {
  source                = "./modules/compute"
  project               = var.project
  environment           = var.environment
  aws_region            = var.aws_region
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  app_security_group_id = module.security.app_security_group_id
  alb_security_group_id = module.security.alb_security_group_id
  instance_type         = var.instance_type
  db_address            = module.database.address
  db_master_secret_arn  = module.database.master_secret_arn
  secret_arns           = module.database.secret_arns
  ecr_registry          = module.ecr.registry
  ecr_repository_arns   = module.ecr.repository_arns
  artifacts_bucket      = module.storage.artifacts_bucket
  artifacts_bucket_arn  = module.storage.artifacts_bucket_arn
  backups_bucket        = module.storage.backups_bucket
  backups_bucket_arn    = module.storage.backups_bucket_arn
  certificate_arn       = var.certificate_arn
  domain_name           = var.domain_name
  route53_zone_id       = var.route53_zone_id
  log_retention_days    = var.log_retention_days
}

module "monitoring" {
  source                  = "./modules/monitoring"
  project                 = var.project
  environment             = var.environment
  aws_region              = var.aws_region
  instance_id             = module.compute.instance_id
  alb_arn_suffix          = module.compute.alb_arn_suffix
  target_group_arn_suffix = module.compute.target_group_arn_suffix
  db_identifier           = module.database.identifier
  container_log_group     = module.compute.container_log_group
  alert_email             = var.alert_email
}

module "cicd" {
  source               = "./modules/cicd"
  project              = var.project
  environment          = var.environment
  aws_region           = var.aws_region
  github_repository    = var.github_repository
  instance_id          = module.compute.instance_id
  artifacts_bucket_arn = module.storage.artifacts_bucket_arn
  ecr_repository_arns  = module.ecr.repository_arns
}
