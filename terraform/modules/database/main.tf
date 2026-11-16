locals {
  name = "${var.project}-${var.environment}"
}

# ---------------------------------------------------------------- RDS ------
resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "db" {
  name        = "${local.name}-rds"
  description = "PostgreSQL: only the application host may connect"
  vpc_id      = var.vpc_id
  tags        = { Name = "${local.name}-rds-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = var.app_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "PostgreSQL from application host only"
}

# Force TLS for every client connection
resource "aws_db_parameter_group" "this" {
  name   = "${local.name}-pg16"
  family = "postgres16"
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
  parameter {
    name         = "log_connections"
    value        = "1"
    apply_method = "immediate"
  }
}

resource "aws_db_instance" "this" {
  identifier        = "${local.name}-postgres"
  engine            = "postgres"
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  username                    = "dbadmin"
  manage_master_user_password = true # master password lives in Secrets Manager, never in state/code

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period    = var.backup_retention_days # automated daily backups + point-in-time recovery
  backup_window              = "21:00-22:00"             # 02:30-03:30 IST
  maintenance_window         = "sun:22:00-sun:23:00"
  copy_tags_to_snapshot      = true
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = !var.deletion_protection
  final_snapshot_identifier  = var.deletion_protection ? "${local.name}-final" : null
  auto_minor_version_upgrade = true

  enabled_cloudwatch_logs_exports = ["postgresql"]
  performance_insights_enabled    = false
}

# ------------------------------------------- application secrets ----------
# One strong random password per tenant role; stored only in Secrets Manager.
# NOTE: random_password values are also kept in Terraform state, so the state
# bucket must be encrypted and access-restricted (see bootstrap/).
resource "random_password" "tenant" {
  for_each = var.tenants
  length   = 32
  special  = false
}

resource "random_password" "django" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "tenant_db" {
  name                    = "${var.project}/${var.environment}/tenant-db-credentials"
  description             = "Per-tenant PostgreSQL role passwords, keyed by env var name"
  recovery_window_in_days = var.deletion_protection ? 30 : 0
}

resource "aws_secretsmanager_secret_version" "tenant_db" {
  secret_id = aws_secretsmanager_secret.tenant_db.id
  secret_string = jsonencode({
    for tenant_id, password_env in var.tenants : password_env => random_password.tenant[tenant_id].result
  })
}

resource "aws_secretsmanager_secret" "django" {
  name                    = "${var.project}/${var.environment}/django"
  description             = "Django SECRET_KEY"
  recovery_window_in_days = var.deletion_protection ? 30 : 0
}

resource "aws_secretsmanager_secret_version" "django" {
  secret_id     = aws_secretsmanager_secret.django.id
  secret_string = jsonencode({ DJANGO_SECRET_KEY = random_password.django.result })
}
