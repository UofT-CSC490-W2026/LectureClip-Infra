# ============================================================================
# AURORA DB MODULE - OUTPUTS
# ============================================================================

output "cluster_arn" {
  description = "ARN of the Aurora cluster"
  value       = aws_rds_cluster.aurora.arn
}

output "cluster_endpoint" {
  description = "Writer endpoint of the Aurora cluster"
  value       = aws_rds_cluster.aurora.endpoint
}

output "secret_arn" {
  description = "Secrets Manager ARN for the Aurora master user credentials"
  value       = aws_rds_cluster.aurora.master_user_secret[0].secret_arn
}

output "db_name" {
  description = "Name of the initial database created on the cluster"
  value       = local.db_name
}

output "security_group_id" {
  description = "ID of the Aurora security group"
  value       = aws_security_group.aurora.id
}

output "db_migrate_function_name" {
  description = "Name of the db-migrate Lambda function"
  value       = aws_lambda_function.db_migrate.function_name
}
