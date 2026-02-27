# ============================================================================
# LAMBDA CODE PLACEHOLDER
# Used for initial bootstrap. App CI (LectureClip-App) owns all code updates
# via `aws lambda update-function-code --zip-file`. Terraform will not
# overwrite CI deployments (ignore_changes = [source_code_hash]).
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

data "archive_file" "lambda_placeholder" {
  type = "zip"
  source {
    content  = "def handler(event, context): return {'statusCode': 503, 'body': 'Lambda not yet deployed'}"
    filename = "index.py"
  }
  output_path = "${path.module}/temp/placeholder.zip"
}

# ============================================================================
# LAMBDA FUNCTIONS
# ============================================================================

# Direct upload — generates a pre-signed PUT URL for the client
resource "aws_lambda_function" "video_upload" {
  filename         = data.archive_file.lambda_placeholder.output_path
  source_code_hash = data.archive_file.lambda_placeholder.output_base64sha256
  function_name    = "${local.name_prefix}-video-upload"
  role             = var.lambda_role_arn
  handler          = "index.handler"
  runtime          = "python3.13"
  timeout          = 30

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      BUCKET_NAME = var.user_videos_bucket_id
      REGION      = var.aws_region
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name        = "${local.name_prefix}-video-upload"
    Environment = var.environment
  }
}

# Multipart init — creates a multipart upload and returns pre-signed part URLs
resource "aws_lambda_function" "multipart_init" {
  filename         = data.archive_file.lambda_placeholder.output_path
  source_code_hash = data.archive_file.lambda_placeholder.output_base64sha256
  function_name    = "${local.name_prefix}-multipart-init"
  role             = var.lambda_role_arn
  handler          = "index.handler"
  runtime          = "python3.13"
  timeout          = 30

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      BUCKET_NAME = var.user_videos_bucket_id
      REGION      = var.aws_region
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name        = "${local.name_prefix}-multipart-init"
    Environment = var.environment
  }
}

# Multipart complete — assembles uploaded parts into a final object
resource "aws_lambda_function" "multipart_complete" {
  filename         = data.archive_file.lambda_placeholder.output_path
  source_code_hash = data.archive_file.lambda_placeholder.output_base64sha256
  function_name    = "${local.name_prefix}-multipart-complete"
  role             = var.lambda_role_arn
  handler          = "index.handler"
  runtime          = "python3.13"
  timeout          = 30

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      BUCKET_NAME = var.user_videos_bucket_id
      REGION      = var.aws_region
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name        = "${local.name_prefix}-multipart-complete"
    Environment = var.environment
  }
}

# ============================================================================
# CLOUDWATCH LOG GROUPS
# ============================================================================

resource "aws_cloudwatch_log_group" "video_upload" {
  name              = "/aws/lambda/${aws_lambda_function.video_upload.function_name}"
  retention_in_days = 14

  tags = {
    Name        = "${local.name_prefix}-video-upload-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "multipart_init" {
  name              = "/aws/lambda/${aws_lambda_function.multipart_init.function_name}"
  retention_in_days = 14

  tags = {
    Name        = "${local.name_prefix}-multipart-init-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "multipart_complete" {
  name              = "/aws/lambda/${aws_lambda_function.multipart_complete.function_name}"
  retention_in_days = 14

  tags = {
    Name        = "${local.name_prefix}-multipart-complete-logs"
    Environment = var.environment
  }
}
