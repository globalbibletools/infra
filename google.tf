resource "google_project_service" "iam_credentials" {
  service = "iamcredentials.googleapis.com"
}
resource "google_project_service" "iam" {
  service = "iam.googleapis.com"
}
resource "google_project_service" "cloud_resource_manager" {
  service = "cloudresourcemanager.googleapis.com"
}
resource "google_project_service" "service_usage" {
  service = "serviceusage.googleapis.com"
}

# Creates Google service role that can be assumed by Terraform Cloud
resource "google_iam_workload_identity_pool" "tfc_pool" {
  workload_identity_pool_id = "my-tfc-pool"
}

resource "google_iam_workload_identity_pool_provider" "tfc_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.tfc_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "my-tfc-provider-id"

  display_name = "my-tfc-provider-id"

  attribute_mapping = {
    "google.subject"                        = "assertion.sub",
    "attribute.aud"                         = "assertion.aud",
    "attribute.terraform_run_phase"         = "assertion.terraform_run_phase",
    "attribute.terraform_project_id"        = "assertion.terraform_project_id",
    "attribute.terraform_project_name"      = "assertion.terraform_project_name",
    "attribute.terraform_workspace_id"      = "assertion.terraform_workspace_id",
    "attribute.terraform_workspace_name"    = "assertion.terraform_workspace_name",
    "attribute.terraform_organization_id"   = "assertion.terraform_organization_id",
    "attribute.terraform_organization_name" = "assertion.terraform_organization_name",
    "attribute.terraform_run_id"            = "assertion.terraform_run_id",
    "attribute.terraform_full_workspace"    = "assertion.terraform_full_workspace",
  }
  oidc {
    issuer_uri = "https://app.terraform.io"
  }
  attribute_condition = "assertion.sub.startsWith(\"organization:global-bible-tools:project:platform:workspace:production\")"
}
resource "google_service_account" "tfc_service_account" {
  account_id   = "tfc-service-account"
  display_name = "Terraform Cloud Service Account"
}
resource "google_service_account_iam_member" "tfc_service_account_member" {
  service_account_id = google_service_account.tfc_service_account.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.tfc_pool.name}/*"
}

# Policy for what GCP terraform role has access to
# TODO: replace with narrow policy
resource "google_project_iam_member" "tfc_project_member" {
  project = var.google_project
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.tfc_service_account.email}"
}

import {
  id = "${var.google_project}/iamcredentials.googleapis.com"
  to = google_project_service.iam_credentials
}
import {
  id = "${var.google_project}/iam.googleapis.com"
  to = google_project_service.iam
}
import {
  id = "${var.google_project}/cloudresourcemanager.googleapis.com"
  to = google_project_service.cloud_resource_manager
}
import {
  id = "${var.google_project}/serviceusage.googleapis.com"
  to = google_project_service.service_usage
}
import {
    to = google_iam_workload_identity_pool.tfc_pool
    id = "projects/${var.google_project}/locations/global/workloadIdentityPools/my-tfc-pool"
}
import {
  id = "projects/${var.google_project}/locations/global/workloadIdentityPools/my-tfc-pool/providers/my-tfc-provider-id"
  to = google_iam_workload_identity_pool_provider.tfc_provider
}
import {
  id = "projects/${var.google_project}/serviceAccounts/tfc-service-account@global-bible-too-1694742039480.iam.gserviceaccount.com"
  to = google_service_account.tfc_service_account
}
import {
  id = "projects/${var.google_project}/serviceAccounts/tfc-service-account@global-bible-too-1694742039480.iam.gserviceaccount.com roles/iam.workloadIdentityUser principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.tfc_pool.name}/*"
  to = google_service_account_iam_member.tfc_service_account_member
}
import {
  id = "${var.google_project} roles/owner serviceAccount:${google_service_account.tfc_service_account.email}"
  to = google_project_iam_member.tfc_project_member
}
