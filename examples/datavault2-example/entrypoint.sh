#!/bin/bash

# Set default permissions for airflow logs
: "${AIRFLOW_UID:="1000"}"
: "${AIRFLOW_GID:="0"}"

# Wait for Postgres to be ready
if [ "$AIRFLOW__CORE__EXECUTOR" = "LocalExecutor" ] || [ "$AIRFLOW__CORE__EXECUTOR" = "CeleryExecutor" ]; then
  if [ -n "$AIRFLOW__CORE__SQL_ALCHEMY_CONN" ]; then
    echo "Checking for Postgres..."
    while ! nc -z $(echo $AIRFLOW__CORE__SQL_ALCHEMY_CONN | sed -e 's|.*://\([^:]*\).*|\1|'):5432; do
      echo "Waiting for Postgres server..."
      sleep 1
    done
    echo "Postgres is up and running!"
  fi
fi

# Initialize database and create the necessary tables
if [ "$1" = "webserver" ]; then
  echo "Initializing database..."
  airflow db upgrade

  echo "Creating admin user..."
  airflow users create \
    --username admin \
    --firstname First \
    --lastname Last \
    --role Admin \
    --email admin@example.com \
    --password admin
fi

# Start Airflow
exec "$@"