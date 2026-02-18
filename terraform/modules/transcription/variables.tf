# ============================================================================
# TRANSCRIPTION MODULE - VARIABLES
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

variable "user_videos_sns_topic_arn" {
  description = "ARN of the SNS topic that receives S3 ObjectCreated events from the user videos bucket"
  type        = string
}
