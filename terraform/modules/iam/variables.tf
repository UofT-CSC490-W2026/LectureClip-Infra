# ============================================================================
# IAM MODULE - VARIABLES
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "user_videos_bucket_arn" {
  description = "ARN of the user videos S3 bucket"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key to grant Lambda decrypt access"
  type        = string
}
