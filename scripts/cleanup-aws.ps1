# AWS Cleanup Script (PowerShell for Windows)
# Deletes ALL resources created for the Task Management Application
# WARNING: This is destructive and cannot be undone!

$ErrorActionPreference = "Continue"
$Region = "us-east-1"

Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "   AWS Resource Cleanup Script" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "WARNING: This will DELETE all resources!" -ForegroundColor Red
Write-Host "Region: $Region"
Write-Host ""

$confirm = Read-Host "Are you sure you want to continue? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Aborted."
    exit 0
}

Write-Host ""
Write-Host "Starting cleanup..."
Write-Host ""

# ==========================================
# 1. Delete EC2 Instances
# ==========================================
Write-Host "=== Deleting EC2 Instances ===" -ForegroundColor Cyan
$instances = aws ec2 describe-instances --region $Region --filters "Name=instance-state-name,Values=running,stopped,pending" --query 'Reservations[*].Instances[*].InstanceId' --output text
if ($instances) {
    foreach ($instanceId in $instances.Split()) {
        if ($instanceId) {
            Write-Host "Terminating instance: $instanceId"
            aws ec2 terminate-instances --region $Region --instance-ids $instanceId 2>$null
        }
    }
    Write-Host "Waiting for instances to terminate..."
    Start-Sleep -Seconds 30
} else {
    Write-Host "No EC2 instances found."
}

# ==========================================
# 2. Release Elastic IPs
# ==========================================
Write-Host ""
Write-Host "=== Releasing Elastic IPs ===" -ForegroundColor Cyan
$eips = aws ec2 describe-addresses --region $Region --query 'Addresses[*].AllocationId' --output text
if ($eips) {
    foreach ($allocId in $eips.Split()) {
        if ($allocId) {
            Write-Host "Releasing EIP: $allocId"
            aws ec2 release-address --region $Region --allocation-id $allocId 2>$null
        }
    }
} else {
    Write-Host "No Elastic IPs found."
}

# ==========================================
# 3. Delete RDS Instances
# ==========================================
Write-Host ""
Write-Host "=== Deleting RDS Instances ===" -ForegroundColor Cyan
$rdsInstances = aws rds describe-db-instances --region $Region --query 'DBInstances[*].DBInstanceIdentifier' --output text
if ($rdsInstances) {
    foreach ($dbId in $rdsInstances.Split()) {
        if ($dbId) {
            Write-Host "Deleting RDS instance: $dbId"
            aws rds delete-db-instance --region $Region --db-instance-identifier $dbId --skip-final-snapshot --delete-automated-backups 2>$null
        }
    }
    Write-Host "Waiting for RDS deletion (this may take 5-10 minutes)..."
    Start-Sleep -Seconds 60
} else {
    Write-Host "No RDS instances found."
}

# ==========================================
# 4. Delete RDS Subnet Groups
# ==========================================
Write-Host ""
Write-Host "=== Deleting RDS Subnet Groups ===" -ForegroundColor Cyan
$subnetGroups = aws rds describe-db-subnet-groups --region $Region --query 'DBSubnetGroups[*].DBSubnetGroupName' --output text
if ($subnetGroups) {
    foreach ($sgName in $subnetGroups.Split()) {
        if ($sgName -and $sgName -ne "default") {
            Write-Host "Deleting subnet group: $sgName"
            aws rds delete-db-subnet-group --region $Region --db-subnet-group-name $sgName 2>$null
        }
    }
} else {
    Write-Host "No custom RDS subnet groups found."
}

# ==========================================
# 5. Delete S3 Buckets
# ==========================================
Write-Host ""
Write-Host "=== Deleting S3 Buckets ===" -ForegroundColor Cyan
$buckets = aws s3api list-buckets --query 'Buckets[*].Name' --output text
if ($buckets) {
    foreach ($bucket in $buckets.Split()) {
        if ($bucket -and ($bucket -like "*task*" -or $bucket -like "*lambda*")) {
            Write-Host "Emptying bucket: $bucket"
            aws s3 rm "s3://$bucket" --recursive 2>$null
            Write-Host "Deleting bucket: $bucket"
            aws s3 rb "s3://$bucket" --force 2>$null
        }
    }
} else {
    Write-Host "No S3 buckets found."
}

# ==========================================
# 6. Delete Lambda Functions
# ==========================================
Write-Host ""
Write-Host "=== Deleting Lambda Functions ===" -ForegroundColor Cyan
$functions = aws lambda list-functions --region $Region --query 'Functions[*].FunctionName' --output text
if ($functions) {
    foreach ($func in $functions.Split()) {
        if ($func) {
            Write-Host "Deleting Lambda function: $func"
            aws lambda delete-function --region $Region --function-name $func 2>$null
        }
    }
} else {
    Write-Host "No Lambda functions found."
}

