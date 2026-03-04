#!/bin/bash

# AWS Deployment Script
# Deploys the Task Management Application to AWS after Terraform creates infrastructure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

echo "=========================================="
echo "   AWS Deployment Script"
echo "=========================================="
echo ""

# Check if terraform outputs exist
cd "$TERRAFORM_DIR"
if ! terraform output ec2_public_ip &>/dev/null; then
    echo "ERROR: Terraform infrastructure not found!"
    echo "Run 'terraform apply' first in the terraform directory."
    exit 1
fi

# Get Terraform outputs
EC2_IP=$(terraform output -raw ec2_public_ip)
RDS_HOST=$(terraform output -raw rds_hostname)
FRONTEND_BUCKET=$(terraform output -raw frontend_bucket)
API_GATEWAY_URL=$(terraform output -raw api_gateway_url)
KEY_FILE="$TERRAFORM_DIR/task-app-key.pem"

echo "EC2 IP: $EC2_IP"
echo "RDS Host: $RDS_HOST"
echo "Frontend Bucket: $FRONTEND_BUCKET"
echo "API Gateway URL: $API_GATEWAY_URL"
echo ""

# ==========================================
# 1. Build Backend
# ==========================================
echo "=== Building Backend ==="
cd "$PROJECT_ROOT/task-api"
mvn clean package -DskipTests
echo "Backend built successfully."
echo ""

# ==========================================
# 2. Deploy Backend to EC2
# ==========================================
echo "=== Deploying Backend to EC2 ==="
if [ ! -f "$KEY_FILE" ]; then
    echo "ERROR: Key file not found: $KEY_FILE"
    exit 1
fi

# Wait for EC2 to be ready
echo "Waiting for EC2 to be ready..."
sleep 10

# Copy JAR to EC2
scp -i "$KEY_FILE" -o StrictHostKeyChecking=no \
    "$PROJECT_ROOT/task-api/target/task-api-1.0.0.jar" \
    "ec2-user@$EC2_IP:~/app/task-api.jar"

echo "Backend JAR deployed to EC2."
echo ""

# ==========================================
# 3. Start Backend on EC2
# ==========================================
echo "=== Starting Backend on EC2 ==="
read -sp "Enter RDS database password: " DB_PASSWORD
echo ""

ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no "ec2-user@$EC2_IP" << EOF
    # Stop existing process
    pkill -f task-api.jar || true
    sleep 2

    # Set environment variables and start
    export RDS_ENDPOINT=$RDS_HOST
    export DB_USERNAME=admin
    export DB_PASSWORD=$DB_PASSWORD

    cd ~/app
    nohup java -jar task-api.jar > app.log 2>&1 &

    sleep 5
    echo "Checking if application started..."
    curl -s http://localhost:8080/api/tasks || echo "Waiting for startup..."
EOF

echo "Backend started on EC2."
echo ""

# ==========================================
# 4. Update Frontend Environment
# ==========================================
echo "=== Updating Frontend Environment ==="
cat > "$PROJECT_ROOT/task-ui/src/environments/environment.prod.ts" << EOF
export const environment = {
  production: true,
  apiUrl: 'http://$EC2_IP:8080',
  fileApiUrl: '$API_GATEWAY_URL',
  isLocal: false
};
EOF

echo "Frontend environment updated."
echo ""

# ==========================================
# 5. Build Frontend
# ==========================================
echo "=== Building Frontend ==="
cd "$PROJECT_ROOT/task-ui"
npm install
npm run build

echo "Frontend built successfully."
echo ""

# ==========================================
# 6. Deploy Frontend to S3
# ==========================================
echo "=== Deploying Frontend to S3 ==="
aws s3 sync "$PROJECT_ROOT/task-ui/dist/task-ui/browser" "s3://$FRONTEND_BUCKET" --delete

FRONTEND_URL="http://$FRONTEND_BUCKET.s3-website-us-east-1.amazonaws.com"
echo "Frontend deployed to S3."
echo ""

# ==========================================
# Summary
# ==========================================
echo "=========================================="
echo "   Deployment Complete!"
echo "=========================================="
echo ""
echo "Application URLs:"
echo "  Frontend: $FRONTEND_URL"
echo "  Backend API: http://$EC2_IP:8080/api/tasks"
echo "  File API: $API_GATEWAY_URL"
echo ""
echo "SSH to EC2:"
echo "  ssh -i $KEY_FILE ec2-user@$EC2_IP"
echo ""
echo "View backend logs:"
echo "  ssh -i $KEY_FILE ec2-user@$EC2_IP 'tail -f ~/app/app.log'"
echo ""
