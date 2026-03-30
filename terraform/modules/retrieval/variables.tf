# ============================================================================
# RETRIEVAL MODULE - VARIABLES
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "aurora_cluster_arn" {
  description = "ARN of the Aurora cluster — used for RDS Data API calls"
  type        = string
}

variable "aurora_secret_arn" {
  description = "Secrets Manager ARN for Aurora master credentials"
  type        = string
}

variable "aurora_db_name" {
  description = "Name of the Aurora database"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the Aurora secret — needed for kms:Decrypt"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket where videos are stored — used to construct the video_uri for DB lookup"
  type        = string
}

variable "rest_api_id" {
  description = "ID of the existing API Gateway REST API to attach /query to"
  type        = string
}

variable "rest_api_execution_arn" {
  description = "Execution ARN of the REST API — used for the Lambda invoke permission"
  type        = string
}

variable "rest_api_root_resource_id" {
  description = "Root resource ID of the REST API — parent for the /query path part"
  type        = string
}

variable "embedding_model_id" {
  description = "Bedrock foundation model ID used to embed queries in query-segments"
  type        = string
}

variable "embedding_dim" {
  description = "Dimensionality of the embedding vectors produced by the embedding model"
  type        = number
}

variable "modal_embedding_url" {
  description = "Modal web endpoint URL for self-hosted jina-clip-v2 embeddings. Empty string when using Bedrock."
  type        = string
  default     = ""
}

variable "chat_model_id" {
  description = "Bedrock model ID for the chat lambda (Claude via Converse API)"
  type        = string
  default     = "global.anthropic.claude-haiku-4-5-20251001-v1:0"
}
