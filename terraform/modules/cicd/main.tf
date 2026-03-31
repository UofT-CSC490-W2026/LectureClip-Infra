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
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:AddTagsToResource",
          "ssm:DeleteParameter",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:ListTagsForResource",
          "ssm:PutParameter",
          "ssm:RemoveTagsFromResource"
        ]
        Resource = [
          "arn:aws:ssm:*:*:parameter/lectureclip/*"
        ]
      },
      {
        # DescribeParameters is account-scoped — AWS does not accept parameter path ARNs as resource
        Effect   = "Allow"
        Action   = ["ssm:DescribeParameters"]
        Resource = ["*"]
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
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:*:${var.account_id}:table/terraform-state-locks"
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_terraform" {
  name = "${local.name_prefix}-github-actions-terraform"
  role = aws_iam_role.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VisualEditor0"
        Effect = "Allow"
        Action = [
          "SNS:GetSubscriptionAttributes",
          "SNS:Subscribe",
          "SNS:Unsubscribe"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "VisualEditor1"
        Effect = "Allow"
        Action = [
          "apigateway:DELETE",
          "apigateway:GET",
          "apigateway:PATCH",
          "apigateway:POST",
          "apigateway:PUT",
          "apigateway:UpdateRestApiPolicy"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "VisualEditor2"
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable",
          "dynamodb:DeleteItem",
          "dynamodb:DeleteTable",
          "dynamodb:DescribeContinuousBackups",
          "dynamodb:DescribeTable",
          "dynamodb:DescribeTimeToLive",
          "dynamodb:GetItem",
          "dynamodb:ListTagsOfResource",
          "dynamodb:PutItem",
          "dynamodb:TagResource",
          "dynamodb:UntagResource",
          "dynamodb:UpdateTable",
          "dynamodb:UpdateTimeToLive"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "VisualEditor3"
        Effect = "Allow"
        Action = [
          "ec2:AllocateAddress",
          "ec2:AssignPrivateNatGatewayAddress",
          "ec2:AssociateAddress",
          "ec2:AssociateNatGatewayAddress",
          "ec2:AssociateRouteTable",
          "ec2:AssociateSubnetCidrBlock",
          "ec2:AttachInternetGateway",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CreateInternetGateway",
          "ec2:CreateNatGateway",
          "ec2:CreateRoute",
          "ec2:CreateRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:CreateSubnet",
          "ec2:CreateTags",
          "ec2:CreateVPC",
          "ec2:DeleteInternetGateway",
          "ec2:DeleteNatGateway",
          "ec2:DeleteRouteTable",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteSubnet",
          "ec2:DeleteTags",
          "ec2:DeleteVPC",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAddressesAttribute",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNatGateways",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeVpcs",
          "ec2:DetachInternetGateway",
          "ec2:DisassociateAddress",
          "ec2:DisassociateNatGatewayAddress",
          "ec2:DisassociateRouteTable",
          "ec2:DisassociateSubnetCidrBlock",
          "ec2:ModifySubnetAttribute",
          "ec2:ModifyVpcAttribute",
          "ec2:ModifyVpcTenancy",
          "ec2:ReleaseAddress",
          "ec2:ReplaceRouteTableAssociation",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:UnassignPrivateNatGatewayAddress"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "VisualEditor4"
        Effect = "Allow"
        Action = [
          "events:DeleteRule",
          "events:DescribeRule",
          "events:ListTagsForResource",
          "events:ListTargetsByRule",
          "events:PutRule",
          "events:PutTargets",
          "events:RemoveTargets",
          "events:TagResource",
          "events:UnTagResource"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "VisualEditor5"
        Effect = "Allow"
        Action = [
          "cognito-idp:CreateUserPool",
          "cognito-idp:CreateUserPoolClient",
          "cognito-idp:DeleteUserPool",
          "cognito-idp:DeleteUserPoolClient",
          "cognito-idp:DescribeUserPool",
          "cognito-idp:DescribeUserPoolClient",
          "cognito-idp:GetUserPoolMfaConfig",
          "cognito-idp:TagResource",
          "cognito-idp:UntagResource",
          "cognito-idp:UpdateUserPool",
          "cognito-idp:UpdateUserPoolClient"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "VisualEditor6"
        Effect = "Allow"
        Action = [
          "iam:AddClientIDToOpenIDConnectProvider",
          "iam:AttachRolePolicy",
          "iam:CreateOpenIDConnectProvider",
          "iam:CreateRole",
          "iam:DeleteOpenIDConnectProvider",
          "iam:DeleteRole",
          "iam:DeleteRolePolicy",
          "iam:DetachRolePolicy",
          "iam:GetOpenIDConnectProvider",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:ListOpenIDConnectProviderTags",
          "iam:ListOpenIDConnectProviders",
          "iam:ListRolePolicies",
          "iam:PassRole",
          "iam:PutRolePolicy",
          "iam:RemoveClientIDFromOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:TagRole",
          "iam:UntagOpenIDConnectProvider",
          "iam:UntagRole",
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:UpdateRoleDescription"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "VisualEditor7"
        Effect = "Allow"
        Action = [
          "kms:CreateAlias",
          "kms:CreateKey",
          "kms:Decrypt",
          "kms:DeleteAlias",
          "kms:DescribeKey",
          "kms:EnableKeyRotation",
          "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus",
          "kms:ListAliases",
          "kms:ListResourceTags",
          "kms:PutKeyPolicy",
          "kms:ScheduleKeyDeletion",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:UpdateAlias",
          "kms:UpdateKeyDescription"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "VisualEditor8"
        Effect = "Allow"
        Action = [
          "lambda:AddPermission",
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:GetFunctionCodeSigningConfig",
          "lambda:GetPolicy",
          "lambda:ListVersionsByFunction",
          "lambda:RemovePermission",
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:UpdateFunctionConfiguration"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "VisualEditor9"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DeleteRetentionPolicy",
          "logs:DescribeLogGroups",
          "logs:ListTagsForResource",
          "logs:ListTagsLogGroup",
          "logs:PutRetentionPolicy",
          "logs:TagLogGroup",
          "logs:UntagLogGroup"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "VisualEditor10"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:DeleteObject",
          "s3:GetAccelerateConfiguration",
          "s3:GetBucketAcl",
          "s3:GetBucketCORS",
          "s3:GetBucketLogging",
          "s3:GetBucketNotification",
          "s3:GetBucketObjectLockConfiguration",
          "s3:GetBucketPolicy",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketRequestPayment",
          "s3:GetBucketTagging",
          "s3:GetBucketVersioning",
          "s3:GetBucketWebsite",
          "s3:GetEncryptionConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:GetReplicationConfiguration",
          "s3:ListBucket",
          "s3:PutBucketCORS",
          "s3:PutBucketNotification",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketTagging",
          "s3:PutBucketVersioning",
          "s3:PutEncryptionConfiguration",
          "s3:PutObject"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "VisualEditor11"
        Effect = "Allow"
        Action = [
          "sns:CreateTopic",
          "sns:DeleteTopic",
          "sns:GetTopicAttributes",
          "sns:ListTagsForResource",
          "sns:SetTopicAttributes",
          "sns:TagResource",
          "sns:UnTagResource"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "VisualEditor12"
        Effect = "Allow"
        Action = [
          "states:CreateStateMachine",
          "states:DeleteStateMachine",
          "states:DescribeStateMachine",
          "states:ListTagsForResource",
          "states:ListStateMachineVersions",
          "states:TagResource",
          "states:UntagResource",
          "states:UpdateStateMachine",
          "states:ValidateStateMachineDefinition"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "VisualEditor13"
        Effect = "Allow"
        Action = [
          "rds:AddTagsToResource",
          "rds:CreateDBCluster",
          "rds:CreateDBInstance",
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBCluster",
          "rds:DeleteDBInstance",
          "rds:DeleteDBSubnetGroup",
          "rds:DescribeDBClusters",
          "rds:DescribeDBEngineVersions",
          "rds:DescribeDBInstanceAutomatedBackups",
          "rds:DescribeDBInstances",
          "rds:DescribeDBParameterGroups",
          "rds:DescribeDBSubnetGroups",
          "rds:DescribeGlobalClusters",
          "rds:ListTagsForResource",
          "rds:ModifyDBCluster",
          "rds:ModifyDBInstance",
          "rds:ModifyDBSubnetGroup",
          "rds:RemoveTagsFromResource"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "VisualEditor14"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:TagResource"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "VisualEditor15"
        Effect = "Allow"
        Action = [
          "amplify:CreateApp",
          "amplify:DeleteApp",
          "amplify:GetApp",
          "amplify:ListApps",
          "amplify:TagResource",
          "amplify:UntagResource",
          "amplify:UpdateApp",
          "amplify:CreateBranch",
          "amplify:DeleteBranch",
          "amplify:GetBranch",
          "amplify:ListBranches",
          "amplify:UpdateBranch"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "VisualEditor16"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:ListRolePolicies",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:UpdateRoleDescription"
        ]
        Resource = "arn:aws:iam::${var.account_id}:role/${var.project_name}-${var.environment}-amplify-service-role"
      },
      {
        Sid    = "ECRManage"
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository",
          "ecr:DeleteRepository",
          "ecr:DescribeRepositories",
          "ecr:GetLifecyclePolicy",
          "ecr:GetRepositoryPolicy",
          "ecr:ListTagsForResource",
          "ecr:PutLifecyclePolicy",
          "ecr:PutImageScanningConfiguration",
          "ecr:PutImageTagMutability",
          "ecr:SetRepositoryPolicy",
          "ecr:TagResource",
          "ecr:UntagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSManage"
        Effect = "Allow"
        Action = [
          "ecs:CreateCluster",
          "ecs:DeleteCluster",
          "ecs:DescribeClusters",
          "ecs:ListClusters",
          "ecs:PutClusterCapacityProviders",
          "ecs:TagResource",
          "ecs:UntagResource",
          "ecs:UpdateCluster",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = "*"
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
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:*:${var.account_id}:function:${var.project_name}-${var.environment}-*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_app_ecr_push" {
  name = "${local.name_prefix}-github-actions-app-ecr-push"
  role = aws_iam_role.github_actions_app.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # GetAuthorizationToken is account-scoped — no resource ARN available
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        # Scoped to ECR repositories that follow the project naming convention
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = "arn:aws:ecr:*:${var.account_id}:repository/${var.project_name}-${var.environment}-*"
      }
    ]
  })
}
