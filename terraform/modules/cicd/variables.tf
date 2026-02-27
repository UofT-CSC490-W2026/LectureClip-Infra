# ============================================================================
# IAM MODULE - VARIABLES
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "create_oidc_provider" {
  description = "Whether to create the GitHub OIDC provider. True for first/prod deploy; false for subsequent environments that share the provider."
  type        = bool
  default     = false
}
