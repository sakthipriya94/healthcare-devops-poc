# Cloud architecture (AWS, `ap-south-1` Mumbai)

> **Implemented** = written as code in this repo. **Proposed** = design only (see [implemented vs proposed](../README.md#implemented-vs-proposed)).

## 1. Cloud architecture diagram (implemented)

```mermaid
flowchart TB
  user([Hospital users<br/>hospital-a.&lt;domain&gt; / hospital-b.&lt;domain&gt;])
  r53[Route 53<br/>wildcard *.domain<br/><i>optional</i>]
  user --> r53 --> alb

  subgraph VPC["VPC 10.10.0.0/16 (one region, 2 AZs)"]
    direction TB
    subgraph PUB["Public subnets (AZ-a, AZ-b)"]
      alb["Application Load Balancer<br/>HTTP :80 (DEV POC)<br/>HTTPS :443 (future production)"]
      subgraph EC2["EC2 t3.small - Amazon Linux 2023 (no SSH, SSM only)"]
        nginx["Nginx reverse proxy :80"]
        fe["React container"]
        be["Django + Gunicorn container"]
        nginx -->|"/"| fe
        nginx -->|"/api/ (Host header kept)"| be
      end
      alb -->|"SG: ALB -> app only"| nginx
    end
    subgraph PRIV["Private subnets (no internet route)"]
      rds[("RDS PostgreSQL 16<br/>db: hospital_a  role: hospital_a_user<br/>db: hospital_b  role: hospital_b_user<br/>TLS enforced, encrypted, backups")]
    end
    be -->|"5432, TLS, SG: app -> rds only"| rds
  end

  ecr[(ECR<br/>backend / frontend / nginx<br/>scan on push, immutable tags)]
  sm[(Secrets Manager<br/>DB passwords, Django key,<br/>RDS master secret)]
  s3a[(S3 artifacts<br/>deploy bundle)]
  s3b[(S3 db-backups<br/>nightly pg_dump)]
  cw[CloudWatch<br/>logs, metrics, alarms,<br/>dashboard, VPC flow logs]
  ssm[Systems Manager<br/>Run Command / Session Manager]
  gha[GitHub Actions<br/>OIDC role, no stored keys]

  EC2 -. pull images .-> ecr
  EC2 -. IAM role: read secrets .-> sm
  EC2 -. nightly backup .-> s3b
  EC2 -. awslogs driver / agent .-> cw
  gha -- push images --> ecr
  gha -- upload bundle --> s3a
  gha -- deploy command --> ssm --> EC2
  EC2 -. fetch bundle .-> s3a
```

### Component summary

| Layer | What | Where defined |
|---|---|---|
| Network | VPC, 2 public + 2 private subnets, IGW, route tables, VPC Flow Logs | `terraform/modules/network` |
| Firewall | ALB SG (HTTP 80 for the deployed DEV POC; HTTPS 443 is a future production requirement), App SG (80 from ALB only), RDS SG (5432 from App SG only) | `terraform/modules/security` |
| Compute | One EC2 host running the Compose stack, behind an ALB | `terraform/modules/compute` |
| Database | RDS PostgreSQL 16, private, encrypted, forced TLS, 7-day backups | `terraform/modules/database` |
| Registry | 3 ECR repos, scan-on-push, immutable tags, lifecycle policy | `terraform/modules/ecr` |
| Storage | S3 `artifacts` and `db-backups` (versioned, encrypted, TLS-only, lifecycle) | `terraform/modules/storage` |
| IAM | EC2 instance role (least privilege), GitHub OIDC deploy role per environment | `compute`, `cicd`, `bootstrap` |
| Monitoring | Log group, 11 alarms, SNS topic, dashboard | `terraform/modules/monitoring` |

### Why these choices (POC trade-offs)

* **EC2 + Docker Compose instead of ECS/Fargate**: the same Compose definition runs locally and in the cloud, which keeps the POC small and the local-to-cloud story obvious. ECS Fargate is the natural next step (see [multi-region](multi-region.md#evolution)).
* **No NAT gateway**: saves ~$35/month. The app host is in a public subnet with a public IP for *outbound* pulls only; no inbound rule reaches it except from the ALB. The database subnets have no internet route at all.
* **Single AZ for the app, 2 AZs for the network**: the ALB and DB subnet group span two AZs (required by AWS). Single-AZ compute/DB is a cost decision; production turns on `db_multi_az` and runs ≥2 app hosts (`prod.tfvars`).
* **SSM instead of SSH**: deployment and administration use IAM-authenticated Systems Manager. There is no open management port.

## 2. Request flow

1. Browser requests the DEV ALB HTTP endpoint. Tenant smoke tests send `Host: hospital-a.local` or `Host: hospital-b.local`.
2. The DEV ALB forwards HTTP traffic to Nginx, preserving the `Host` header. HTTPS termination using ACM and a custom domain is a production requirement, not deployed in this POC.
3. Nginx serves the React app for `/` and proxies `/api/` to Django, again keeping `Host`.
4. Django's `TenantMiddleware` resolves `hospital-a` → tenant `hospital_a` and binds it to the request.
5. The database router sends **every** query to `hospital_a`'s own database and role. See [multi-tenant database](multi-tenant-database.md).

## 3. Environments

**DEV:** Provisioned and deployed in AWS Mumbai (`ap-south-1`) using Terraform and GitHub Actions. The application currently uses HTTP and synthetic demonstration data.

**UAT / Staging:** Not deployed. Previously provisioned staging resources have been destroyed to control costs.

**Production:** Not deployed. A production rollout would require HTTPS with ACM, stronger application authentication and authorization, production-grade secrets and data protection, approval gates, and tested rollback procedures.

Only DEV is implemented in AWS for this POC. Staging and Production are documented as future environment configurations. See [CI/CD](ci-cd.md#environment-strategy).
