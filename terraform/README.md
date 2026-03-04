# Terraform Infrastructure

This directory contains Terraform configuration to provision and destroy all AWS resources for the Task Management Application.

## Resources Created

| Resource | Description | Free Tier |
|----------|-------------|-----------|
| EC2 Instance | Spring Boot API server (t2.micro) | Yes |
| Elastic IP | Static IP for EC2 | Yes (when attached) |
| RDS MySQL | Database (db.t3.micro) | Yes |
| S3 Bucket (Frontend) | Static website hosting | Yes |
| S3 Bucket (Files) | File storage for attachments | Yes |
| Lambda Function | File API handler | Yes |
| API Gateway | REST API for Lambda | Yes |
| Security Groups | EC2 and RDS security | Yes |
| IAM Role | Lambda execution role | Yes |
| CloudWatch Logs | API Gateway logging | Yes |

## Prerequisites

1. **AWS CLI** configured with your credentials:
   ```bash
   aws configure
   ```

2. **Terraform** installed (v1.0.0 or higher):
   ```bash
   # macOS
   brew install terraform

   # Windows (with chocolatey)
   choco install terraform

   # Verify installation
   terraform version
   ```

## Quick Start

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Create Variables File

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set your database password:
```hcl
db_password = "YourStrongPassword123!"
```

### 3. Preview Changes

```bash
terraform plan
```

### 4. Create All Resources

```bash
terraform apply
```

Type `yes` when prompted. This will take 5-10 minutes (RDS is slow to create).

### 5. Deploy Application (Automated - Mac/Linux)

Use the deploy script to automatically build and deploy everything:

```bash
cd ..
./scripts/deploy-aws.sh
```

This script will:
- Build the Spring Boot JAR
- Deploy JAR to EC2
- Start the backend service
- Update Angular environment with new URLs
- Build Angular app
- Deploy frontend to S3

### 5. Deploy Application (Windows)

#### Fix PEM File Permissions (Required on Windows)

Windows requires special permission handling for PEM files:

```powershell
# Run in PowerShell as Administrator
$pemFile = "task-app-key.pem"
icacls $pemFile /inheritance:r
icacls $pemFile /grant:r "$($env:USERNAME):(R)"
```

#### Deploy to EC2 (Windows)

```powershell
# Build backend
cd ..\task-api
mvn clean package -DskipTests

# Copy to EC2 (use forward slashes or escape backslashes)
scp -i ..\terraform\task-app-key.pem -o StrictHostKeyChecking=no target/task-api-1.0.0.jar ec2-user@<EC2_IP>:~/app/

# SSH to EC2
ssh -i ..\terraform\task-app-key.pem ec2-user@<EC2_IP>
```

#### Alternative: Use S3 to Transfer Files (No SSH permissions needed)

```powershell
# Upload JAR to S3
aws s3 cp task-api\target\task-api-1.0.0.jar s3://<FILES_BUCKET>/

# SSH to EC2, then download from S3
aws s3 cp s3://<FILES_BUCKET>/task-api-1.0.0.jar ~/app/
```

### 5. Deploy Application (Manual - Mac/Linux)

If you prefer to deploy manually:

```bash
# Build and deploy backend
cd ../task-api
mvn clean package -DskipTests
scp -i ../terraform/task-app-key.pem target/task-api-1.0.0.jar ec2-user@<EC2_IP>:~/app/task-api.jar

# SSH to EC2 and start the application
ssh -i ../terraform/task-app-key.pem ec2-user@<EC2_IP>
cd ~/app
export RDS_ENDPOINT=<RDS_HOSTNAME>
export DB_USERNAME=admin
export DB_PASSWORD=<YOUR_PASSWORD>
nohup java -jar task-api.jar > app.log 2>&1 &

# Deploy frontend
cd ../task-ui
# Update src/environments/environment.prod.ts with Terraform outputs
npm run build
aws s3 sync dist/task-ui/browser s3://<FRONTEND_BUCKET> --delete
```

## Destroy All Resources (Stop Billing)

**IMPORTANT:** Run this when you're done to avoid AWS charges!

```bash
terraform destroy
```

Type `yes` when prompted. This will delete ALL resources.

## Cost Considerations

All resources are configured for AWS Free Tier eligibility:

| Resource | Free Tier Limit |
|----------|-----------------|
| EC2 (t2.micro) | 750 hours/month |
| RDS (db.t3.micro) | 750 hours/month |
| S3 | 5 GB storage |
| Lambda | 1M requests/month |
| API Gateway | 1M calls/month |

**To avoid charges:**
- Run `terraform destroy` when not using the application
- Or stop the EC2 instance and RDS instance manually

## File Structure

```
terraform/
├── main.tf              # Provider and backend configuration
├── variables.tf         # Input variables
├── vpc.tf               # VPC and networking (uses default VPC)
├── security-groups.tf   # EC2 and RDS security groups
├── rds.tf               # RDS MySQL instance
├── ec2.tf               # EC2 instance with Elastic IP
├── s3.tf                # S3 buckets for frontend and files
├── lambda.tf            # Lambda function and IAM
├── api-gateway.tf       # API Gateway configuration
├── outputs.tf           # Output values
├── terraform.tfvars.example  # Example variables (copy to terraform.tfvars)
└── README.md            # This file
```

## Outputs

After `terraform apply`, you'll see useful outputs:

| Output | Description |
|--------|-------------|
| `ec2_public_ip` | EC2 public IP address |
| `ssh_command` | Command to SSH into EC2 |
| `rds_endpoint` | RDS MySQL endpoint |
| `frontend_url` | S3 website URL |
| `api_gateway_url` | API Gateway URL |
| `deploy_backend_command` | Command to deploy JAR to EC2 |
| `deploy_frontend_command` | Command to deploy frontend to S3 |
| `angular_environment_config` | Angular environment.prod.ts content |

View outputs anytime with:
```bash
terraform output
```

## Common Commands

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply

# Destroy all resources
terraform destroy

# View outputs
terraform output

# View specific output
terraform output ec2_public_ip

# Refresh state
terraform refresh

# Format files
terraform fmt
```

## Troubleshooting

### "Error creating DB Instance: DBSubnetGroupNotFoundFault"
The default VPC subnets need to be in the subnet group. This is handled automatically.

### "Error: creating EC2 Instance: InvalidKeyPair.NotFound"
Leave `ec2_key_name` empty in terraform.tfvars to create a new key pair.

### Lambda deployment fails
Make sure the `serverless-file-manager/api/` directory exists with `index.js`.

### RDS takes too long
RDS creation typically takes 5-10 minutes. Be patient.

## Security Notes

1. **terraform.tfvars** - Contains secrets. Added to .gitignore automatically.
2. **Key pair** - The generated .pem file should be kept secure.
3. **RDS public access** - Enabled for development. Disable in production.
4. **Security groups** - Allow all IPs for development. Restrict in production.
