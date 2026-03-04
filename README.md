# Task Management Application

A full-stack Task Management application with support for both **local development** and **AWS production deployment**.

## Quick Start

### Local Development (No AWS Required)

```bash
# Terminal 1 - Backend (must use local profile!)
cd task-api
mvn spring-boot:run -Dspring-boot.run.profiles=local

# Terminal 2 - Frontend
cd task-ui
npm install
npm start
```

Open http://localhost:4200

### AWS Production

See [AWS Deployment](#aws-deployment) section below.

---

## Architecture

### Local Development
```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   Angular App    │────▶│   Spring Boot    │────▶│   H2 Database    │
│   localhost:4200 │     │   localhost:8080 │     │   (In-Memory)    │
└──────────────────┘     └────────┬─────────┘     └──────────────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │  Local Uploads   │
                         │   ./uploads/     │
                         └──────────────────┘
```

### AWS Production
```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   S3 Bucket      │────▶│   EC2 Instance   │────▶│   RDS MySQL      │
│   (Angular App)  │     │   (Spring Boot)  │     │   (Database)     │
└──────────────────┘     └──────────────────┘     └──────────────────┘

┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   API Gateway    │────▶│     Lambda       │────▶│   S3 Bucket      │
│   (File API)     │     │   (File Handler) │     │   (File Storage) │
└──────────────────┘     └──────────────────┘     └──────────────────┘
```

---

## Project Structure

```
tasks-aws/
├── task-api/                        # Spring Boot REST API
│   ├── src/main/java/.../
│   │   ├── controller/
│   │   │   ├── TaskController.java  # Task CRUD endpoints
│   │   │   └── FileController.java  # Local file endpoints (local profile only)
│   │   ├── entity/Task.java         # JPA Entity
│   │   ├── repository/              # Data Repositories
│   │   ├── service/
│   │   │   ├── TaskService.java     # Business logic
│   │   │   └── FileStorageService.java  # Local file storage (local profile only)
│   │   └── config/CorsConfig.java
│   └── src/main/resources/
│       ├── application.properties        # Production config (MySQL)
│       └── application-local.properties  # Local config (H2 + local files)
│
├── task-ui/                         # Angular 17 Frontend
│   ├── src/app/
│   │   ├── components/              # UI Components
│   │   ├── models/                  # TypeScript Models
│   │   └── services/
│   │       ├── task.service.ts      # Task API service
│   │       └── file.service.ts      # File API service (supports both modes)
│   ├── src/environments/
│   │   ├── environment.ts           # Default (local) config
│   │   ├── environment.local.ts     # Local config
│   │   └── environment.prod.ts      # AWS production config
│   └── proxy.conf.json              # Dev server proxy config
│
├── serverless-file-manager/         # AWS Lambda File Management
│   ├── api/                         # REST API Lambda
│   └── index.js                     # S3 Trigger Lambda
│
├── terraform/                       # Infrastructure as Code
│   ├── main.tf                      # Provider configuration
│   ├── variables.tf                 # Input variables
│   ├── ec2.tf                       # EC2 instance
│   ├── rds.tf                       # RDS MySQL
│   ├── s3.tf                        # S3 buckets
│   ├── lambda.tf                    # Lambda functions
│   ├── api-gateway.tf               # API Gateway
│   └── outputs.tf                   # Output values
│
├── AWS_SETUP_DOCUMENTATION.md       # Manual AWS setup guide
└── README.md                        # This file
```

---

## Local Development

Run the entire application locally without any AWS dependencies.

### Prerequisites

```bash
# Required tools
java -version      # Java 17+
mvn -version       # Maven 3.6+
node -version      # Node.js 18+
npm -version       # npm 9+
```

### Backend Setup

> **IMPORTANT:** You MUST run with the `local` profile for file uploads to work!

```bash
cd task-api

# Run with local profile (REQUIRED for file uploads)
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

**Verify the local profile is active.** You should see this in the console:
```
The following 1 profile is active: "local"
...
File storage initialized at: /path/to/your/project/uploads
```

If you don't see `"local"` profile active, file uploads will return **404 Not Found**.

**Local Backend Features:**
- **H2 In-Memory Database** - Data resets on restart
- **H2 Console** - http://localhost:8080/h2-console
  - JDBC URL: `jdbc:h2:mem:taskdb`
  - Username: `sa`
  - Password: *(empty)*
- **Local File Storage** - Files saved to `./uploads/tasks/{taskId}/`
- **File API** - Available at `/api/files` (only with `local` profile)

### Frontend Setup

```bash
cd task-ui
npm install

# Run with proxy to backend
npm start
```

Access the app at: **http://localhost:4200**

> **Note:** The frontend uses a proxy configuration to forward `/api` requests to `http://localhost:8080`. This avoids CORS issues.

### Local API Endpoints

#### Task API (http://localhost:8080)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/tasks` | Get all tasks |
| GET | `/api/tasks/{id}` | Get task by ID |
| GET | `/api/tasks?status={status}` | Filter by status |
| POST | `/api/tasks` | Create task |
| PUT | `/api/tasks/{id}` | Update task |
| DELETE | `/api/tasks/{id}` | Delete task |

#### File API (Local Mode - http://localhost:8080)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/files?taskId={id}` | List files for a task |
| POST | `/api/files/upload?taskId={id}` | Upload file (multipart/form-data) |
| GET | `/api/files/download?taskId={id}&fileName={name}` | Download file |
| DELETE | `/api/files` | Delete file (body: `{taskId, fileName}`) |

### Quick Test (Local)

```bash
# Create a task
curl -X POST http://localhost:8080/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Task", "description": "My first task", "status": "PENDING"}'

# Get all tasks
curl http://localhost:8080/api/tasks

# Upload a file to task 1
curl -X POST "http://localhost:8080/api/files/upload?taskId=1" \
  -F "file=@/path/to/your/file.txt"

# List files for task 1
curl "http://localhost:8080/api/files?taskId=1"
```

---

## AWS Deployment

### Option 1: Terraform (Recommended)

Use Terraform to create and destroy all AWS resources with a single command.

```bash
cd terraform

# Create terraform.tfvars from example
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and set db_password

# Create all resources
terraform init
terraform apply

# When done - DESTROY ALL RESOURCES to stop billing
terraform destroy
```

See **[terraform/README.md](./terraform/README.md)** for detailed instructions.

### Option 2: Manual Setup

For manual AWS Console/CLI setup:
- AWS Account with configured CLI (`aws configure`)
- Required IAM permissions (EC2, RDS, S3, Lambda, API Gateway)

See **[AWS_SETUP_DOCUMENTATION.md](./AWS_SETUP_DOCUMENTATION.md)** for complete step-by-step instructions.

### Quick Deploy

#### 1. Deploy Backend to EC2

```bash
cd task-api
mvn clean package -DskipTests
scp -i springboot-key.pem target/task-api-1.0.0.jar ec2-user@<EC2-IP>:~/

# On EC2:
nohup java -jar task-api-1.0.0.jar \
  --spring.datasource.url='jdbc:mysql://<RDS-ENDPOINT>:3306/taskdb?useSSL=false&allowPublicKeyRetrieval=true' \
  --spring.datasource.username=admin \
  --spring.datasource.password=<PASSWORD> \
  > app.log 2>&1 &
```

#### 2. Deploy Frontend to S3

```bash
cd task-ui
npm install
npm run build
aws s3 sync dist/task-ui/browser s3://<BUCKET-NAME> --delete
```

### AWS API Endpoints

#### Task API (EC2)

```
http://<EC2-PUBLIC-IP>:8080/api/tasks
```

#### File API (Lambda + API Gateway)

```
https://<API-GATEWAY-ID>.execute-api.us-east-1.amazonaws.com/prod
```

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/files?taskId={id}` | List files for a task |
| POST | `/upload` | Get presigned URL for S3 upload |
| DELETE | `/files` | Delete a file |
| GET | `/logs` | Get Lambda processing logs |

---

## Configuration Files

### Backend Profiles

| Profile | Config File | Database | File Storage |
|---------|-------------|----------|--------------|
| **default** (production) | `application.properties` | MySQL (RDS) | S3 (via Lambda) |
| **local** | `application-local.properties` | H2 (in-memory) | Local filesystem |

### Frontend Environments

| Environment | Config File | API URL | File API URL |
|-------------|-------------|---------|--------------|
| **default** (local dev) | `environment.ts` | `/api` (via proxy) | `/api/files` (via proxy) |
| **local** | `environment.local.ts` | `/api` (via proxy) | `/api/files` (via proxy) |
| **production** (AWS) | `environment.prod.ts` | EC2 endpoint | API Gateway |

> **Note:** Local environments use relative URLs (`/api`) which are proxied to `http://localhost:8080` by the Angular dev server.

### NPM Scripts (task-ui)

| Script | Command | Description |
|--------|---------|-------------|
| `npm start` | `ng serve --proxy-config proxy.conf.json` | Run with proxy to backend |
| `npm run start:local` | `ng serve --configuration local --proxy-config proxy.conf.json` | Run with local config + proxy |
| `npm run build` | `ng build` | Build for AWS production |
| `npm run build:local` | `ng build --configuration local` | Build for local |

> **Note:** The proxy forwards `/api` requests from Angular (port 4200) to Spring Boot (port 8080).

### Maven Commands (task-api)

| Command | Description |
|---------|-------------|
| `mvn spring-boot:run` | Run with production profile (MySQL) |
| `mvn spring-boot:run -Dspring-boot.run.profiles=local` | Run with local profile (H2) |
| `mvn clean package` | Build JAR for deployment |
| `mvn clean package -DskipTests` | Build JAR, skip tests |

---

## Features

- **Task Management**: Create, read, update, delete tasks
- **Status Filtering**: Filter tasks by PENDING, IN_PROGRESS, COMPLETED
- **Search**: Search tasks by title
- **File Attachments**: Attach files to individual tasks
  - Local: Stored in `./uploads/tasks/{taskId}/`
  - AWS: Stored in S3 under `tasks/{taskId}/`
- **Responsive UI**: Modern Angular 17 interface

---

## Technologies

| Layer | Local | Production (AWS) |
|-------|-------|------------------|
| **Frontend** | Angular 17 | Angular 17 on S3 |
| **Backend** | Spring Boot 3.2 | Spring Boot 3.2 on EC2 |
| **Database** | H2 (in-memory) | MySQL 8.0 on RDS |
| **File Storage** | Local filesystem | S3 + Lambda |
| **File API** | Spring Boot REST | Lambda + API Gateway |

---

## Troubleshooting

### Local Development Issues

| Issue | Solution |
|-------|----------|
| **File upload returns 404** | Backend not running with `local` profile. Run: `mvn spring-boot:run -Dspring-boot.run.profiles=local` |
| Port 8080 in use | Kill existing process or change `server.port` in properties |
| H2 console not loading | Ensure profile is `local` |
| Files not uploading (permission) | Check `./uploads` folder permissions |
| CORS errors | Use `npm start` which includes proxy config |

### Windows-Specific Issues

#### PEM File Permission Denied

When using SSH/SCP on Windows, you may get "permission denied" errors with PEM files.

**Fix permissions in PowerShell (Run as Administrator):**
```powershell
$pemFile = "terraform\task-app-key.pem"
icacls $pemFile /inheritance:r
icacls $pemFile /grant:r "$($env:USERNAME):(R)"
```

**Alternative: Use S3 to transfer files:**
```powershell
# Upload to S3
aws s3 cp task-api\target\task-api-1.0.0.jar s3://<YOUR-BUCKET>/

# On EC2, download from S3
aws s3 cp s3://<YOUR-BUCKET>/task-api-1.0.0.jar ~/app/
```

#### SCP Path Issues on Windows

Use forward slashes or escape backslashes:
```powershell
# Correct
scp -i terraform/task-app-key.pem file.jar ec2-user@IP:~/

# Also correct
scp -i terraform\task-app-key.pem file.jar ec2-user@IP:~/
```

#### File Upload 404 Error

If you see this error in browser console:
```
POST http://localhost:8080/api/files/upload?taskId=2 404 (Not Found)
```

**Cause:** The `FileController` and `FileStorageService` are only loaded when running with the `local` Spring profile.

**Solution:**
```bash
# Make sure to include -Dspring-boot.run.profiles=local
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

Verify by checking the startup logs for:
```
The following 1 profile is active: "local"
```

### AWS Issues

| Issue | Solution |
|-------|----------|
| Cannot connect to RDS | Check security group allows EC2 → RDS on port 3306 |
| API returns 403 | Check S3 bucket policy and CORS configuration |
| File upload fails | Verify Lambda has S3 permissions |

See **[AWS_SETUP_DOCUMENTATION.md](./AWS_SETUP_DOCUMENTATION.md)** for detailed troubleshooting.

---

## License

MIT
