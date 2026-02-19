# ============================================================================
# VARIABLES - ROOT MODULE
# ============================================================================

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ca-central-1"
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "757242163795"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "lectureclip"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}
