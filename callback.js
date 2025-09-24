const express = require("express");
const bodyParser = require("body-parser");
const { Kafka } = require("kafkajs");

const app = express();
app.use(bodyParser.json());

// Configuración de Kafka
const kafka = new Kafka({
  clientId: "middleware",
  brokers: ["kafka:9092"], // nombre del servicio Kafka en docker-compose
});

const producer = kafka.producer();

// Función para inicializar Kafka
async function initKafka() {
  try {
    await producer.connect();
    console.log("✅ Conectado a Kafka");
  } catch (err) {
    console.error("❌ Error conectando a Kafka, reintentando en 5s...", err);
    setTimeout(initKafka, 5000); // reintenta cada 5 segundos
  }
}

// Endpoint para recibir callbacks de HAPI-FHIR
app.post("/callback", async (req, res) => {
  try {
    const data = req.body;
    console.log("📩 Recibido desde HAPI FHIR:", JSON.stringify(data, null, 2));

    // Enviar al topic Patient
    await producer.send({
      topic: "Patient",
      messages: [{ value: JSON.stringify(data) }],
    });

    console.log("📤 Enviado a Kafka -> Topic: Patient");
    res.status(200).send("OK");
  } catch (err) {
    console.error("❌ Error en callback:", err);
    res.status(500).send("Error");
  }
});

// Inicializar servidor solo después de conectar Kafka
initKafka().then(() => {
  app.listen(5000, () => {
    console.log("🚀 Middleware escuchando en http://0.0.0.0:5000/callback");
  });
});
