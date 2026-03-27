# ============================================================================
# VIDEO PROCESSING STEP FUNCTION WORKFLOW MODULE - MAIN
# Video processing workflow:
#   S3 upload → SNS → s3-trigger Lambda → Step Functions
#   → start-transcribe Lambda (WAIT_FOR_TASK_TOKEN)
#   → Amazon Transcribe (async)
#   → EventBridge → process-transcribe Lambda → SendTaskSuccess
#   → process-results Lambda (Bedrock embeddings) → SFN done
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ============================================================================
# STEP FUNCTIONS STATE MACHINE — IAM ROLE
# ============================================================================

resource "aws_iam_role" "sfn_video_processing" {
  name = "${local.name_prefix}-snf-video-processing"

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
    Name        = "${local.name_prefix}-snf-video-processing"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "sfn_video_processing" {
  name = "${local.name_prefix}-snf-video-processing"
  role = aws_iam_role.sfn_video_processing.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "InvokeLambda"
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = [var.start_transcribe_lambda_arn, var.process_results_lambda_arn]
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
# STEP FUNCTIONS STATE MACHINE — Video Processing Workflow
# start-transcribe uses WAIT_FOR_TASK_TOKEN: the Lambda stores the token in
# DynamoDB and Step Functions pauses until process-transcribe calls
# SendTaskSuccess (via EventBridge → Transcribe job state change).
# ============================================================================

resource "aws_sfn_state_machine" "video_processing" {
  name     = "${local.name_prefix}-video-processing"
  role_arn = aws_iam_role.sfn_video_processing.arn
  type     = "STANDARD"

  definition = jsonencode({
    Comment = "LectureClip video processing: start Transcribe job, wait for completion, then generate embeddings"
    StartAt = "StartTranscribe"
    States = {
      StartTranscribe = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke.waitForTaskToken"
        Parameters = {
          FunctionName = var.start_transcribe_lambda_arn
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
        Next = "ProcessResults"
      }
      ProcessResults = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.process_results_lambda_arn
          "Payload.$"  = "$"
        }
        ResultSelector = {
          "segmentCount.$"   = "$.Payload.segmentCount"
          "embeddingCount.$" = "$.Payload.embeddingCount"
        }
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
            IntervalSeconds = 10
            MaxAttempts     = 3
            BackoffRate     = 2
          }
        ]
        End = true
      }
    }
  })

  tags = {
    Name        = "${local.name_prefix}-audio-transcription"
    Environment = var.environment
  }
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
  arn       = var.process_transcribe_lambda_arn
}

resource "aws_lambda_permission" "eventbridge_invoke_process_transcribe" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.process_transcribe_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.transcribe_state_change.arn
}

# ============================================================================
# IAM ROLE — S3 TRIGGER LAMBDA
# Separate role scoped only to starting the Step Functions execution
# ============================================================================

resource "aws_iam_role" "s3_trigger_lambda" {
  name = "${local.name_prefix}-s3-trigger-lambda"

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
    Name        = "${local.name_prefix}-s3-trigger-lambda"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "s3_trigger_lambda_basic" {
  role       = aws_iam_role.s3_trigger_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "s3_trigger_lambda" {
  name = "${local.name_prefix}-s3-trigger-lambda"
  role = aws_iam_role.s3_trigger_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SFNStartExecution"
        Effect   = "Allow"
        Action   = ["states:StartExecution"]
        Resource = aws_sfn_state_machine.video_processing.arn
      }
    ]
  })
}

# ============================================================================
# LAMBDA — S3 TRIGGER
# Receives SNS ObjectCreated events and starts the Step Functions execution
# ============================================================================

data "archive_file" "placeholder" {
  type        = "zip"
  output_path = "${path.module}/temp/placeholder.zip"

  source {
    content  = "# placeholder — deployed by LectureClip-App CI"
    filename = "index.py"
  }
}

resource "aws_lambda_function" "s3_trigger" {
  function_name    = "${local.name_prefix}-s3-trigger"
  role             = aws_iam_role.s3_trigger_lambda.arn
  handler          = "index.handler"
  runtime          = "python3.13"
  timeout          = 30
  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      STATE_MACHINE_ARN = aws_sfn_state_machine.video_processing.arn
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name        = "${local.name_prefix}-s3-trigger"
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
  topic_arn = var.user_videos_sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.s3_trigger.arn
}
