# AWS Deployment Script (PowerShell for Windows)
# Deploys the Task Management Application to AWS after Terraform creates infrastructure

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$TerraformDir = Join-Path $ProjectRoot "terraform"

Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "   AWS Deployment Script (Windows)" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host ""

# Check if terraform outputs exist
Set-Location $TerraformDir
try {
    $null = terraform output ec2_public_ip 2>$null
} catch {
    Write-Host "ERROR: Terraform infrastructure not found!" -ForegroundColor Red
    Write-Host "Run 'terraform apply' first in the terraform directory."
    exit 1
}

# Get Terraform outputs
$EC2_IP = (terraform output -raw ec2_public_ip)
$RDS_HOST = (terraform output -raw rds_hostname)
$FRONTEND_BUCKET = (terraform output -raw frontend_bucket)
$API_GATEWAY_URL = (terraform output -raw api_gateway_url)
$KEY_FILE = Join-Path $TerraformDir "task-app-key.pem"

Write-Host "EC2 IP: $EC2_IP"
Write-Host "RDS Host: $RDS_HOST"
Write-Host "Frontend Bucket: $FRONTEND_BUCKET"
Write-Host "API Gateway URL: $API_GATEWAY_URL"
Write-Host ""

# ==========================================
# Fix PEM file permissions (Windows)
# ==========================================
Write-Host "=== Fixing PEM File Permissions ===" -ForegroundColor Cyan
if (Test-Path $KEY_FILE) {
    icacls $KEY_FILE /inheritance:r 2>$null
    icacls $KEY_FILE /grant:r "$($env:USERNAME):(R)" 2>$null
    Write-Host "PEM file permissions fixed."
} else {
    Write-Host "ERROR: Key file not found: $KEY_FILE" -ForegroundColor Red
    exit 1
}
Write-Host ""

# ==========================================
# 1. Build Backend
# ==========================================
Write-Host "=== Building Backend ===" -ForegroundColor Cyan
Set-Location (Join-Path $ProjectRoot "task-api")
mvn clean package -DskipTests
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Maven build failed!" -ForegroundColor Red
    exit 1
}
Write-Host "Backend built successfully."
Write-Host ""

# ==========================================
# 2. Deploy Backend to EC2
# ==========================================
Write-Host "=== Deploying Backend to EC2 ===" -ForegroundColor Cyan
Write-Host "Waiting for EC2 to be ready..."
Start-Sleep -Seconds 10

$JarFile = Join-Path $ProjectRoot "task-api\target\task-api-1.0.0.jar"
scp -i $KEY_FILE -o StrictHostKeyChecking=no $JarFile "ec2-user@${EC2_IP}:~/app/task-api.jar"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: SCP failed! Trying S3 method..." -ForegroundColor Yellow

    # Alternative: Use S3
    $S3Bucket = $FRONTEND_BUCKET -replace "-ui-", "-files-"
    aws s3 cp $JarFile "s3://$S3Bucket/task-api-1.0.0.jar"

    Write-Host "JAR uploaded to S3. SSH to EC2 and run:"
    Write-Host "  aws s3 cp s3://$S3Bucket/task-api-1.0.0.jar ~/app/task-api.jar"
} else {
    Write-Host "Backend JAR deployed to EC2."
}
Write-Host ""

# ==========================================
# 3. Update Frontend Environment
# ==========================================
Write-Host "=== Updating Frontend Environment ===" -ForegroundColor Cyan
$EnvProdFile = Join-Path $ProjectRoot "task-ui\src\environments\environment.prod.ts"
$EnvContent = @"
export const environment = {
  production: true,
  apiUrl: 'http://$EC2_IP:8080',
  fileApiUrl: '$API_GATEWAY_URL',
  isLocal: false
};
"@
Set-Content -Path $EnvProdFile -Value $EnvContent
Write-Host "Frontend environment updated."
Write-Host ""

# ==========================================
# 4. Build Frontend
# ==========================================
Write-Host "=== Building Frontend ===" -ForegroundColor Cyan
Set-Location (Join-Path $ProjectRoot "task-ui")
npm install
npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Angular build failed!" -ForegroundColor Red
    exit 1
}
Write-Host "Frontend built successfully."
Write-Host ""

# ==========================================
# 5. Deploy Frontend to S3
# ==========================================
Write-Host "=== Deploying Frontend to S3 ===" -ForegroundColor Cyan
$DistPath = Join-Path $ProjectRoot "task-ui\dist\task-ui\browser"
aws s3 sync $DistPath "s3://$FRONTEND_BUCKET" --delete
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: S3 sync failed!" -ForegroundColor Red
    exit 1
}

$FRONTEND_URL = "http://$FRONTEND_BUCKET.s3-website-us-east-1.amazonaws.com"
Write-Host "Frontend deployed to S3."
Write-Host ""

# ==========================================
# Summary
# ==========================================
Write-Host "==========================================" -ForegroundColor Green
Write-Host "   Deployment Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Application URLs:" -ForegroundColor Yellow
Write-Host "  Frontend: $FRONTEND_URL"
Write-Host "  Backend API: http://${EC2_IP}:8080/api/tasks"
Write-Host "  File API: $API_GATEWAY_URL"
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. SSH to EC2: ssh -i $KEY_FILE ec2-user@$EC2_IP"
Write-Host "  2. Start the backend:"
Write-Host "     export RDS_ENDPOINT=$RDS_HOST"
Write-Host "     export DB_USERNAME=admin"
Write-Host "     export DB_PASSWORD=<your-password>"
Write-Host "     cd ~/app && nohup java -jar task-api.jar > app.log 2>&1 &"
Write-Host ""
