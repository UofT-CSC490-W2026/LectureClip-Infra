# ============================================================================
# S3 MODULE - VARIABLES
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

variable "kms_key_arn" {
  description = "ARN of the KMS key for S3 server-side encryption"
  type        = string
}
