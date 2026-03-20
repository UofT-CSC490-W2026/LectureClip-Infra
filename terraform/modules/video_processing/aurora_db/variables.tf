# ============================================================================
# AURORA DB MODULE - VARIABLES
# ============================================================================

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to place Aurora in"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the Aurora DB subnet group"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "ID of the Lambda security group — allowed to reach Aurora on port 5432"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt Aurora storage and the managed secret"
  type        = string
}
