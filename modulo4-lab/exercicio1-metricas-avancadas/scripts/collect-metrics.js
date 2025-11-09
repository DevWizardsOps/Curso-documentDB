#!/usr/bin/env node

const { MongoClient } = require('mongodb');
const { CloudWatchClient, PutMetricDataCommand } = require('@aws-sdk/client-cloudwatch');

// Configuração
const config = {
  connectionString: `mongodb://${process.env.DB_USERNAME}:${process.env.DB_PASSWORD}@${process.env.CLUSTER_ENDPOINT}:27017/performanceDB?ssl=true&retryWrites=false&tlsCAFile=global-bundle.pem&tlsAllowInvalidHostnames=true&authMechanism=SCRAM-SHA-1`,
  clusterId: process.env.ID + '-lab-cluster-console'
};

const cloudwatch = new CloudWatchClient({ region: process.env.AWS_REGION || 'us-east-2' });

class MetricsCollector {
  constructor() {
    this.client = null;
    this.metrics = {};
  }

  async connect() {
    this.client = new MongoClient(config.connectionString, {
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 10000,
      tls: true,
      tlsCAFile: 'global-bundle.pem'
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
    // Simular tempo de query (para fins educacionais)
    const avgQueryTime = 15 + Math.random() * 20; // 15-35ms
    const slowQueries = Math.floor(Math.random() * 5);

    console.log(`Simulated query performance: ${avgQueryTime.toFixed(2)}ms avg, ${slowQueries} slow queries`);

    return {
      QueryExecutionTime: avgQueryTime,
      SlowQueries: slowQueries
    };
  }

  async measureIndexEfficiency() {
    // Simular métricas de índices
    const indexHitRatio = 85 + Math.random() * 10; // 85-95%
    const indexMisses = Math.floor(Math.random() * 20);

    console.log(`Simulated index efficiency: ${indexHitRatio.toFixed(2)}% hit ratio, ${indexMisses} misses`);

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
    const utilization = (activeConnections / (activeConnections + idleConnections)) * 100;

    console.log(`Simulated connection pool: ${activeConnections} active, ${idleConnections} idle, ${utilization.toFixed(2)}% utilization`);

    return {
      ActiveConnections: activeConnections,
      IdleConnections: idleConnections,
      ConnectionWaitTime: connectionWaitTime,
      ConnectionPoolUtilization: utilization
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

    const command = new PutMetricDataCommand({
      Namespace: 'Custom/DocumentDB',
      MetricData: metricData
    });

    try {
      console.log(`Sending metrics to CloudWatch in region: ${process.env.AWS_REGION || 'us-east-2'}`);
      console.log(`Cluster ID: ${config.clusterId}`);
      console.log(`Metrics to send:`, metricData.map(m => `${m.MetricName}: ${m.Value}`));

      const result = await cloudwatch.send(command);
      console.log('Metrics sent to CloudWatch successfully');
      console.log('Response:', result);
    } catch (error) {
      console.error('Error sending metrics to CloudWatch:', error);
      console.error('Error details:', error.message);
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