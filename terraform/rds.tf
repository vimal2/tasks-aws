# RDS MySQL Database

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# RDS MySQL Instance
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-mysql"

  # Engine
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = var.db_instance_class
  parameter_group_name = "default.mysql8.0"

  # Storage
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = 0  # Disable autoscaling for free tier
  storage_type          = "gp2"

  # Database
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 3306

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = true

  # Backup & Maintenance
  backup_retention_period = 0  # Disable backups for free tier
  skip_final_snapshot     = true
  deletion_protection     = false

  # Performance Insights (disabled for free tier)
  performance_insights_enabled = false

  tags = {
    Name = "${var.project_name}-mysql"
  }
}
