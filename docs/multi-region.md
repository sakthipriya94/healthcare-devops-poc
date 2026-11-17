# Multi-Region Architecture Proposal

## 1. Current implementation

The application is deployed in AWS Mumbai (`ap-south-1`). Hospital A and Hospital B use separate PostgreSQL databases in this region.

Only Mumbai is implemented. Additional regions below are a proposal, not deployed infrastructure.

## 2. Proposed tenant assignment

| Region | Example tenant | Database |
|---|---|---|
| Mumbai (`ap-south-1`) | Hospital A | Regional PostgreSQL |
| Hyderabad (`ap-south-2`) | Hospital B | Regional PostgreSQL |
| UAE (`me-central-1`) | Hospital C | Regional PostgreSQL |

A tenant registry can record the tenant identifier, assigned region, database endpoint reference and secret reference. Tenant placement should consider latency, contractual requirements and data residency.

## 3. Regional database connectivity

Each region should host its own application and PostgreSQL service. The application connects privately to the database assigned to the tenant. Database credentials are retrieved from a secrets manager, and connections use encryption.

## 4. Backups and disaster recovery

- Enable automated database backups and point-in-time recovery.
- Define retention according to business requirements.
- Copy approved backups to a recovery region when permitted.
- Document recovery time objective (RTO) and recovery point objective (RPO).
- Test restoration and application recovery procedures.

## 5. Data residency

Tenant data, backups and replicas must remain in regions permitted by applicable legal, contractual and customer requirements. Cross-region transfer must be reviewed before implementation.

## 6. Secure cross-region communication

Use private connectivity where required, encryption in transit, restricted network routes, least-privilege IAM and CloudWatch monitoring.

## 7. Implementation status

Mumbai deployment and the two tenant databases are implemented. Hyderabad, UAE, cross-region replication and disaster recovery deployment are proposed only.
