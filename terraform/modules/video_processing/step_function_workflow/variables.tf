# ============================================================================
# VIDEO PROCESSING STEP FUNCTION WORKFLOW MODULE - VARIABLES
# ============================================================================

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "start_transcribe_lambda_arn" {
  description = "ARN of the start-transcribe Lambda function"
  type        = string
}

variable "process_transcribe_lambda_arn" {
  description = "ARN of the process-transcribe Lambda function"
  type        = string
}

variable "process_transcribe_function_name" {
  description = "Name of the process-transcribe Lambda function"
  type        = string
}

variable "user_videos_sns_topic_arn" {
  description = "ARN of the SNS topic that receives S3 ObjectCreated events from the user videos bucket"
  type        = string
}

variable "process_results_lambda_arn" {
  description = "ARN of the process-results Lambda function invoked after transcription completes"
  type        = string
}

variable "ecs_cluster_arn" {
  description = "ARN of the ECS cluster used to run the segment-frame extraction task"
  type        = string
}

variable "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition (family:revision) for the segment-frame extractor"
  type        = string
}

variable "ecs_subnet_ids" {
  description = "Private subnet IDs in which the ECS Fargate task will run"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID attached to the ECS task network interface"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role — Step Functions must PassRole to ECS"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ARN of the ECS task role — Step Functions must PassRole to ECS"
  type        = string
}
