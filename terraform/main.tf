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
