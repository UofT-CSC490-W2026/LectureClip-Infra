# ============================================================================
# VIDEO PROCESSING CONTAINER MODULE - OUTPUTS
# ============================================================================

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition (includes revision)"
  value       = aws_ecs_task_definition.segment_frame_extractor.arn
}

output "ecr_repository_url" {
  description = "ECR repository URL for CI to push container images"
  value       = aws_ecr_repository.segment_frame_extractor.repository_url
}

output "task_security_group_id" {
  description = "Security group ID to attach to ECS task network interfaces"
  value       = aws_security_group.ecs_task.id
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role (for Step Functions PassRole)"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role (for Step Functions PassRole)"
  value       = aws_iam_role.segment_frame_extractor_task.arn
}

output "private_subnet_ids" {
  description = "Private subnet IDs passed through for use in Step Functions RunTask"
  value       = var.private_subnet_ids
}