# ==========================================
# 7. Delete API Gateways
# ==========================================
Write-Host ""
Write-Host "=== Deleting API Gateways ===" -ForegroundColor Cyan
$apis = aws apigatewayv2 get-apis --region $Region --query 'Items[*].ApiId' --output text 2>$null
if ($apis) {
    foreach ($apiId in $apis.Split()) {
        if ($apiId) {
            Write-Host "Deleting API Gateway: $apiId"
            aws apigatewayv2 delete-api --region $Region --api-id $apiId 2>$null
        }
    }
}

$restApis = aws apigateway get-rest-apis --region $Region --query 'items[*].id' --output text 2>$null
if ($restApis) {
    foreach ($apiId in $restApis.Split()) {
        if ($apiId) {
            Write-Host "Deleting REST API: $apiId"
            aws apigateway delete-rest-api --region $Region --rest-api-id $apiId 2>$null
        }
    }
} else {
    Write-Host "No API Gateways found."
}

# ==========================================
# 8. Delete Security Groups
# ==========================================
Write-Host ""
Write-Host "=== Deleting Security Groups ===" -ForegroundColor Cyan
$securityGroups = aws ec2 describe-security-groups --region $Region --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text
if ($securityGroups) {
    foreach ($sgId in $securityGroups.Split()) {
        if ($sgId) {
            Write-Host "Deleting security group: $sgId"
            aws ec2 delete-security-group --region $Region --group-id $sgId 2>$null
        }
    }
} else {
    Write-Host "No custom security groups found."
}

# ==========================================
# 9. Delete Key Pairs
# ==========================================
Write-Host ""
Write-Host "=== Deleting Key Pairs ===" -ForegroundColor Cyan
$keyPairs = aws ec2 describe-key-pairs --region $Region --query 'KeyPairs[*].KeyName' --output text
if ($keyPairs) {
    foreach ($key in $keyPairs.Split()) {
        if ($key -and ($key -like "*springboot*" -or $key -like "*task*")) {
            Write-Host "Deleting key pair: $key"
            aws ec2 delete-key-pair --region $Region --key-name $key 2>$null
        }
    }
} else {
    Write-Host "No key pairs found."
}

# ==========================================
# 10. Delete Custom VPCs (NOT default VPC)
# ==========================================
Write-Host ""
Write-Host "=== Checking for Custom VPCs ===" -ForegroundColor Cyan

$customVpcs = aws ec2 describe-vpcs --region $Region --filters "Name=isDefault,Values=false" --query 'Vpcs[*].VpcId' --output text
if ($customVpcs) {
    foreach ($vpcId in $customVpcs.Split()) {
        if ($vpcId) {
            Write-Host "Processing custom VPC: $vpcId"

            # Delete Internet Gateways
            $igws = aws ec2 describe-internet-gateways --region $Region --filters "Name=attachment.vpc-id,Values=$vpcId" --query 'InternetGateways[*].InternetGatewayId' --output text
            foreach ($igw in $igws.Split()) {
                if ($igw) {
                    Write-Host "  Detaching and deleting Internet Gateway: $igw"
                    aws ec2 detach-internet-gateway --region $Region --internet-gateway-id $igw --vpc-id $vpcId 2>$null
                    aws ec2 delete-internet-gateway --region $Region --internet-gateway-id $igw 2>$null
                }
            }

            # Delete Subnets
            $subnets = aws ec2 describe-subnets --region $Region --filters "Name=vpc-id,Values=$vpcId" --query 'Subnets[*].SubnetId' --output text
            foreach ($subnet in $subnets.Split()) {
                if ($subnet) {
                    Write-Host "  Deleting Subnet: $subnet"
                    aws ec2 delete-subnet --region $Region --subnet-id $subnet 2>$null
                }
            }

            # Delete Route Tables
            $routeTables = aws ec2 describe-route-tables --region $Region --filters "Name=vpc-id,Values=$vpcId" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text
            foreach ($rt in $routeTables.Split()) {
                if ($rt) {
                    Write-Host "  Deleting Route Table: $rt"
                    aws ec2 delete-route-table --region $Region --route-table-id $rt 2>$null
                }
            }

            # Delete the VPC
            Write-Host "  Deleting VPC: $vpcId"
            aws ec2 delete-vpc --region $Region --vpc-id $vpcId 2>$null
        }
    }
} else {
    Write-Host "No custom VPCs found (default VPC is preserved)."
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "   Cleanup Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Verify no resources remain:" -ForegroundColor Yellow
Write-Host "  aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' --output table"
Write-Host "  aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus]' --output table"
Write-Host "  aws s3 ls"
Write-Host ""
