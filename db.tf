variable "db_master_password" {
  type      = string
  sensitive = true
}

variable "db_master_username" {
  type    = string
  default = "postgres"
}

variable "db_identifier" {
    type = string
    default = "prod"
}

data "aws_rds_engine_version" "postgres" {
  engine = "postgres"
  parameter_group_family = "postgres14"
}

resource "aws_db_parameter_group" "postgres" {
  name = "gbt-platform"
  family = data.aws_rds_engine_version.postgres.parameter_group_family
  description = "Parameters for the Platform Postgres database"

  parameter {
    apply_method = "pending-reboot"
    name         = "cron.database_name"
    value        = "prod"
  }

  parameter {
    apply_method = "pending-reboot"
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements,pg_cron"
  }
}

resource "aws_db_instance" "default" {
  identifier = var.db_identifier
  allocated_storage   = 20
  engine              = "postgres"
  instance_class      = "db.t4g.medium"
  password            = var.db_master_password
  username            = var.db_master_username
  deletion_protection = true
  enabled_cloudwatch_logs_exports = [
    "postgresql"
  ]
  performance_insights_enabled = true
  storage_encrypted = true
  publicly_accessible = true
  skip_final_snapshot = true
  parameter_group_name    = aws_db_parameter_group.postgres.name
  
  depends_on = [aws_cloudwatch_log_group.postgres]
}

resource "aws_cloudwatch_log_group" "postgres" {
  name = "/aws/rds/instance/${var.db_identifier}/postgresql"
}

data "aws_iam_policy_document" "rds_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}
resource "aws_iam_role" "rds" {
  name               = "AWSServiceRoleForRDS"
  assume_role_policy = data.aws_iam_policy_document.rds_assume_role.json
  description = "Allows Amazon RDS to manage AWS resources on your behalf"
  path               = "/aws-service-role/rds.amazonaws.com/"
}

resource "aws_iam_role_policy_attachment" "rds" {
  role       = aws_iam_role.rds.name
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AmazonRDSServiceRolePolicy"
}

