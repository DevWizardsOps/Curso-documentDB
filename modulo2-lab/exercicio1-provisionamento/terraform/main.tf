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

# Data sources
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group para DocumentDB
resource "aws_security_group" "docdb" {
  name        = "${var.student_id}-${var.cluster_identifier}-sg"
  description = "Security group for DocumentDB cluster ${var.student_id}-${var.cluster_identifier}"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "MongoDB protocol"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.student_id}-${var.cluster_identifier}-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Student     = var.student_id
  }
}

# Subnet Group para DocumentDB
resource "aws_docdb_subnet_group" "main" {
  name       = "${var.student_id}-${var.cluster_identifier}-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name        = "${var.student_id}-${var.cluster_identifier}-subnet-group"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Student     = var.student_id
  }
}

# Cluster Parameter Group
resource "aws_docdb_cluster_parameter_group" "main" {
  family      = "docdb5.0"
  name        = "${var.student_id}-${var.cluster_identifier}-params"
  description = "DocumentDB cluster parameter group for ${var.student_id}-${var.cluster_identifier}"

  parameter {
    name  = "tls"
    value = "enabled"
  }

  parameter {
    name  = "ttl_monitor"
    value = "enabled"
  }

  parameter {
    name  = "audit_logs"
    value = var.enable_audit_logs ? "enabled" : "disabled"
  }

  tags = {
    Name        = "${var.student_id}-${var.cluster_identifier}-params"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Student     = var.student_id
  }
}

# DocumentDB Cluster
resource "aws_docdb_cluster" "main" {
  cluster_identifier              = "${var.student_id}-${var.cluster_identifier}"
  engine                          = "docdb"
  engine_version                  = var.engine_version
  master_username                 = var.master_username
  master_password                 = var.master_password
  backup_retention_period         = var.backup_retention_period
  preferred_backup_window         = var.preferred_backup_window
  preferred_maintenance_window    = var.preferred_maintenance_window
  skip_final_snapshot            = var.skip_final_snapshot
  final_snapshot_identifier      = var.skip_final_snapshot ? null : "${var.student_id}-${var.cluster_identifier}-final-snapshot"
  db_subnet_group_name           = aws_docdb_subnet_group.main.name
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.main.name
  vpc_security_group_ids         = [aws_security_group.docdb.id]
  enabled_cloudwatch_logs_exports = var.cloudwatch_logs_exports
  storage_encrypted              = true
  kms_key_id                     = var.kms_key_id

  tags = {
    Name        = "${var.student_id}-${var.cluster_identifier}"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Student     = var.student_id
  }
}

# DocumentDB Cluster Instances
resource "aws_docdb_cluster_instance" "main" {
  count              = var.instance_count
  identifier         = "${var.student_id}-${var.cluster_identifier}-${count.index + 1}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.instance_class
  
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  promotion_tier            = count.index

  tags = {
    Name        = "${var.student_id}-${var.cluster_identifier}-instance-${count.index + 1}"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Role        = count.index == 0 ? "primary" : "replica"
    Student     = var.student_id
  }
}
