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

variable "domain" {
    type = string
    default = "globalbibletools.com"
}

variable "smtp_user" {
    type = string
    default = "smtp-user"
}

variable "mail_from_subdomain" {
    type = string
    default = "bounce"
}

variable "ses_sns_topic" {
    type = string
    default = "ses-notifications"
}

variable "bounce_subscription_url" {
    type = string
    default = "https://globalbibletools.com/email/notifications"
}
