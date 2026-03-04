#!/bin/bash

# AWS Cleanup Script
# Deletes ALL resources created for the Task Management Application
# WARNING: This is destructive and cannot be undone!

set -e

REGION="us-east-1"
PROJECT_PREFIX="task"

echo "=========================================="
echo "   AWS Resource Cleanup Script"
echo "=========================================="
echo ""
echo "WARNING: This will DELETE all resources!"
echo "Region: $REGION"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

# ==========================================
# 1. Delete EC2 Instances
# ==========================================
echo "=== Deleting EC2 Instances ==="
INSTANCE_IDS=$(aws ec2 describe-instances \
    --region $REGION \
    --filters "Name=instance-state-name,Values=running,stopped,pending" \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text)

if [ -n "$INSTANCE_IDS" ]; then
    echo "Found instances: $INSTANCE_IDS"
    for INSTANCE_ID in $INSTANCE_IDS; do
        echo "Terminating instance: $INSTANCE_ID"
        aws ec2 terminate-instances --region $REGION --instance-ids $INSTANCE_ID || true
    done
    echo "Waiting for instances to terminate..."
    aws ec2 wait instance-terminated --region $REGION --instance-ids $INSTANCE_IDS 2>/dev/null || true
else
    echo "No EC2 instances found."
fi

# ==========================================
# 2. Release Elastic IPs
# ==========================================
echo ""
echo "=== Releasing Elastic IPs ==="
EIP_ALLOCS=$(aws ec2 describe-addresses \
    --region $REGION \
    --query 'Addresses[*].AllocationId' \
    --output text)

if [ -n "$EIP_ALLOCS" ]; then
    for ALLOC_ID in $EIP_ALLOCS; do
        echo "Releasing EIP: $ALLOC_ID"
        aws ec2 release-address --region $REGION --allocation-id $ALLOC_ID || true
    done
else
    echo "No Elastic IPs found."
fi

# ==========================================
# 3. Delete RDS Instances
# ==========================================
echo ""
echo "=== Deleting RDS Instances ==="
RDS_INSTANCES=$(aws rds describe-db-instances \
    --region $REGION \
    --query 'DBInstances[*].DBInstanceIdentifier' \
    --output text)

if [ -n "$RDS_INSTANCES" ]; then
    for DB_ID in $RDS_INSTANCES; do
        echo "Deleting RDS instance: $DB_ID"
        aws rds delete-db-instance \
            --region $REGION \
            --db-instance-identifier $DB_ID \
            --skip-final-snapshot \
            --delete-automated-backups || true
    done
    echo "Waiting for RDS instances to be deleted (this may take 5-10 minutes)..."
    for DB_ID in $RDS_INSTANCES; do
        aws rds wait db-instance-deleted --region $REGION --db-instance-identifier $DB_ID 2>/dev/null || true
    done
else
    echo "No RDS instances found."
fi

# ==========================================
# 4. Delete RDS Subnet Groups
# ==========================================
echo ""
echo "=== Deleting RDS Subnet Groups ==="
SUBNET_GROUPS=$(aws rds describe-db-subnet-groups \
    --region $REGION \
    --query 'DBSubnetGroups[*].DBSubnetGroupName' \
    --output text)

if [ -n "$SUBNET_GROUPS" ]; then
    for SG_NAME in $SUBNET_GROUPS; do
        if [ "$SG_NAME" != "default" ]; then
            echo "Deleting subnet group: $SG_NAME"
            aws rds delete-db-subnet-group --region $REGION --db-subnet-group-name $SG_NAME || true
        fi
    done
else
    echo "No custom RDS subnet groups found."
fi

# ==========================================
# 5. Delete S3 Buckets
# ==========================================
echo ""
echo "=== Deleting S3 Buckets ==="
BUCKETS=$(aws s3api list-buckets --query 'Buckets[*].Name' --output text)

