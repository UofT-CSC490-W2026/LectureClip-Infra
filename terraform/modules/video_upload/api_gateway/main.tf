# ============================================================================
# API GATEWAY MODULE - MAIN
# REST API with three endpoints matching the reference architecture:
#   POST /uploads            → video-upload Lambda (direct pre-signed URL)
#   POST /multipart/init     → multipart-init Lambda
#   POST /multipart/complete → multipart-complete Lambda
# ============================================================================

resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api"
  description = "LectureClip video upload API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "${var.project_name}-api"
    Environment = var.environment
  }
}

# ============================================================================
# /uploads — direct pre-signed URL upload
# ============================================================================

resource "aws_api_gateway_resource" "uploads" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "uploads"
}

resource "aws_api_gateway_method" "uploads_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.uploads.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "uploads_post" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.uploads.id
  http_method             = aws_api_gateway_method.uploads_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.video_upload_invoke_arn
}

resource "aws_api_gateway_method" "uploads_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.uploads.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "uploads_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.uploads.id
  http_method = aws_api_gateway_method.uploads_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "uploads_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.uploads.id
  http_method = aws_api_gateway_method.uploads_options.http_method
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

resource "aws_api_gateway_integration_response" "uploads_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.uploads.id
  http_method = aws_api_gateway_method.uploads_options.http_method
  status_code = aws_api_gateway_method_response.uploads_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.uploads_options]
}

resource "aws_lambda_permission" "uploads" {
  statement_id  = "AllowAPIGatewayInvokeUploads"
  action        = "lambda:InvokeFunction"
  function_name = var.video_upload_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# ============================================================================
# /multipart — parent resource
# ============================================================================

resource "aws_api_gateway_resource" "multipart" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "multipart"
}

# ============================================================================
# /multipart/init
# ============================================================================

resource "aws_api_gateway_resource" "multipart_init" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.multipart.id
  path_part   = "init"
}

resource "aws_api_gateway_method" "multipart_init_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.multipart_init.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "multipart_init_post" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.multipart_init.id
  http_method             = aws_api_gateway_method.multipart_init_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.multipart_init_invoke_arn
}

resource "aws_api_gateway_method" "multipart_init_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.multipart_init.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "multipart_init_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.multipart_init.id
  http_method = aws_api_gateway_method.multipart_init_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "multipart_init_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.multipart_init.id
  http_method = aws_api_gateway_method.multipart_init_options.http_method
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

resource "aws_api_gateway_integration_response" "multipart_init_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.multipart_init.id
  http_method = aws_api_gateway_method.multipart_init_options.http_method
  status_code = aws_api_gateway_method_response.multipart_init_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.multipart_init_options]
}

resource "aws_lambda_permission" "multipart_init" {
  statement_id  = "AllowAPIGatewayInvokeMultipartInit"
  action        = "lambda:InvokeFunction"
  function_name = var.multipart_init_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# ============================================================================
# /multipart/complete
# ============================================================================

resource "aws_api_gateway_resource" "multipart_complete" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.multipart.id
  path_part   = "complete"
}

resource "aws_api_gateway_method" "multipart_complete_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.multipart_complete.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "multipart_complete_post" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.multipart_complete.id
  http_method             = aws_api_gateway_method.multipart_complete_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.multipart_complete_invoke_arn
}

resource "aws_api_gateway_method" "multipart_complete_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.multipart_complete.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "multipart_complete_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.multipart_complete.id
  http_method = aws_api_gateway_method.multipart_complete_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "multipart_complete_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.multipart_complete.id
  http_method = aws_api_gateway_method.multipart_complete_options.http_method
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

resource "aws_api_gateway_integration_response" "multipart_complete_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.multipart_complete.id
  http_method = aws_api_gateway_method.multipart_complete_options.http_method
  status_code = aws_api_gateway_method_response.multipart_complete_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.multipart_complete_options]
}

resource "aws_lambda_permission" "multipart_complete" {
  statement_id  = "AllowAPIGatewayInvokeMultipartComplete"
  action        = "lambda:InvokeFunction"
  function_name = var.multipart_complete_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# ============================================================================
# DEPLOYMENT & STAGE
# ============================================================================

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.uploads.id,
      aws_api_gateway_method.uploads_post.id,
      aws_api_gateway_integration.uploads_post.id,
      aws_api_gateway_resource.multipart_init.id,
      aws_api_gateway_method.multipart_init_post.id,
      aws_api_gateway_integration.multipart_init_post.id,
      aws_api_gateway_resource.multipart_complete.id,
      aws_api_gateway_method.multipart_complete_post.id,
      aws_api_gateway_integration.multipart_complete_post.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.uploads_post,
    aws_api_gateway_integration.uploads_options,
    aws_api_gateway_integration.multipart_init_post,
    aws_api_gateway_integration.multipart_init_options,
    aws_api_gateway_integration.multipart_complete_post,
    aws_api_gateway_integration.multipart_complete_options,
  ]
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
  }
}
