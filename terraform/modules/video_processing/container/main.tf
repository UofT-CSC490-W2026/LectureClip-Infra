# ============================================================================
# VIDEO PROCESSING CONTAINER MODULE - MAIN
# Segment-frame embedding container:
#   ECS Fargate task that downloads a lecture video, extracts one frame per
#   transcript segment using FFmpeg, generates image embeddings via Bedrock
#   Titan Embed Image V1, and writes the results to S3.  Invoked as a
#   waitForTaskToken Step Functions task between transcription and
#   process-results.
# ============================================================================

locals {
  name_prefix    = "${var.project_name}-${var.environment}"
  container_name = "segment-frame-extractor"
}

# ============================================================================
# ECR REPOSITORY
# CI pushes the container image here; task definition references :latest
# so every new ECS run picks up the most recently pushed image.
# ============================================================================

resource "aws_ecr_repository" "segment_frame_extractor" {
  name                 = "${local.name_prefix}-${local.container_name}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${local.name_prefix}-${local.container_name}"
    Environment = var.environment
  }
}

resource "aws_ecr_lifecycle_policy" "segment_frame_extractor" {
  repository = aws_ecr_repository.segment_frame_extractor.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      }
    ]
  })
}

# ============================================================================
# ECS CLUSTER
# Fargate-only cluster; no EC2 capacity required.
# ============================================================================

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-ecs"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${local.name_prefix}-ecs"
    Environment = var.environment
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
}

# ============================================================================
# CLOUDWATCH LOG GROUP
# ============================================================================

resource "aws_cloudwatch_log_group" "segment_frame_extractor" {
  name              = "/ecs/${local.name_prefix}/${local.container_name}"
  retention_in_days = 14

  tags = {
    Name        = "${local.name_prefix}-${local.container_name}"
    Environment = var.environment
  }
}

# ============================================================================
# IAM — ECS TASK EXECUTION ROLE
# Used by the ECS agent to pull the container image from ECR and ship logs
# to CloudWatch.  Not visible to container code.
# ============================================================================

resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name_prefix}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-ecs-task-execution"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ============================================================================
# IAM — ECS TASK ROLE
# Permissions available to code running inside the container.
# ============================================================================

resource "aws_iam_role" "segment_frame_extractor_task" {
  name = "${local.name_prefix}-${local.container_name}-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-${local.container_name}-task"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "segment_frame_extractor_task" {
  name = "${local.name_prefix}-${local.container_name}-task"
  role = aws_iam_role.segment_frame_extractor_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadVideo"
        Effect = "Allow"
        Action = ["s3:GetObject"]
        # Read: source video + transcription JSON
        Resource = "${var.user_videos_bucket_arn}/*"
      },
      {
        Sid    = "S3WriteEmbeddings"
        Effect = "Allow"
        Action = ["s3:PutObject"]
        # Write: segment_frame_embeddings.json
        Resource = "${var.user_videos_bucket_arn}/*"
      },
      {
        Sid      = "KMSDecryptEncrypt"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = var.kms_key_arn
      },
      {
        Sid    = "BedrockInvokeModel"
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        # Titan Embed Image V1 — used to embed video frames
        Resource = "arn:aws:bedrock:*::foundation-model/${var.embedding_model_id}"
      },
      {
        Sid      = "SFNTaskCallback"
        Effect   = "Allow"
        Action   = ["states:SendTaskSuccess", "states:SendTaskFailure"]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# SECURITY GROUP — ECS TASKS
# Egress-only: tasks reach AWS APIs (S3, Bedrock, Step Functions) via NAT.
# No inbound traffic is needed.
# ============================================================================

resource "aws_security_group" "ecs_task" {
  name        = "${local.name_prefix}-ecs-task-sg"
  description = "Egress-only security group for ${local.name_prefix} ECS Fargate tasks"
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS to AWS APIs via NAT"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-ecs-task-sg"
    Environment = var.environment
  }
}

# ============================================================================
# ECS TASK DEFINITION
# CI pushes new images to ECR under :latest; the task definition always
# references :latest so each new execution picks up the current image without
# requiring a Terraform change.
# Env vars injected at runtime by Step Functions (container overrides):
#   TASK_TOKEN   — $$.Task.Token
#   S3_URI       — the source video URI from the state machine input
# ============================================================================

resource "aws_ecs_task_definition" "segment_frame_extractor" {
  family                   = "${local.name_prefix}-${local.container_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "4096"
  memory                   = "8192"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.segment_frame_extractor_task.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = "${aws_ecr_repository.segment_frame_extractor.repository_url}:latest"
      essential = true

      environment = [
        { name = "TRANSCRIPTS_BUCKET", value = var.user_videos_bucket_id },
        { name = "FRAME_EMBEDDING_MODEL_ID", value = var.embedding_model_id },
        { name = "EMBEDDING_DIM", value = tostring(var.embedding_dim) }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.segment_frame_extractor.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name        = "${local.name_prefix}-${local.container_name}"
    Environment = var.environment
  }
}