if [ -n "$BUCKETS" ]; then
    for BUCKET in $BUCKETS; do
        if [[ "$BUCKET" == *"task"* ]] || [[ "$BUCKET" == *"lambda"* ]]; then
            echo "Emptying bucket: $BUCKET"
            aws s3 rm s3://$BUCKET --recursive || true
            echo "Deleting bucket: $BUCKET"
            aws s3 rb s3://$BUCKET --force || true
        fi
    done
else
    echo "No S3 buckets found."
fi

# ==========================================
# 6. Delete Lambda Functions
# ==========================================
echo ""
echo "=== Deleting Lambda Functions ==="
FUNCTIONS=$(aws lambda list-functions \
    --region $REGION \
    --query 'Functions[*].FunctionName' \
    --output text)

if [ -n "$FUNCTIONS" ]; then
    for FUNC in $FUNCTIONS; do
        echo "Deleting Lambda function: $FUNC"
        aws lambda delete-function --region $REGION --function-name $FUNC || true
    done
else
    echo "No Lambda functions found."
fi

# ==========================================
# 7. Delete API Gateways (HTTP APIs)
# ==========================================
echo ""
echo "=== Deleting API Gateways ==="
API_IDS=$(aws apigatewayv2 get-apis \
    --region $REGION \
    --query 'Items[*].ApiId' \
    --output text 2>/dev/null)

if [ -n "$API_IDS" ]; then
    for API_ID in $API_IDS; do
        echo "Deleting API Gateway: $API_ID"
        aws apigatewayv2 delete-api --region $REGION --api-id $API_ID || true
    done
else
    echo "No API Gateways found."
fi

# Also check REST APIs
REST_API_IDS=$(aws apigateway get-rest-apis \
    --region $REGION \
    --query 'items[*].id' \
    --output text 2>/dev/null)

if [ -n "$REST_API_IDS" ]; then
    for API_ID in $REST_API_IDS; do
        echo "Deleting REST API: $API_ID"
        aws apigateway delete-rest-api --region $REGION --rest-api-id $API_ID || true
    done
fi

# ==========================================
# 8. Delete IAM Roles (Lambda roles)
# ==========================================
echo ""
echo "=== Deleting IAM Roles ==="
ROLES=$(aws iam list-roles \
    --query 'Roles[?contains(RoleName, `lambda`) || contains(RoleName, `task`)].RoleName' \
    --output text)

if [ -n "$ROLES" ]; then
    for ROLE in $ROLES; do
        echo "Processing IAM role: $ROLE"

        # Detach managed policies
        POLICIES=$(aws iam list-attached-role-policies --role-name $ROLE --query 'AttachedPolicies[*].PolicyArn' --output text 2>/dev/null)
        for POLICY in $POLICIES; do
            echo "  Detaching policy: $POLICY"
            aws iam detach-role-policy --role-name $ROLE --policy-arn $POLICY || true
        done

        # Delete inline policies
        INLINE_POLICIES=$(aws iam list-role-policies --role-name $ROLE --query 'PolicyNames[*]' --output text 2>/dev/null)
        for POLICY in $INLINE_POLICIES; do
            echo "  Deleting inline policy: $POLICY"
            aws iam delete-role-policy --role-name $ROLE --policy-name $POLICY || true
        done

        # Delete the role
        echo "  Deleting role: $ROLE"
        aws iam delete-role --role-name $ROLE || true
    done
else
    echo "No matching IAM roles found."
fi

# ==========================================
# 9. Delete Security Groups
# ==========================================
echo ""
echo "=== Deleting Security Groups ==="
SG_IDS=$(aws ec2 describe-security-groups \
    --region $REGION \
    --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
    --output text)

if [ -n "$SG_IDS" ]; then
    for SG_ID in $SG_IDS; do
        echo "Deleting security group: $SG_ID"
        aws ec2 delete-security-group --region $REGION --group-id $SG_ID 2>/dev/null || true
    done
else
    echo "No custom security groups found."
fi

# ==========================================
# 10. Delete Key Pairs
# ==========================================
echo ""
echo "=== Deleting Key Pairs ==="
KEY_NAMES=$(aws ec2 describe-key-pairs \
    --region $REGION \
    --query 'KeyPairs[*].KeyName' \
    --output text)

