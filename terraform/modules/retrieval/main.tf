# ============================================================================
# RETRIEVAL MODULE - MAIN
# All infrastructure for the query-segments and query-segments-info features:
#   - IAM roles scoped to Bedrock InvokeModel + RDS Data API
#   - query-segments Lambda function
#   - query-segments-info Lambda function (same search, richer response)
#   - POST /query API Gateway resource, method, and integration
#   - OPTIONS /query CORS preflight
#   - POST /query-info API Gateway resource, method, and integration
#   - OPTIONS /query-info CORS preflight
#   - Lambda invoke permissions for API Gateway
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ============================================================================
# PLACEHOLDER ARCHIVE
# Real code is deployed by LectureClip-App CI via aws lambda update-function-code
# ============================================================================

data "archive_file" "placeholder" {
  type        = "zip"
  output_path = "${path.module}/temp/placeholder.zip"

  source {
    content  = "# placeholder — deployed by LectureClip-App CI"
    filename = "index.py"
  }
}

# ============================================================================
# IAM ROLE
# Scoped to Bedrock InvokeModel (embed query) + RDS Data API (vector search)
# ============================================================================

resource "aws_iam_role" "query_segments" {
  name = "${local.name_prefix}-query-segments-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-query-segments-lambda"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "query_segments_basic" {
  role       = aws_iam_role.query_segments.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "query_segments" {
  name = "${local.name_prefix}-query-segments-lambda"
  role = aws_iam_role.query_segments.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "BedrockInvokeModel"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:*::foundation-model/${var.embedding_model_id}"
      },
      {
        Sid      = "RDSDataAPI"
        Effect   = "Allow"
        Action   = ["rds-data:ExecuteStatement"]
        Resource = var.aurora_cluster_arn
      },
      {
        Sid      = "AuroraSecretAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.aurora_secret_arn
      },
      {
        Sid      = "KMSDecryptSecret"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# ============================================================================
# LAMBDA FUNCTION
# Embeds the query via Bedrock and runs a pgvector cosine similarity search.
# Timeout 30 s: one Bedrock InvokeModel call + one RDS Data API call.
# ============================================================================

resource "aws_lambda_function" "query_segments" {
  function_name    = "${local.name_prefix}-query-segments"
  role             = aws_iam_role.query_segments.arn
  handler          = "index.handler"
  runtime          = "python3.13"
  timeout          = 30
  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      EMBEDDING_MODEL_ID  = var.embedding_model_id
      EMBEDDING_DIM       = tostring(var.embedding_dim)
      MODAL_EMBEDDING_URL = var.modal_embedding_url
      AURORA_CLUSTER_ARN  = var.aurora_cluster_arn
      AURORA_SECRET_ARN   = var.aurora_secret_arn
      AURORA_DB_NAME      = var.aurora_db_name
      BUCKET_NAME         = var.bucket_name
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name        = "${local.name_prefix}-query-segments"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "query_segments" {
  name              = "/aws/lambda/${aws_lambda_function.query_segments.function_name}"
  retention_in_days = 14

  tags = {
    Environment = var.environment
  }
}

# ============================================================================
# API GATEWAY — /query
# ============================================================================

resource "aws_api_gateway_resource" "query" {
  rest_api_id = var.rest_api_id
  parent_id   = var.rest_api_root_resource_id
  path_part   = "query"
}

# POST /query

resource "aws_api_gateway_method" "query_post" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.query.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "query_post" {
  rest_api_id             = var.rest_api_id
  resource_id             = aws_api_gateway_resource.query.id
  http_method             = aws_api_gateway_method.query_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.query_segments.invoke_arn
}

# OPTIONS /query (CORS preflight)

resource "aws_api_gateway_method" "query_options" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.query.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "query_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.query.id
  http_method = aws_api_gateway_method.query_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "query_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.query.id
  http_method = aws_api_gateway_method.query_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "query_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.query.id
  http_method = aws_api_gateway_method.query_options.http_method
  status_code = aws_api_gateway_method_response.query_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.query_options]
}

# Lambda invoke permission for API Gateway

resource "aws_lambda_permission" "query_apigw" {
  statement_id  = "AllowAPIGatewayInvokeQuery"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.query_segments.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.rest_api_execution_arn}/*/*"
}

# ============================================================================
# IAM ROLE — query-segments-info
# Same permissions as query-segments: Bedrock InvokeModel + RDS Data API
# ============================================================================

resource "aws_iam_role" "query_segments_info" {
  name = "${local.name_prefix}-query-segments-info-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-query-segments-info-lambda"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "query_segments_info_basic" {
  role       = aws_iam_role.query_segments_info.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "query_segments_info" {
  name = "${local.name_prefix}-query-segments-info-lambda"
  role = aws_iam_role.query_segments_info.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "BedrockInvokeModel"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:*::foundation-model/${var.embedding_model_id}"
      },
      {
        Sid      = "RDSDataAPI"
        Effect   = "Allow"
        Action   = ["rds-data:ExecuteStatement"]
        Resource = var.aurora_cluster_arn
      },
      {
        Sid      = "AuroraSecretAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.aurora_secret_arn
      },
      {
        Sid      = "KMSDecryptSecret"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# ============================================================================
# LAMBDA FUNCTION — query-segments-info
# Same vector search as query-segments; returns segment_id, idx, text, and
# similarity score in addition to start/end timestamps.
# ============================================================================

resource "aws_lambda_function" "query_segments_info" {
  function_name    = "${local.name_prefix}-query-segments-info"
  role             = aws_iam_role.query_segments_info.arn
  handler          = "index.handler"
  runtime          = "python3.13"
  timeout          = 30
  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      EMBEDDING_MODEL_ID  = var.embedding_model_id
      EMBEDDING_DIM       = tostring(var.embedding_dim)
      MODAL_EMBEDDING_URL = var.modal_embedding_url
      AURORA_CLUSTER_ARN  = var.aurora_cluster_arn
      AURORA_SECRET_ARN   = var.aurora_secret_arn
      AURORA_DB_NAME      = var.aurora_db_name
      BUCKET_NAME         = var.bucket_name
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name        = "${local.name_prefix}-query-segments-info"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "query_segments_info" {
  name              = "/aws/lambda/${aws_lambda_function.query_segments_info.function_name}"
  retention_in_days = 14

  tags = {
    Environment = var.environment
  }
}

# ============================================================================
# API GATEWAY — /query-info
# ============================================================================

resource "aws_api_gateway_resource" "query_info" {
  rest_api_id = var.rest_api_id
  parent_id   = var.rest_api_root_resource_id
  path_part   = "query-info"
}

# POST /query-info

resource "aws_api_gateway_method" "query_info_post" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.query_info.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "query_info_post" {
  rest_api_id             = var.rest_api_id
  resource_id             = aws_api_gateway_resource.query_info.id
  http_method             = aws_api_gateway_method.query_info_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.query_segments_info.invoke_arn
}

# OPTIONS /query-info (CORS preflight)

resource "aws_api_gateway_method" "query_info_options" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.query_info.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "query_info_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.query_info.id
  http_method = aws_api_gateway_method.query_info_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "query_info_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.query_info.id
  http_method = aws_api_gateway_method.query_info_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "query_info_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.query_info.id
  http_method = aws_api_gateway_method.query_info_options.http_method
  status_code = aws_api_gateway_method_response.query_info_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.query_info_options]
}

# Lambda invoke permission for API Gateway

resource "aws_lambda_permission" "query_info_apigw" {
  statement_id  = "AllowAPIGatewayInvokeQueryInfo"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.query_segments_info.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.rest_api_execution_arn}/*/*"
}

# ============================================================================
# DYNAMODB TABLE — chat sessions
# Stores Converse API message history keyed by session_id, with a 24-hour TTL.
# ============================================================================

resource "aws_dynamodb_table" "chat_sessions" {
  name         = "${local.name_prefix}-chat-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name        = "${local.name_prefix}-chat-sessions"
    Environment = var.environment
  }
}

