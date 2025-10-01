variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_location" {
  type = string
}

variable "gcp_artifact_repository_name" {
  type = string
}

variable "pg_db_name" {
  type = string
}

variable "pg_username" {
  type = string
}

variable "pg_password" {
  type = string
  sensitive = true
}

variable "authorized_networks" {
  description = "List of authorized networks for Cloud SQL"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "image_name" {
  type = string
}
