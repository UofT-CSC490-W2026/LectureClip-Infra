# ============================================================================
# ROOT MODULE - MAIN CONFIGURATION
# Orchestrates all infrastructure modules
# ============================================================================

terraform {
  # Partial backend config — supply the environment-specific key at init time:
  #   terraform init -backend-config="environments/backend-dev.hcl"
  #   terraform init -backend-config="environments/backend-prod.hcl"
  backend "s3" {
    bucket       = "757242163795-workshop-tf-state"
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

# ============================================================================
# AURORA DB MODULE
# Aurora Serverless v2 PostgreSQL with pgvector for embeddings and evaluation
# ============================================================================
module "aurora_db" {
  source = "./modules/video_processing/aurora_db"

  project_name             = var.project_name
  environment              = var.environment
  vpc_id                   = module.networking.vpc_id
  private_subnet_ids       = module.networking.private_subnet_ids
  lambda_security_group_id = module.networking.lambda_security_group_id
  kms_key_arn              = module.kms.key_arn

  depends_on = [module.networking, module.kms]
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
  source               = "./modules/cicd"
  project_name         = var.project_name
  environment          = var.environment
  account_id           = var.account_id
  create_oidc_provider = var.create_oidc_provider
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
  aurora_cluster_arn        = module.aurora_db.cluster_arn
  aurora_secret_arn         = module.aurora_db.secret_arn
  aurora_db_name            = module.aurora_db.db_name
  embedding_model_id        = var.embedding_model_id
  embedding_dim             = var.embedding_dim
  modal_embedding_url       = var.modal_embedding_url

  depends_on = [module.kms, module.storage, module.video_processing_database, module.aurora_db]
}

# ============================================================================
# VIDEO PROCESSING — CONTAINER MODULE
# Segment-frame extraction: ECR repo, ECS Fargate cluster, task definition,
# IAM roles, and security group for the waitForTaskToken ECS step.
# ============================================================================
module "video_processing_container" {
  source = "./modules/video_processing/container"

  project_name           = var.project_name
  environment            = var.environment
  aws_region             = data.aws_region.current.name
  vpc_id                 = module.networking.vpc_id
  private_subnet_ids     = module.networking.private_subnet_ids
  user_videos_bucket_id  = module.storage.user_videos_bucket_id
  user_videos_bucket_arn = module.storage.user_videos_bucket_arn
  kms_key_arn            = module.kms.key_arn
  embedding_model_id     = var.embedding_model_id
  embedding_dim          = var.embedding_dim
  modal_embedding_url    = var.modal_embedding_url

  depends_on = [module.networking, module.kms, module.storage]
}

# ============================================================================
# VIDEO PROCESSING — STEP FUNCTION WORKFLOW MODULE
# Transcription → frame extraction → embedding insertion pipeline:
#   SNS → s3-trigger → Step Functions → start-transcribe (waitForTaskToken)
#   → Amazon Transcribe → EventBridge → process-transcribe → SendTaskSuccess
#   → ExtractFrames ECS task (waitForTaskToken) → SendTaskSuccess
#   → process-results Lambda
# ============================================================================
module "video_processing_step_functions" {
  source = "./modules/video_processing/step_function_workflow"

  project_name                     = var.project_name
  environment                      = var.environment
  start_transcribe_lambda_arn      = module.video_processing_lambdas.start_transcribe_arn
  process_transcribe_lambda_arn    = module.video_processing_lambdas.process_transcribe_arn
  process_transcribe_function_name = module.video_processing_lambdas.process_transcribe_function_name
  process_results_lambda_arn       = module.video_processing_lambdas.process_results_arn
  user_videos_sns_topic_arn        = module.storage.user_videos_sns_topic_arn
  ecs_cluster_arn                  = module.video_processing_container.ecs_cluster_arn
  ecs_task_definition_arn          = module.video_processing_container.task_definition_arn
  ecs_subnet_ids                   = module.video_processing_container.private_subnet_ids
  ecs_security_group_id            = module.video_processing_container.task_security_group_id
  ecs_task_execution_role_arn      = module.video_processing_container.task_execution_role_arn
  ecs_task_role_arn                = module.video_processing_container.task_role_arn

  depends_on = [module.video_processing_lambdas, module.video_processing_container]
}

# ============================================================================
# API GATEWAY MODULE
# REST API + /upload, /multipart/init, /multipart/complete resources.
# Deployment and stage are created below so that the retrieval module's
# /query resources can be included in the same deployment trigger.
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

# ============================================================================
# RETRIEVAL MODULE
# ============================================================================
# AUTH MODULE — Cognito User Pool + SPA client
# ============================================================================
module "auth" {
  source = "./modules/auth"

  project_name = var.project_name
  environment  = var.environment
}

# query-segments Lambda + IAM + POST /query API Gateway route
# ============================================================================
module "retrieval" {
  source = "./modules/retrieval"

  project_name              = var.project_name
  environment               = var.environment
  aurora_cluster_arn        = module.aurora_db.cluster_arn
  aurora_secret_arn         = module.aurora_db.secret_arn
  aurora_db_name            = module.aurora_db.db_name
  kms_key_arn               = module.kms.key_arn
  bucket_name               = module.storage.user_videos_bucket_id
  embedding_model_id        = var.embedding_model_id
  embedding_dim             = var.embedding_dim
  modal_embedding_url       = var.modal_embedding_url
  chat_model_id             = var.chat_model_id
  rest_api_id               = module.api_gateway.api_id
  rest_api_execution_arn    = module.api_gateway.api_execution_arn
  rest_api_root_resource_id = module.api_gateway.root_resource_id

  depends_on = [module.api_gateway, module.aurora_db, module.kms]
}

# ============================================================================
# API GATEWAY DEPLOYMENT & STAGE1
# Single deployment so all routes (/upload, /multipart/*, /query) are
# included in one trigger hash and deployed atomically.
# NOTE: if migrating an existing environment, run:
#   terraform state mv module.api_gateway.aws_api_gateway_deployment.main \
#                       aws_api_gateway_deployment.main
#   terraform state mv module.api_gateway.aws_api_gateway_stage.main \
#                       aws_api_gateway_stage.main
# ============================================================================
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = module.api_gateway.api_id

  triggers = {
    redeployment = sha1(jsonencode([
      module.api_gateway.upload_post_integration_id,
      module.api_gateway.upload_options_integration_id,
      module.api_gateway.multipart_init_post_integration_id,
      module.api_gateway.multipart_init_options_integration_id,
      module.api_gateway.multipart_complete_post_integration_id,
      module.api_gateway.multipart_complete_options_integration_id,
      module.retrieval.query_post_integration_id,
      module.retrieval.query_options_integration_id,
      module.retrieval.query_info_post_integration_id,
      module.retrieval.query_info_options_integration_id,
      module.retrieval.chat_post_integration_id,
      module.retrieval.chat_options_integration_id,
      module.retrieval.register_user_post_integration_id,
      module.retrieval.register_user_options_integration_id,
      module.retrieval.lectures_get_integration_id,
      module.retrieval.lectures_options_integration_id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [module.api_gateway, module.retrieval]
}

# ============================================================================
# FRONTEND MODULE
# AWS Amplify hosting for the React/Vite frontend in LectureClip-App/frontend.
# GitHub token is read from SSM at /lectureclip/github-access-token.
# ============================================================================
data "aws_ssm_parameter" "github_access_token" {
  name            = "/lectureclip/github-access-token"
  with_decryption = true
}

module "frontend" {
  source = "./modules/frontend"

  project_name        = var.project_name
  environment         = var.environment
  github_access_token = data.aws_ssm_parameter.github_access_token.value
  api_base_url        = aws_api_gateway_stage.main.invoke_url

  depends_on = [aws_api_gateway_stage.main]
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = module.api_gateway.api_id
  stage_name    = var.environment

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
  }
}
