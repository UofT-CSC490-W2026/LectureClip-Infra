# ============================================================================
# KMS MODULE - MAIN
# Customer-managed key for encrypting S3 objects and CloudWatch logs.
# Lambda access is managed via IAM role policy (IAM delegation pattern) —
# no need to enumerate Lambda ARNs directly in the key policy.
# ============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_kms_key" "main" {
  description             = "${var.project_name} ${var.environment} encryption key"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Root account has full key admin rights; Lambda access is delegated via IAM policies
        Sid    = "EnableIAMDelegation"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowS3SSE"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-key-test"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "main" {
  # TODO: test suffix should be removed once the previously made keys are deleted.
  name          = "alias/${var.project_name}-${var.environment}-test"
  target_key_id = aws_kms_key.main.key_id
}
