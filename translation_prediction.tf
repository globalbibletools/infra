resource "google_project_service" "cloud_translation" {
  service = "translate.googleapis.com"
}

data "google_project" "project" {
}
resource "google_project_iam_member" "project" {
  project = data.google_project.project.id
  role    = "roles/cloudtranslate.user"
  member  = google_service_account.default.member
}

