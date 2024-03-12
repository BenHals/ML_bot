
output "base_url" {
  value = aws_api_gateway_deployment.name.invoke_url
}
