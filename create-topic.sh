#!/bin/bash
docker exec kafka kafka-topics.sh --create \
  --topic Patient \
  --bootstrap-server kafka:9092 \
  --partitions 1 \
  --replication-factor 1
