# Task Management Application - AWS Deployment

A full-stack Task Management application deployed on AWS infrastructure.

## Architecture

- **Frontend**: Angular 17 hosted on Amazon S3
- **Backend**: Spring Boot 3.2 REST API on Amazon EC2
- **Database**: MySQL 8.0 on Amazon RDS

## Project Structure

```
tasks-aws/
├── task-api/                    # Spring Boot REST API
│   ├── src/main/java/
│   │   └── com/example/taskapi/
│   │       ├── controller/      # REST Controllers
│   │       ├── entity/          # JPA Entities
│   │       ├── repository/      # Data Repositories
│   │       ├── service/         # Business Logic
│   │       └── config/          # CORS Configuration
│   └── pom.xml
├── task-ui/                     # Angular Frontend
│   ├── src/app/
│   │   ├── components/          # UI Components
│   │   ├── models/              # TypeScript Models
│   │   └── services/            # HTTP Services
│   └── package.json
├── AWS_SETUP_DOCUMENTATION.md   # Complete AWS setup guide
├── userdata.sh                  # EC2 bootstrap script
└── README.md
```

## Live URLs

| Component | URL |
|-----------|-----|
| Frontend | http://task-ui-app-127246139738.s3-website-us-east-1.amazonaws.com |
| Backend API | http://44.195.1.174:8080/api/tasks |

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/tasks` | Get all tasks |
| GET | `/api/tasks/{id}` | Get task by ID |
| GET | `/api/tasks?status={status}` | Filter by status |
| POST | `/api/tasks` | Create task |
| PUT | `/api/tasks/{id}` | Update task |
| DELETE | `/api/tasks/{id}` | Delete task |

## Local Development

### Backend (Spring Boot)

```bash
cd task-api
mvn clean package
java -jar target/task-api-1.0.0.jar
```

### Frontend (Angular)

```bash
cd task-ui
npm install
ng serve
```

## Deployment

### Deploy Backend to EC2

```bash
cd task-api
mvn clean package -DskipTests
scp -i springboot-key.pem target/task-api-1.0.0.jar ec2-user@44.195.1.174:~/
```

### Deploy Frontend to S3

```bash
cd task-ui
npm run build
aws s3 sync dist/task-ui/browser s3://task-ui-app-127246139738 --delete
```

## AWS Resources

See [AWS_SETUP_DOCUMENTATION.md](./AWS_SETUP_DOCUMENTATION.md) for complete infrastructure details.

## Technologies

- Java 17
- Spring Boot 3.2
- Angular 17
- MySQL 8.0
- AWS EC2, RDS, S3
