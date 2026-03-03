# AWS Infrastructure Setup Documentation

## Project Overview

This document describes the complete AWS infrastructure setup for a full-stack Task Management application consisting of:
- **Frontend**: Angular 17 application hosted on Amazon S3
- **Backend**: Spring Boot 3.2 REST API running on Amazon EC2
- **Database**: MySQL 8.0 on Amazon RDS

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [AWS Account Configuration](#aws-account-configuration)
3. [Network Configuration](#network-configuration)
4. [Security Groups](#security-groups)
5. [RDS MySQL Database](#rds-mysql-database)
6. [EC2 Instance](#ec2-instance)
7. [S3 Static Website Hosting](#s3-static-website-hosting)
8. [Application Deployment](#application-deployment)
9. [API Endpoints](#api-endpoints)
10. [Connection Details](#connection-details)
11. [Troubleshooting](#troubleshooting)

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

| Property | Value |
|----------|-------|
| Account ID | `127246139738` |
| IAM User | `vimal.subha.family1` |
| User ARN | `arn:aws:iam::127246139738:user/vimal.subha.family1` |
| Region | `us-east-1 (N. Virginia)` |

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

**Key File Location:** `/Users/vimalkrishnan/Workspace/revature/2353/review/p2/springboot-key.pem`

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

| Component | URL/Endpoint |
|-----------|--------------|
| Frontend (S3) | http://task-ui-app-127246139738.s3-website-us-east-1.amazonaws.com |
| Backend API | http://44.195.1.174:8080/api/tasks |
| EC2 SSH | `ssh -i springboot-key.pem ec2-user@44.195.1.174` |
| RDS Endpoint | `springboot-mysql.cevayug0ey5k.us-east-1.rds.amazonaws.com:3306` |

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

> **Warning:** Remember to stop/terminate resources when not in use to avoid charges.

---

## Cleanup Instructions

To delete all resources and avoid ongoing charges:

```bash
# Delete S3 bucket
aws s3 rb s3://task-ui-app-127246139738 --force

# Terminate EC2 instance
aws ec2 terminate-instances --instance-ids i-07de93ccfe9e3e8b6

# Delete RDS instance
aws rds delete-db-instance --db-instance-identifier springboot-mysql --skip-final-snapshot

# Delete DB subnet group (after RDS is deleted)
aws rds delete-db-subnet-group --db-subnet-group-name springboot-db-subnet

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
| Author | Claude Code Assistant |
| Version | 1.0 |
