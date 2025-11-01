terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_identifier" {
  description = "DocumentDB cluster identifier"
  type        = string
  default     = "lab-cluster-console"
}

variable "alert_email" {
  description = "Email para receber alertas"
  type        = string
}

# SNS Topic for Alerts
resource "aws_sns_topic" "documentdb_alerts" {
  name = "documentdb-alerts"

  tags = {
    Name        = "DocumentDB Alerts"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.documentdb_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Alarm 1: High CPU Utilization
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "DocumentDB-HighCPU"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/DocDB"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU utilization acima de 80% por 5 minutos"
  alarm_actions       = [aws_sns_topic.documentdb_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = var.cluster_identifier
  }

  tags = {
    Name        = "DocumentDB High CPU Alarm"
    Environment = "Lab"
    Severity    = "High"
  }
}

# Alarm 2: High Database Connections
resource "aws_cloudwatch_metric_alarm" "high_connections" {
  alarm_name          = "DocumentDB-HighConnections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/DocDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 500
  alarm_description   = "Mais de 500 conexões ativas"
  alarm_actions       = [aws_sns_topic.documentdb_alerts.arn]

  dimensions = {
    DBClusterIdentifier = var.cluster_identifier
  }

  tags = {
    Name        = "DocumentDB High Connections Alarm"
    Environment = "Lab"
    Severity    = "Medium"
  }
}

# Alarm 3: High Replica Lag
resource "aws_cloudwatch_metric_alarm" "high_replica_lag" {
  alarm_name          = "DocumentDB-HighReplicaLag"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "DBClusterReplicaLagMaximum"
  namespace           = "AWS/DocDB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1000
  alarm_description   = "Replica lag acima de 1 segundo"
  alarm_actions       = [aws_sns_topic.documentdb_alerts.arn]

  dimensions = {
    DBClusterIdentifier = var.cluster_identifier
  }

  tags = {
    Name        = "DocumentDB High Replica Lag Alarm"
    Environment = "Lab"
    Severity    = "High"
  }
}

# Alarm 4: Low Freeable Memory
resource "aws_cloudwatch_metric_alarm" "low_memory" {
  alarm_name          = "DocumentDB-LowMemory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/DocDB"
  period              = 300
  statistic           = "Average"
  threshold           = 1073741824  # 1 GB in bytes
  alarm_description   = "Memória livre abaixo de 1GB"
  alarm_actions       = [aws_sns_topic.documentdb_alerts.arn]

  dimensions = {
    DBClusterIdentifier = var.cluster_identifier
  }

  tags = {
    Name        = "DocumentDB Low Memory Alarm"
    Environment = "Lab"
    Severity    = "High"
  }
}

# Alarm 5: High Storage Usage
resource "aws_cloudwatch_metric_alarm" "high_storage" {
  alarm_name          = "DocumentDB-HighStorage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "VolumeBytesUsed"
  namespace           = "AWS/DocDB"
  period              = 3600
  statistic           = "Average"
  threshold           = 85899345920  # 80 GB in bytes
  alarm_description   = "Storage usado acima de 80GB"
  alarm_actions       = [aws_sns_topic.documentdb_alerts.arn]

  dimensions = {
    DBClusterIdentifier = var.cluster_identifier
  }

  tags = {
    Name        = "DocumentDB High Storage Alarm"
    Environment = "Lab"
    Severity    = "Medium"
  }
}

# Alarm 6: High Write Latency
resource "aws_cloudwatch_metric_alarm" "high_write_latency" {
  alarm_name          = "DocumentDB-HighWriteLatency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "WriteLatency"
  namespace           = "AWS/DocDB"
  period              = 300
  statistic           = "Average"
  threshold           = 100  # 100ms
  alarm_description   = "Write latency acima de 100ms"
  alarm_actions       = [aws_sns_topic.documentdb_alerts.arn]

  dimensions = {
    DBClusterIdentifier = var.cluster_identifier
  }

  tags = {
    Name        = "DocumentDB High Write Latency Alarm"
    Environment = "Lab"
    Severity    = "Medium"
  }
}

# Alarm 7: High Read Latency
resource "aws_cloudwatch_metric_alarm" "high_read_latency" {
  alarm_name          = "DocumentDB-HighReadLatency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ReadLatency"
  namespace           = "AWS/DocDB"
  period              = 300
  statistic           = "Average"
  threshold           = 100  # 100ms
  alarm_description   = "Read latency acima de 100ms"
  alarm_actions       = [aws_sns_topic.documentdb_alerts.arn]

  dimensions = {
    DBClusterIdentifier = var.cluster_identifier
  }

  tags = {
    Name        = "DocumentDB High Read Latency Alarm"
    Environment = "Lab"
    Severity    = "Medium"
  }
}

# Alarm 8: Swap Usage
resource "aws_cloudwatch_metric_alarm" "swap_usage" {
  alarm_name          = "DocumentDB-SwapUsage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "SwapUsage"
  namespace           = "AWS/DocDB"
  period              = 300
  statistic           = "Average"
  threshold           = 268435456  # 256 MB
  alarm_description   = "Swap usage acima de 256MB indica pressão de memória"
  alarm_actions       = [aws_sns_topic.documentdb_alerts.arn]

  dimensions = {
    DBClusterIdentifier = var.cluster_identifier
  }

  tags = {
    Name        = "DocumentDB Swap Usage Alarm"
    Environment = "Lab"
    Severity    = "High"
  }
}

# Composite Alarm: Critical Cluster Health
resource "aws_cloudwatch_composite_alarm" "critical_cluster_health" {
  alarm_name          = "DocumentDB-CriticalClusterHealth"
  alarm_description   = "Múltiplos indicadores críticos detectados"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.documentdb_alerts.arn]

  alarm_rule = join(" OR ", [
    "ALARM(${aws_cloudwatch_metric_alarm.high_cpu.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.low_memory.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.high_replica_lag.alarm_name})"
  ])

  tags = {
    Name        = "DocumentDB Critical Health Composite Alarm"
    Environment = "Lab"
    Severity    = "Critical"
  }
}

# Outputs
output "sns_topic_arn" {
  description = "ARN do tópico SNS para alertas"
  value       = aws_sns_topic.documentdb_alerts.arn
}

output "alarm_names" {
  description = "Lista de todos os alarmes criados"
  value = [
    aws_cloudwatch_metric_alarm.high_cpu.alarm_name,
    aws_cloudwatch_metric_alarm.high_connections.alarm_name,
    aws_cloudwatch_metric_alarm.high_replica_lag.alarm_name,
    aws_cloudwatch_metric_alarm.low_memory.alarm_name,
    aws_cloudwatch_metric_alarm.high_storage.alarm_name,
    aws_cloudwatch_metric_alarm.high_write_latency.alarm_name,
    aws_cloudwatch_metric_alarm.high_read_latency.alarm_name,
    aws_cloudwatch_metric_alarm.swap_usage.alarm_name
  ]
}
