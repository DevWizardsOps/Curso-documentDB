output "cluster_id" {
  description = "The DocumentDB cluster identifier"
  value       = aws_docdb_cluster.main.id
}

output "cluster_arn" {
  description = "The ARN of the DocumentDB cluster"
  value       = aws_docdb_cluster.main.arn
}

output "cluster_endpoint" {
  description = "The cluster endpoint (writer)"
  value       = aws_docdb_cluster.main.endpoint
}

output "cluster_reader_endpoint" {
  description = "The cluster reader endpoint"
  value       = aws_docdb_cluster.main.reader_endpoint
}

output "cluster_port" {
  description = "The port the cluster is listening on"
  value       = aws_docdb_cluster.main.port
}

output "cluster_resource_id" {
  description = "The resource ID of the cluster"
  value       = aws_docdb_cluster.main.cluster_resource_id
}

output "master_username" {
  description = "The master username"
  value       = aws_docdb_cluster.main.master_username
  sensitive   = true
}

output "instance_endpoints" {
  description = "List of instance endpoints"
  value       = aws_docdb_cluster_instance.main[*].endpoint
}

output "instance_identifiers" {
  description = "List of instance identifiers"
  value       = aws_docdb_cluster_instance.main[*].identifier
}

output "security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.docdb.id
}

output "subnet_group_name" {
  description = "The name of the subnet group"
  value       = aws_docdb_subnet_group.main.name
}

output "connection_string" {
  description = "MongoDB connection string (without password)"
  value       = "mongodb://${aws_docdb_cluster.main.master_username}:PASSWORD@${aws_docdb_cluster.main.endpoint}:${aws_docdb_cluster.main.port}/?tls=true&tlsCAFile=global-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
  sensitive   = true
}

output "ssl_certificate_url" {
  description = "URL to download the SSL certificate"
  value       = "https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem"
}
