#!/bin/bash

docker-compose -f docker-compose-datavault2-bde.yml down -v
docker volume prune -y
