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

variable "create_oidc_provider" {
  description = "Whether to create the GitHub OIDC provider. Set to true for the first environment deployed (prod), false for subsequent environments (dev) to avoid duplicate provider errors."
  type        = bool
  default     = false
}

variable "embedding_model_id" {
  description = "Bedrock foundation model ID used for all embeddings (frame extraction, query encoding)"
  type        = string
  default     = "amazon.titan-embed-image-v1"
}

variable "embedding_dim" {
  description = "Dimensionality of the embedding vectors produced by the embedding model"
  type        = number
  default     = 1024
}

variable "modal_embedding_url" {
  description = "Modal web endpoint URL for self-hosted jina-clip-v2 embeddings. Required when embedding_model_id=modal-jina-clip-v2, empty string otherwise."
  type        = string
  default     = ""
}
