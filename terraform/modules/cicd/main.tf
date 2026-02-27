# ============================================================================
# GITHUB ACTIONS OIDC & ROLE
# The OIDC provider is a singleton per AWS account. Set create_oidc_provider=true
# for prod (first deploy). Dev uses a data source to reference the existing provider.
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Branch that is allowed to deploy infra for this environment:
  #   dev  → develop branch
  #   prod → main branch
  deploy_branch = var.environment == "prod" ? "main" : "develop"
}

# Create the OIDC provider only once (in prod). Dev looks it up via data source.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

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

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

# ============================================================================
# GITHUB ACTIONS ROLE — INFRA REPO (LectureClip-Infra)
# Scoped to the environment's deploy branch (develop→dev, main→prod).
# PRs to main also allowed so the plan step can run against prod state.
# ============================================================================

resource "aws_iam_role" "github_actions" {
  name        = "${local.name_prefix}-github-actions"
  description = "Role for GitHub Actions to deploy LectureClip ${var.environment} infrastructure"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Allow the environment's deploy branch, plus PRs (for plan-only runs)
            "token.actions.githubusercontent.com:sub" = [
              "repo:UofT-CSC490-W2026/LectureClip-Infra:ref:refs/heads/${local.deploy_branch}",
              "repo:UofT-CSC490-W2026/LectureClip-Infra:pull_request"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-github-actions"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "github_actions_ssm" {
  name = "${local.name_prefix}-github-actions-ssm"
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
  name = "${local.name_prefix}-github-actions-tf-state"
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
# GITHUB ACTIONS ROLE — APP REPO (LectureClip-App)
# Scoped to Lambda deployments for this environment only.
# Keyed to the environment's deploy branch (develop→dev, main→prod).
# ============================================================================

resource "aws_iam_role" "github_actions_app" {
  name        = "${local.name_prefix}-github-actions-app"
  description = "Role for LectureClip-App GitHub Actions to deploy ${var.environment} Lambda functions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:UofT-CSC490-W2026/LectureClip-App:ref:refs/heads/${local.deploy_branch}"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-github-actions-app"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "github_actions_app_lambda_deploy" {
  name = "${local.name_prefix}-github-actions-app-lambda-deploy"
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
        Resource = "arn:aws:lambda:*:${var.account_id}:function:${var.project_name}-${var.environment}-*"
      }
    ]
  })
}
