# Deployment and Verification Instructions

## 1. Current DEV deployment

- AWS region: `ap-south-1` (Mumbai)
- Application URL: http://healthcare-dev-alb-1349434775.ap-south-1.elb.amazonaws.com
- Compute: EC2
- Database: private Amazon RDS PostgreSQL
- Container registry: Amazon ECR
- Deployment: GitHub Actions, S3 and AWS Systems Manager

The DEV infrastructure is already provisioned. These instructions describe how to inspect and verify it. Do not apply or destroy infrastructure just to demonstrate the project.

## 2. Local prerequisites

Install Git, Docker Desktop with Docker Compose, Python, AWS CLI and Terraform.

```bash
git clone https://github.com/sakthipriya94/healthcare-devops-poc.git
cd healthcare-devops-poc
```

Follow the repository's environment setup instructions. Do not commit `.env` files, passwords or cloud credentials.

## 3. Run with Docker Compose

From the directory containing the applicable Compose file, run:

```bash
docker compose up -d --build
docker compose ps
docker compose logs --tail=100
```

Stop the local stack:

```bash
docker compose down
```

Use the actual Compose file path or Makefile target if the repository specifies one. Verify health checks and persistent database storage using the Compose configuration.

## 4. Terraform initialization and review

The DEV backend configuration is `terraform/environments/dev.backend.hcl`.

```bash
terraform -chdir=terraform init -backend-config=environments/dev.backend.hcl
terraform -chdir=terraform validate
terraform -chdir=terraform plan -var-file=environments/dev.tfvars
```

Review the plan and backend state before any change. Do not run `terraform apply` or `terraform destroy` during the interview walkthrough unless an infrastructure change is explicitly intended and approved.

## 5. Verify AWS DEV endpoints

```bash
APP_URL="http://healthcare-dev-alb-1349434775.ap-south-1.elb.amazonaws.com"

curl -i --max-time 20 "$APP_URL/api/health/"
curl -i --max-time 20 "$APP_URL/api/live/"
curl -i --max-time 20 -H "Host: hospital-a.local" "$APP_URL/api/tenant/"
curl -i --max-time 20 -H "Host: hospital-b.local" "$APP_URL/api/tenant/"
```

Expected observations from the verified deployment:

- Health endpoint returns HTTP 200 and reports both tenant databases as up.
- Live endpoint returns HTTP 200.
- Hospital A resolves to `hospital_a`.
- Hospital B resolves to `hospital_b`.

## 6. Run tenant tests

The previously completed automated test run used in-memory SQLite:

```bash
cd backend

DJANGO_DEBUG=true DJANGO_SECRET_KEY='local-only-test-key-do-not-use-in-production' TENANT_DB_ENGINE=sqlite TENANTS_FILE='../database/tenants/tenants.json' python manage.py test patients.tests -v 2
```

The previous run passed 12 tests. These SQLite tests are separate from AWS RDS endpoint verification.

## 7. CI/CD deployment

Review `.github/workflows/ci.yml`, `.github/workflows/deploy.yml` and `.github/workflows/terraform.yml`. Show a successful Actions run, the corresponding ECR images and the deployed application health checks.

## 8. Environment status

DEV is implemented. Staging and production are not currently provisioned. Production should include HTTPS, approved deployment, production authentication and authorization, backups, and a tested rollback/recovery procedure.

## 9. Safety

- Never commit secrets or database passwords.
- Keep RDS private.
- Review Terraform plans before changes.
- Keep the current DEV deployment available for the walkthrough.
- The current DEV application uses HTTP; HTTPS is a production follow-up.
