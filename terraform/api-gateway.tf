# API Gateway (HTTP API v2)

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-file-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 3600
  }
}

# Lambda Integration
resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.file_api.invoke_arn
  integration_method = "POST"
}

# Routes
resource "aws_apigatewayv2_route" "get_files" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /files"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "post_upload" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "delete_files" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "DELETE /files"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "get_logs" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /logs"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "options" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "OPTIONS /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Stage
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "prod"
  auto_deploy = true

  # Note: Access logging removed - requires CloudWatch Logs permissions
  # Add back if your IAM user has logs:CreateLogGroup permission
}
