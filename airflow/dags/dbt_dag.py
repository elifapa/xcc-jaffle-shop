from datetime import datetime
from airflow.sdk import DAG
from airflow.providers.google.cloud.operators.cloud_run import CloudRunExecuteJobOperator

"""
Demo for triggering https://console.cloud.google.com/run/jobs/details/europe-west4/dbt-ci-job/executions?authuser=4&project=ae-dbt-ci-2025
with Airflow's GCP Provider.
- How to handle GCP auth? 
- Installing the provider? apache-airflow-providers-google

"""

with DAG(
    "airflow_dbt_cloudrun_dag",
    schedule=None, 
    start_date=datetime.today(), 
    catchup=False,
    tags=["xcc_jaffle_shop"]
) as dag:

    GCP_CLOUDRUN_TASK_ID="airflow-dbt-ci-job"
    GCP_PROJECT_ID="ae-dbt-ci-2025"
    GCP_REGION="europe-west4"

    execute1 = CloudRunExecuteJobOperator(
        task_id="execute-cloudrun-job",
        project_id=GCP_PROJECT_ID,
        gcp_conn_id="google_cloud_default",
        region=GCP_REGION,
        job_name=GCP_CLOUDRUN_TASK_ID,
        dag=dag,
        deferrable=False,
    )

    execute1