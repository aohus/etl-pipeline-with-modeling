from airflow import DAG
from airflow.operators.hive_operator import HiveOperator
from airflow.utils.dates import days_ago

default_args = {
    "owner": "airflow",
    "start_date": days_ago(1),
}

dag = DAG(
    "hive_example",
    default_args=default_args,
    description="An example DAG to run Hive queries",
    schedule_interval=None,
)

hive_task = HiveOperator(
    task_id="run_hive_query",
    hql="CREATE DATABASE IF NOT EXIST test;",
    hive_cli_conn_id="hive_default",
    dag=dag,
)

hive_task
