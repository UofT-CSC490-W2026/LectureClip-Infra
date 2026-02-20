# ============================================================================
# LAMBDA MODULE - VARIABLES
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "user_videos_bucket_id" {
  description = "ID of the user videos S3 bucket"
  type        = string
}

variable "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of the private subnets for Lambda VPC placement"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "ID of the Lambda security group"
  type        = string
}
