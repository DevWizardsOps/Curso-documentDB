variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-2"
}

variable "cluster_identifier" {
  description = "Identifier for the DocumentDB cluster"
  type        = string
  default     = "lab-cluster-terraform"
}

variable "engine_version" {
  description = "DocumentDB engine version"
  type        = string
  default     = "5.0.0"
}

variable "master_username" {
  description = "Master username for DocumentDB"
  type        = string
  default     = "docdbadmin"
}

variable "master_password" {
  description = "Master password for DocumentDB (use Secrets Manager in production)"
  type        = string
  sensitive   = true
  default     = "Lab12345!"
}

variable "instance_count" {
  description = "Number of instances in the cluster"
  type        = number
  default     = 3
  
  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 16
    error_message = "Instance count must be between 1 and 16."
  }
}

variable "instance_class" {
  description = "Instance class for DocumentDB instances"
  type        = string
  default     = "db.t3.medium"
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35
    error_message = "Backup retention must be between 1 and 35 days."
  }
}

variable "preferred_backup_window" {
  description = "Daily time range for backups (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "preferred_maintenance_window" {
  description = "Weekly time range for maintenance (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when deleting cluster"
  type        = bool
  default     = true
}

variable "auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades"
  type        = bool
  default     = true
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to DocumentDB"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Change this in production!
}

variable "enable_audit_logs" {
  description = "Enable audit logs"
  type        = bool
  default     = false
}

variable "cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = ["audit", "profiler"]
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (uses default if not specified)"
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "lab"
}
