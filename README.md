
# Multi-Tenant Healthcare Application — Cloud Infrastructure & CI/CD POC

A multi-tenant healthcare application demonstrating cloud infrastructure provisioning, Docker containerization, PostgreSQL database isolation, CI/CD automation and infrastructure monitoring using AWS.

The application is built using React, Django REST Framework, PostgreSQL and Nginx. Infrastructure is provisioned using Terraform, while GitHub Actions automates application testing, Docker image builds, security scanning, ECR publishing and AWS deployment.

**Cloud Provider:** AWS  
**AWS Region:** ap-south-1 (Mumbai)  
**Frontend:** React  
**Backend:** Django REST Framework  
**Database:** PostgreSQL  
**Reverse Proxy:** Nginx  
**Containerization:** Docker and Docker Compose  
**CI/CD:** GitHub Actions  
**Infrastructure as Code:** Terraform  
**Monitoring:** Amazon CloudWatch  

All patient data used in this POC is fictional. End-user authentication is not implemented because full healthcare functionality is outside the assignment scope.

---

## 1. Project Overview

The objective of this project is to design and deploy a basic cloud infrastructure for a multi-tenant healthcare application.

The application supports two healthcare organizations:

- Hospital A
- Hospital B

Each hospital has its own PostgreSQL database and database role. Tenant identification is performed through the application hostname, and database routing ensures that tenant data remains isolated.

The project demonstrates:

- AWS cloud infrastructure provisioning.
- Docker containerization and Docker Compose.
- Multi-tenant application architecture.
- PostgreSQL database connectivity.
- GitHub Actions CI/CD automation.
- Terraform infrastructure automation.
- AWS networking and security.
- Monitoring, logging and troubleshooting.
- Database backup and recovery procedures.

## 2. Application Architecture

### Technology Stack

| Component | Technology |
|---|---|
| Frontend | React |
| Backend | Django REST Framework |
| Database | PostgreSQL |
| Reverse Proxy | Nginx |
| Containerization | Docker |
| Local Orchestration | Docker Compose |
| Cloud Platform | AWS |
| Infrastructure as Code | Terraform |
| CI/CD | GitHub Actions |
| Container Registry | Amazon ECR |
| Monitoring | Amazon CloudWatch |

### Application Architecture Diagram

```text
                 Users
                   |
                   v
            Application Load
               Balancer
                   |
                   v
                 Nginx
                   |
            +------+------+
            |             |
            v             v
        React UI     Django REST API
                          |
                   Tenant Middleware
                          |
                    Tenant Router
                          |
                +---------+---------+
                |                   |
                v                   v
          Hospital A DB       Hospital B DB
            PostgreSQL          PostgreSQL
```

### Tenant Database Mapping

| Tenant | Organization | Database |
|---|---|---|
| Tenant A | Hospital A | hospital_a |
| Tenant B | Hospital B | hospital_b |

Tenant identification uses the hostname:

- `hospital-a` identifies Hospital A.
- `hospital-b` identifies Hospital B.

The application resolves the tenant and routes database operations to the corresponding PostgreSQL database.

## 3. Repository Structure