if [ -n "$KEY_NAMES" ]; then
    for KEY in $KEY_NAMES; do
        if [[ "$KEY" == *"springboot"* ]] || [[ "$KEY" == *"task"* ]]; then
            echo "Deleting key pair: $KEY"
            aws ec2 delete-key-pair --region $REGION --key-name $KEY || true
        fi
    done
else
    echo "No key pairs found."
fi

# ==========================================
# 11. Delete CloudWatch Log Groups
# ==========================================
echo ""
echo "=== Deleting CloudWatch Log Groups ==="
LOG_GROUPS=$(aws logs describe-log-groups \
    --region $REGION \
    --query 'logGroups[*].logGroupName' \
    --output text)

if [ -n "$LOG_GROUPS" ]; then
    for LG in $LOG_GROUPS; do
        if [[ "$LG" == *"task"* ]] || [[ "$LG" == *"lambda"* ]] || [[ "$LG" == *"apigateway"* ]]; then
            echo "Deleting log group: $LG"
            aws logs delete-log-group --region $REGION --log-group-name "$LG" || true
        fi
    done
else
    echo "No matching log groups found."
fi

# ==========================================
# 12. Delete Custom VPCs (NOT default VPC)
# ==========================================
echo ""
echo "=== Checking for Custom VPCs ==="

# Get non-default VPCs
CUSTOM_VPCS=$(aws ec2 describe-vpcs \
    --region $REGION \
    --filters "Name=isDefault,Values=false" \
    --query 'Vpcs[*].VpcId' \
    --output text)

if [ -n "$CUSTOM_VPCS" ]; then
    for VPC_ID in $CUSTOM_VPCS; do
        echo "Processing custom VPC: $VPC_ID"

        # Delete NAT Gateways
        NAT_GWS=$(aws ec2 describe-nat-gateways --region $REGION --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[*].NatGatewayId' --output text 2>/dev/null)
        for NAT in $NAT_GWS; do
            echo "  Deleting NAT Gateway: $NAT"
            aws ec2 delete-nat-gateway --region $REGION --nat-gateway-id $NAT || true
        done

        # Delete Internet Gateways
        IGW_IDS=$(aws ec2 describe-internet-gateways --region $REGION --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[*].InternetGatewayId' --output text)
        for IGW in $IGW_IDS; do
            echo "  Detaching Internet Gateway: $IGW"
            aws ec2 detach-internet-gateway --region $REGION --internet-gateway-id $IGW --vpc-id $VPC_ID || true
            echo "  Deleting Internet Gateway: $IGW"
            aws ec2 delete-internet-gateway --region $REGION --internet-gateway-id $IGW || true
        done

        # Delete Subnets
        SUBNET_IDS=$(aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text)
        for SUBNET in $SUBNET_IDS; do
            echo "  Deleting Subnet: $SUBNET"
            aws ec2 delete-subnet --region $REGION --subnet-id $SUBNET || true
        done

        # Delete Route Tables (except main)
        RT_IDS=$(aws ec2 describe-route-tables --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text)
        for RT in $RT_IDS; do
            echo "  Deleting Route Table: $RT"
            aws ec2 delete-route-table --region $REGION --route-table-id $RT || true
        done

        # Delete Security Groups (except default)
        SG_IDS=$(aws ec2 describe-security-groups --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text)
        for SG in $SG_IDS; do
            echo "  Deleting Security Group: $SG"
            aws ec2 delete-security-group --region $REGION --group-id $SG || true
        done

        # Delete the VPC
        echo "  Deleting VPC: $VPC_ID"
        aws ec2 delete-vpc --region $REGION --vpc-id $VPC_ID || true
    done
else
    echo "No custom VPCs found (default VPC is preserved)."
fi

echo ""
echo "=========================================="
echo "   Cleanup Complete!"
echo "=========================================="
echo ""
echo "Verify no resources remain:"
echo "  aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' --output table"
echo "  aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus]' --output table"
echo "  aws s3 ls"
echo ""
