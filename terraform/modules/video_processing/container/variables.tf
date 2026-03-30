# ============================================================================
# VIDEO PROCESSING CONTAINER MODULE - VARIABLES
# ============================================================================

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for CloudWatch log group configuration"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the ECS task security group"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs in which ECS Fargate tasks will run"
  type        = list(string)
}

variable "user_videos_bucket_id" {
  description = "Name of the user videos S3 bucket (used as TRANSCRIPTS_BUCKET env var)"
  type        = string
}

variable "user_videos_bucket_arn" {
  description = "ARN of the user videos S3 bucket (used to scope S3 IAM policy)"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt S3 objects read/written by the container"
  type        = string
}

variable "embedding_model_id" {
  description = "Bedrock foundation model ID used for frame embeddings in the ECS container"
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
