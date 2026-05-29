########################################
# Authorizer Lambda
########################################

module "lambda" {
  source = "../lambda"

  project_name = var.project_name

  lambda        = var.lambda
  source_config = var.source_config
  iam           = var.iam
  network       = var.network
  logging       = var.logging
  tracing       = var.tracing
  tags          = var.tags
}

########################################
# Permission for API Gateway to invoke the authorizer
########################################

resource "aws_lambda_permission" "authorizer" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_execution_arn}/authorizers/*"
}

########################################
# API Gateway v2 Authorizer (REQUEST / Lambda)
########################################

resource "aws_apigatewayv2_authorizer" "this" {
  api_id           = var.api_id
  name             = "${var.project_name}-${var.authorizer.name}"
  authorizer_type  = var.authorizer.authorizer_type
  identity_sources = var.authorizer.identity_sources

  authorizer_uri                    = module.lambda.function_invoke_arn
  authorizer_payload_format_version = var.authorizer.authorizer_payload_format_version
  authorizer_result_ttl_in_seconds  = var.authorizer.authorizer_result_ttl_in_seconds
  enable_simple_responses           = var.authorizer.enable_simple_responses
}
