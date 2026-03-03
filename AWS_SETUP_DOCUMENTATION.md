# AWS Infrastructure Setup Documentation

> **IMPORTANT FOR LEARNERS**
>
> This document contains **example values** from a specific AWS deployment. **DO NOT copy these values directly.** You must replace them with your own AWS resource IDs, endpoints, and credentials when setting up your environment.
>
> Values you MUST replace include:
> - AWS Account ID (e.g., `127246139738`)
> - S3 Bucket names (e.g., `task-ui-app-127246139738`)
> - EC2 Instance IDs and Public IPs
> - RDS Endpoints
> - API Gateway IDs and URLs
> - Security Group IDs
> - Subnet IDs
> - IAM Role ARNs
> - Database credentials
>
> When you create your own resources, AWS will generate unique IDs for you. Use those instead.

---

## Project Overview

This document describes the complete AWS infrastructure setup for a full-stack Task Management application consisting of:
- **Frontend**: Angular 17 application hosted on Amazon S3
- **Backend**: Spring Boot 3.2 REST API running on Amazon EC2
- **Database**: MySQL 8.0 on Amazon RDS
- **File Storage**: Serverless file management using AWS Lambda, S3, and API Gateway

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [AWS Account Configuration](#aws-account-configuration)
3. [Network Configuration](#network-configuration)
4. [Security Groups](#security-groups)
5. [RDS MySQL Database](#rds-mysql-database)
6. [EC2 Instance](#ec2-instance)
7. [S3 Static Website Hosting](#s3-static-website-hosting)
8. [Serverless File Manager](#serverless-file-manager)
9. [Application Deployment](#application-deployment)
10. [API Endpoints](#api-endpoints)
11. [Connection Details](#connection-details)
12. [Troubleshooting](#troubleshooting)

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
│  │  Port: 80 (HTTP) │     │  Port: 8080      │     │  Port: 3306  │ │
│  └──────────────────┘     └──────────────────┘     └──────────────┘ │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
         ▲                          ▲
         │                          │
         │         HTTPS            │         HTTP
         │                          │
    ┌─────────┐                ┌─────────┐
    │  User   │                │  User   │
    │ Browser │                │ (API)   │
    └─────────┘                └─────────┘
```

---

## AWS Account Configuration

### IAM User Details

| Property | Example Value | Replace With |
|----------|---------------|--------------|
| Account ID | `127246139738` | `<YOUR-ACCOUNT-ID>` |
| IAM User | `your-iam-username` | `<YOUR-IAM-USERNAME>` |
| User ARN | `arn:aws:iam::127246139738:user/your-iam-username` | `arn:aws:iam::<YOUR-ACCOUNT-ID>:user/<YOUR-IAM-USERNAME>` |
| Region | `us-east-1 (N. Virginia)` | Your preferred region |

### Required IAM Policies

The following policies must be attached to the IAM user:

| Policy Name | Purpose |
|-------------|---------|
| `AmazonEC2FullAccess` | Create and manage EC2 instances, security groups |
| `AmazonRDSFullAccess` | Create and manage RDS database instances |
| `AmazonS3FullAccess` | Create S3 buckets and host static websites |
| `AmazonVPCFullAccess` | VPC and networking configuration |

### Permissions Boundary

If a permissions boundary is applied, ensure it includes:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "rds:*",
        "s3:*"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## Network Configuration

### VPC Details

| Property | Value |
|----------|-------|
| VPC ID | `vpc-054d7a28d11948a4f` |
| CIDR Block | `172.31.0.0/16` |
| Type | Default VPC |

### Subnets Used

| Subnet ID | Availability Zone |
|-----------|-------------------|
| `subnet-0197ad55cc4847070` | us-east-1a |
| `subnet-044393f4dc42d3c93` | us-east-1b |
| `subnet-079ecf7120b3aae84` | us-east-1c |
| `subnet-0864bb6218b97cb4c` | us-east-1d |
| `subnet-02e6f6021e2170901` | us-east-1e |
| `subnet-02b557e41520628df` | us-east-1f |

---

## Security Groups

### EC2 Security Group

| Property | Value |
|----------|-------|
| Security Group ID | `sg-05a2d410a297dd07d` |
| Name | `springboot-ec2-sg` |
| Description | Security group for Spring Boot EC2 instance |

**Inbound Rules:**

| Type | Protocol | Port | Source | Purpose |
|------|----------|------|--------|---------|
| SSH | TCP | 22 | 0.0.0.0/0 | Remote server access |
| Custom TCP | TCP | 8080 | 0.0.0.0/0 | Spring Boot API access |

### RDS Security Group

| Property | Value |
|----------|-------|
| Security Group ID | `sg-009ce5d8b6c50e11d` |
| Name | `springboot-rds-sg` |
| Description | Security group for MySQL RDS |

**Inbound Rules:**

| Type | Protocol | Port | Source | Purpose |
|------|----------|------|--------|---------|
| MySQL/Aurora | TCP | 3306 | sg-05a2d410a297dd07d | Allow EC2 to connect to RDS |

---

## RDS MySQL Database

### Instance Configuration

| Property | Value |
|----------|-------|
| DB Instance Identifier | `springboot-mysql` |
| Engine | MySQL 8.0 |
| Instance Class | `db.t3.micro` (Free Tier) |
| Storage | 20 GB (General Purpose SSD) |
| Multi-AZ | No |
| Publicly Accessible | Yes |

### Connection Details

| Property | Value |
|----------|-------|
| Endpoint | `springboot-mysql.cevayug0ey5k.us-east-1.rds.amazonaws.com` |
| Port | `3306` |
| Database Name | `taskdb` |
| Master Username | `admin` |
| Master Password | `Admin123!` |

### DB Subnet Group

| Property | Value |
|----------|-------|
| Name | `springboot-db-subnet` |
| Description | Subnet group for Spring Boot RDS |
| Subnets | `subnet-0197ad55cc4847070`, `subnet-044393f4dc42d3c93` |

### JDBC Connection String

```
jdbc:mysql://springboot-mysql.cevayug0ey5k.us-east-1.rds.amazonaws.com:3306/taskdb?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC
```

---

## EC2 Instance

### Instance Configuration

| Property | Value |
|----------|-------|
| Instance ID | `i-07de93ccfe9e3e8b6` |
| Instance Type | `t2.micro` (Free Tier) |
| AMI | Amazon Linux 2023 (`ami-0f3caa1cf4417e51b`) |
| Key Pair | `springboot-key` |
| Public IP | `44.195.1.174` |
| Availability Zone | `us-east-1a` |

### Instance Tags

| Key | Value |
|-----|-------|
| Name | `springboot-api-server` |

### User Data Script

The following script was executed on instance launch:

```bash
#!/bin/bash
yum update -y
yum install -y java-17-amazon-corretto-devel
yum install -y mysql
```

### SSH Access

```bash
ssh -i springboot-key.pem ec2-user@44.195.1.174
```

**Key File Location:** Store your `.pem` key file in a secure location on your machine

> **Note:** Ensure the key file has proper permissions: `chmod 400 springboot-key.pem`

---

## S3 Static Website Hosting

### Bucket Configuration

| Property | Value |
|----------|-------|
| Bucket Name | `task-ui-app-127246139738` |
| Region | `us-east-1` |
| Website Hosting | Enabled |
| Index Document | `index.html` |
| Error Document | `index.html` |

### Website URL

```
http://task-ui-app-127246139738.s3-website-us-east-1.amazonaws.com
```

### Bucket Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::task-ui-app-127246139738/*"
    }
  ]
}
```

### Public Access Settings

| Setting | Value |
|---------|-------|
| Block Public ACLs | False |
| Ignore Public ACLs | False |
| Block Public Policy | False |
| Restrict Public Buckets | False |

---

## Serverless File Manager

The application includes a serverless file management system for task file attachments.

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud (us-east-1)                       │
│                                                                      │
│  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────┐ │
│  │   API Gateway    │────▶│   Lambda (API)   │────▶│  S3 Bucket   │ │
│  │                  │     │  s3-demo-api     │     │  (Files)     │ │
│  └──────────────────┘     └──────────────────┘     └──────────────┘ │
│                                                           │         │
│                                                           ▼         │
│                                                    ┌──────────────┐ │
│                                                    │   Lambda     │ │
│                                                    │  (Trigger)   │ │
│                                                    │ s3-file-     │ │
│                                                    │ processor    │ │
│                                                    └──────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### Lambda Functions

#### API Lambda (s3-demo-api)

| Property | Value |
|----------|-------|
| Function Name | `s3-demo-api` |
| Runtime | Node.js 20.x |
| Handler | `index.handler` |
| Memory | 256 MB |
| Timeout | 30 seconds |
| Role | `lambda-s3-execution-role` |

**Environment Variables:**

| Variable | Value |
|----------|-------|
| BUCKET_NAME | `lambda-s3-demo-bucket-127246139738` |

#### File Processor Lambda (s3-file-processor)

| Property | Value |
|----------|-------|
| Function Name | `s3-file-processor` |
| Runtime | Node.js 20.x |
| Handler | `index.handler` |
| Memory | 128 MB |
| Timeout | 30 seconds |
| Trigger | S3 ObjectCreated events |

### API Gateway

| Property | Value |
|----------|-------|
| API ID | `hk327mcsu7` |
| API Name | `s3-demo-api` |
| Stage | `prod` |
| Endpoint Type | Regional |

**Base URL:**
```
https://hk327mcsu7.execute-api.us-east-1.amazonaws.com/prod
```

**Endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| GET | /files | List files (supports ?taskId=X) |
| POST | /upload | Get presigned URL for upload |
| DELETE | /files | Delete a file |
| GET | /logs | Get Lambda processing logs |

### S3 Buckets

#### Data Bucket (File Storage)

| Property | Value |
|----------|-------|
| Bucket Name | `lambda-s3-demo-bucket-127246139738` |
| Region | us-east-1 |
| Versioning | Disabled |

**Folder Structure:**
```
lambda-s3-demo-bucket-127246139738/
├── uploads/           # Standalone file uploads
└── tasks/             # Task-specific files
    ├── 1/             # Files for task ID 1
    ├── 2/             # Files for task ID 2
    └── ...
```

**CORS Configuration:**
```json
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
```

#### File Manager UI Bucket

| Property | Value |
|----------|-------|
| Bucket Name | `lambda-s3-demo-ui-127246139738` |
| Region | us-east-1 |
| Website Hosting | Enabled |
| Index Document | index.html |

**Website URL:**
```
http://lambda-s3-demo-ui-127246139738.s3-website-us-east-1.amazonaws.com
```

### IAM Role

| Property | Value |
|----------|-------|
| Role Name | `lambda-s3-execution-role` |
| Role ARN | `arn:aws:iam::127246139738:role/lambda-s3-execution-role` |

**Attached Policies:**

| Policy | Purpose |
|--------|---------|
| AWSLambdaBasicExecutionRole | CloudWatch Logs access |
| AmazonS3FullAccess | S3 bucket operations |
| CloudWatchLogsReadOnlyAccess | Read Lambda logs |

### Sample API Requests

**List Task Files:**
```bash
curl "https://hk327mcsu7.execute-api.us-east-1.amazonaws.com/prod/files?taskId=1"
```

**Get Upload URL:**
```bash
curl -X POST https://hk327mcsu7.execute-api.us-east-1.amazonaws.com/prod/upload \
  -H "Content-Type: application/json" \
  -d '{
    "fileName": "document.pdf",
    "contentType": "application/pdf",
    "taskId": 1
  }'
```

**Delete Task File:**
```bash
curl -X DELETE https://hk327mcsu7.execute-api.us-east-1.amazonaws.com/prod/files \
  -H "Content-Type: application/json" \
  -d '{
    "fileName": "document.pdf",
    "taskId": 1
  }'
```

### Deployment

**Update API Lambda:**
```bash
cd serverless-file-manager/api
npm install
zip -r ../api-function.zip index.js node_modules/
aws lambda update-function-code --function-name s3-demo-api --zip-file fileb://../api-function.zip
```

**Update File Processor Lambda:**
```bash
cd serverless-file-manager
npm install
zip -r function.zip index.js node_modules/
aws lambda update-function-code --function-name s3-file-processor --zip-file fileb://function.zip
```

---

## Application Deployment

### Backend (Spring Boot)

**Application Location on EC2:** `/home/ec2-user/task-api-1.0.0.jar`

**Start Command:**

```bash
nohup java -jar task-api-1.0.0.jar \
  --spring.datasource.url='jdbc:mysql://springboot-mysql.cevayug0ey5k.us-east-1.rds.amazonaws.com:3306/taskdb?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC' \
  --spring.datasource.username=admin \
  --spring.datasource.password=Admin123! \
  > app.log 2>&1 &
```

**View Logs:**

```bash
tail -f /home/ec2-user/app.log
```

**Stop Application:**

```bash
pkill -f task-api
```

### Frontend (Angular)

**Build Command:**

```bash
cd task-ui
npm run build
```

**Deploy to S3:**

```bash
aws s3 sync dist/task-ui/browser s3://task-ui-app-127246139738 --delete
```

---

## API Endpoints

### Base URL

```
http://44.195.1.174:8080
```

### Task Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/tasks` | Get all tasks |
| GET | `/api/tasks/{id}` | Get task by ID |
| GET | `/api/tasks?status={status}` | Filter tasks by status |
| GET | `/api/tasks?search={query}` | Search tasks by title |
| POST | `/api/tasks` | Create a new task |
| PUT | `/api/tasks/{id}` | Update an existing task |
| DELETE | `/api/tasks/{id}` | Delete a task |

### Task Status Values

- `PENDING`
- `IN_PROGRESS`
- `COMPLETED`

### Sample API Requests

**Create Task:**

```bash
curl -X POST http://44.195.1.174:8080/api/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My New Task",
    "description": "Task description here",
    "status": "PENDING"
  }'
```

**Get All Tasks:**

```bash
curl http://44.195.1.174:8080/api/tasks
```

**Filter by Status:**

```bash
curl "http://44.195.1.174:8080/api/tasks?status=COMPLETED"
```

**Update Task:**

```bash
curl -X PUT http://44.195.1.174:8080/api/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Updated Task",
    "description": "Updated description",
    "status": "COMPLETED"
  }'
```

**Delete Task:**

```bash
curl -X DELETE http://44.195.1.174:8080/api/tasks/1
```

---

## Connection Details

### Quick Reference

> **Note:** Replace these example URLs with your own AWS resource endpoints.

| Component | Example URL/Endpoint | Replace With |
|-----------|---------------------|--------------|
| Task Manager UI (S3) | http://task-ui-app-127246139738.s3-website-us-east-1.amazonaws.com | `http://<YOUR-BUCKET-NAME>.s3-website-<REGION>.amazonaws.com` |
| Task API (EC2) | http://44.195.1.174:8080/api/tasks | `http://<YOUR-EC2-PUBLIC-IP>:8080/api/tasks` |
| File API (Lambda) | https://hk327mcsu7.execute-api.us-east-1.amazonaws.com/prod | `https://<YOUR-API-ID>.execute-api.<REGION>.amazonaws.com/prod` |
| File Manager UI (S3) | http://lambda-s3-demo-ui-127246139738.s3-website-us-east-1.amazonaws.com | `http://<YOUR-UI-BUCKET>.s3-website-<REGION>.amazonaws.com` |
| EC2 SSH | `ssh -i springboot-key.pem ec2-user@44.195.1.174` | `ssh -i <YOUR-KEY>.pem ec2-user@<YOUR-EC2-IP>` |
| RDS Endpoint | `springboot-mysql.cevayug0ey5k.us-east-1.rds.amazonaws.com:3306` | `<YOUR-RDS-IDENTIFIER>.<ID>.<REGION>.rds.amazonaws.com:3306` |

### Database Connection (from EC2)

```bash
mysql -h springboot-mysql.cevayug0ey5k.us-east-1.rds.amazonaws.com -u admin -p taskdb
```

---

## Troubleshooting

### Common Issues

#### 1. CORS Errors

If the Angular app shows "Failed to load tasks", ensure the Spring Boot API has CORS configured:

```java
@RestController
@RequestMapping("/api/tasks")
@CrossOrigin(origins = "*")
public class TaskController {
    // ...
}
```

#### 2. EC2 Instance Not Visible in Console

Ensure you're viewing the correct region: **US East (N. Virginia) us-east-1**

#### 3. Cannot Connect to RDS

- Verify security group allows traffic from EC2 security group
- Check RDS is in "available" status
- Verify credentials are correct

#### 4. Application Not Starting on EC2

Check logs:

```bash
ssh -i springboot-key.pem ec2-user@44.195.1.174 "tail -100 app.log"
```

#### 5. S3 Website Not Accessible

- Verify bucket policy allows public read
- Ensure public access block is disabled
- Check index.html exists in bucket

### Useful Commands

**Check EC2 Instance Status:**

```bash
aws ec2 describe-instances --instance-ids i-07de93ccfe9e3e8b6 \
  --query 'Reservations[0].Instances[0].[State.Name,PublicIpAddress]'
```

**Check RDS Status:**

```bash
aws rds describe-db-instances --db-instance-identifier springboot-mysql \
  --query 'DBInstances[0].[DBInstanceStatus,Endpoint.Address]'
```

**List S3 Bucket Contents:**

```bash
aws s3 ls s3://task-ui-app-127246139738
```

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

> **Warning:** Remember to stop/terminate resources when not in use to avoid charges.

---

## Cleanup Instructions

To delete all resources and avoid ongoing charges:

```bash
# Delete S3 buckets
aws s3 rb s3://task-ui-app-127246139738 --force
aws s3 rb s3://lambda-s3-demo-bucket-127246139738 --force
aws s3 rb s3://lambda-s3-demo-ui-127246139738 --force

# Terminate EC2 instance
aws ec2 terminate-instances --instance-ids i-07de93ccfe9e3e8b6

# Delete RDS instance
aws rds delete-db-instance --db-instance-identifier springboot-mysql --skip-final-snapshot

# Delete DB subnet group (after RDS is deleted)
aws rds delete-db-subnet-group --db-subnet-group-name springboot-db-subnet

# Delete Lambda functions
aws lambda delete-function --function-name s3-demo-api
aws lambda delete-function --function-name s3-file-processor

# Delete API Gateway
aws apigateway delete-rest-api --rest-api-id hk327mcsu7

# Delete IAM role (detach policies first)
aws iam detach-role-policy --role-name lambda-s3-execution-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam detach-role-policy --role-name lambda-s3-execution-role --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
aws iam detach-role-policy --role-name lambda-s3-execution-role --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsReadOnlyAccess
aws iam delete-role --role-name lambda-s3-execution-role

# Delete security groups (after EC2 and RDS are deleted)
aws ec2 delete-security-group --group-id sg-009ce5d8b6c50e11d
aws ec2 delete-security-group --group-id sg-05a2d410a297dd07d

# Delete key pair
aws ec2 delete-key-pair --key-name springboot-key
```

---

## Document Information

| Property | Value |
|----------|-------|
| Created | March 3, 2026 |
| Updated | March 3, 2026 |
| Author | Claude Code Assistant |
| Version | 1.1 |

### Changelog

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
