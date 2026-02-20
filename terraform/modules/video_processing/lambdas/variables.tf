# ============================================================================
# VIDEO PROCESSING LAMBDAS MODULE - VARIABLES
# ============================================================================

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for S3 and CloudWatch encryption"
  type        = string
}

variable "user_videos_bucket_id" {
  description = "ID (name) of the user videos S3 bucket"
  type        = string
}

variable "user_videos_bucket_arn" {
  description = "ARN of the user videos S3 bucket"
  type        = string
}

variable "transcriptions_table_name" {
  description = "Name of the DynamoDB table used to track Transcribe job states"
  type        = string
}

variable "transcriptions_table_arn" {
  description = "ARN of the DynamoDB table used to track Transcribe job states"
  type        = string
}
