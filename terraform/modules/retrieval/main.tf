# ============================================================================
# RETRIEVAL MODULE - MAIN
# All infrastructure for the query-segments feature:
#   - IAM role scoped to Bedrock InvokeModel + RDS Data API
#   - query-segments Lambda function
#   - POST /query API Gateway resource, method, and integration
#   - OPTIONS /query CORS preflight
#   - Lambda invoke permission for API Gateway
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
      EMBEDDING_MODEL_ID = var.embedding_model_id
      EMBEDDING_DIM      = tostring(var.embedding_dim)
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
