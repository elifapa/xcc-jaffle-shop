terraform {
  backend "gcs" {
    bucket = "xcc-jaffle-shop-tfstate"
    prefix = "env/ci/terraform/state"
  }
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "6.8.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_location
}

data "google_project" "ae_project" {
}

data "google_artifact_registry_docker_image" "my_image" {
  location      = var.gcp_location
  repository_id = var.gcp_artifact_repository_name
  image_name    = "${var.image_name}:${var.image_tag}"
}

locals {
  default_compute_sa_email = "${data.google_project.ae_project.number}-compute@developer.gserviceaccount.com"
}

resource "google_sql_database_instance" "postgres_instance" {
  name             = "jaffle-shop-postgres"
  project          = data.google_project.ae_project.project_id
  region           = var.gcp_location
  database_version = "POSTGRES_17"  # match Postgres 17.0 image version

  settings {
    tier = "db-custom-1-3840"  # machine type
    ip_configuration {
        ipv4_enabled = true # public IP
        ssl_mode = "ENCRYPTED_ONLY"
        dynamic "authorized_networks" {
            for_each = var.authorized_networks
            iterator = authorized_networks
            content {
              name  = authorized_networks.value.name
              value = authorized_networks.value.value
            }
        }
    }
  }
  deletion_protection = false
}

# Create the database
resource "google_sql_database" "database" {
  name     = var.pg_db_name
  instance = google_sql_database_instance.postgres_instance.name
}

# Create the database user
resource "google_sql_user" "user" {
  name     = var.pg_username
  instance = google_sql_database_instance.postgres_instance.name
  password = var.pg_password
}

# Enable IAM Service Account Credentials API in the project
resource "google_project_service" "iamcredentials_api" {
  project = data.google_project.ae_project.project_id
  service = "iamcredentials.googleapis.com"
  disable_on_destroy = false
}

# Enable Cloud SQL Admin API in the project
resource "google_project_service" "cloud_sql_admin" {
  project = data.google_project.ae_project.project_id
  service = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

# Enable Artifact Registry API
resource "google_project_service" "artifact_registry" {
  project = data.google_project.ae_project.project_id
  service = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

# IAM binding for GitHub Service Account to act as Cloud Run's runtime SA
resource "google_service_account_iam_member" "github_sa_service_account_user" {
  service_account_id = "projects/${data.google_project.ae_project.project_id}/serviceAccounts/${local.default_compute_sa_email}"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.gcp_sa_email}"
}

resource "google_cloud_run_v2_job" "dbt_cloudrunjob" {
  name     = "cloudrun-job"
  location = var.gcp_location
  template {
    template{
      volumes {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [google_sql_database_instance.postgres_instance.connection_name]
        }
      }

      containers {
        name = var.gcp_cloud_run_job
        image = data.google_artifact_registry_docker_image.my_image.self_link
        env {
          name  = "PG_HOSTNAME"
          value = "/cloudsql/${google_sql_database_instance.postgres_instance.connection_name}" #unix socket #google_sql_database_instance.postgres_instance.public_ip_address #tcp connection
        }
        env {
          name  = "PG_USERNAME"
          value = var.pg_username
        }
        env {
          name  = "PG_PASSWORD"
          value = var.pg_password
        }
        env {
          name  = "PG_DB_NAME"
          value = var.pg_db_name
        }
        env {
          name  = "GITHUB_PR_SCHEMA"
          value = var.github_pr_schema
        }
        volume_mounts {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }
      }
    }
  }

  deletion_protection = false
  # APIs to be enabled before creating the Cloud Run Job
  depends_on = [
    google_project_service.iamcredentials_api,
    google_project_service.cloud_sql_admin,
    google_project_service.artifact_registry,
    google_service_account_iam_member.github_sa_service_account_user
  ]
}
