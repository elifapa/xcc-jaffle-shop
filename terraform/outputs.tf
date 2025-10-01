output "pg_instance_connection_name" {
  value       = google_sql_database_instance.postgres_instance.connection_name
  description = "Postgres connection name for UNIX socket connections"
}
