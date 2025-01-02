resource "google_project_service" "cloud_translation" {
  service = "translate.googleapis.com"
}

# Service user for translate requests
resource "google_service_account" "default" {
  account_id   = "api-prod"
  display_name = "API Server"
  description  = "Enables API server to use Google Translate"
}
resource "google_service_account_key" "default" {
  service_account_id = google_service_account.default.name
}
data "google_project" "project" {
}
resource "google_project_iam_member" "project" {
  project = data.google_project.project.id
  role    = "roles/cloudtranslate.user"
  member  = google_service_account.default.member
}

import {
  id = "${var.google_project}/translate.googleapis.com"
  to = google_project_service.cloud_translation
}
import {
  id = "projects/${var.google_project}/serviceAccounts/api-prod@global-bible-too-1694742039480.iam.gserviceaccount.com"
  to = google_service_account.default
}
import {
  id = "${var.google_project} roles/cloudtranslate.user serviceAccount:${google_service_account.default.email}"
  to = google_project_iam_member.project
}
