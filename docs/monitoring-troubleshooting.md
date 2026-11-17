# Monitoring, Logging and Troubleshooting

## 1. Monitoring implementation

The DEV environment uses Amazon CloudWatch for infrastructure monitoring, logs, dashboard visualisation and alarms.

Dashboard: `healthcare-dev`

Configured alarm coverage includes:

- ALB target 5xx errors
- ALB unhealthy targets
- Application errors
- Deployment failures
- EC2 CPU and status checks
- Disk and memory utilisation
- RDS connections, CPU and free storage

Alarm state and notification delivery should be checked in the AWS console during the walkthrough.

## 2. Log sources

Configured log groups include:

- `/healthcare/dev/containers`
- `/healthcare/dev/vpc-flow-logs`
- `/aws/rds/instance/healthcare-dev-postgres/postgresql`

Review the actual log group streams and recent timestamps before presenting them as live evidence.

## 3. Application health checks

```bash
APP_URL="http://healthcare-dev-alb-1349434775.ap-south-1.elb.amazonaws.com"

curl -i "$APP_URL/api/health/"
curl -i "$APP_URL/api/live/"
curl -i -H "Host: hospital-a.local" "$APP_URL/api/tenant/"
curl -i -H "Host: hospital-b.local" "$APP_URL/api/tenant/"
```

The previously verified DEV health endpoint returned HTTP 200 and reported both tenant databases as up.

## 4. Linux and Docker troubleshooting

Run these commands on the relevant Linux host or local Docker environment:

```bash
# Running containers
docker ps

# Container logs
docker logs <container_name> --tail 100

# Container resource usage
docker stats --no-stream

# Disk usage
df -h

# Memory usage
free -m

# CPU and running processes
top

# Listening ports
sudo ss -tulpn

# Docker service status
sudo systemctl status docker
```

Use AWS Systems Manager for approved administration of the EC2 host.

## 5. Basic outage investigation

1. Check the ALB target health.
2. Check the EC2 instance status and system metrics.
3. Check container status and restart state.
4. Inspect Nginx and Django application logs.
5. Check the application health endpoint.
6. Verify RDS availability, connections and security-group access.
7. Check the latest GitHub Actions deployment result.
8. If a release caused the issue, assess whether to redeploy the last known-good immutable image tag.

Do not perform a rollback or infrastructure change without checking database migration compatibility and obtaining the required approval.

## 6. Database connectivity troubleshooting

- Confirm the RDS instance is available.
- Confirm the application is using the intended tenant database mapping.
- Confirm the RDS security group permits port 5432 from the application security group.
- Review Django application logs for connection errors.
- Never expose the database publicly as a troubleshooting shortcut.

## 7. Evidence

Use current CloudWatch dashboard, alarms, logs, Docker and application screenshots in `screenshots/`. Do not claim a fault-injection or recovery test unless it has actually been performed.
