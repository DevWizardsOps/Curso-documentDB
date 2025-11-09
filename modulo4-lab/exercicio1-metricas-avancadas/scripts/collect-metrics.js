#!/usr/bin/env node

const { MongoClient } = require('mongodb');
const AWS = require('aws-sdk');

// Configuração
const config = {
  connectionString: `mongodb://${process.env.DB_USERNAME}:${process.env.DB_PASSWORD}@${process.env.CLUSTER_ENDPOINT}:27017/performanceDB?ssl=true&retryWrites=false`,
  clusterId: process.env.ID + '-lab-cluster-console'
};

const cloudwatch = new AWS.CloudWatch();

class MetricsCollector {
  constructor() {
    this.client = null;
    this.metrics = {};
  }

  async connect() {
    this.client = new MongoClient(config.connectionString, {
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 5000
    });
    await this.client.connect();
    console.log('Connected to DocumentDB for metrics collection');
  }

  async collectCustomMetrics() {
    try {
      // Coletar métricas de performance de queries
      const queryMetrics = await this.measureQueryPerformance();
      
      // Coletar métricas de índices
      const indexMetrics = await this.measureIndexEfficiency();
      
      // Coletar métricas de connection pool
      const poolMetrics = await this.measureConnectionPool();
      
      // Enviar para CloudWatch
      await this.sendToCloudWatch({
        ...queryMetrics,
        ...indexMetrics,
        ...poolMetrics
      });

      console.log('Metrics collected and sent to CloudWatch');
    } catch (error) {
      console.error('Error collecting metrics:', error);
    }
  }

  async measureQueryPerformance() {
    const db = this.client.db('performanceDB');
    const iterations = 10;
    
    // Medir queries simples
    const start = Date.now();
    for (let i = 0; i < iterations; i++) {
      await db.collection('products').findOne({category: 'electronics'});
    }
    const avgQueryTime = (Date.now() - start) / iterations;

    // Contar queries lentas (simulado)
    const slowQueries = Math.floor(Math.random() * 5);

    return {
      QueryExecutionTime: avgQueryTime,
      SlowQueries: slowQueries
    };
  }

  async measureIndexEfficiency() {
    // Simular métricas de índices
    const indexHitRatio = 85 + Math.random() * 10; // 85-95%
    const indexMisses = Math.floor(Math.random() * 20);

    return {
      IndexHitRatio: indexHitRatio,
      IndexMisses: indexMisses
    };
  }

  async measureConnectionPool() {
    // Simular métricas de connection pool
    const activeConnections = Math.floor(Math.random() * 50) + 10;
    const idleConnections = Math.floor(Math.random() * 20) + 5;
    const connectionWaitTime = Math.random() * 100;

    return {
      ActiveConnections: activeConnections,
      IdleConnections: idleConnections,
      ConnectionWaitTime: connectionWaitTime,
      ConnectionPoolUtilization: (activeConnections / (activeConnections + idleConnections)) * 100
    };
  }

  async sendToCloudWatch(metrics) {
    const metricData = Object.entries(metrics).map(([name, value]) => ({
      MetricName: name,
      Value: value,
      Unit: name.includes('Time') ? 'Milliseconds' : 
            name.includes('Ratio') || name.includes('Utilization') ? 'Percent' : 'Count',
      Dimensions: [
        {
          Name: 'ClusterIdentifier',
          Value: config.clusterId
        }
      ]
    }));

    const params = {
      Namespace: 'Custom/DocumentDB',
      MetricData: metricData
    };

    try {
      await cloudwatch.putMetricData(params).promise();
    } catch (error) {
      console.error('Error sending metrics to CloudWatch:', error);
    }
  }

  async disconnect() {
    if (this.client) {
      await this.client.close();
    }
  }
}

// Executar coleta de métricas
async function main() {
  const collector = new MetricsCollector();
  
  try {
    await collector.connect();
    await collector.collectCustomMetrics();
  } finally {
    await collector.disconnect();
  }
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = MetricsCollector;