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
