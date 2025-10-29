output "pg_instance_connection_name" {
  value       = google_sql_database_instance.postgres_instance.connection_name
  description = "Postgres connection name for UNIX socket connections"
}

output "airflow_dbt_cloudrunjob_latest_execution" {
  value       = google_cloud_run_v2_job.airflow_dbt_cloudrunjob.latest_created_execution
  description = "Latest execution of the Airflow DBT Cloud Run job"
}
