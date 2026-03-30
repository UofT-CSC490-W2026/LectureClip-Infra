# ============================================================================
# VIDEO PROCESSING LAMBDAS MODULE - MAIN
# Lambda functions for audio transcription:
#   - start-transcribe: Starts Transcribe job (called by Step Functions)
#   - process-transcribe: Handles Transcribe completion (called by EventBridge)
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ============================================================================
# IAM ROLE - TRANSCRIPTION LAMBDAS
# ============================================================================

resource "aws_iam_role" "transcription_lambda" {
  name = "${local.name_prefix}-transcription-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-transcription-lambda"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "transcription_lambda_basic" {
  role       = aws_iam_role.transcription_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "transcription_lambda" {
  name = "${local.name_prefix}-transcription-lambda"
  role = aws_iam_role.transcription_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "S3Access"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${var.user_videos_bucket_arn}/*"
      },
      {
        Sid      = "KMSAccess"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = var.kms_key_arn
      },
      {
        Sid      = "DynamoDBAccess"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
        Resource = var.transcriptions_table_arn
      },
      {
        Sid    = "TranscribeAccess"
        Effect = "Allow"
        Action = [
          "transcribe:StartTranscriptionJob",
          "transcribe:GetTranscriptionJob"
        ]
        Resource = "*"
      },
      {
        Sid      = "SFNTaskSignal"
        Effect   = "Allow"
        Action   = ["states:SendTaskSuccess", "states:SendTaskFailure"]
        Resource = "*"
      }
    ]
  })
}


# ============================================================================
# LAMBDA — PLACEHOLDER ARCHIVE
# Real code is deployed by LectureClip-App CI via aws lambda update-function-code
# ============================================================================

data "archive_file" "placeholder" {
  type        = "zip"
  output_path = "${path.module}/temp/placeholder.zip"

  source {
    content  = "# placeholder — deployed by LectureClip-App CI"
    filename = "index.py"
  }
}

# ============================================================================
# LAMBDA FUNCTIONS
# handler = index.handler  (matches LectureClip-App convention)
# ignore_changes on source_code_hash so CI deployments are never reverted
# ============================================================================

resource "aws_lambda_function" "start_transcribe" {
  function_name    = "${local.name_prefix}-start-transcribe"
  role             = aws_iam_role.transcription_lambda.arn
  handler          = "index.handler"
  runtime          = "python3.13"
  timeout          = 60
  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      TRANSCRIBE_TABLE   = var.transcriptions_table_name
      TRANSCRIPTS_BUCKET = var.user_videos_bucket_id
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name        = "${local.name_prefix}-start-transcribe"
    Environment = var.environment
  }
}

resource "aws_lambda_function" "process_transcribe" {
  function_name    = "${local.name_prefix}-process-transcribe"
  role             = aws_iam_role.transcription_lambda.arn
  handler          = "index.handler"
  runtime          = "python3.13"
  timeout          = 60
  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      TRANSCRIBE_TABLE = var.transcriptions_table_name
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name        = "${local.name_prefix}-process-transcribe"
    Environment = var.environment
  }
}

# ============================================================================
# IAM ROLE - PROCESS RESULTS LAMBDA
# Separate role scoped to Bedrock InvokeModel + S3 GetObject (transcript fetch)
# ============================================================================

resource "aws_iam_role" "process_results_lambda" {
  name = "${local.name_prefix}-process-results-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-process-results-lambda"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "process_results_lambda_basic" {
  role       = aws_iam_role.process_results_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "process_results_lambda" {
  name = "${local.name_prefix}-process-results-lambda"
  role = aws_iam_role.process_results_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "S3GetTranscript"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${var.user_videos_bucket_arn}/*"
      },
      {
        Sid      = "S3ListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = var.user_videos_bucket_arn
      },
      {
        Sid      = "KMSDecrypt"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = var.kms_key_arn
      },
      {
        Sid      = "BedrockInvokeModel"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:*::foundation-model/${var.embedding_model_id}"
      },
      {
        Sid      = "RDSDataAPI"
        Effect   = "Allow"
        Action   = ["rds-data:ExecuteStatement", "rds-data:BatchExecuteStatement"]
        Resource = var.aurora_cluster_arn
      },
      {
        Sid      = "AuroraSecretAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.aurora_secret_arn
      }
    ]
  })
}

# ============================================================================
# LAMBDA — PROCESS RESULTS
# Invoked by Step Functions after transcription completes; fetches the
# Transcribe output, parses speaker segments, and generates Bedrock embeddings.
# Real code is deployed by LectureClip-App CI via aws lambda update-function-code
# ============================================================================

resource "aws_lambda_function" "process_results" {
  function_name    = "${local.name_prefix}-process-results"
  role             = aws_iam_role.process_results_lambda.arn
  handler          = "index.handler"
  runtime          = "python3.13"
  memory_size      = 1024
  timeout          = 900
  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      EMBEDDING_MODEL_ID       = var.embedding_model_id
      EMBEDDING_DIM            = tostring(var.embedding_dim)
      FRAME_EMBEDDING_MODEL_ID = var.embedding_model_id
      MODAL_EMBEDDING_URL      = var.modal_embedding_url
      AURORA_CLUSTER_ARN       = var.aurora_cluster_arn
      AURORA_SECRET_ARN        = var.aurora_secret_arn
      AURORA_DB_NAME           = var.aurora_db_name
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name        = "${local.name_prefix}-process-results"
    Environment = var.environment
  }
}