```text
healthcare-devops-poc/
│
├── frontend/
│   └── React application
│
├── backend/
│   ├── tenants/
│   ├── patients/
│   └── Django REST API
│
├── docker/
│   ├── docker-compose.yml
│   ├── docker-compose.prod.yml
│   └── Dockerfiles
│
├── nginx/
│   └── Nginx configuration
│
├── database/
│   ├── tenants/
│   └── scripts/
│
├── terraform/
│   ├── bootstrap/
│   ├── modules/
│   └── environments/
│
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── deploy.yml
│       └── terraform.yml
│
├── scripts/
│   ├── isolation_demo.sh
│   ├── deploy.sh
│   └── render_env.sh
│
├── docs/
│   ├── architecture.md
│   ├── ci-cd.md
│   ├── deployment.md
│   ├── multi-tenant-database.md
│   ├── security-networking.md
│   ├── monitoring-troubleshooting.md
│   ├── multi-region.md
│   └── vpn.md
│
├── screenshots/
│   ├── VPC.png
│   ├── Security Groups.png
│   ├── AWS EC2 instance.png
│   ├── Application Load Balancer.png
│   ├── Target Group.png
│   ├── RDS PostgreSQL.png
│   ├── Amazon ECR image.png
│   ├── S3 buckets.png
│   ├── Healthcare application.png
│   ├── Docker Compose container-1.png
│   ├── Docker Compose container-2.png
│   ├── GitHub Actions successful pipeline-1.png
│   ├── GitHub Actions successful pipeline-2.png
│   ├── CloudWatch dashboard.png
│   ├── CloudWatch.png
│   ├── CloudWatch alarms.png
│   ├── Hospital A and Hospital B tenant verification.png
│   └── Tenant isolation test results.png
│
├── .env.example
├── .gitignore
├── Makefile
└── README.md
```

## 4. Implemented vs Proposed

| Component | Status |
|---|---|
| React frontend | Implemented |
| Django REST API | Implemented |
| PostgreSQL database | Implemented |
| Nginx reverse proxy | Implemented |
| Dockerfiles and Docker Compose | Implemented |
| Container health checks | Implemented |
| Container restart policies | Implemented |
| Docker networking and persistent volumes | Implemented |
| Multi-tenant database isolation | Implemented |
| Tenant-to-database mapping | Implemented |
| Tenant-specific database roles | Implemented |
| Cross-tenant isolation tests | Implemented |
| AWS VPC and networking | Deployed in DEV |
| EC2 and Application Load Balancer | Deployed in DEV |
| Amazon RDS PostgreSQL | Deployed in DEV |
| Amazon ECR | Implemented |
| Amazon S3 | Implemented |
| IAM and GitHub OIDC | Implemented |
| AWS Secrets Manager | Implemented |
| Terraform infrastructure | Applied in AWS DEV |
| GitHub Actions CI/CD | Implemented and executed successfully |
| Trivy container scanning | Implemented |
| AWS Systems Manager deployment | Implemented |
| CloudWatch dashboard and alarms | Implemented |
| CloudWatch logging | Implemented |
| Staging environment | Documented, not deployed |
| Production environment | Documented, not deployed |
| Production HTTPS | Future implementation |
| Multi-region architecture | Proposed |
| Site-to-site VPN | Proposed |
| WAF and GuardDuty | Proposed |
| End-user authentication and authorization | Future implementation |

## 5. Docker Implementation

Docker is used to containerize the application components.

Separate containers are configured for:

1. React frontend.
2. Django backend.
3. PostgreSQL database.
4. Nginx reverse proxy.

### Docker Compose Features

- Separate application containers.
- Docker networking.
- Environment-specific configuration.
- Persistent PostgreSQL volume.
- Container health checks.
- Restart policies.
- Environment variable-based configuration.
- Multi-stage Dockerfiles where appropriate.

### Local Setup

Prerequisites:

- Docker Desktop.
- Docker Compose v2.
- Git.
- Make.
- curl.

Clone the repository:

```bash
git clone https://github.com/sakthipriya94/healthcare-devops-poc.git

cd healthcare-devops-poc
```

Configure environment variables:

```bash
cp .env.example .env
```

Update `.env` with local development credentials. Do not commit `.env` to GitHub.

Start the application:

```bash
make up
```

Alternatively:

```bash
docker compose --env-file .env \
-f docker/docker-compose.yml up -d
```

Check container status:

```bash
make ps
```

Or:

```bash
docker compose --env-file .env \
-f docker/docker-compose.yml ps
```

View application logs:

```bash
make logs
```

Access the tenant applications:

```text
http://hospital-a.localhost
http://hospital-b.localhost
```

Demonstrate tenant isolation:

```bash
make isolation-demo
```

Stop the application:

```bash
make down
```

The database volume is retained when using the normal stop command.

## 6. Multi-Tenant Database Architecture

The application follows a database-per-tenant isolation model.

