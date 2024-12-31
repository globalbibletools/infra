variable "github_token" {
  type = string
  sensitive = true
}

variable "db_master_password" {
  type      = string
  sensitive = true
}

variable "db_master_username" {
  type    = string
  default = "postgres"
}

variable "db_app_password" {
  type      = string
  sensitive = true
}

variable "db_app_username" {
  type    = string
  default = "app"
}

variable "db_identifier" {
    type = string
    default = "prod"
}
