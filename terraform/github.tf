# Wires this stack's outputs into GitHub so the deploy workflow needs no manual copy/paste.
# Enabled with manage_github = true; authenticate with the GITHUB_TOKEN environment variable.

locals {
  github_repo_name = split("/", var.github_repository)[1]
  public_base      = var.domain_name != "" ? var.domain_name : module.compute.alb_dns_name
  public_scheme    = var.certificate_arn != "" ? "https" : "http"

  github_environment_variables = {
    AWS_REGION          = var.aws_region
    AWS_DEPLOY_ROLE_ARN = module.cicd.deploy_role_arn
    INSTANCE_ID         = module.compute.instance_id
    ARTIFACTS_BUCKET    = module.storage.artifacts_bucket
    APP_URL             = "${local.public_scheme}://${local.public_base}"
    TENANT_HOSTS        = join(" ", [for t in keys(var.tenants) : "${replace(t, "_", "-")}.${local.public_base}"])
  }
}

resource "github_repository_environment" "this" {
  count       = var.manage_github ? 1 : 0
  repository  = local.github_repo_name
  environment = var.environment
}

resource "github_actions_environment_variable" "this" {
  for_each      = var.manage_github ? local.github_environment_variables : {}
  repository    = local.github_repo_name
  environment   = github_repository_environment.this[0].environment
  variable_name = each.key
  value         = each.value
}