### Database Mapping

| Tenant | Database | Access |
|---|---|---|
| Hospital A | hospital_a | Hospital A database role |
| Hospital B | hospital_b | Hospital B database role |

### Tenant Isolation Implementation

- Tenant identification through hostname/subdomain.
- Tenant mapping maintained in `database/tenants/tenants.json`.
- Tenant middleware resolves the incoming tenant.
- Tenant database router scopes database operations.
- Separate database roles restrict database access.
- Requests without a valid tenant fail closed.
- Cross-tenant record access is restricted.

### Automated Testing

The Django test suite covers:

- Tenant database identification.
- Database routing.
- Tenant-specific data storage.
- Cross-tenant data access prevention.
- Unauthorized record retrieval.
- Cross-tenant update and delete prevention.
- Invalid hostname handling.
- Tenant header restrictions.
- Database health verification.

**Test Result: 12/12 tests passed.**

The automated Django isolation tests use SQLite test databases. They are separate from the AWS RDS connectivity verification.

### Additional Tenant Onboarding

To onboard a new hospital:

1. Add the tenant to `database/tenants/tenants.json`.
2. Configure its database credentials through the Terraform tenant configuration.
3. Provision its database and database role.
4. Apply database migrations.
5. Deploy the updated application.
6. Verify tenant identification and isolation.

Detailed documentation: `docs/multi-tenant-database.md`.

## 7. AWS Cloud Infrastructure

The application infrastructure is deployed in AWS Mumbai (`ap-south-1`).

### AWS Services

| AWS Service | Purpose |
|---|---|
| VPC | Network isolation |
| Public Subnets | Load balancer connectivity |
| Private Subnets | Application and database resources |
| EC2 | Application hosting |
| Application Load Balancer | Application traffic distribution |
| Security Groups | Network access control |
| Amazon RDS | PostgreSQL database |
| Amazon ECR | Docker image registry |
| Amazon S3 | Artifacts and database backups |
| IAM | Identity and access management |
| Secrets Manager | Application secrets |
| Systems Manager | Remote instance management and deployment |
| CloudWatch | Monitoring, logging and alerts |

### Deployment Information

**AWS Region:** `ap-south-1`

**DEV Application URL:**

http://healthcare-dev-alb-1349434775.ap-south-1.elb.amazonaws.com

**Application health endpoint:**

`/api/health/`

**Live health endpoint:**

`/api/live/`

The DEV application was deployed and verified successfully.

### Environment Strategy

| Environment | Status |
|---|---|
| Development | Deployed in AWS |
| Staging / UAT | Documented, not deployed |
| Production | Documented, not deployed |

Only the DEV environment is provisioned to control infrastructure costs.

The staging and production configurations and deployment strategy are documented separately.

## 8. CI/CD Pipeline — GitHub Actions

GitHub Actions automates application validation, testing, Docker image building, security scanning, image publishing and deployment.

### CI/CD Workflow

```text
       Developer Push
              |
              v
       GitHub Actions
              |
              v
       Code Validation
              |
              v
       Backend Tests
              |
              v
       Frontend Build
              |
              v
       Docker Image Build
              |
              v
        Trivy Security Scan
              |
              v
        Amazon ECR Push
              |
              v
       AWS Deployment
       Through SSM
              |
              v
       Health Verification
              |
              v
       Deployment Success
```

### GitHub Actions Workflows

| Workflow | Purpose |
|---|---|
| `ci.yml` | Validation, tests, Docker builds and scanning |
| `deploy.yml` | Application deployment to AWS DEV |
| `terraform.yml` | Terraform workflow configuration |

### Pipeline Execution

1. Developer pushes code to GitHub.
2. GitHub Actions triggers the workflow.
3. Code validation and backend tests execute.
4. Frontend production build runs.
5. Docker images are built.
6. Trivy performs container vulnerability scanning.
7. Images are published to Amazon ECR.
8. GitHub Actions authenticates to AWS using OIDC.
9. Application deployment is triggered through AWS Systems Manager.
10. Post-deployment health checks verify the application.

