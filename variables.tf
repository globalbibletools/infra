variable "google_domain_verification" {
  type = string
}

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

variable "db_adrian_password" {
  type      = string
  sensitive = true
}

variable "db_adrian_username" {
  type    = string
  default = "adrian"
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

variable "api_user" {
  type        = string
  default     = "app-prod"
}

variable "terraform_organization" {
    type = string
    default = "global-bible-tools"
}

variable "google_project" {
    type = string
}

variable "openai_key" {
    type = string
    sensitive = true
}

variable "fathom_id" {
    type = string
}

variable "analytics_sheet_id" {
    type = string
}

variable "global_bible_systems_api_key" {
    type = string
}
