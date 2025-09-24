#!/bin/bash

# 🚀 Setup completo HAPI-FHIR + Kafka + Middleware

set -e  # Salir si hay error

TOPIC_NAME="Patient"
HAPI_URL="http://localhost:8080/fhir"
MIDDLEWARE_URL="http://middleware:5000/callback"

echo "1️⃣ Apagando contenedores anteriores y limpiando Docker..."
docker compose down
docker system prune -f

echo "2️⃣ Levantando contenedores..."
docker compose up -d --build

# Esperar que Kafka esté listo
echo "⏳ Esperando a que Kafka esté listo..."
for i in {1..15}; do
  if docker exec kafka kafka-topics.sh --list --bootstrap-server kafka:9092 &>/dev/null; then
    echo "Kafka listo"
    break
  fi
  echo "Esperando Kafka... ($i/15)"
  sleep 2
done

# Borrar topic si existe para iniciar limpio
echo "🗑️ Borrando topic $TOPIC_NAME si existe..."
docker exec kafka kafka-topics.sh --delete \
  --topic $TOPIC_NAME \
  --bootstrap-server kafka:9092 2>/dev/null || echo "Topic $TOPIC_NAME no existía"

# Crear topic limpio
echo "3️⃣ Creando topic $TOPIC_NAME..."
docker exec kafka kafka-topics.sh --create \
  --topic $TOPIC_NAME \
  --bootstrap-server kafka:9092 \
  --partitions 1 \
  --replication-factor 1

# Esperar a que HAPI-FHIR esté listo
echo "⏳ Esperando a que HAPI-FHIR esté listo..."
for i in {1..15}; do
  if curl -s $HAPI_URL/Patient | grep -q "resourceType"; then
    echo "HAPI-FHIR listo"
    break
  fi
  echo "Esperando HAPI-FHIR... ($i/15)"
  sleep 2
done

# Crear suscripción antes de crear paciente
echo "4️⃣ Creando suscripción en HAPI-FHIR..."
curl -s -X POST $HAPI_URL/Subscription \
-H "Content-Type: application/fhir+json" \
-d "{
  \"resourceType\": \"Subscription\",
  \"status\": \"active\",
  \"criteria\": \"Patient?_id=*\",
  \"channel\": {
    \"type\": \"rest-hook\",
    \"endpoint\": \"$MIDDLEWARE_URL\",
    \"payload\": \"application/fhir+json\"
  }
}" >/dev/null

# Crear paciente de prueba
echo "5️⃣ Creando paciente de prueba..."
curl -s -X POST $HAPI_URL/Patient \
-H "Content-Type: application/fhir+json" \
-d '{
  "resourceType": "Patient",
  "name": [{"use": "official","family": "Perez","given": ["Luis"]}],
  "gender": "male",
  "birthDate": "2000-01-01"
}' >/dev/null

echo "✅ Setup completado!"
echo "👀 Verifica los logs del middleware con: docker logs -f middleware"
echo "📝 Verifica mensajes en Kafka con: docker exec -it kafka kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic $TOPIC_NAME --from-beginning"
