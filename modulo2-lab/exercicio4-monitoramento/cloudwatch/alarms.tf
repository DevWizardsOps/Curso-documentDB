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
variable "student_id" {
  description = "Unique identifier for the student (e.g., 'johndoe'). Used to prefix resource names."
  type        = string
}

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
  name = "${var.student_id}-documentdb-alerts"

  tags = {
    Name        = "${var.student_id}-DocumentDB Alerts"
    Environment = "Lab"
    ManagedBy   = "Terraform"
    Student     = var.student_id
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.documentdb_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Alarm 1: High CPU Utilization
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.student_id}-DocumentDB-HighCPU"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/DocDB"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU utilization for ${var.student_id} cluster above 80% for 5 minutes"
  alarm_actions       = [aws_sns_topic.documentdb_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = "${var.student_id}-${var.cluster_identifier}"
  }

  tags = {
    Name        = "${var.student_id}-DocumentDB High CPU Alarm"
    Environment = "Lab"
    Severity    = "High"
    Student     = var.student_id
  }
}

# ... (outros alarmes com o mesmo padrão de prefixo) ...

# Composite Alarm: Critical Cluster Health
resource "aws_cloudwatch_composite_alarm" "critical_cluster_health" {
  alarm_name          = "${var.student_id}-DocumentDB-CriticalClusterHealth"
  alarm_description   = "Múltiplos indicadores críticos detectados para o cluster de ${var.student_id}"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.documentdb_alerts.arn]

  alarm_rule = join(" OR ", [
    "ALARM(\"${aws_cloudwatch_metric_alarm.high_cpu.alarm_name}\")",
    // Adicione outros alarmes aqui
  ])

  tags = {
    Name        = "${var.student_id}-DocumentDB Critical Health Composite Alarm"
    Environment = "Lab"
    Severity    = "Critical"
    Student     = var.student_id
  }
}

# Outputs
output "sns_topic_arn" {
  description = "ARN do tópico SNS para alertas"
  value       = aws_sns_topic.documentdb_alerts.arn
}
