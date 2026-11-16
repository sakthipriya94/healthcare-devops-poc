locals {
  name = "${var.project}-${var.environment}"
}

# ------------------------------------------------------- alert routing ----
resource "aws_sns_topic" "alerts" {
  name = "${local.name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email # recipient must confirm the subscription e-mail
}

# ---------------------------------------------- alarms: application host ---
resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
  alarm_name          = "${local.name}-ec2-cpu-high"
  alarm_description   = "Application host CPU > 80% for 10 minutes"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { InstanceId = var.instance_id }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "ec2_status" {
  alarm_name          = "${local.name}-ec2-status-check-failed"
  alarm_description   = "EC2 system or instance status check failing"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  dimensions          = { InstanceId = var.instance_id }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "memory" {
  alarm_name          = "${local.name}-memory-high"
  alarm_description   = "Host memory > 85% (CloudWatch agent)"
  namespace           = "CWAgent"
  metric_name         = "mem_used_percent"
  dimensions          = { InstanceId = var.instance_id }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "breaching" # agent stopped / host hung
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "disk" {
  alarm_name          = "${local.name}-disk-high"
  alarm_description   = "Root volume > 80% used"
  namespace           = "CWAgent"
  metric_name         = "disk_used_percent"
  dimensions          = { InstanceId = var.instance_id }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

# ------------------------------------------------ alarms: load balancer ----
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${local.name}-alb-unhealthy-targets"
  alarm_description   = "The ALB health check (/api/live/) is failing: the application is down"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = { LoadBalancer = var.alb_arn_suffix, TargetGroup = var.target_group_arn_suffix }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name}-alb-target-5xx"
  alarm_description   = "Application returning 5xx errors"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

# ------------------------------------------------------ alarms: RDS -------
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.name}-rds-cpu-high"
  alarm_description   = "Database CPU > 80%"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = var.db_identifier }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${local.name}-rds-free-storage-low"
  alarm_description   = "Database free storage < 2 GiB"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = var.db_identifier }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 2147483648
  comparison_operator = "LessThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${local.name}-rds-connections-high"
  alarm_description   = "Database connections high (db.t4g.micro allows ~80-100)"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  dimensions          = { DBInstanceIdentifier = var.db_identifier }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.db_connections_threshold
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

# ---------------------------------------- app logs -> metric -> alarm ------
resource "aws_cloudwatch_log_metric_filter" "app_errors" {
  name           = "${local.name}-app-errors"
  log_group_name = var.container_log_group
  pattern        = "?ERROR ?Traceback ?\"Internal Server Error\""

  metric_transformation {
    name          = "ApplicationErrors"
    namespace     = "Healthcare"
    value         = "1"
    default_value = "0"
    dimensions    = {}
  }
}

resource "aws_cloudwatch_metric_alarm" "app_errors" {
  alarm_name          = "${local.name}-application-errors"
  alarm_description   = "More than 20 ERROR/Traceback log lines in 5 minutes"
  namespace           = "Healthcare"
  metric_name         = "ApplicationErrors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 20
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

# --------------- deployment status (metric emitted by scripts/deploy.sh) ---
resource "aws_cloudwatch_metric_alarm" "deploy_failed" {
  alarm_name          = "${local.name}-deployment-failed"
  alarm_description   = "A deployment or its post-deploy health check failed (and was rolled back)"
  namespace           = "Healthcare"
  metric_name         = "DeploymentFailed"
  dimensions          = { Environment = var.environment }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

# ----------------------------------------------------------- dashboard ----
resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = local.name
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "Host CPU / memory / disk (%)"
          region = var.aws_region
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", var.instance_id],
            ["CWAgent", "mem_used_percent", "InstanceId", var.instance_id],
            ["CWAgent", "disk_used_percent", "InstanceId", var.instance_id],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "ALB: requests, 5xx, healthy targets"
          region = var.aws_region
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum" }],
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Minimum" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "RDS: CPU, connections"
          region = var.aws_region
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_identifier],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.db_identifier],
          ]
        }
      },
      {
        type = "log", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "Recent application errors"
          region = var.aws_region
          query  = "SOURCE '${var.container_log_group}' | fields @timestamp, @message | filter @message like /ERROR|Traceback/ | sort @timestamp desc | limit 50"
        }
      },
      {
        type = "alarm", x = 0, y = 12, width = 24, height = 4
        properties = {
          title = "Alarm status"
          alarms = [
            aws_cloudwatch_metric_alarm.unhealthy_hosts.arn,
            aws_cloudwatch_metric_alarm.alb_5xx.arn,
            aws_cloudwatch_metric_alarm.ec2_cpu.arn,
            aws_cloudwatch_metric_alarm.memory.arn,
            aws_cloudwatch_metric_alarm.rds_cpu.arn,
            aws_cloudwatch_metric_alarm.rds_connections.arn,
            aws_cloudwatch_metric_alarm.deploy_failed.arn,
          ]
        }
      },
    ]
  })
}
