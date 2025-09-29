const express = require('express');
const swaggerUi = require('swagger-ui-express');

const app = express();
const port = process.env.PORT || 3000;

const swaggerDocument = {
  openapi: '3.0.0',
  info: {
    title: 'Core Pipeline API',
    version: '1.0.0',
    description: 'Core Pipeline Service'
  },
  servers: [
    {
      url: process.env.NODE_ENV === 'production' 
        ? 'https://core-pipeline.theedgestory.org'
        : 'https://core-pipeline.dev.theedgestory.org'
    }
  ],
  paths: {
    '/': {
      get: {
        summary: 'Health check',
        responses: {
          '200': {
            description: 'Service is healthy',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    status: { type: 'string' },
                    environment: { type: 'string' },
                    timestamp: { type: 'string' }
                  }
                }
              }
            }
          }
        }
      }
    },
    '/health': {
      get: {
        summary: 'Health endpoint',
        responses: {
          '200': { description: 'Healthy' }
        }
      }
    },
    '/ready': {
      get: {
        summary: 'Readiness endpoint',
        responses: {
          '200': { description: 'Ready' }
        }
      }
    }
  }
};

// Routes
app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

app.get('/ready', (req, res) => {
  res.json({ status: 'ready' });
});

// Swagger UI
app.use('/swagger', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// Start server
app.listen(port, () => {
  console.log(`Core Pipeline running on port ${port}`);
  console.log(`Swagger UI available at http://localhost:${port}/swagger`);
});