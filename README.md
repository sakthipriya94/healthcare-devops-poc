# Multi-Tenant Healthcare Platform — Cloud Infrastructure & CI/CD POC

A small multi-tenant healthcare application (React + Django REST + PostgreSQL + Nginx) with **database-per-tenant isolation**, Docker Compose for local development, **Terraform** for AWS, and **GitHub Actions** for build → scan → push → deploy → health check.

Cloud: **AWS, `ap-south-1` (Mumbai)**. Tenants are identified by sub-domain (`hospital-a.<domain>`, `hospital-b.<domain>`).

> All patient data is **fictional**. There is no end-user login in this POC (not required by the brief); see [limitations](docs/multi-tenant-database.md#trade-offs-and-limitations-be-honest-in-the-walkthrough).

## Repository layout

| Path | Content |
|---|---|
| `frontend/` | React (Vite) patient list / add form, shows the resolved tenant |
| `backend/` | Django REST API, `tenants/` app (middleware, DB router, registry), `patients/` sample app + isolation tests |
| `docker/` | Multi-stage Dockerfiles, `docker-compose.yml` (local), `docker-compose.prod.yml` (server) |
| `nginx/` | Reverse proxy config and image |
| `database/` | Tenant → DB mapping (`tenants/tenants.json`), provisioning, backup/restore, RDS bootstrap scripts |
| `terraform/` | Reusable modules, per-environment `*.tfvars`, `bootstrap/` (state bucket + GitHub OIDC) |
| `.github/workflows/` | `ci.yml`, `deploy.yml`, `terraform.yml`, Dependabot |
| `scripts/` | `isolation_demo.sh`, host-side `deploy.sh` / `render_env.sh` |
| `docs/` | Architecture, multi-tenant DB, CI/CD, security, multi-region, VPN, monitoring, cost |

## Implemented vs proposed

| Area | Status |
|---|---|
| React, Django, Nginx, PostgreSQL containers; Compose with health checks, restart policies, networks, volume | **Implemented** |
| Two tenants, sub-domain identification, per-tenant DB + role, fail-closed router, isolation tests | **Implemented** |
| DB provisioning, backup (`pg_dump` → S3), restore, access restrictions, troubleshooting guide | **Implemented** |
| Terraform for one region: VPC, subnets, SGs, EC2, ALB, RDS, ECR, S3, IAM, CloudWatch, Secrets Manager | **Implemented** (written; see [verification status](#verification-status)) |
| GitHub Actions: tests, build, Trivy scan, ECR push, deploy via SSM, health check, rollback | **Implemented** (written; runs once you configure GitHub) |
| Dev / staging / prod separation | dev + staging **implemented as config**; prod config **documented, not meant to be applied** |
| Multi-region (Mumbai / Hyderabad / UAE) | **Proposed** — [docs/multi-region.md](docs/multi-region.md) |
| Site-to-site VPN | **Proposed** — [docs/vpn.md](docs/vpn.md) |
| WAF, GuardDuty, KMS CMKs, end-user auth, PHI audit trail, ALB access logs | **Proposed / out of scope** |

## Documentation map (brief § 10)

| Deliverable | Where |
|---|---|
| Cloud architecture diagram | [docs/architecture.md](docs/architecture.md) |
| Multi-tenant database diagram | [docs/multi-tenant-database.md](docs/multi-tenant-database.md) |
| CI/CD workflow diagram, environments, approval, rollback | [docs/ci-cd.md](docs/ci-cd.md) |
| Security and networking | [docs/security-networking.md](docs/security-networking.md) |
| Multi-region proposal | [docs/multi-region.md](docs/multi-region.md) |
| VPN diagram | [docs/vpn.md](docs/vpn.md) |
| Monitoring + outage runbook | [docs/monitoring-troubleshooting.md](docs/monitoring-troubleshooting.md) |
| Estimated cost (before provisioning) | [docs/cost-estimate.md](docs/cost-estimate.md) |
| Screenshots / video | **You record these** — see [Demo script](#demo-script-for-the-walkthrough) |

Diagrams are Mermaid and render directly on GitHub.

---

## 1. Run locally with Docker Compose

Prerequisites: Docker with Compose v2, `make`, `curl`.

```bash
cp .env.example .env          # then replace every "change-me" value
#   openssl rand -base64 32 | tr -d '/+='    generates good passwords
make up                       # builds 4 images, starts db, backend, frontend, nginx
make ps                       # all services should become "healthy"
```

Open **http://hospital-a.localhost** and **http://hospital-b.localhost** (`*.localhost` resolves to 127.0.0.1 in current browsers and curl). Each shows its own tenant name and patients.

```bash
make isolation-demo           # proves A cannot see B (API + database level)
make logs                     # follow logs
make down                     # stop (data kept in the pgdata volume)
make up                       # start again - data is still there
make reset                    # stop AND delete the database volume
```

Backend tests need no Docker or Postgres (SQLite stand-in):

```bash
python -m venv .venv && . .venv/bin/activate
pip install -r backend/requirements-dev.txt
make test                     # 12 tests incl. cross-tenant access attempts
```

Security notes for local: `.env` is git-ignored; the database is on an `internal` Docker network (no host or internet access); only Nginx publishes a port; containers run as non-root.

## 2. Deploy to AWS with Terraform

Prerequisites: AWS account + admin credentials in your shell, Terraform ≥ 1.10, a GitHub repo containing this code. **Read [docs/cost-estimate.md](docs/cost-estimate.md) first** (≈ USD 70/month while running; destroy after the demo) and create an AWS Budget alert.

```bash
# 2.1 One-time bootstrap: state bucket + GitHub OIDC roles (local state)
cd terraform/bootstrap
terraform init
terraform apply -var github_repository=<OWNER>/<REPO>
#   note the outputs: state_bucket, ecr_push_role_arn, terraform_plan_role_arn

# 2.2 Configure the dev environment
cd ..
cp environments/backend.hcl.example environments/dev.backend.hcl   # set bucket = <state_bucket>, key = healthcare/dev/terraform.tfstate
$EDITOR environments/dev.tfvars                                    # set github_repository (optional: domain, certificate, alert_email)

# 2.3 Create the infrastructure
terraform init -backend-config=environments/dev.backend.hcl
terraform plan  -var-file=environments/dev.tfvars -out=tfplan
terraform apply tfplan
#   note: alb_dns_name, instance_id, artifacts_bucket, github_deploy_role_arn
```

No secret appears in any tfvars file: DB passwords and the Django key are **generated by Terraform and stored in Secrets Manager**; the RDS master password is managed by RDS.

> First run order matters: `manage_ecr = true` in `dev.tfvars` creates the shared ECR repositories. Apply **dev first**; staging/prod look the repositories up.

### Recreate the infrastructure (demonstrates repeatability)

```bash
terraform destroy -var-file=environments/dev.tfvars     # tears everything down (dev has no deletion protection)
terraform apply   -var-file=environments/dev.tfvars     # identical environment again, ~10-15 min
# then run the Deploy workflow to put the application back
```

Everything is code + a state file; the host holds no unique state (stateless containers, data in RDS, backups in S3).

## 3. Configure GitHub and run the pipeline

1. **Settings → Environments**: create `dev`, `staging`, `prod`. On each, add variables: `AWS_REGION`, `AWS_DEPLOY_ROLE_ARN` (`github_deploy_role_arn` output), `INSTANCE_ID`, `ARTIFACTS_BUCKET`, `APP_URL` (e.g. `http://<alb_dns_name>`), `TENANT_HOSTS` (e.g. `hospital-a.<alb_dns_name> hospital-b.<alb_dns_name>`). On `prod`: add **required reviewers** and restrict branches to `main`.
2. **Settings → Secrets and variables → Actions → Variables** (repository): `AWS_REGION`, `AWS_ECR_PUSH_ROLE_ARN`, and optionally `TF_PLAN_ROLE_ARN`, `TF_STATE_BUCKET`.
3. Push to `develop` → CI validates, builds, scans, pushes to ECR, deploys to **dev**, and health-checks it. Push to `main` → same for **staging**. Production: **Actions → Deploy → prod → image tag**, then a reviewer approves.
4. Roll back at any time: **Actions → Deploy → action = rollback**.

No GitHub secrets and no AWS access keys are needed (OIDC). Details: [docs/ci-cd.md](docs/ci-cd.md).

**Tenant URLs without a domain.** With only the ALB DNS name, the sub-domain trick doesn't resolve, so test with a Host header:

```bash
BASE=http://<alb_dns_name> A_HOST=hospital-a.<alb_dns_name> B_HOST=hospital-b.<alb_dns_name> bash scripts/isolation_demo.sh
```

With a domain, set `domain_name`, `route53_zone_id`, `certificate_arn` in tfvars (wildcard `*.domain` record + ACM certificate) to get real `https://hospital-a.<domain>`.

## 4. Onboarding a new tenant

Short version: add an entry to `database/tenants/tenants.json`, add its password variable to the Terraform `tenants` map, deploy (the pipeline creates the database/role and runs migrations). Full steps: [docs/multi-tenant-database.md](docs/multi-tenant-database.md#5-onboarding-a-new-tenant-eg-hospital_c).

## 5. Backup, restore and troubleshooting

* RDS automated backups (7 days dev / 35 prod) + nightly per-tenant `pg_dump` to S3 (`database/scripts/backup.sh`, cron installed by Terraform user data).
* Verify a backup: `restore.sh <db> <s3-key>` restores into `<db>_restore_test`, never over live data.
* Connection problems and outage investigation: [docs/monitoring-troubleshooting.md](docs/monitoring-troubleshooting.md).

## Verification status

What was **actually run** while building this repo, in a sandbox without a Docker daemon or AWS access:

| Check | Result |
|---|---|
| 12 Django tests (tenant isolation, unknown tenant, header spoofing, fail-closed, health) on SQLite | Pass |
| App against **real PostgreSQL 16**: migrations for both tenants, seed, HTTP isolation (B reading A's record → 404, unknown tenant → 404, `/api/health/` ok) | Pass |
| `provision_tenants.sh` against Postgres: idempotent, handles passwords with quotes/`$`; role A denied `CONNECT` to DB B | Pass |
| `pg_dump` / `pg_restore` round trip with tenant credentials | Pass |
| `flake8`, `shellcheck`, React production build, YAML parse of all workflows and compose files, `docker compose config` for both stacks | Pass |
| All Terraform parsed as valid HCL2 | Pass |

What was **not** run, and must be validated by you before relying on it:

* `docker compose up` / image builds (no Docker daemon was available) — run `make up` and fix anything that surfaces.
* `terraform init/validate/plan/apply` (Terraform could not be installed) — run `terraform fmt -recursive` and `terraform validate`; the CI `terraform.yml` workflow does this on pull requests.
* The GitHub Actions workflows, SSM-based deploy and AWS-side scripts (`deploy.sh`, `render_env.sh`, `bootstrap_rds.sh`) — they have only been syntax-checked.

Expect a small number of first-run fixes; that is normal for infrastructure code that hasn't met a real account yet.

## Demo script for the walkthrough

The brief asks for screenshots or a short video and a 15–20 minute walkthrough. Suggested flow (≈ 15 min):

1. **Architecture** (3 min): open [architecture.md](docs/architecture.md); explain request flow and the public/private split.
2. **Local stack** (2 min): `make up`, `make ps` (healthy), open both tenant URLs, `make down` / `make up` to show the persistent volume.
3. **Isolation** (3 min): `make isolation-demo`; show `tenants.json`, `router.py`, and the DB-level `permission denied`.
4. **Pipeline** (3 min): push a commit, show tests → build → Trivy → ECR → deploy → health check; show a deliberately failing scan or health check and the automatic rollback.
5. **Cloud** (2 min): ALB URL, CloudWatch dashboard, a Logs Insights query filtered by `tenant=`.
6. **Proposals** (2 min): multi-region and VPN diagrams; state clearly these are designs, not deployed.

Capture screenshots of: Compose healthy status, both tenant pages, isolation demo output, a green workflow run, ECR images, the CloudWatch dashboard, and the Terraform apply output.

## Acceptance-criteria checklist

| # | Criterion | Where |
|---|---|---|
| 1–3 | Containers build/run; Compose works locally | §1, `docker/` |
| 4–6 | Two tenants, mapping, cross-tenant blocked | `database/tenants/tenants.json`, `backend/tenants/`, `make isolation-demo` |
| 7 | Actions builds and publishes images | `ci.yml` |
| 8 | Cloud deployment | §2–3 (you run it) |
| 9 | Terraform provided | `terraform/` |
| 10 | No credentials in source | `.gitignore`, `.env.example`, Secrets Manager |
| 11 | Monitoring and logs | `modules/monitoring`, [docs](docs/monitoring-troubleshooting.md) |
| 12 | Multi-region, VPN, backup, recovery documented | `docs/` |