# ============================================================================
# IAM ROLE — chat
# Embedding InvokeModel + LLM Converse + RDS Data API + DynamoDB sessions
# ============================================================================

resource "aws_iam_role" "chat" {
  name = "${local.name_prefix}-chat-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-chat-lambda"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "chat_basic" {
  role       = aws_iam_role.chat.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "chat" {
  name = "${local.name_prefix}-chat-lambda"
  role = aws_iam_role.chat.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "BedrockInvoke"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel", "bedrock:Converse"]
        Resource = "*"
      },
      {
        Sid      = "RDSDataAPI"
        Effect   = "Allow"
        Action   = ["rds-data:ExecuteStatement"]
        Resource = var.aurora_cluster_arn
      },
      {
        Sid      = "AuroraSecretAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.aurora_secret_arn
      },
      {
        Sid      = "KMSDecryptSecret"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = var.kms_key_arn
      },
      {
        Sid      = "DynamoDBSessions"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem"]
        Resource = aws_dynamodb_table.chat_sessions.arn
      }
    ]
  })
}

# ============================================================================
# LAMBDA FUNCTION — chat
# ============================================================================

resource "aws_lambda_function" "chat" {
  function_name    = "${local.name_prefix}-chat"
  role             = aws_iam_role.chat.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.13"
  timeout          = 60
  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      EMBEDDING_MODEL_ID  = var.embedding_model_id
      EMBEDDING_DIM       = tostring(var.embedding_dim)
      MODAL_EMBEDDING_URL = var.modal_embedding_url
      CHAT_MODEL_ID       = var.chat_model_id
      CHAT_SESSIONS_TABLE = aws_dynamodb_table.chat_sessions.name
      AURORA_CLUSTER_ARN  = var.aurora_cluster_arn
      AURORA_SECRET_ARN   = var.aurora_secret_arn
      AURORA_DB_NAME      = var.aurora_db_name
      BUCKET_NAME         = var.bucket_name
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name        = "${local.name_prefix}-chat"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "chat" {
  name              = "/aws/lambda/${aws_lambda_function.chat.function_name}"
  retention_in_days = 14

  tags = {
    Environment = var.environment
  }
}

# ============================================================================
# API GATEWAY — POST /chat
# ============================================================================

resource "aws_api_gateway_resource" "chat" {
  rest_api_id = var.rest_api_id
  parent_id   = var.rest_api_root_resource_id
  path_part   = "chat"
}

resource "aws_api_gateway_method" "chat_post" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.chat.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "chat_post" {
  rest_api_id             = var.rest_api_id
  resource_id             = aws_api_gateway_resource.chat.id
  http_method             = aws_api_gateway_method.chat_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.chat.invoke_arn
}

resource "aws_api_gateway_method" "chat_options" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.chat.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "chat_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "chat_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "chat_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_options.http_method
  status_code = aws_api_gateway_method_response.chat_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.chat_options]
}

