# ============================================================================
# ROOT MODULE - MAIN CONFIGURATION
# Orchestrates all infrastructure modules
# ============================================================================

terraform {
  backend "s3" {
    bucket       = "757242163795-workshop-tf-state"
    key          = "lectureclip/terraform.tfstate"
    region       = "ca-central-1"
    encrypt      = true
    use_lockfile = true
  }

  required_version = "~>1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~>2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "UofT-CSC490-W2026/LectureClip-Infra"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# CI/CD MODULE
# GitHub Actions OIDC role for secure deployment without long-term credentials
# ============================================================================
module "cicd" {
  source       = "./modules/cicd"
  project_name = var.project_name
  account_id   = var.account_id
}

# ============================================================================
# NETWORKING MODULE
# VPC, subnets, NAT gateway, Lambda security group
# ============================================================================
module "networking" {
  source = "./modules/video_upload/networking"

  project_name = var.project_name
  environment  = var.environment
}

# ============================================================================
# IAM MODULE
# Lambda execution role, GitHub Actions OIDC role
# ============================================================================
module "iam" {
  source = "./modules/video_upload/iam"

  project_name           = var.project_name
  environment            = var.environment
  user_videos_bucket_arn = module.storage.user_videos_bucket_arn
  kms_key_arn            = module.kms.key_arn

  depends_on = [module.kms]
}

# ============================================================================
# KMS MODULE
# Customer-managed encryption key for S3 and CloudWatch
# Lambda access managed via IAM delegation (no circular dep)
# ============================================================================
module "kms" {
  source = "./modules/video_upload/kms"

  project_name = var.project_name
  environment  = var.environment
}

# ============================================================================
# STORAGE MODULE
# User videos S3 bucket with KMS encryption, CORS, and lifecycle policies
# ============================================================================
module "storage" {
  source = "./modules/video_upload/storage"

  project_name = var.project_name
  environment  = var.environment
  account_id   = var.account_id
  kms_key_arn  = module.kms.key_arn
}

# ============================================================================
# LAMBDA MODULE
# Three Lambda functions: video-upload, multipart-init, multipart-complete
# ============================================================================
module "lambda" {
  source = "./modules/video_upload/lambda"

  project_name             = var.project_name
  environment              = var.environment
  user_videos_bucket_id    = module.storage.user_videos_bucket_id
  lambda_role_arn          = module.iam.video_upload_lambda_role_arn
  aws_region               = data.aws_region.current.name
  private_subnet_ids       = module.networking.private_subnet_ids
  lambda_security_group_id = module.networking.lambda_security_group_id
}

# ============================================================================
# VIDEO PROCESSING — DATABASE MODULE
# DynamoDB table for tracking Transcribe job state
# ============================================================================
module "video_processing_database" {
  source = "./modules/video_processing/database"

  project_name = var.project_name
  environment  = var.environment
}

# ============================================================================
# VIDEO PROCESSING — LAMBDAS MODULE
# start-transcribe and process-transcribe Lambda functions
# ============================================================================
module "video_processing_lambdas" {
  source = "./modules/video_processing/lambdas"

  project_name              = var.project_name
  environment               = var.environment
  kms_key_arn               = module.kms.key_arn
  user_videos_bucket_id     = module.storage.user_videos_bucket_id
  user_videos_bucket_arn    = module.storage.user_videos_bucket_arn
  transcriptions_table_name = module.video_processing_database.transcriptions_table_name
  transcriptions_table_arn  = module.video_processing_database.transcriptions_table_arn

  depends_on = [module.kms, module.storage, module.video_processing_database]
}

# ============================================================================
# VIDEO PROCESSING — STEP FUNCTION WORKFLOW MODULE
# Audio transcription workflow: SNS → s3-trigger → Step Functions →
# start-transcribe → Amazon Transcribe → EventBridge → process-transcribe
# ============================================================================
module "video_processing_step_functions" {
  source = "./modules/video_processing/step_function_workflow"

  project_name                     = var.project_name
  environment                      = var.environment
  start_transcribe_lambda_arn      = module.video_processing_lambdas.start_transcribe_arn
  process_transcribe_lambda_arn    = module.video_processing_lambdas.process_transcribe_arn
  process_transcribe_function_name = module.video_processing_lambdas.process_transcribe_function_name
  user_videos_sns_topic_arn        = module.storage.user_videos_sns_topic_arn

  depends_on = [module.video_processing_lambdas]
}

# ============================================================================
# API GATEWAY MODULE
# Three endpoints: /uploads, /multipart/init, /multipart/complete
# ============================================================================
module "api_gateway" {
  source = "./modules/video_upload/api_gateway"

  project_name                     = var.project_name
  environment                      = var.environment
  video_upload_function_name       = module.lambda.video_upload_function_name
  video_upload_invoke_arn          = module.lambda.video_upload_invoke_arn
  multipart_init_function_name     = module.lambda.multipart_init_function_name
  multipart_init_invoke_arn        = module.lambda.multipart_init_invoke_arn
  multipart_complete_function_name = module.lambda.multipart_complete_function_name
  multipart_complete_invoke_arn    = module.lambda.multipart_complete_invoke_arn
}
