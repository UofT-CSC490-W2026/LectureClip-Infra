# ============================================================================
# IAM MODULE - MAIN
# Manages IAM roles and policies
# ============================================================================

# ============================================================================
# LAMBDA EXECUTION ROLE
# ============================================================================

resource "aws_iam_role" "video_upload_lambda" {
  name = "${var.project_name}-video-upload-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-video-upload-lambda"
    Environment = var.environment
  }
}

# S3 permissions — direct upload (presigned URL) + multipart upload lifecycle
resource "aws_iam_role_policy" "video_upload_lambda_s3" {
  name = "${var.project_name}-video-upload-lambda-s3"
  role = aws_iam_role.video_upload_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:CreateMultipartUpload",
          "s3:UploadPart",
          "s3:CompleteMultipartUpload",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = "${var.user_videos_bucket_arn}/*"
      }
    ]
  })
}

# KMS permissions — required to generate presigned URLs for KMS-encrypted buckets
resource "aws_iam_role_policy" "video_upload_lambda_kms" {
  name = "${var.project_name}-video-upload-lambda-kms"
  role = aws_iam_role.video_upload_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "video_upload_lambda_basic" {
  role       = aws_iam_role.video_upload_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC access — required for Lambdas placed in private subnets
resource "aws_iam_role_policy_attachment" "video_upload_lambda_vpc" {
  role       = aws_iam_role.video_upload_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
