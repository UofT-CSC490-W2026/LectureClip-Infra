# ============================================================================
# TRANSCRIPTION MODULE - MAIN
# Audio transcription workflow:
#   S3 upload → SNS → s3-trigger Lambda → Step Functions
#   → start-transcribe Lambda (WAIT_FOR_TASK_TOKEN)
#   → Amazon Transcribe (async)
#   → EventBridge → process-transcribe Lambda → SendTaskSuccess → SFN done
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
        Resource = aws_dynamodb_table.transcriptions.arn
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
        Sid      = "SFNStartExecution"
        Effect   = "Allow"
        Action   = ["states:StartExecution"]
        Resource = aws_sfn_state_machine.audio_transcription.arn
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
# DYNAMODB TABLE — TRANSCRIPTION JOB TRACKING
# Stores {TranscriptionJobName, status, s3_uri, sftoken (task token)}
# ============================================================================

resource "aws_dynamodb_table" "transcriptions" {
  name         = "${local.name_prefix}-transcriptions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "TranscriptionJobName"

  attribute {
    name = "TranscriptionJobName"
    type = "S"
  }

  tags = {
    Name        = "${local.name_prefix}-transcriptions"
    Environment = var.environment
  }
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
# STEP FUNCTIONS STATE MACHINE — IAM ROLE
# ============================================================================

resource "aws_iam_role" "sfn_audio_transcription" {
  name = "${local.name_prefix}-sfn-audio-transcription"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "states.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-sfn-audio-transcription"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "sfn_audio_transcription" {
  name = "${local.name_prefix}-sfn-audio-transcription"
  role = aws_iam_role.sfn_audio_transcription.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "InvokeLambda"
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = [aws_lambda_function.start_transcribe.arn]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# LAMBDA FUNCTIONS
# handler = index.handler  (matches LectureClip-App convention)
# ignore_changes on source_code_hash so CI deployments are never reverted
# ============================================================================

resource "aws_lambda_function" "start_transcribe" {
  function_name    = "${var.project_name}-start-transcribe"
  role             = aws_iam_role.transcription_lambda.arn
  handler          = "index.handler"
  runtime          = "python3.13"
  timeout          = 60
  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      TRANSCRIBE_TABLE   = aws_dynamodb_table.transcriptions.name
      TRANSCRIPTS_BUCKET = var.user_videos_bucket_id
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name        = "${var.project_name}-start-transcribe"
    Environment = var.environment
  }
}

resource "aws_lambda_function" "process_transcribe" {
  function_name    = "${var.project_name}-process-transcribe"
  role             = aws_iam_role.transcription_lambda.arn
  handler          = "index.handler"
  runtime          = "python3.13"
  timeout          = 60
  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      TRANSCRIBE_TABLE = aws_dynamodb_table.transcriptions.name
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name        = "${var.project_name}-process-transcribe"
    Environment = var.environment
  }
}

# ============================================================================
# STEP FUNCTIONS STATE MACHINE — AUDIO TRANSCRIPTION
# start-transcribe uses WAIT_FOR_TASK_TOKEN: the Lambda stores the token in
# DynamoDB and Step Functions pauses until process-transcribe calls
# SendTaskSuccess (via EventBridge → Transcribe job state change).
# ============================================================================

resource "aws_sfn_state_machine" "audio_transcription" {
  name     = "${var.project_name}-audio-transcription"
  role_arn = aws_iam_role.sfn_audio_transcription.arn
  type     = "STANDARD"

  definition = jsonencode({
    Comment = "LectureClip audio transcription: start Transcribe job and wait for completion"
    StartAt = "StartTranscribe"
    States = {
      StartTranscribe = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke.waitForTaskToken"
        Parameters = {
          FunctionName = aws_lambda_function.start_transcribe.arn
          Payload = {
            "s3_uri.$"  = "$.s3_uri"
            "sftoken.$" = "$$.Task.Token"
          }
        }
        TimeoutSeconds = 1800
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
            IntervalSeconds = 10
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
        End = true
      }
    }
  })

  tags = {
    Name        = "${var.project_name}-audio-transcription"
    Environment = var.environment
  }
}

# ============================================================================
# LAMBDA — S3 TRIGGER
# Created after the state machine so STATE_MACHINE_ARN is available
# ============================================================================

resource "aws_lambda_function" "s3_trigger" {
  function_name    = "${var.project_name}-s3-trigger"
  role             = aws_iam_role.transcription_lambda.arn
  handler          = "index.handler"
  runtime          = "python3.13"
  timeout          = 30
  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      STATE_MACHINE_ARN = aws_sfn_state_machine.audio_transcription.arn
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name        = "${var.project_name}-s3-trigger"
    Environment = var.environment
  }
}

# ============================================================================
# SNS → s3-trigger SUBSCRIPTION
# The user_videos bucket already sends ObjectCreated events to this SNS topic;
# s3-trigger subscribes and filters by file extension in code.
# ============================================================================

resource "aws_lambda_permission" "sns_invoke_s3_trigger" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_trigger.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.user_videos_sns_topic_arn
}

resource "aws_sns_topic_subscription" "s3_trigger" {
  topic_arn  = var.user_videos_sns_topic_arn
  protocol   = "lambda"
  endpoint   = aws_lambda_function.s3_trigger.arn
}

# ============================================================================
# EVENTBRIDGE — TRANSCRIBE JOB STATE CHANGE → process-transcribe
# ============================================================================

resource "aws_cloudwatch_event_rule" "transcribe_state_change" {
  name        = "${local.name_prefix}-transcribe-state-change"
  description = "Capture Amazon Transcribe job completion/failure events"

  event_pattern = jsonencode({
    source      = ["aws.transcribe"]
    detail-type = ["Transcribe Job State Change"]
    detail = {
      TranscriptionJobStatus = ["COMPLETED", "FAILED"]
    }
  })

  tags = {
    Name        = "${local.name_prefix}-transcribe-state-change"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "process_transcribe" {
  rule      = aws_cloudwatch_event_rule.transcribe_state_change.name
  target_id = "ProcessTranscribeLambda"
  arn       = aws_lambda_function.process_transcribe.arn
}

resource "aws_lambda_permission" "eventbridge_invoke_process_transcribe" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_transcribe.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.transcribe_state_change.arn
}
