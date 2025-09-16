import { defineConfig } from 'vite';
import dotenv from 'dotenv';

dotenv.config();

const target = process.env.AWS_API_BASE || 'https://example.execute-api.us-east-1.amazonaws.com';

export default defineConfig({
  server: {
    port: 5173,
    proxy: {
      '/device': {
        target,
        changeOrigin: true,
        secure: true,
        configure: (proxy) => {
          proxy.on('proxyReq', (proxyReq, req) => {
            // Preserve JSON content-type and body if present
            if (req.body) {
              const bodyData = JSON.stringify(req.body);
              proxyReq.setHeader('Content-Length', Buffer.byteLength(bodyData));
              proxyReq.write(bodyData);
            }
          });
        },
      },
    },
  },
});
