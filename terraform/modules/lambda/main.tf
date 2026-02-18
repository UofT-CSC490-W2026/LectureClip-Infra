
# ============================================================================
# LAMBDA ARTIFACTS BUCKET
# ============================================================================

resource "aws_s3_bucket" "lambda_artifacts" {
  bucket = "${var.project_name}-lambda-artifacts-${var.account_id}"

  tags = {
    Name        = "${var.project_name}-lambda-artifacts"
    Environment = var.environment
    Purpose     = "Lambda deployment packages"
  }
}

resource "aws_s3_bucket_versioning" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================================
# LAMBDA CODE PLACEHOLDER
# Used for initial bootstrap. App CI (LectureClip-App) owns all code updates
# via `aws lambda update-function-code`. Terraform will not overwrite CI deployments.
# ============================================================================

data "archive_file" "lambda_placeholder" {
  type = "zip"
  source {
    content  = "def handler(event, context): return {'statusCode': 503, 'body': 'Lambda not yet deployed'}"
    filename = "index.py"
  }
  output_path = "${path.module}/temp/placeholder.zip"
}

# One S3 object per function — same placeholder zip, different keys
resource "aws_s3_object" "video_upload_code" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  key    = var.lambda_code_s3_key
  source = data.archive_file.lambda_placeholder.output_path
  etag   = data.archive_file.lambda_placeholder.output_md5

  lifecycle {
    ignore_changes = [source, etag]
  }
}

resource "aws_s3_object" "multipart_init_code" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  key    = var.multipart_init_s3_key
  source = data.archive_file.lambda_placeholder.output_path
  etag   = data.archive_file.lambda_placeholder.output_md5

  lifecycle {
    ignore_changes = [source, etag]
  }
}

resource "aws_s3_object" "multipart_complete_code" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  key    = var.multipart_complete_s3_key
  source = data.archive_file.lambda_placeholder.output_path
  etag   = data.archive_file.lambda_placeholder.output_md5

  lifecycle {
    ignore_changes = [source, etag]
  }
}

# ============================================================================
# LAMBDA FUNCTIONS
# ============================================================================

# Direct upload — generates a pre-signed PUT URL for the client
resource "aws_lambda_function" "video_upload" {
  s3_bucket        = aws_s3_bucket.lambda_artifacts.id
  s3_key           = aws_s3_object.video_upload_code.key
  function_name    = "${var.project_name}-video-upload"
  role             = var.lambda_role_arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_placeholder.output_base64sha256
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
    Name        = "${var.project_name}-video-upload"
    Environment = var.environment
  }
}

# Multipart init — creates a multipart upload and returns pre-signed part URLs
resource "aws_lambda_function" "multipart_init" {
  s3_bucket        = aws_s3_bucket.lambda_artifacts.id
  s3_key           = aws_s3_object.multipart_init_code.key
  function_name    = "${var.project_name}-multipart-init"
  role             = var.lambda_role_arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_placeholder.output_base64sha256
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
    Name        = "${var.project_name}-multipart-init"
    Environment = var.environment
  }
}

# Multipart complete — assembles uploaded parts into a final object
resource "aws_lambda_function" "multipart_complete" {
  s3_bucket        = aws_s3_bucket.lambda_artifacts.id
  s3_key           = aws_s3_object.multipart_complete_code.key
  function_name    = "${var.project_name}-multipart-complete"
  role             = var.lambda_role_arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_placeholder.output_base64sha256
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
    Name        = "${var.project_name}-multipart-complete"
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
    Name        = "${var.project_name}-video-upload-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "multipart_init" {
  name              = "/aws/lambda/${aws_lambda_function.multipart_init.function_name}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-multipart-init-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "multipart_complete" {
  name              = "/aws/lambda/${aws_lambda_function.multipart_complete.function_name}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-multipart-complete-logs"
    Environment = var.environment
  }
}
