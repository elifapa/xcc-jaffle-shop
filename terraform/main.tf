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

# data "google_artifact_registry_docker_image" "my_image" {
#   location      = var.gcp_location
#   repository_id = var.gcp_artifact_repository_name
#   image_name    = "${var.artifact_image_name}:${var.artifact_image_tag}"
# }


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
