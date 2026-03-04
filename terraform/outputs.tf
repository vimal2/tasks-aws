# Output Values

# EC2 Outputs
output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_eip.api.public_ip
}

output "ec2_instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.api.id
}

output "ssh_command" {
  description = "SSH command to connect to EC2"
  value       = "ssh -i ${var.project_name}-key.pem ec2-user@${aws_eip.api.public_ip}"
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS MySQL endpoint"
  value       = aws_db_instance.main.endpoint
}

output "rds_hostname" {
  description = "RDS MySQL hostname (without port)"
  value       = aws_db_instance.main.address
}

output "jdbc_url" {
  description = "JDBC connection URL"
  value       = "jdbc:mysql://${aws_db_instance.main.endpoint}/${var.db_name}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"
  sensitive   = true
}

# S3 Outputs
output "frontend_bucket" {
  description = "Frontend S3 bucket name"
  value       = aws_s3_bucket.frontend.bucket
}

output "frontend_url" {
  description = "Frontend website URL"
  value       = "http://${aws_s3_bucket.frontend.bucket}.s3-website-${var.aws_region}.amazonaws.com"
}

output "files_bucket" {
  description = "Files S3 bucket name"
  value       = aws_s3_bucket.files.bucket
}

# API Gateway Outputs
output "api_gateway_url" {
  description = "API Gateway URL for file operations"
  value       = aws_apigatewayv2_stage.prod.invoke_url
}

# Lambda Outputs
output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.file_api.function_name
}

# Deployment Commands
output "deploy_backend_command" {
  description = "Command to deploy backend JAR to EC2"
  value       = "scp -i ${var.project_name}-key.pem ../task-api/target/task-api-1.0.0.jar ec2-user@${aws_eip.api.public_ip}:~/app/task-api.jar"
}

output "deploy_frontend_command" {
  description = "Command to deploy frontend to S3"
  value       = "aws s3 sync ../task-ui/dist/task-ui/browser s3://${aws_s3_bucket.frontend.bucket} --delete"
}

output "start_backend_command" {
  description = "Command to run on EC2 to start the backend"
  value       = <<-EOT
    # SSH into EC2 first, then run:
    export RDS_ENDPOINT=${aws_db_instance.main.address}
    export DB_USERNAME=${var.db_username}
    export DB_PASSWORD=<your-password>
    nohup java -jar ~/app/task-api.jar > ~/app/app.log 2>&1 &
  EOT
  sensitive   = true
}

# Environment Configuration
output "angular_environment_config" {
  description = "Angular environment.prod.ts configuration"
  value       = <<-EOT
    export const environment = {
      production: true,
      apiUrl: 'http://${aws_eip.api.public_ip}:8080',
      fileApiUrl: '${aws_apigatewayv2_stage.prod.invoke_url}',
      isLocal: false
    };
  EOT
}
