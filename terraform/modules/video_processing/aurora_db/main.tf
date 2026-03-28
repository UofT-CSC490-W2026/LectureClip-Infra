# ============================================================================
# AURORA DB MODULE - MAIN
# Aurora Serverless v2 PostgreSQL with pgvector extension for LectureClip.
#
# Access pattern: Lambda calls the RDS Data API (HTTPS/443) — no direct
# TCP connection to port 5432 is required in the default deployment.
# The Aurora SG accepts port 5432 from the Lambda SG for future direct access.
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  db_name     = "lectureclip"
}

# ============================================================================
# DB SUBNET GROUP
# ============================================================================

resource "aws_db_subnet_group" "aurora" {
  name        = "${local.name_prefix}-aurora"
  subnet_ids  = var.private_subnet_ids
  description = "Aurora subnet group for ${local.name_prefix}"

  tags = {
    Name        = "${local.name_prefix}-aurora-subnet-group"
    Environment = var.environment
  }
}

# ============================================================================
# AURORA SECURITY GROUP
# Allows inbound PostgreSQL (5432) from the Lambda security group.
# ============================================================================

resource "aws_security_group" "aurora" {
  name        = "${local.name_prefix}-aurora-sg"
  description = "Security group for Aurora PostgreSQL cluster"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from Lambda"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.lambda_security_group_id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-aurora-sg"
    Environment = var.environment
  }
}

# ============================================================================
# AURORA SERVERLESS V2 CLUSTER
# - Engine: Aurora PostgreSQL 16.6
# - Managed master user secret (RDS generates and rotates credentials in
#   Secrets Manager automatically — no plaintext password in Terraform state)
# - Data API enabled: Lambda calls rds-data:ExecuteStatement over HTTPS
# - Storage encrypted with the shared KMS key
# ============================================================================

resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${local.name_prefix}-aurora"

  engine         = "aurora-postgresql"
  engine_version = "16.6"
  database_name  = local.db_name

  # RDS manages the master password and stores it in Secrets Manager.
  manage_master_user_password   = true
  master_username               = "clusteradmin"
  master_user_secret_kms_key_id = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  # RDS Data API — lets Lambda call SQL over HTTPS without a direct DB connection
  enable_http_endpoint = true

  backup_retention_period = 7
  skip_final_snapshot     = var.environment != "prod"
  deletion_protection     = var.environment == "prod"

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 4.0
  }

  tags = {
    Name        = "${local.name_prefix}-aurora"
    Environment = var.environment
  }
}

# ============================================================================
# AURORA WRITER INSTANCE (Serverless v2)
# ============================================================================

resource "aws_rds_cluster_instance" "writer" {
  identifier           = "${local.name_prefix}-aurora-writer"
  cluster_identifier   = aws_rds_cluster.aurora.id
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.aurora.engine
  engine_version       = aws_rds_cluster.aurora.engine_version
  db_subnet_group_name = aws_db_subnet_group.aurora.name

  tags = {
    Name        = "${local.name_prefix}-aurora-writer"
    Environment = var.environment
  }
}

# ============================================================================
# SSM PARAMETERS
# Expose cluster ARN, secret ARN, and DB name so downstream modules and the
# application CI can discover them without hardcoding.
# ============================================================================

# ============================================================================
# DB-MIGRATE LAMBDA
# Placeholder shell — real code deployed by LectureClip-App CI.
# CI invokes this synchronously after each code deployment (deploy.sh).
# ============================================================================

data "archive_file" "placeholder" {
  type        = "zip"
  output_path = "${path.module}/temp/placeholder.zip"

  source {
    content  = "# placeholder — deployed by LectureClip-App CI"
    filename = "index.py"
  }
}

resource "aws_iam_role" "db_migrate" {
  name = "${local.name_prefix}-db-migrate"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${local.name_prefix}-db-migrate" }
}

resource "aws_iam_role_policy_attachment" "db_migrate_basic" {
  role       = aws_iam_role.db_migrate.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "db_migrate" {
  name = "${local.name_prefix}-db-migrate"
  role = aws_iam_role.db_migrate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "RDSDataAPI"
        Effect   = "Allow"
        Action   = ["rds-data:ExecuteStatement", "rds-data:BatchExecuteStatement"]
        Resource = aws_rds_cluster.aurora.arn
      },
      {
        Sid      = "AuroraSecretAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_rds_cluster.aurora.master_user_secret[0].secret_arn
      },
      {
        Sid      = "KMSDecrypt"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = var.kms_key_arn
      }
    ]
  })
}

resource "aws_lambda_function" "db_migrate" {
  function_name    = "${local.name_prefix}-db-migrate"
  role             = aws_iam_role.db_migrate.arn
  handler          = "index.handler"
  runtime          = "python3.13"
  timeout          = 300
  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256
  kms_key_arn      = var.kms_key_arn

  environment {
    variables = {
      AURORA_CLUSTER_ARN = aws_rds_cluster.aurora.arn
      AURORA_SECRET_ARN  = aws_rds_cluster.aurora.master_user_secret[0].secret_arn
      AURORA_DB_NAME     = local.db_name
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name        = "${local.name_prefix}-db-migrate"
    Environment = var.environment
  }

  depends_on = [aws_rds_cluster_instance.writer]
}

resource "aws_ssm_parameter" "cluster_arn" {
  name        = "/${var.project_name}/${var.environment}/aurora/cluster-arn"
  type        = "String"
  value       = aws_rds_cluster.aurora.arn
  description = "Aurora cluster ARN for ${local.name_prefix}"

  tags = { Name = "${local.name_prefix}-aurora-cluster-arn" }
}

resource "aws_ssm_parameter" "secret_arn" {
  name        = "/${var.project_name}/${var.environment}/aurora/secret-arn"
  type        = "String"
  value       = aws_rds_cluster.aurora.master_user_secret[0].secret_arn
  description = "Secrets Manager ARN for Aurora master credentials"

  tags = { Name = "${local.name_prefix}-aurora-secret-arn" }
}

resource "aws_ssm_parameter" "db_name" {
  name        = "/${var.project_name}/${var.environment}/aurora/db-name"
  type        = "String"
  value       = local.db_name
  description = "Aurora database name for ${local.name_prefix}"

  tags = { Name = "${local.name_prefix}-aurora-db-name" }
}

resource "aws_ssm_parameter" "db_migrate_function_name" {
  name        = "/${var.project_name}/${var.environment}/aurora/db-migrate-function-name"
  type        = "String"
  value       = aws_lambda_function.db_migrate.function_name
  description = "db-migrate Lambda function name for ${local.name_prefix}"

  tags = { Name = "${local.name_prefix}-db-migrate-function-name" }
}