resource "aws_lambda_permission" "chat_apigw" {
  statement_id  = "AllowAPIGatewayInvokeChat"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.rest_api_execution_arn}/*/*"
}

# ============================================================================
# IAM ROLE — register-user
# Only needs RDS Data API + Secrets Manager (no Bedrock, no S3)
# ============================================================================

resource "aws_iam_role" "register_user" {
  name = "${local.name_prefix}-register-user-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-register-user-lambda"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "register_user_basic" {
  role       = aws_iam_role.register_user.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "register_user" {
  name = "${local.name_prefix}-register-user-lambda"
  role = aws_iam_role.register_user.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "RDSDataAPI"
        Effect   = "Allow"
        Action   = ["rds-data:ExecuteStatement"]
        Resource = var.aurora_cluster_arn
      },
      {
        Sid      = "AuroraSecretAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.aurora_secret_arn
      },
      {
        Sid      = "KMSDecryptSecret"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# ============================================================================
# LAMBDA FUNCTION — register-user
# ============================================================================

resource "aws_lambda_function" "register_user" {
  function_name    = "${local.name_prefix}-register-user"
  role             = aws_iam_role.register_user.arn
  handler          = "index.handler"
  runtime          = "python3.13"
  timeout          = 10
  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      AURORA_CLUSTER_ARN = var.aurora_cluster_arn
      AURORA_SECRET_ARN  = var.aurora_secret_arn
      AURORA_DB_NAME     = var.aurora_db_name
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name        = "${local.name_prefix}-register-user"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "register_user" {
  name              = "/aws/lambda/${aws_lambda_function.register_user.function_name}"
  retention_in_days = 14

  tags = {
    Environment = var.environment
  }
}

# ============================================================================
# API GATEWAY — POST /users/register
# ============================================================================

resource "aws_api_gateway_resource" "users" {
  rest_api_id = var.rest_api_id
  parent_id   = var.rest_api_root_resource_id
  path_part   = "users"
}

resource "aws_api_gateway_resource" "users_register" {
  rest_api_id = var.rest_api_id
  parent_id   = aws_api_gateway_resource.users.id
  path_part   = "register"
}

resource "aws_api_gateway_method" "register_user_post" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.users_register.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "register_user_post" {
  rest_api_id             = var.rest_api_id
  resource_id             = aws_api_gateway_resource.users_register.id
  http_method             = aws_api_gateway_method.register_user_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.register_user.invoke_arn
}

resource "aws_api_gateway_method" "register_user_options" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.users_register.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "register_user_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.users_register.id
  http_method = aws_api_gateway_method.register_user_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "register_user_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.users_register.id
  http_method = aws_api_gateway_method.register_user_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "register_user_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.users_register.id
  http_method = aws_api_gateway_method.register_user_options.http_method
  status_code = aws_api_gateway_method_response.register_user_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.register_user_options]
}

resource "aws_lambda_permission" "register_user_apigw" {
  statement_id  = "AllowAPIGatewayInvokeRegisterUser"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.register_user.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.rest_api_execution_arn}/*/*"
}

