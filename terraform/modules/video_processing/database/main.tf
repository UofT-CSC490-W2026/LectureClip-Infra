# ============================================================================
# VIDEO PROCESSING DATABASE MODULE - MAIN
# DynamoDB table for tracking Amazon Transcribe job state
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_dynamodb_table" "transcriptions" {
  name         = "${local.name_prefix}-transcriptions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "TranscriptionJobName"

  attribute {
    name = "TranscriptionJobName"
    type = "S"
  }

  tags = {
    Name        = "${local.name_prefix}-transcriptions"
    Environment = var.environment
  }
}
