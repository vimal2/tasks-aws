# EC2 Instance for Spring Boot API

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create key pair if not provided
resource "tls_private_key" "ec2" {
  count     = var.ec2_key_name == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2" {
  count      = var.ec2_key_name == "" ? 1 : 0
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ec2[0].public_key_openssh
}

# Save private key locally
resource "local_file" "private_key" {
  count           = var.ec2_key_name == "" ? 1 : 0
  content         = tls_private_key.ec2[0].private_key_pem
  filename        = "${path.module}/${var.project_name}-key.pem"
  file_permission = "0400"
}

# EC2 Instance
resource "aws_instance" "api" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.ec2_instance_type
  key_name      = var.ec2_key_name != "" ? var.ec2_key_name : aws_key_pair.ec2[0].key_name

  vpc_security_group_ids = [aws_security_group.ec2.id]

  # User data script to install Java
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y java-17-amazon-corretto-devel
    yum install -y mysql

    # Create app directory
    mkdir -p /home/ec2-user/app
    chown ec2-user:ec2-user /home/ec2-user/app

    # Create systemd service for Spring Boot
    cat > /etc/systemd/system/taskapi.service << 'SERVICEEOF'
    [Unit]
    Description=Task API Spring Boot Application
    After=network.target

    [Service]
    User=ec2-user
    WorkingDirectory=/home/ec2-user/app
    ExecStart=/usr/bin/java -jar /home/ec2-user/app/task-api.jar
    SuccessExitStatus=143
    Restart=always
    RestartSec=10

    [Install]
    WantedBy=multi-user.target
    SERVICEEOF

    systemctl daemon-reload
  EOF

  root_block_device {
    volume_size = 30  # Amazon Linux 2023 requires minimum 30GB
    volume_type = "gp2"
  }

  tags = {
    Name = "${var.project_name}-api-server"
  }
}

# Elastic IP for consistent public IP
resource "aws_eip" "api" {
  instance = aws_instance.api.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-api-eip"
  }
}
