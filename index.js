import express from 'express';
import { Kafka } from 'kafkajs';

const app = express();
app.use(express.json());

const kafka = new Kafka({
  clientId: 'middleware',
  brokers: [process.env.KAFKA_BROKERS || 'kafka:9092'],
});

const producer = kafka.producer();

const connectKafka = async () => {
  let connected = false;
  while (!connected) {
    try {
      await producer.connect();
      console.log("✅ Conectado a Kafka");
      connected = true;
    } catch (err) {
      console.log("⚠️ Kafka no disponible, reintentando en 2s...");
      await new Promise(res => setTimeout(res, 2000));
    }
  }
};

// Endpoint REST-Hook para recibir recursos FHIR
app.post('/callback', async (req, res) => {
  console.log("📥 Recurso recibido:", req.body);

  await producer.send({
    topic: 'Patient',
    messages: [{ value: JSON.stringify(req.body) }],
  });

  res.status(200).send("Recibido en Kafka");
});

// Inicialización
const start = async () => {
  await connectKafka();

  app.listen(5000, () => {
    console.log("🚀 Middleware escuchando en http://0.0.0.0:5000/callback");
  });
};

start();
