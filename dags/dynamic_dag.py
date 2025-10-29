from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime
import json
from pathlib import Path


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
    # Load manifest
    with open(MANIFEST_PATH, "r") as f:
        manifest = json.load(f)

    dbt_nodes = {k: v for k, v in manifest["nodes"].items() if k.startswith("model.")}

    # Store task references to set dependencies later
    tasks = {}

    # Create an Airflow task for each dbt model
    for node_name, node in dbt_nodes.items():
        model_name = node["name"]

        tasks[node_name] = BashOperator(
            task_id=model_name,
            bash_command=f"dbt run --select {model_name}",
        )

    # Now set dependencies
    for node_name, node in dbt_nodes.items():
        current_task = tasks[node_name]
        upstream_nodes = node["depends_on"]["nodes"]

        for upstream in upstream_nodes:
            if upstream in tasks:
                tasks[upstream] >> current_task
