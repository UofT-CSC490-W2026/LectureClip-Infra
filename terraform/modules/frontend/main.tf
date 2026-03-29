# ============================================================================
# FRONTEND MODULE - AWS AMPLIFY HOSTING
# Deploys the React/Vite frontend from LectureClip-App/frontend via Amplify.
# Frontend-only build — no Amplify Gen 2 backend pipeline deployment.
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  branch_name = var.environment == "prod" ? "main" : "develop"
}

# ============================================================================
# AMPLIFY SERVICE ROLE
# Amplify Gen 2 detects amplify/backend.ts and requires a service role to
# deploy backend resources (Cognito, AppSync) via CloudFormation.
# ============================================================================
resource "aws_iam_role" "amplify_service_role" {
  name        = "${local.name_prefix}-amplify-service-role"
  description = "Service role for Amplify Gen 2 backend deployment in ${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "amplify.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-amplify-service-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "amplify_service_role_admin" {
  role       = aws_iam_role.amplify_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess-Amplify"
}

# ============================================================================
# AMPLIFY APP
# Connects to the LectureClip-App GitHub repo. Monorepo build spec points to
# the frontend/ subdirectory. Gen 2 backend deploys auth + data on each push.
# ============================================================================
resource "aws_amplify_app" "frontend" {
  # TODO: use the repo in the 490 org once the PAT is approved.
  name                 = "${local.name_prefix}-frontend"
  repository           = "https://github.com/prash-red/LectureClip-App"
  access_token         = var.github_access_token
  iam_service_role_arn = aws_iam_role.amplify_service_role.arn

  # Monorepo: frontend app lives in frontend/ subdirectory.
  # Matches the existing frontend/amplify.yml — frontend-only build, no backend phase.
  build_spec = <<-EOT
    version: 1
    applications:
      - appRoot: frontend
        frontend:
          phases:
            preBuild:
              commands:
                - nvm use 20
                - npm install --cache .npm --prefer-offline
            build:
              commands:
                - npm run build
          artifacts:
            baseDirectory: dist
            files:
              - '**/*'
          cache:
            paths:
              - .npm/**/*
              - node_modules/**/*
  EOT

  environment_variables = {
    VITE_API_BASE_URL = var.api_base_url
  }

  enable_auto_branch_creation = false
  enable_branch_auto_deletion = true

  tags = {
    Name        = "${local.name_prefix}-frontend"
    Environment = var.environment
  }

}

# ============================================================================
# AMPLIFY BRANCH
# Tracks the environment-appropriate branch (develop→dev, main→prod).
# Auto-build triggers a new deployment on every push to that branch.
# ============================================================================
resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.frontend.id
  branch_name = local.branch_name

  enable_auto_build = true

  environment_variables = {
    VITE_API_BASE_URL = var.api_base_url
  }

  tags = {
    Name        = "${local.name_prefix}-frontend-${local.branch_name}"
    Environment = var.environment
  }
}
