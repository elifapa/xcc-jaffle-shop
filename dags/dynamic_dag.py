from airflow import DAG
from datetime import datetime
import json
from pathlib import Path
from airflow.providers.google.cloud.operators.cloud_run import (
    CloudRunExecuteJobOperator,
)


BASE_DIR = Path(__file__).resolve().parent
MANIFEST_PATH = BASE_DIR.parent / "dbt" / "target" / "manifest.json"

# DAG settings
default_args = {
    "owner": "data_eng",
    "start_date": datetime(2024, 1, 1),
    "retries": 1,
}

with DAG(
    dag_id="dbt_dynamic_dag",
    default_args=default_args,
    schedule=None,
    catchup=False,
) as dag:
    GCP_CLOUDRUN_TASK_ID = "airflow-dbt-ci-job"
    GCP_PROJECT_ID = "ae-dbt-ci-2025"
    GCP_REGION = "europe-west4"

    # Load manifest
    with open(MANIFEST_PATH, "r") as f:
        manifest = json.load(f)

    dbt_nodes = {k: v for k, v in manifest["nodes"].items() if k.startswith("model.")}

    # Store task references to set dependencies later
    tasks = {}

    # Create an Airflow task for each dbt model
    for node_name, node in dbt_nodes.items():
        model_name = node["name"]

        tasks[node_name] = CloudRunExecuteJobOperator(
            task_id=f"run_{model_name}",
            project_id=GCP_PROJECT_ID,
            region=GCP_REGION,
            job_name=GCP_CLOUDRUN_TASK_ID,
            overrides={
                "container_overrides": [
                    {
                        "args": ["run", "--select", model_name],
                    }
                ],
            },
            deferrable=False,
        )

    # Now set dependencies
    for node_name, node in dbt_nodes.items():
        current_task = tasks[node_name]
        upstream_nodes = node["depends_on"]["nodes"]

        for upstream in upstream_nodes:
            if upstream in tasks:
                tasks[upstream] >> current_task