### GitHub Environment Configuration

The `dev` environment uses variables including:

- `INSTANCE_ID`
- `ARTIFACTS_BUCKET`
- `APP_URL`
- `TENANT_HOSTS`

Repository-level variables include:

- `AWS_REGION`
- `AWS_ECR_PUSH_ROLE_ARN`
- `TF_PLAN_ROLE_ARN` (where configured)
- `TF_STATE_BUCKET` (where configured)

AWS access keys are not required for the OIDC deployment flow.

### Production Deployment Strategy

Production deployment approval and rollback procedures are documented.

Production deployment is not enabled in this POC. The rollback strategy is documented but has not been implemented or tested.

Detailed documentation: `docs/ci-cd.md`.

## 9. Infrastructure as Code — Terraform

Terraform is used to provision and manage AWS infrastructure through reusable modules.

### Terraform Components

- VPC and subnet configuration.
- Security Groups.
- EC2 application hosting.
- Application Load Balancer.
- RDS PostgreSQL.
- ECR repositories.
- S3 storage.
- IAM roles and policies.
- Secrets Manager.
- CloudWatch monitoring.

### Terraform Directory Structure

```text
terraform/
├── bootstrap/
├── modules/
└── environments/
    ├── dev.tfvars
    ├── staging.tfvars
    └── prod.tfvars
```

### Terraform Commands

Initialize:

```bash
terraform init
```

Validate:

```bash
terraform validate
```

Review the plan:

```bash
terraform plan -var-file=environments/dev.tfvars
```

Apply infrastructure changes only after reviewing the plan and confirming the intended environment.

**Important:** DEV infrastructure is already deployed. Do not run `terraform destroy` against the active DEV environment.

Staging and Production configurations are documented but are not provisioned.

## 10. Database, Backup and Recovery

PostgreSQL is used as the application database.

### Database Features

- Separate databases for Hospital A and Hospital B.
- Tenant-specific database roles.
- Restricted database connectivity.
- Tenant-to-database mapping.
- Database health checks.
- Backup and restore scripts.

### Backup

The project includes PostgreSQL backup scripts using `pg_dump` and Amazon S3 storage.

Relevant scripts:

```text
database/scripts/backup.sh
database/scripts/restore.sh
```

AWS RDS automated backups are also configured for the DEV database.

### Restore

The restore procedure supports restoring a backup into a separate test database rather than overwriting live data.

Detailed backup and operational procedures are documented in the repository.

## 11. Networking and Security

The project implements cloud networking and security controls.

### Implemented Security Controls

- AWS VPC networking.
- Public and private subnet separation.
- Security Group restrictions.
- Private RDS database connectivity.
- Database access restricted to the application security group.
- IAM roles for AWS service access.
- GitHub OIDC authentication.
- Secrets Manager for application secrets.
- AWS Systems Manager for remote management.
- Environment-based local configuration.
- Internal Docker network for database communication.

### Future Security Improvements

- Production HTTPS using ACM certificates and a custom domain.
- AWS WAF.
- GuardDuty.
- Customer-managed KMS keys.
- End-user authentication and authorization.
- PHI audit trail.
- Additional production security hardening.

The current DEV application uses HTTP on port 80. Production HTTPS is not deployed.

Detailed documentation: `docs/security-networking.md`.

## 12. Monitoring and Logging

Amazon CloudWatch is used to monitor the AWS infrastructure and application.

### Monitoring Coverage

- Application health endpoints.
- EC2 CPU utilization.
- EC2 status checks.
- Memory utilization.
- Disk utilization.
- ALB target health.
- ALB HTTP 5xx errors.
- RDS CPU utilization.
- RDS database connections.
- RDS free storage.
- Application errors.
- Deployment failures.

### CloudWatch Dashboard

Dashboard name:

`healthcare-dev`

### CloudWatch Alarms

**11 CloudWatch alarms were in OK state at the time of verification.**

### CloudWatch Log Groups

