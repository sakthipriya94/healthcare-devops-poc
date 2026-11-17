# Terraform does everything

One command (or one manual workflow run) builds the AWS environment **and** writes the GitHub variables the
deploy workflow needs. Nothing is copied by hand.

| Terraform creates | Where |
|---|---|
| VPC, subnets, security groups, EC2 host, ALB, RDS, S3 buckets, IAM roles, CloudWatch | AWS |
| `AWS_REGION`, `AWS_DEPLOY_ROLE_ARN`, `INSTANCE_ID`, `ARTIFACTS_BUCKET`, `APP_URL`, `TENANT_HOSTS` | GitHub **Environment** variables (`manage_github = true`) |

## One-time setup

1. **State bucket** (local state, once):
   ```bash
   cd terraform/bootstrap && terraform init && terraform apply -var github_repository=sakthipriya94/healthcare-devops-poc
   ```
   Note the `state_bucket` output.
2. **GitHub token for Terraform**: create a personal access token with `repo` scope.
3. **Repository settings** (Settings -> Secrets and variables -> Actions):

   | Kind | Name | Value |
   |---|---|---|
   | Variable | `TF_STATE_BUCKET` | the `state_bucket` output |
   | Variable | `TF_APPLY_ROLE_ARN` | an AWS role this workflow may assume (below) |
   | Secret | `TF_GITHUB_TOKEN` | the token from step 2 |

4. **Role for `TF_APPLY_ROLE_ARN`**: it creates infrastructure, so give it broad rights (for a POC,
   `AdministratorAccess`; for real use, a scoped policy). Trust policy, using the same GitHub OIDC provider
   you already have:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Principal": { "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com" },
       "Action": "sts:AssumeRoleWithWebIdentity",
       "Condition": {
         "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
         "StringLike": { "token.actions.githubusercontent.com:sub": [
           "repo:sakthipriya94/healthcare-devops-poc:environment:dev",
           "repo:sakthipriya94/healthcare-devops-poc:environment:staging",
           "repo:sakthipriya94/healthcare-devops-poc:environment:prod"
         ] }
       }
     }]
   }
   ```
   (The sub is `environment:<name>` because the workflow job targets a GitHub Environment.)

## Run it

**From GitHub:** Actions -> *Terraform Apply* -> Run workflow -> environment `staging`, action `plan`; read the
plan; run again with action `apply` (about 10-15 minutes). Then push to `main` to deploy.

**From your computer:**
```bash
export GITHUB_TOKEN=<token>     # only needed because manage_github = true
cd terraform
terraform init -backend-config="bucket=<state_bucket>" -backend-config="key=healthcare/staging/terraform.tfstate" \
               -backend-config="region=ap-south-1" -backend-config="use_lockfile=true"
terraform apply -var-file=environments/staging.tfvars
```

## Notes
- `manage_github = false` skips the GitHub part (the `Terraform` PR workflow does this so plans need no token).
- `terraform destroy -var-file=environments/<env>.tfvars` removes the AWS resources and the GitHub variables.
- ECR repositories are not created (`manage_ecr = false`) because they already exist; set `true` on a fresh account.
