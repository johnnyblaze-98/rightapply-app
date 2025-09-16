import express from 'express';
import { createProxyMiddleware } from 'http-proxy-middleware';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
app.use(express.json());

const target = process.env.AWS_API_BASE;
if (!target) {
  console.warn('AWS_API_BASE not set. Please create api/.env with AWS_API_BASE=https://<api-id>.execute-api.<region>.amazonaws.com');
}

// Proxy the Flutter app endpoints to AWS
app.use('/device', createProxyMiddleware({
  target: target || 'https://example.execute-api.us-east-1.amazonaws.com',
  changeOrigin: true,
}));

const port = process.env.PORT || 5173;
app.listen(port, () => {
  console.log(`Proxy API listening on http://localhost:${port}, forwarding to ${target}`);
});