# ============================================================================
# IAM ROLE — list-lectures
# RDS Data API + S3 GetObject (for presigned playback URLs) + Secrets + KMS
# ============================================================================

resource "aws_iam_role" "list_lectures" {
  name = "${local.name_prefix}-list-lectures-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-list-lectures-lambda"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "list_lectures_basic" {
  role       = aws_iam_role.list_lectures.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "list_lectures" {
  name = "${local.name_prefix}-list-lectures-lambda"
  role = aws_iam_role.list_lectures.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "RDSDataAPI"
        Effect   = "Allow"
        Action   = ["rds-data:ExecuteStatement"]
        Resource = var.aurora_cluster_arn
      },
      {
        Sid      = "AuroraSecretAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.aurora_secret_arn
      },
      {
        Sid      = "KMSDecryptSecret"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = var.kms_key_arn
      },
      {
        Sid      = "S3PresignedGet"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:aws:s3:::${var.bucket_name}/*"
      }
    ]
  })
}

# ============================================================================
# LAMBDA FUNCTION — list-lectures
# ============================================================================

resource "aws_lambda_function" "list_lectures" {
  function_name    = "${local.name_prefix}-list-lectures"
  role             = aws_iam_role.list_lectures.arn
  handler          = "index.handler"
  runtime          = "python3.13"
  timeout          = 15
  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      AURORA_CLUSTER_ARN = var.aurora_cluster_arn
      AURORA_SECRET_ARN  = var.aurora_secret_arn
      AURORA_DB_NAME     = var.aurora_db_name
      BUCKET_NAME        = var.bucket_name
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name        = "${local.name_prefix}-list-lectures"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "list_lectures" {
  name              = "/aws/lambda/${aws_lambda_function.list_lectures.function_name}"
  retention_in_days = 14

  tags = {
    Environment = var.environment
  }
}

# ============================================================================
# API GATEWAY — GET /lectures
# ============================================================================

resource "aws_api_gateway_resource" "lectures" {
  rest_api_id = var.rest_api_id
  parent_id   = var.rest_api_root_resource_id
  path_part   = "lectures"
}

resource "aws_api_gateway_method" "lectures_get" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.lectures.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lectures_get" {
  rest_api_id             = var.rest_api_id
  resource_id             = aws_api_gateway_resource.lectures.id
  http_method             = aws_api_gateway_method.lectures_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_lectures.invoke_arn
}

resource "aws_api_gateway_method" "lectures_options" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.lectures.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lectures_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.lectures.id
  http_method = aws_api_gateway_method.lectures_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "lectures_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.lectures.id
  http_method = aws_api_gateway_method.lectures_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "lectures_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.lectures.id
  http_method = aws_api_gateway_method.lectures_options.http_method
  status_code = aws_api_gateway_method_response.lectures_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.lectures_options]
}

resource "aws_lambda_permission" "lectures_apigw" {
  statement_id  = "AllowAPIGatewayInvokeListLectures"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_lectures.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.rest_api_execution_arn}/*/*"
}
