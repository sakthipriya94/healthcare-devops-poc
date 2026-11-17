# CI/CD design (GitHub Actions)

Workflow files: [`ci.yml`](../.github/workflows/ci.yml), [`deploy.yml`](../.github/workflows/deploy.yml), [`terraform.yml`](../.github/workflows/terraform.yml).

## Workflow diagram

The `develop` branch triggers validation, frontend and backend builds, Trivy scans, immutable ECR image pushes, and automatic deployment to AWS DEV through S3 and SSM. Post-deployment checks verify application health and tenant endpoints.

Staging deployment has been removed. Production deployment is not enabled in this POC.

## Stages in detail

| # | Stage | Detail | Fails the build when |
|---|---|---|---|
| 1 | Backend | `flake8`, `manage.py check`, `makemigrations --check`, isolation tests on SQLite | lint error, missing migration, any test fails (incl. cross-tenant tests) |
| 1 | Frontend | `npm ci` + `vite build` | build error |
| 1 | Config | `docker compose config` for local + server stacks, `shellcheck` | invalid YAML / risky shell |
| 2 | Build | BuildKit with GitHub cache, one matrix job per image | build error |
| 3 | Scan | Trivy on the built image (OS + libraries), CRITICAL/HIGH with a fix available | fixable HIGH/CRITICAL vulnerability |
| 4 | Push | `aws-actions/configure-aws-credentials` via **OIDC**, tag = `${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}`, ECR tags are **immutable** | on configured push branches; DEV deployment runs on `develop` |
| 5 | Deploy | S3 bundle → SSM Run Command → `deploy.sh` (pull, `up -d`, health check) | deployment or host health check fails |
| 6 | Verify | `GET /api/health/` through the ALB (checks **every tenant DB**) + `GET /api/tenant/` per tenant host | non-200 or unhealthy |

Tags combine the commit SHA, workflow run ID and attempt. ECR immutability prevents an existing tag from being overwritten.

## Environment strategy

| Area | Development | UAT / Staging | Production |
|---|---|---|---|
| Status | **Deployed and verified on AWS** | Not deployed; resources destroyed | Not deployed |
| Deployment | Automatic push to `develop` | Not enabled | Not enabled |
| Terraform | `environments/dev.tfvars` | Configuration retained for reference | Proposed configuration |
| Region | AWS Mumbai (`ap-south-1`) | Proposed | Proposed |
| HTTPS | HTTP for synthetic POC data | HTTPS required | HTTPS required |
| Data | Synthetic demonstration data | Synthetic or anonymised data | Protected production data |
| Monitoring | CloudWatch dashboard, alarms and logs | To be configured | Enhanced monitoring required |

The assignment does not require all three environments to be provisioned. This POC implements DEV and documents how Staging and Production can be introduced later.

### Configuration separation

- Keep environment-specific configuration separate.
- Store secrets in AWS Secrets Manager, not source code.
- Use separate Terraform state, databases, secrets and IAM roles for isolated environments.
- Consider a separate AWS account for Production.

## Production approval

Production deployment is not enabled in the current workflow. A future production release should use a dedicated GitHub Environment with required reviewers, restricted deployment branches, and a separate production OIDC IAM role. Approval must happen before production deployment credentials are issued.

## Rollback strategy

Immutable image versions make it possible to select a previously successful version for redeployment.

| Situation | Recommended response |
|---|---|
| Deployment health check fails | Stop the release, inspect logs and restore the last known-good image if rollback is configured |
| Issue discovered after deployment | Redeploy a previously successful image tag |
| Database migration failure | Use backward-compatible migrations and restore from a verified backup when necessary |
| Infrastructure change failure | Review and safely revert the Terraform change |

**Verification note:** DEV deployment and health checks have passed. An induced deployment failure and rollback have not been demonstrated.

## Setting it up (one time)

```text
GitHub repo -> Settings -> Environments: configure dev (the only deployed environment)
  Variables on each environment:
    AWS_REGION, AWS_DEPLOY_ROLE_ARN (terraform output github_deploy_role_arn),
    INSTANCE_ID, ARTIFACTS_BUCKET, APP_URL, TENANT_HOSTS
  Future production setup: configure required reviewers and restrict deployment branches.
GitHub repo -> Settings -> Secrets and variables -> Actions -> Variables (repository):
    AWS_REGION, AWS_ECR_PUSH_ROLE_ARN (bootstrap output), TF_PLAN_ROLE_ARN, TF_STATE_BUCKET
```

No GitHub *secrets* are needed at all.
