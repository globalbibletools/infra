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

provider "postgresql" {
  host            = aws_db_instance.default.address
  port            = aws_db_instance.default.port
  database        = "postgres"
  username        = var.db_master_username
  password        = var.db_master_password
  sslmode         = "require"
  connect_timeout = 15
  superuser       = false
}

resource "postgresql_database" "prod" {
  name = "prod"
}

resource "postgresql_role" "app" {
  login    = true
  name     = var.db_app_username
  password = var.db_app_password
}

resource "postgresql_grant" "create" {
  database    = postgresql_database.prod.name
  role        = postgresql_role.app.name
  schema      = "public"
  object_type = "database"
  privileges  = ["CREATE"]
}

resource "postgresql_role" "adrian" {
  login    = true
  name     = var.db_adrian_username
  password = var.db_adrian_password
}

resource "postgresql_grant" "create_adrian" {
  database    = postgresql_database.prod.name
  role        = postgresql_role.adrian.name
  schema      = "public"
  object_type = "database"
  privileges  = ["CREATE"]
}

locals {
    database_url = "postgresql://${postgresql_role.app.name}:${postgresql_role.app.password}@${aws_db_instance.default.address}:${aws_db_instance.default.port}/${postgresql_database.prod.name}"
}
