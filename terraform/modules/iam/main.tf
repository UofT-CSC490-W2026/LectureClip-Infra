# ============================================================================
# IAM MODULE - MAIN
# Manages IAM roles and policies
# ============================================================================

# ============================================================================
# GITHUB ACTIONS OIDC & ROLE
# ============================================================================

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name = "GitHub-OIDC-Provider"
  }
}

resource "aws_iam_role" "github_actions" {
  name        = "${var.project_name}-github-actions"
  description = "Role for GitHub Actions to deploy LectureClip infrastructure"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:UofT-CSC490-W2026/LectureClip-Infra:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-github-actions"
  }
}

resource "aws_iam_role_policy" "github_actions_ssm" {
  name = "${var.project_name}-github-actions-ssm"
  role = aws_iam_role.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        Resource = [
          "arn:aws:ssm:*:*:parameter/workshop/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_tf_state" {
  name = "${var.project_name}-github-actions-tf-state"
  role = aws_iam_role.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::*-workshop-tf-state",
          "arn:aws:s3:::*-workshop-tf-state/*"
        ]
      }
    ]
  })
}

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

# ============================================================================
# GITHUB ACTIONS OIDC ROLE — APP REPO (LectureClip-App)
# Scoped to Lambda deployments only; separate from the Infra repo's role.
# ============================================================================

resource "aws_iam_role" "github_actions_app" {
  name        = "${var.project_name}-github-actions-app"
  description = "Role for LectureClip-App GitHub Actions to deploy Lambda functions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:UofT-CSC490-W2026/LectureClip-App:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-github-actions-app"
  }
}

resource "aws_iam_role_policy" "github_actions_app_lambda_deploy" {
  name = "${var.project_name}-github-actions-app-lambda-deploy"
  role = aws_iam_role.github_actions_app.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:GetFunctionConfiguration",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
        ]
        Resource = "arn:aws:lambda:*:${var.account_id}:function:${var.project_name}-*"
      }
    ]
  })
}
