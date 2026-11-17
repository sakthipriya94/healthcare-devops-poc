# Security and Networking

## 1. VPC and subnet architecture

The application is deployed in an AWS VPC in `ap-south-1`.

- Public network components provide the entry path through the Application Load Balancer.
- The application host runs the containerized application.
- RDS PostgreSQL is private and is not directly accessible from the public internet.
- Security Groups control traffic between the load balancer, application host and database.

## 2. Security Group intent

| Component | Allowed traffic |
|---|---|
| Application Load Balancer | HTTP port 80 for current DEV access |
| Application host | Application traffic from the ALB security group |
| RDS PostgreSQL | PostgreSQL port 5432 from the application security group only |

The exact deployed rules are defined in Terraform. Review the Terraform configuration and AWS console when demonstrating the actual rules.

## 3. IAM and administration

- EC2 uses an instance role for permitted AWS service access.
- GitHub Actions uses OIDC to assume a deployment role.
- Administrative access is intended to use AWS Systems Manager.
- Avoid unrestricted SSH access and long-lived access keys.
- Grant only the permissions required by each role.

## 4. Secrets management

Database credentials are stored outside source code and retrieved through AWS Secrets Manager / environment configuration. Do not commit secret values or print them in logs.

## 5. Database security

- RDS is private.
- Inbound PostgreSQL access is restricted to the application security group.
- Tenant databases use separate database identities as configured.
- Use encrypted database connections and backups according to the deployed RDS settings.

## 6. HTTPS status

The current DEV application is accessed over HTTP port 80 through the ALB. HTTPS port 443 with a domain and ACM certificate is a production follow-up and is not claimed as implemented.

## 7. Logging

CloudWatch receives application/container and infrastructure-related logs. VPC flow logging and RDS log configuration should be described according to the resources currently enabled in the AWS account.

## 8. Production security improvements

Before production use, implement end-user authentication and authorization, HTTPS, audit logging, security testing, and a reviewed least-privilege access model. This sample application is a technical POC using synthetic data, not a production healthcare platform.
