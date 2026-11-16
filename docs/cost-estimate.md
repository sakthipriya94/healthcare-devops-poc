# Estimated cost (provide before provisioning)

> **These are rough estimates** for `ap-south-1`, on-demand, USD, based on public price levels I know; **prices change and vary by region, so confirm with the [AWS Pricing Calculator](https://calculator.aws/) before applying.** Nothing in this repository creates resources until you run `terraform apply`.

## Dev environment (what the POC deploys)

| Resource | Sizing | ≈ USD / month |
|---|---|---|
| EC2 `t3.small` (24×7) | 2 vCPU, 2 GiB | 16 |
| EBS gp3 | 20 GiB | 2 |
| RDS PostgreSQL `db.t4g.micro`, single-AZ | + 20 GiB gp3, 7-day backups (within free backup allowance) | 14 |
| Application Load Balancer | 1 ALB + minimal LCUs | 19 |
| Public IPv4 addresses | 1 EC2 + 2 ALB (AWS charges per public IPv4) | 11 |
| Secrets Manager | 4 secrets | 2 |
| CloudWatch | ~11 alarms, 1 dashboard, small log volume, flow logs | 5 |
| S3, ECR, SSM, data transfer | tiny | 2 |
| **Total (24×7)** | | **≈ 70 / month (≈ 2.3 / day)** |

**Budget for a 2-day evaluation: about USD 5–8**, including leaving it up for the demo, then `terraform destroy`.

## Ways to reduce cost further

* `terraform destroy -var-file=environments/dev.tfvars` straight after the demo (dev is built to be recreated — `protect_data = false`, buckets `force_destroy`).
* Stop the EC2 host and RDS instance overnight (RDS auto-restarts after 7 days).
* Skip the ALB for a pure smoke test and expose Nginx on the instance's Elastic IP (≈ −USD 25/month; but you lose managed TLS and the health-check target group).
* No NAT gateway is used (saves ≈ USD 35+/month).

## Production profile (documented, not deployed)

`t3.medium` ×2 hosts, `db.t4g.medium` **Multi-AZ**, 100 GiB, 35-day backups, WAF, NAT or VPC endpoints, KMS keys: roughly **USD 350–600 / month per region** before data transfer and support. Every additional region repeats that figure.

## Cost controls included

* Tag everything (`Project`, `Environment`, `ManagedBy`) via provider `default_tags` → cost-allocation reports.
* Create an **AWS Budget** with an alert at USD 10 before applying (recommended; not created by this code).
* ECR lifecycle keeps only the last 20 images; S3 lifecycle expires old deploy bundles and backups; log retention 14 days.
