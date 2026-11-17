# Site-to-Site VPN Architecture

## 1. Objective

This proposal explains how an on-premises hospital network could connect securely to the AWS VPC. Actual VPN provisioning is not required for this POC and has not been performed.

## 2. Architecture diagram

```mermaid
flowchart LR
    A[Hospital on-premises network]
    B[Customer Gateway]
    C[Encrypted IPsec VPN tunnels]
    D[Virtual Private Gateway]
    E[AWS VPC]
    F[Private application network]
    G[Private PostgreSQL RDS]

    A --> B
    B --> C
    C --> D
    D --> E
    E --> F
    F --> G
```

## 3. Components

- Customer Gateway: represents the hospital VPN device and its public IP address.
- Virtual Private Gateway: AWS VPN endpoint attached to the VPC.
- IPsec tunnels: encrypted connectivity between the hospital and AWS.
- VPC route tables: direct approved hospital network traffic through the VPN.
- Security Groups: permit only the application and database traffic required.

## 4. Security and monitoring

1. Use non-overlapping CIDR ranges.
2. Configure redundant VPN tunnels.
3. Restrict access to required application and database ports.
4. Encrypt traffic through the VPN.
5. Monitor tunnel status and relevant network logs.
6. Review routes and access rules regularly.

## 5. Implementation status

The AWS VPC, subnets, application infrastructure and security groups are implemented. The site-to-site VPN is documented as a proposed design only.
