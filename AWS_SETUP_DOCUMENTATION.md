# AWS Infrastructure Setup Documentation

## Introduction

This guide walks you through deploying a full-stack Task Management application on AWS. By the end, you'll have a working application with:
- **Frontend**: Angular 17 application hosted on Amazon S3
- **Backend**: Spring Boot 3.2 REST API running on Amazon EC2
- **Database**: MySQL 8.0 on Amazon RDS
- **File Storage**: Serverless file management using AWS Lambda, S3, and API Gateway

> **Note for Learners**: This document shows example configurations. When you create resources, AWS generates unique IDs - use your own values, not the examples shown here.

> **Tip**: For development and testing, you can run the entire application locally without AWS. See [Local Development Alternative](#local-development-alternative) at the end of this document.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Step-by-Step Setup Guide](#step-by-step-setup-guide)
   - Step 1: AWS Account Setup
   - Step 2: Create Security Groups
   - Step 3: Create RDS Database
   - Step 4: Launch EC2 Instance
   - Step 5: Deploy Backend API
   - Step 6: Create S3 Bucket for Frontend
   - Step 7: Deploy Frontend
   - Step 8: (Optional) Setup Serverless File Manager
4. [Testing Your Deployment](#testing-your-deployment)
5. [Troubleshooting](#troubleshooting)
6. [Cleanup](#cleanup)
7. [Reference: Resource Details](#reference-resource-details)
8. [Local Development Alternative](#local-development-alternative)

---

## Prerequisites

Before starting, ensure you have:

### 1. AWS Account
- An active AWS account ([Create one here](https://aws.amazon.com/free/))
- IAM user with programmatic access (Access Key ID and Secret Access Key)

### 2. Local Development Tools
```bash
# Check if these are installed
java -version      # Java 17 or higher
mvn -version       # Maven 3.6+
node -version      # Node.js 18+
npm -version       # npm 9+
ng version         # Angular CLI 17+
aws --version      # AWS CLI v2
```

### 3. Required IAM Permissions
Your IAM user needs these policies attached:

| Policy Name | Purpose |
|-------------|---------|
| `AmazonEC2FullAccess` | Create EC2 instances and security groups |
| `AmazonRDSFullAccess` | Create RDS database |
| `AmazonS3FullAccess` | Create S3 buckets for hosting |
| `AmazonVPCFullAccess` | Network configuration |
| `AWSLambda_FullAccess` | (Optional) For serverless file manager |
| `AmazonAPIGatewayAdministrator` | (Optional) For serverless file manager |

### 4. Configure AWS CLI
```bash
aws configure
# Enter your:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: us-east-1
# - Default output format: json
```

### 5. Project Files
Clone or download the project:
```bash
git clone <repository-url>
cd tasks-aws
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud (us-east-1)                       │
│                                                                      │
│  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────┐ │
│  │   S3 Bucket      │     │   EC2 Instance   │     │  RDS MySQL   │ │
│  │  (Angular App)   │────▶│  (Spring Boot)   │────▶│  (Database)  │ │
│  │                  │     │                  │     │              │ │
│  │  Static Website  │     │  Port: 8080      │     │  Port: 3306  │ │
│  └──────────────────┘     └──────────────────┘     └──────────────┘ │
│                                                                      │
│  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────┐ │
│  │   API Gateway    │────▶│     Lambda       │────▶│  S3 Bucket   │ │
│  │  (File API)      │     │  (File Handler)  │     │  (Files)     │ │
│  └──────────────────┘     └──────────────────┘     └──────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

**How it works:**
1. Users access the Angular app from S3 (static website)
2. Angular app calls the Spring Boot API on EC2
3. Spring Boot API stores/retrieves data from RDS MySQL
4. (Optional) File attachments are handled by Lambda + S3

---

## Step-by-Step Setup Guide

### Step 1: AWS Account Setup

#### 1.1 Get Your Account ID
1. Log into [AWS Console](https://console.aws.amazon.com)
2. Click your username in the top-right corner
3. Note your **Account ID** (12-digit number)

#### 1.2 Select Your Region
1. In the top-right, select **US East (N. Virginia) us-east-1**
2. Stay consistent with this region for all resources

---

### Step 2: Create Security Groups

Security groups act as firewalls for your AWS resources.

#### 2.1 Create EC2 Security Group

**Via AWS Console:**
1. Go to **EC2** → **Security Groups** → **Create security group**
2. Fill in:
   - Name: `springboot-ec2-sg`
   - Description: `Security group for Spring Boot EC2`
   - VPC: Select default VPC
3. Add **Inbound Rules**:

   | Type | Port | Source | Purpose |
   |------|------|--------|---------|
   | SSH | 22 | 0.0.0.0/0 | Remote access |
   | Custom TCP | 8080 | 0.0.0.0/0 | API access |

4. Click **Create security group**
5. **Note the Security Group ID** (starts with `sg-`)

**Via AWS CLI:**
```bash
# Create security group
aws ec2 create-security-group \
  --group-name springboot-ec2-sg \
  --description "Security group for Spring Boot EC2"

# Add SSH rule
aws ec2 authorize-security-group-ingress \
  --group-name springboot-ec2-sg \
  --protocol tcp --port 22 --cidr 0.0.0.0/0

# Add API rule
aws ec2 authorize-security-group-ingress \
  --group-name springboot-ec2-sg \
  --protocol tcp --port 8080 --cidr 0.0.0.0/0
```

#### 2.2 Create RDS Security Group

**Via AWS Console:**
1. Go to **EC2** → **Security Groups** → **Create security group**
2. Fill in:
   - Name: `springboot-rds-sg`
   - Description: `Security group for MySQL RDS`
3. Add **Inbound Rule**:

   | Type | Port | Source | Purpose |
   |------|------|--------|---------|
   | MySQL/Aurora | 3306 | springboot-ec2-sg | Allow EC2 to connect |

4. Click **Create security group**

**Via AWS CLI:**
```bash
# Get EC2 security group ID first
EC2_SG_ID=$(aws ec2 describe-security-groups \
  --group-names springboot-ec2-sg \
  --query 'SecurityGroups[0].GroupId' --output text)

# Create RDS security group
aws ec2 create-security-group \
  --group-name springboot-rds-sg \
  --description "Security group for MySQL RDS"

# Allow MySQL from EC2 security group
aws ec2 authorize-security-group-ingress \
  --group-name springboot-rds-sg \
  --protocol tcp --port 3306 --source-group $EC2_SG_ID
```

---

### Step 3: Create RDS Database

#### 3.1 Create DB Subnet Group

**Via AWS Console:**
1. Go to **RDS** → **Subnet groups** → **Create DB subnet group**
2. Fill in:
   - Name: `springboot-db-subnet`
   - Description: `Subnet group for Spring Boot RDS`
   - VPC: Select default VPC
   - Availability Zones: Select at least 2 (e.g., us-east-1a, us-east-1b)
   - Subnets: Select subnets from each AZ
3. Click **Create**

#### 3.2 Create RDS Instance

**Via AWS Console:**
1. Go to **RDS** → **Create database**
2. Choose:
   - **Standard create**
   - Engine: **MySQL**
   - Version: **MySQL 8.0.x**
   - Template: **Free tier**
3. Settings:
   - DB instance identifier: `springboot-mysql`
   - Master username: `admin`
   - Master password: Choose a strong password (e.g., `Admin123!`)
4. Instance configuration:
   - DB instance class: `db.t3.micro`
5. Storage:
   - Allocated storage: `20 GB`
   - Disable storage autoscaling (for free tier)
6. Connectivity:
   - VPC: Default VPC
   - DB subnet group: `springboot-db-subnet`
   - Public access: **Yes**
   - VPC security group: Choose existing → `springboot-rds-sg`
7. Additional configuration:
   - Initial database name: `taskdb`
8. Click **Create database**

⏳ **Wait 5-10 minutes** for the database to be created.

#### 3.3 Get RDS Endpoint

1. Go to **RDS** → **Databases** → Click on `springboot-mysql`
2. Under **Connectivity & security**, copy the **Endpoint** (e.g., `springboot-mysql.xxxxx.us-east-1.rds.amazonaws.com`)

---

### Step 4: Launch EC2 Instance

#### 4.1 Create Key Pair

**Via AWS Console:**
1. Go to **EC2** → **Key Pairs** → **Create key pair**
2. Fill in:
   - Name: `springboot-key`
   - Key pair type: RSA
   - Private key format: `.pem`
3. Click **Create key pair**
4. **Save the downloaded `.pem` file** securely!

```bash
# Set correct permissions on the key file
chmod 400 springboot-key.pem
```

#### 4.2 Launch Instance

**Via AWS Console:**
1. Go to **EC2** → **Instances** → **Launch instances**
2. Configure:
   - Name: `springboot-api-server`
   - AMI: **Amazon Linux 2023** (Free tier eligible)
   - Instance type: `t2.micro` (Free tier eligible)
   - Key pair: `springboot-key`
   - Network settings:
     - Select existing security group: `springboot-ec2-sg`
   - Advanced details → User data (paste this script):
     ```bash
     #!/bin/bash
     yum update -y
     yum install -y java-17-amazon-corretto-devel
     yum install -y mysql
     ```
3. Click **Launch instance**

#### 4.3 Get EC2 Public IP

1. Go to **EC2** → **Instances**
2. Select your instance
3. Copy the **Public IPv4 address**

#### 4.4 Connect to EC2

```bash
ssh -i springboot-key.pem ec2-user@<YOUR-EC2-PUBLIC-IP>
```

#### 4.5 Verify Java Installation

```bash
java -version
# Should show: openjdk version "17.x.x"
```

---

### Step 5: Deploy Backend API

#### 5.1 Build the Application (on your local machine)

```bash
cd task-api
mvn clean package -DskipTests
```

This creates `target/task-api-1.0.0.jar`

#### 5.2 Upload to EC2

```bash
scp -i springboot-key.pem target/task-api-1.0.0.jar ec2-user@<YOUR-EC2-PUBLIC-IP>:~/
```

#### 5.3 Run the Application (on EC2)

```bash
# SSH into EC2
ssh -i springboot-key.pem ec2-user@<YOUR-EC2-PUBLIC-IP>

# Run the application
nohup java -jar task-api-1.0.0.jar \
  --spring.datasource.url='jdbc:mysql://<YOUR-RDS-ENDPOINT>:3306/taskdb?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC' \
  --spring.datasource.username=admin \
  --spring.datasource.password=<YOUR-DB-PASSWORD> \
  > app.log 2>&1 &

# Verify it's running
curl http://localhost:8080/api/tasks
```

#### 5.4 Test API from Your Machine

```bash
curl http://<YOUR-EC2-PUBLIC-IP>:8080/api/tasks
# Should return: [] (empty array)
```

---

### Step 6: Create S3 Bucket for Frontend

#### 6.1 Create Bucket

**Via AWS Console:**
1. Go to **S3** → **Create bucket**
2. Configure:
   - Bucket name: `task-ui-app-<YOUR-ACCOUNT-ID>` (must be globally unique)
   - Region: `us-east-1`
   - Uncheck **Block all public access**
   - Acknowledge the warning
3. Click **Create bucket**

**Via AWS CLI:**
```bash
aws s3 mb s3://task-ui-app-<YOUR-ACCOUNT-ID> --region us-east-1
```

#### 6.2 Enable Static Website Hosting

1. Click on your bucket → **Properties**
2. Scroll to **Static website hosting** → **Edit**
3. Enable static website hosting
4. Index document: `index.html`
5. Error document: `index.html`
6. Click **Save changes**
7. **Note the website endpoint URL**

#### 6.3 Set Bucket Policy

1. Go to **Permissions** → **Bucket policy** → **Edit**
2. Paste this policy (replace `<YOUR-BUCKET-NAME>`):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::<YOUR-BUCKET-NAME>/*"
    }
  ]
}
```

3. Click **Save changes**

---

### Step 7: Deploy Frontend

#### 7.1 Update API URL

Edit `task-ui/src/environments/environment.prod.ts`:
```typescript
export const environment = {
  production: true,
  apiUrl: 'http://<YOUR-EC2-PUBLIC-IP>:8080'
};
```

#### 7.2 Build Angular App

```bash
cd task-ui
npm install
npm run build
```

#### 7.3 Deploy to S3

```bash
aws s3 sync dist/task-ui/browser s3://<YOUR-BUCKET-NAME> --delete
```

#### 7.4 Access Your Application

Open your browser and go to:
```
http://<YOUR-BUCKET-NAME>.s3-website-us-east-1.amazonaws.com
```

🎉 **Congratulations!** Your application is now live!

---

### Step 8: (Optional) Setup Serverless File Manager

This step adds file attachment capability to tasks using AWS Lambda.

#### 8.1 Create IAM Role for Lambda

```bash
# Create trust policy file
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name lambda-s3-execution-role \
  --assume-role-policy-document file://trust-policy.json

# Attach policies
aws iam attach-role-policy --role-name lambda-s3-execution-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam attach-role-policy --role-name lambda-s3-execution-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
aws iam attach-role-policy --role-name lambda-s3-execution-role \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsReadOnlyAccess
```

#### 8.2 Create S3 Bucket for Files

```bash
aws s3 mb s3://lambda-s3-demo-bucket-<YOUR-ACCOUNT-ID>

# Add CORS configuration
cat > cors.json << 'EOF'
{
  "CORSRules": [
    {
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
      "AllowedOrigins": ["*"],
      "ExposeHeaders": ["ETag"]
    }
  ]
}
EOF

aws s3api put-bucket-cors \
  --bucket lambda-s3-demo-bucket-<YOUR-ACCOUNT-ID> \
  --cors-configuration file://cors.json
```

#### 8.3 Deploy Lambda Functions

```bash
cd serverless-file-manager/api
npm install
zip -r ../api-function.zip index.js node_modules/

# Get role ARN
ROLE_ARN=$(aws iam get-role --role-name lambda-s3-execution-role \
  --query 'Role.Arn' --output text)

# Create Lambda function
aws lambda create-function \
  --function-name s3-demo-api \
  --runtime nodejs20.x \
  --handler index.handler \
  --role $ROLE_ARN \
  --zip-file fileb://../api-function.zip \
  --environment Variables={BUCKET_NAME=lambda-s3-demo-bucket-<YOUR-ACCOUNT-ID>} \
  --timeout 30 \
  --memory-size 256
```

#### 8.4 Create API Gateway

See the detailed instructions in the [Reference: Serverless File Manager](#serverless-file-manager) section below.

---

## Testing Your Deployment

### Test Backend API

```bash
# Create a task
curl -X POST http://<YOUR-EC2-IP>:8080/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Task", "description": "My first task", "status": "PENDING"}'

# Get all tasks
curl http://<YOUR-EC2-IP>:8080/api/tasks
```

### Test Frontend

1. Open `http://<YOUR-BUCKET-NAME>.s3-website-us-east-1.amazonaws.com`
2. Click **+ New Task**
3. Create a task and verify it appears in the list

### Test File Attachments (if configured)

1. Open a task in the UI
2. Click the **Attachments** section
3. Upload a file
4. Verify the file appears in the list

---

## Troubleshooting

### Common Issues and Solutions

#### 1. "Failed to load tasks" in Frontend

**Cause:** CORS error or API not reachable

**Solutions:**
- Verify EC2 security group allows port 8080
- Check the API URL in `environment.prod.ts` matches your EC2 IP
- Ensure Spring Boot app is running: `curl http://<EC2-IP>:8080/api/tasks`

#### 2. Cannot Connect to RDS from EC2

**Cause:** Security group misconfiguration

**Solutions:**
- Verify RDS security group allows MySQL (3306) from EC2 security group
- Check RDS is in "Available" status
- Test connection: `mysql -h <RDS-ENDPOINT> -u admin -p`

#### 3. Application Won't Start on EC2

**Cause:** Java not installed or wrong database credentials

**Solutions:**
```bash
# Check Java
java -version

# Check application logs
tail -100 app.log

# Verify database connectivity
mysql -h <RDS-ENDPOINT> -u admin -p taskdb
```

#### 4. S3 Website Returns 403 Forbidden

**Cause:** Bucket policy not set or public access blocked

**Solutions:**
- Verify bucket policy allows public read
- Check "Block public access" is disabled
- Ensure `index.html` exists in the bucket

#### 5. File Upload Fails (Serverless)

**Cause:** CORS not configured on S3 bucket

**Solutions:**
```bash
# Apply CORS configuration
aws s3api put-bucket-cors --bucket <YOUR-BUCKET> --cors-configuration file://cors.json
```

---

## Cleanup

To avoid ongoing AWS charges, delete resources when done:

```bash
# 1. Empty and delete S3 buckets
aws s3 rm s3://<YOUR-UI-BUCKET> --recursive
aws s3 rb s3://<YOUR-UI-BUCKET>

# 2. Terminate EC2 instance
aws ec2 terminate-instances --instance-ids <YOUR-INSTANCE-ID>

# 3. Delete RDS instance (takes several minutes)
aws rds delete-db-instance --db-instance-identifier springboot-mysql --skip-final-snapshot

# 4. Delete security groups (after EC2 and RDS are deleted)
aws ec2 delete-security-group --group-name springboot-rds-sg
aws ec2 delete-security-group --group-name springboot-ec2-sg

# 5. Delete key pair
aws ec2 delete-key-pair --key-name springboot-key

# 6. (If serverless was configured) Delete Lambda and API Gateway
aws lambda delete-function --function-name s3-demo-api
aws apigateway delete-rest-api --rest-api-id <YOUR-API-ID>
```

---

## Reference: Recommended Resource Names

Use these naming conventions for your resources:

| Resource | Recommended Name |
|----------|-----------------|
| EC2 Security Group | `springboot-ec2-sg` |
| RDS Security Group | `springboot-rds-sg` |
| RDS Instance | `springboot-mysql` |
| RDS Subnet Group | `springboot-db-subnet` |
| EC2 Instance | `springboot-api-server` |
| EC2 Key Pair | `springboot-key` |
| S3 UI Bucket | `task-ui-app-<YOUR-ACCOUNT-ID>` |
| S3 Files Bucket | `lambda-s3-demo-bucket-<YOUR-ACCOUNT-ID>` |
| Lambda Function | `s3-demo-api` |
| IAM Role | `lambda-s3-execution-role` |

---

## Reference: Configuration Values

### RDS Configuration

| Setting | Recommended Value |
|---------|-------------------|
| Engine | MySQL 8.0 |
| Instance Class | `db.t3.micro` (Free Tier) |
| Storage | 20 GB |
| Database Name | `taskdb` |
| Port | 3306 |

### EC2 Configuration

| Setting | Recommended Value |
|---------|-------------------|
| Instance Type | `t2.micro` (Free Tier) |
| AMI | Amazon Linux 2023 |
| User Data Script | See Step 4.2 above |

### JDBC Connection String Template

```
jdbc:mysql://<YOUR-RDS-ENDPOINT>:3306/taskdb?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC
```

### SSH Access Template

```bash
ssh -i <YOUR-KEY-FILE>.pem ec2-user@<YOUR-EC2-PUBLIC-IP>
```

> **Note:** Ensure the key file has proper permissions: `chmod 400 <YOUR-KEY-FILE>.pem`

---

## Reference: Serverless File Manager

### File API Endpoints

Once API Gateway is configured, your endpoints will be:

| Method | Path | Description |
|--------|------|-------------|
| GET | /files | List files (supports `?taskId=X`) |
| POST | /upload | Get presigned URL for upload |
| DELETE | /files | Delete a file |
| GET | /logs | Get Lambda processing logs |

### API Gateway URL Format

```
https://<YOUR-API-ID>.execute-api.<REGION>.amazonaws.com/prod
```

### Lambda Configuration

| Property | Recommended Value |
|----------|-------------------|
| Runtime | Node.js 20.x |
| Handler | `index.handler` |
| Memory | 256 MB |
| Timeout | 30 seconds |

### S3 File Structure

```
<YOUR-FILES-BUCKET>/
├── uploads/           # Standalone uploads
└── tasks/             # Task-specific files
    ├── 1/             # Files for task ID 1
    ├── 2/             # Files for task ID 2
    └── ...
```

### Sample File API Requests

**List Task Files:**
```bash
curl "https://<YOUR-API-ID>.execute-api.us-east-1.amazonaws.com/prod/files?taskId=1"
```

**Get Upload URL:**
```bash
curl -X POST https://<YOUR-API-ID>.execute-api.us-east-1.amazonaws.com/prod/upload \
  -H "Content-Type: application/json" \
  -d '{
    "fileName": "document.pdf",
    "contentType": "application/pdf",
    "taskId": 1
  }'
```

**Delete Task File:**
```bash
curl -X DELETE https://<YOUR-API-ID>.execute-api.us-east-1.amazonaws.com/prod/files \
  -H "Content-Type: application/json" \
  -d '{
    "fileName": "document.pdf",
    "taskId": 1
  }'
```

---

## Reference: Task API Endpoints

### Base URL Format
```
http://<YOUR-EC2-PUBLIC-IP>:8080
```

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/tasks` | Get all tasks |
| GET | `/api/tasks/{id}` | Get task by ID |
| GET | `/api/tasks?status={status}` | Filter tasks by status |
| POST | `/api/tasks` | Create a new task |
| PUT | `/api/tasks/{id}` | Update an existing task |
| DELETE | `/api/tasks/{id}` | Delete a task |

### Task Status Values
- `PENDING`
- `IN_PROGRESS`
- `COMPLETED`

---

## Cost Considerations

All resources are configured for **AWS Free Tier** eligibility:

| Resource | Free Tier Limit |
|----------|-----------------|
| EC2 (t2.micro) | 750 hours/month |
| RDS (db.t3.micro) | 750 hours/month |
| S3 | 5 GB storage, 20,000 GET requests |
| Lambda | 1M requests/month, 400,000 GB-seconds |
| API Gateway | 1M API calls/month |

> **Warning:** Remember to stop/terminate resources when not in use to avoid charges

---

## Document Information

| Property | Value |
|----------|-------|
| Created | March 3, 2026 |
| Updated | March 4, 2026 |
| Author | Claude Code Assistant |
| Version | 2.1 |

### Changelog

- **v2.1** - Added Local Development Alternative section (H2 database, local file storage)
- **v2.0** - Complete restructure with step-by-step beginner guide, removed specific IDs
- **v1.1** - Added Serverless File Manager documentation (Lambda, API Gateway, S3 file storage)
- **v1.0** - Initial documentation (EC2, RDS, S3 static hosting)

---

## Appendix: Finding Your AWS Resource IDs

When you create your own AWS resources, here's how to find the IDs you'll need:

| Resource | Where to Find |
|----------|---------------|
| **AWS Account ID** | AWS Console → Click your username (top right) → Account ID |
| **EC2 Instance ID** | EC2 Console → Instances → Instance ID column |
| **EC2 Public IP** | EC2 Console → Instances → Select instance → Public IPv4 address |
| **RDS Endpoint** | RDS Console → Databases → Select DB → Connectivity & security → Endpoint |
| **S3 Bucket Name** | S3 Console → Buckets → Name column |
| **S3 Website URL** | S3 Console → Select bucket → Properties → Static website hosting → Endpoint |
| **Security Group ID** | EC2 Console → Security Groups → Security group ID column |
| **Subnet ID** | VPC Console → Subnets → Subnet ID column |
| **API Gateway ID** | API Gateway Console → APIs → API ID column |
| **API Gateway URL** | API Gateway Console → Select API → Stages → Invoke URL |
| **Lambda Function ARN** | Lambda Console → Functions → Select function → Function ARN |
| **IAM Role ARN** | IAM Console → Roles → Select role → ARN |

### AWS CLI Commands to Find Resources

```bash
# Get your AWS Account ID
aws sts get-caller-identity --query Account --output text

# List EC2 instances
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,Tags[?Key==`Name`].Value]' --output table

# List RDS instances
aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,Endpoint.Address]' --output table

# List S3 buckets
aws s3 ls

# List API Gateways
aws apigateway get-rest-apis --query 'items[*].[id,name]' --output table

# List Lambda functions
aws lambda list-functions --query 'Functions[*].[FunctionName,FunctionArn]' --output table

# List Security Groups
aws ec2 describe-security-groups --query 'SecurityGroups[*].[GroupId,GroupName]' --output table
```

---

## Local Development Alternative

If you want to develop and test without AWS infrastructure, the application supports a **local development mode** with:
- **H2 In-Memory Database** (instead of RDS MySQL)
- **Local File Storage** (instead of S3 + Lambda)

### Quick Start (Local Mode)

#### 1. Start Backend with Local Profile

```bash
cd task-api
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

This starts the backend with:
- H2 database at `jdbc:h2:mem:taskdb`
- H2 Console at http://localhost:8080/h2-console (username: `sa`, password: empty)
- Local file storage in `./uploads/` directory
- File API endpoints at `/api/files`

#### 2. Start Frontend with Local Configuration

```bash
cd task-ui
npm install
npm run start:local
```

Access the app at http://localhost:4200

### Comparison: Local vs AWS

| Feature | Local Mode | AWS Production |
|---------|------------|----------------|
| **Database** | H2 (in-memory, resets on restart) | MySQL on RDS (persistent) |
| **File Storage** | `./uploads/` folder | S3 bucket |
| **File API** | Spring Boot REST (`/api/files`) | Lambda + API Gateway |
| **Frontend** | localhost:4200 | S3 static website |
| **Backend** | localhost:8080 | EC2 instance |
| **Cost** | Free | AWS charges apply |
| **Setup Time** | ~2 minutes | ~30 minutes |

### When to Use Each Mode

| Use Local Mode When... | Use AWS Mode When... |
|------------------------|----------------------|
| Developing new features | Testing AWS integration |
| Debugging backend code | Deploying to production |
| Running unit/integration tests | Demonstrating the full architecture |
| Working offline | Sharing with others |

### Configuration Files

| Mode | Backend Config | Frontend Config |
|------|----------------|-----------------|
| **Local** | `application-local.properties` | `environment.local.ts` |
| **AWS** | `application.properties` | `environment.ts` |

### Local Mode File Structure

```
task-api/
└── uploads/
    └── tasks/
        ├── 1/
        │   ├── document.pdf
        │   └── image.png
        ├── 2/
        │   └── report.xlsx
        └── ...
```

For complete local development instructions, see the main [README.md](./README.md).