```text
/healthcare/dev/containers

/healthcare/dev/vpc-flow-logs

/aws/rds/instance/healthcare-dev-postgres/postgresql
```

### Troubleshooting Approach

For an application outage:

1. Check Application Load Balancer target health.
2. Verify EC2 instance status.
3. Check Docker container status.
4. Inspect Nginx and Django application logs.
5. Verify PostgreSQL connectivity.
6. Review CloudWatch alarms and metrics.
7. Check GitHub Actions deployment history.
8. Perform targeted recovery and verify application health.

Detailed documentation: `docs/monitoring-troubleshooting.md`.

## 13. Multi-Region Architecture Proposal

The current application is deployed in AWS Mumbai (`ap-south-1`).

A future multi-region architecture is documented for supporting additional healthcare organizations.

| Region | Example Tenant | Database |
|---|---|---|
| Mumbai, India | Hospital A | PostgreSQL |
| Hyderabad, India | Hospital B | PostgreSQL |
| UAE | Hospital C | PostgreSQL |

### Proposed Design

- Assign tenants to regions based on geographic and data residency requirements.
- Maintain regional application and database infrastructure.
- Use secure cross-region communication.
- Configure regional backups and disaster recovery.
- Consider data residency and regulatory requirements.
- Implement regional recovery and failover strategies.

Multi-region infrastructure is proposed only and has not been deployed.

Reference: `docs/multi-region.md`.

## 14. Site-to-Site VPN Architecture

A proposed VPN architecture is documented for connecting an on-premises hospital network securely to AWS.

The design covers:

- On-premises hospital network.
- AWS VPC.
- Virtual Private Gateway.
- Customer Gateway.
- Encrypted site-to-site VPN tunnels.
- Private application and database connectivity.
- Network access restrictions.

Actual VPN provisioning is not part of this POC.

Reference: `docs/vpn.md`.

## 15. Screenshots and Implementation Evidence

Screenshots are included in the root-level `screenshots/` directory to provide visual evidence of the implemented application, AWS infrastructure, CI/CD pipeline, monitoring and tenant isolation.

### AWS Infrastructure

| Screenshot | Evidence |
|---|---|
| [VPC](screenshots/VPC.png) | AWS VPC networking |
| [Security Groups](screenshots/Security%20Groups.png) | Network security rules |
| [EC2 Instance](screenshots/AWS%20EC2%20instance.png) | Application hosting |
| [Application Load Balancer](screenshots/Application%20Load%20Balancer.png) | Application traffic routing |
| [Target Group](screenshots/Target%20Group.png) | Target group health |
| [RDS PostgreSQL](screenshots/RDS%20PostgreSQL.png) | Managed PostgreSQL database |
| [Amazon ECR](screenshots/Amazon%20ECR%20image.png) | Container image registry |
| [S3 Buckets](screenshots/S3%20buckets.png) | Artifact and backup storage |

### Application and Docker

| Screenshot | Evidence |
|---|---|
| [Healthcare Application](screenshots/Healthcare%20application.png) | Application interface |
| [Docker Compose Containers 1](screenshots/Docker%20Compose%20container-1.png) | Docker containers |
| [Docker Compose Containers 2](screenshots/Docker%20Compose%20container-2.png) | Docker containers |

### CI/CD Pipeline

| Screenshot | Evidence |
|---|---|
| [GitHub Actions Pipeline 1](screenshots/GitHub%20Actions%20successful%20pipeline-1.png) | Successful workflow execution |
| [GitHub Actions Pipeline 2](screenshots/GitHub%20Actions%20successful%20pipeline-2.png) | Successful workflow execution |

### Monitoring and Tenant Isolation

| Screenshot | Evidence |
|---|---|
| [CloudWatch Dashboard](screenshots/CloudWatch%20dashboard.png) | Infrastructure monitoring |
| [CloudWatch Monitoring](screenshots/CloudWatch.png) | Monitoring configuration |
| [CloudWatch Alarms](screenshots/CloudWatch%20alarms.png) | Infrastructure alerts |
| [Hospital A and Hospital B Verification](screenshots/Hospital%20A%20and%20Hospital%20B%20tenant%20verification.png) | Tenant identification |
| [Tenant Isolation Test Results](screenshots/Tenant%20isolation%20test%20results.png) | Automated tenant isolation tests |

