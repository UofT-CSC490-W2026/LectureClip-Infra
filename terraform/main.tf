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
# NETWORKING MODULE
# VPC, subnets, NAT gateway, Lambda security group
# ============================================================================
module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  environment  = var.environment
}

# ============================================================================
# IAM MODULE
# Lambda execution role, GitHub Actions OIDC role
# ============================================================================
module "iam" {
  source = "./modules/iam"

  project_name           = var.project_name
  environment            = var.environment
  account_id             = var.account_id
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
  source = "./modules/kms"

  project_name = var.project_name
  environment  = var.environment
}

# ============================================================================
# STORAGE MODULE
# User videos S3 bucket with KMS encryption, CORS, and lifecycle policies
# ============================================================================
module "storage" {
  source = "./modules/storage"

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
  source = "./modules/lambda"

  project_name             = var.project_name
  environment              = var.environment
  user_videos_bucket_id    = module.storage.user_videos_bucket_id
  lambda_role_arn          = module.iam.video_upload_lambda_role_arn
  aws_region               = data.aws_region.current.name
  private_subnet_ids       = module.networking.private_subnet_ids
  lambda_security_group_id = module.networking.lambda_security_group_id
}

# ============================================================================
# TRANSCRIPTION MODULE
# Audio transcription workflow: SNS → s3-trigger → Step Functions →
# start-transcribe → Amazon Transcribe → EventBridge → process-transcribe
# ============================================================================
module "transcription" {
  source = "./modules/transcription"

  project_name              = var.project_name
  environment               = var.environment
  kms_key_arn               = module.kms.key_arn
  user_videos_bucket_id     = module.storage.user_videos_bucket_id
  user_videos_bucket_arn    = module.storage.user_videos_bucket_arn
  user_videos_sns_topic_arn = module.storage.user_videos_sns_topic_arn

  depends_on = [module.kms, module.storage]
}

# ============================================================================
# API GATEWAY MODULE
# Three endpoints: /uploads, /multipart/init, /multipart/complete
# ============================================================================
module "api_gateway" {
  source = "./modules/api_gateway"

  project_name                     = var.project_name
  environment                      = var.environment
  video_upload_function_name       = module.lambda.video_upload_function_name
  video_upload_invoke_arn          = module.lambda.video_upload_invoke_arn
  multipart_init_function_name     = module.lambda.multipart_init_function_name
  multipart_init_invoke_arn        = module.lambda.multipart_init_invoke_arn
  multipart_complete_function_name = module.lambda.multipart_complete_function_name
  multipart_complete_invoke_arn    = module.lambda.multipart_complete_invoke_arn
}