## 16. Verification Status

The following checks were completed during the AWS DEV POC.

| Verification | Result |
|---|---|
| GitHub Actions CI workflow | Successful |
| GitHub Actions DEV deployment | Successful |
| AWS `/api/health/` | HTTP 200 |
| AWS `/api/live/` | HTTP 200 |
| Hospital A tenant endpoint | HTTP 200 |
| Hospital B tenant endpoint | HTTP 200 |
| Both tenant databases | Reported as up |
| Django tenant isolation tests | 12/12 passed |
| Cross-tenant record access tests | Passed |
| CloudWatch dashboard | Verified |
| CloudWatch alarms | 11 in OK state at verification time |
| Container log streams | Verified active |
| VPC Flow Log streams | Verified active |
| RDS PostgreSQL log stream | Verified active |

### AWS Application Verification

DEV application:

http://healthcare-dev-alb-1349434775.ap-south-1.elb.amazonaws.com

Health endpoint:

```text
/api/health/
```

Live endpoint:

```text
/api/live/
```

Tenant verification:

```bash
APP_URL="http://healthcare-dev-alb-1349434775.ap-south-1.elb.amazonaws.com"

curl -i "$APP_URL/api/health/"

curl -i "$APP_URL/api/live/"

curl -i -H "Host: hospital-a.local" "$APP_URL/api/tenant/"

curl -i -H "Host: hospital-b.local" "$APP_URL/api/tenant/"
```

The automated Django isolation tests use SQLite test databases. The AWS endpoint checks independently verified the deployed application and its database connectivity.

## 17. Environment Scope and Limitations

| Environment / Feature | Status |
|---|---|
| AWS DEV | Deployed and verified |
| AWS Staging | Not deployed |
| AWS Production | Not deployed |
| Production HTTPS | Not deployed |
| Multi-region | Proposed only |
| Site-to-site VPN | Proposed only |

### Known Limitations

- End-user authentication and authorization are not implemented.
- Production HTTPS is not deployed.
- Staging and Production are not provisioned.
- Multi-region infrastructure is not deployed.
- Site-to-site VPN is not provisioned.
- Production rollback is documented but has not been implemented or tested.
- The POC uses fictional patient data and is not intended for real healthcare workloads.

The implementation status is clearly separated from proposed architecture and future production improvements.

## 18. Documentation

Additional project documentation is available in the `docs/` directory.

| Document | Description |
|---|---|
| `architecture.md` | AWS and application architecture |
| `deployment.md` | Application deployment instructions |
| `ci-cd.md` | GitHub Actions pipeline and environment strategy |
| `multi-tenant-database.md` | Tenant database mapping and isolation |
| `security-networking.md` | AWS security and networking |
| `monitoring-troubleshooting.md` | CloudWatch monitoring and troubleshooting |
| `multi-region.md` | Proposed multi-region architecture |
| `vpn.md` | Proposed site-to-site VPN architecture |

## 19. GitHub Repository

**Repository:**  
https://github.com/sakthipriya94/healthcare-devops-poc

### Technologies and Tools

React | Python | Django REST Framework | PostgreSQL | Docker | Docker Compose | Nginx | AWS | Terraform | GitHub Actions | Amazon ECR | Amazon RDS | Amazon S3 | IAM | AWS Systems Manager | AWS Secrets Manager | CloudWatch | Trivy

---

**Project Summary**

This project demonstrates a multi-tenant healthcare application with database-per-tenant isolation, Docker containerization, AWS cloud infrastructure, Terraform automation, GitHub Actions CI/CD and CloudWatch monitoring.

The DEV environment was successfully deployed and verified in AWS Mumbai. Staging, Production, multi-region and VPN capabilities are documented as future extensions.

