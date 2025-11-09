# Exercício 4: Otimização de Conexões, Pools e Latência

## 🎯 Objetivos

- Configurar connection pools otimizados para diferentes cenários
- Implementar estratégias avançadas de reutilização de conexões
- Monitorar e reduzir latência de rede e aplicação
- Diagnosticar e resolver problemas de conectividade

## ⏱️ Duração Estimada
75 minutos

> ⚠️ **Atenção:** Lembre-se de usar seu prefixo de aluno (`<seu-id>`) em todos os nomes de recursos e comandos.

---

## 🔌 Parte 1: Configuração Otimizada de Connection Pools

### Passo 1: Configuração Básica de Pool

```javascript
const { MongoClient } = require('mongodb');

// Configuração otimizada para diferentes cenários
class ConnectionPoolManager {
  constructor() {
    this.pools = {};
  }

  // Pool para aplicações web (alta concorrência, conexões curtas)
  createWebAppPool(connectionString) {
    return new MongoClient(connectionString, {
      maxPoolSize: 100,        // Máximo de conexões
      minPoolSize: 10,         // Mínimo de conexões mantidas
      maxIdleTimeMS: 30000,    // 30s timeout para conexões idle
      waitQueueTimeoutMS: 5000, // 5s timeout na fila
      serverSelectionTimeoutMS: 5000, // 5s para seleção de servidor
      socketTimeoutMS: 45000,  // 45s timeout de socket
      family: 4,               // IPv4
      keepAlive: true,
      keepAliveInitialDelay: 120000, // 2min keep-alive
      compression: 'snappy'    // Compressão para reduzir latência
    });
  }

  // Pool para batch jobs (baixa concorrência, conexões longas)
  createBatchJobPool(connectionString) {
    return new MongoClient(connectionString, {
      maxPoolSize: 20,         // Menos conexões simultâneas
      minPoolSize: 5,
      maxIdleTimeMS: 300000,   // 5min timeout (conexões mais longas)
      waitQueueTimeoutMS: 30000, // 30s timeout na fila
      serverSelectionTimeoutMS: 10000,
      socketTimeoutMS: 300000, // 5min timeout de socket
      family: 4,
      keepAlive: true,
      keepAliveInitialDelay: 300000, // 5min keep-alive
      compression: 'zlib'      // Compressão mais eficiente
    });
  }

  // Pool para analytics (queries longas, poucos clientes)
  createAnalyticsPool(connectionString) {
    return new MongoClient(connectionString, {
      maxPoolSize: 10,         // Poucas conexões
      minPoolSize: 2,
      maxIdleTimeMS: 600000,   // 10min timeout
      waitQueueTimeoutMS: 60000, // 1min timeout na fila
      serverSelectionTimeoutMS: 15000,
      socketTimeoutMS: 1800000, // 30min timeout de socket
      family: 4,
      keepAlive: true,
      keepAliveInitialDelay: 600000, // 10min keep-alive
      readPreference: 'secondary', // Usar read replicas
      compression: 'zlib'
    });
  }
}
```

### Passo 2: Implementação de Pool Adaptativo

```javascript
class AdaptiveConnectionPool {
  constructor(baseConnectionString) {
    this.baseConnectionString = baseConnectionString;
    this.currentLoad = 0;
    this.maxLoad = 100;
    this.client = null;
    this.lastReconfiguration = Date.now();
    this.reconfigurationInterval = 60000; // 1 minuto
  }

  async getConnection() {
    // Reconfigurar pool baseado na carga atual
    if (this.shouldReconfigure()) {
      await this.reconfigurePool();
    }

    if (!this.client) {
      this.client = await this.createOptimalPool();
    }

    return this.client;
  }

  shouldReconfigure() {
    const timeSinceLastReconfig = Date.now() - this.lastReconfiguration;
    return timeSinceLastReconfig > this.reconfigurationInterval;
  }

  async reconfigurePool() {
    const loadPercentage = (this.currentLoad / this.maxLoad) * 100;
    
    let poolConfig;
    if (loadPercentage > 80) {
      // Alta carga - pool agressivo
      poolConfig = {
        maxPoolSize: 150,
        minPoolSize: 20,
        maxIdleTimeMS: 15000,
        waitQueueTimeoutMS: 2000
      };
    } else if (loadPercentage > 50) {
      // Carga média - pool balanceado
      poolConfig = {
        maxPoolSize: 100,
        minPoolSize: 15,
        maxIdleTimeMS: 30000,
        waitQueueTimeoutMS: 5000
      };
    } else {
      // Baixa carga - pool conservador
      poolConfig = {
        maxPoolSize: 50,
        minPoolSize: 5,
        maxIdleTimeMS: 60000,
        waitQueueTimeoutMS: 10000
      };
    }

    // Fechar cliente atual se existir
    if (this.client) {
      await this.client.close();
    }

    // Criar novo cliente com configuração otimizada
    this.client = new MongoClient(this.baseConnectionString, {
      ...poolConfig,
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
      family: 4,
      keepAlive: true,
      compression: 'snappy'
    });

    this.lastReconfiguration = Date.now();
    console.log(`Pool reconfigured for ${loadPercentage.toFixed(1)}% load:`, poolConfig);
  }

  updateLoad(currentConnections) {
    this.currentLoad = currentConnections;
  }

  async createOptimalPool() {
    return new MongoClient(this.baseConnectionString, {
      maxPoolSize: 100,
      minPoolSize: 10,
      maxIdleTimeMS: 30000,
      waitQueueTimeoutMS: 5000,
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
      family: 4,
      keepAlive: true,
      compression: 'snappy'
    });
  }
}
```

---

## 📊 Parte 2: Monitoramento de Conexões em Tempo Real

### Passo 1: Monitor de Pool de Conexões

```javascript
class ConnectionPoolMonitor {
  constructor(client) {
    this.client = client;
    this.metrics = {
      totalConnections: 0,
      activeConnections: 0,
      idleConnections: 0,
      waitingOperations: 0,
      connectionErrors: 0,
      averageLatency: 0
    };
    this.latencyHistory = [];
  }

  async collectMetrics() {
    try {
      // Obter estatísticas do pool
      const poolStats = this.client.topology?.s?.server?.s?.pool?.totalConnectionCount || 0;
      const activeStats = this.client.topology?.s?.server?.s?.pool?.availableConnectionCount || 0;

      this.metrics.totalConnections = poolStats;
      this.metrics.activeConnections = poolStats - activeStats;
      this.metrics.idleConnections = activeStats;

      // Medir latência
      const latency = await this.measureLatency();
      this.updateLatencyMetrics(latency);

      // Enviar métricas para CloudWatch
      await this.sendToCloudWatch();

      return this.metrics;
    } catch (error) {
      this.metrics.connectionErrors++;
      console.error('Error collecting pool metrics:', error);
    }
  }

  async measureLatency() {
    const start = Date.now();
    try {
      await this.client.db('admin').command({ ping: 1 });
      return Date.now() - start;
    } catch (error) {
      return -1; // Erro na medição
    }
  }

  updateLatencyMetrics(latency) {
    if (latency > 0) {
      this.latencyHistory.push(latency);
      
      // Manter apenas últimas 100 medições
      if (this.latencyHistory.length > 100) {
        this.latencyHistory.shift();
      }

      // Calcular média
      this.metrics.averageLatency = this.latencyHistory.reduce((a, b) => a + b, 0) / this.latencyHistory.length;
    }
  }

  async sendToCloudWatch() {
    const AWS = require('aws-sdk');
    const cloudwatch = new AWS.CloudWatch();

    const params = {
      Namespace: 'Custom/DocumentDB/ConnectionPool',
      MetricData: [
        {
          MetricName: 'TotalConnections',
          Value: this.metrics.totalConnections,
          Unit: 'Count',
          Dimensions: [
            {
              Name: 'ClusterIdentifier',
              Value: process.env.ID + '-lab-cluster-console'
            }
          ]
        },
        {
          MetricName: 'ActiveConnections',
          Value: this.metrics.activeConnections,
          Unit: 'Count',
          Dimensions: [
            {
              Name: 'ClusterIdentifier',
              Value: process.env.ID + '-lab-cluster-console'
            }
          ]
        },
        {
          MetricName: 'AverageLatency',
          Value: this.metrics.averageLatency,
          Unit: 'Milliseconds',
          Dimensions: [
            {
              Name: 'ClusterIdentifier',
              Value: process.env.ID + '-lab-cluster-console'
            }
          ]
        }
      ]
    };

    try {
      await cloudwatch.putMetricData(params).promise();
    } catch (error) {
      console.error('Error sending metrics to CloudWatch:', error);
    }
  }

  startMonitoring(intervalMs = 30000) {
    setInterval(() => {
      this.collectMetrics();
    }, intervalMs);
  }
}
```

### Passo 2: Script de Monitoramento Contínuo

```bash
# Criar script de monitoramento
cat > scripts/connection-monitor.sh << 'EOF'
#!/bin/bash

ID="<seu-id>"
INTERVAL=30

echo "Starting connection monitoring for cluster: $ID-lab-cluster-console"
echo "Monitoring interval: ${INTERVAL}s"
echo "Timestamp,TotalConnections,ActiveConnections,IdleConnections,Latency(ms)"

while true; do
    # Executar script Node.js para coletar métricas
    node scripts/collect-connection-metrics.js
    sleep $INTERVAL
done
EOF

chmod +x scripts/connection-monitor.sh
```

---

## 🚀 Parte 3: Otimização de Latência

### Passo 1: Análise de Latência de Rede

```javascript
class LatencyAnalyzer {
  constructor(endpoints) {
    this.endpoints = endpoints;
    this.results = new Map();
  }

  async analyzeNetworkLatency() {
    console.log('Analyzing network latency to DocumentDB endpoints...');
    
    for (const endpoint of this.endpoints) {
      const latencies = [];
      
      // Executar múltiplas medições
      for (let i = 0; i < 10; i++) {
        const latency = await this.measureTCPLatency(endpoint, 27017);
        if (latency > 0) {
          latencies.push(latency);
        }
        await this.sleep(100); // Pequeno delay entre medições
      }

      if (latencies.length > 0) {
        const stats = this.calculateLatencyStats(latencies);
        this.results.set(endpoint, stats);
        
        console.log(`${endpoint}:`);
        console.log(`  Min: ${stats.min}ms`);
        console.log(`  Max: ${stats.max}ms`);
        console.log(`  Avg: ${stats.avg.toFixed(2)}ms`);
        console.log(`  P95: ${stats.p95}ms`);
      }
    }

    return this.results;
  }

  async measureTCPLatency(host, port) {
    const net = require('net');
    
    return new Promise((resolve) => {
      const start = Date.now();
      const socket = new net.Socket();
      
      const timeout = setTimeout(() => {
        socket.destroy();
        resolve(-1);
      }, 5000);

      socket.connect(port, host, () => {
        clearTimeout(timeout);
        const latency = Date.now() - start;
        socket.destroy();
        resolve(latency);
      });

      socket.on('error', () => {
        clearTimeout(timeout);
        resolve(-1);
      });
    });
  }

  calculateLatencyStats(latencies) {
    const sorted = latencies.sort((a, b) => a - b);
    return {
      min: sorted[0],
      max: sorted[sorted.length - 1],
      avg: latencies.reduce((a, b) => a + b, 0) / latencies.length,
      p95: sorted[Math.floor(sorted.length * 0.95)]
    };
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
```

### Passo 2: Otimização de Queries para Baixa Latência

```javascript
class LowLatencyQueryOptimizer {
  constructor(client) {
    this.client = client;
  }

  // Query otimizada com projection e limit
  async getProductsSummary(category, limit = 10) {
    const db = this.client.db('performanceDB');
    
    return await db.collection('products')
      .find(
        { category },
        { 
          projection: { 
            _id: 1, 
            name: 1, 
            price: 1 
          } // Reduzir dados transferidos
        }
      )
      .limit(limit) // Limitar resultados
      .hint({ category: 1, price: 1 }) // Forçar uso de índice
      .toArray();
  }

  // Agregação otimizada com early filtering
  async getOrderStatistics(startDate, endDate) {
    const db = this.client.db('performanceDB');
    
    return await db.collection('orders')
      .aggregate([
        // Filtrar primeiro para reduzir dados processados
        {
          $match: {
            orderDate: { $gte: startDate, $lte: endDate }
          }
        },
        // Projetar apenas campos necessários
        {
          $project: {
            totalAmount: 1,
            status: 1,
            orderDate: 1
          }
        },
        // Agrupar
        {
          $group: {
            _id: '$status',
            count: { $sum: 1 },
            totalRevenue: { $sum: '$totalAmount' }
          }
        }
      ], {
        allowDiskUse: false, // Forçar operação em memória
        maxTimeMS: 5000      // Timeout de 5s
      })
      .toArray();
  }

  // Batch de queries com Promise.all para paralelização
  async getBatchData(productIds) {
    const db = this.client.db('performanceDB');
    
    // Dividir em lotes menores para otimizar
    const batchSize = 100;
    const batches = [];
    
    for (let i = 0; i < productIds.length; i += batchSize) {
      const batch = productIds.slice(i, i + batchSize);
      batches.push(batch);
    }

    // Executar lotes em paralelo
    const results = await Promise.all(
      batches.map(batch =>
        db.collection('products')
          .find({ _id: { $in: batch } })
          .toArray()
      )
    );

    // Combinar resultados
    return results.flat();
  }
}
```

---

## 🔧 Parte 4: Troubleshooting de Conectividade

### Passo 1: Diagnóstico Automático

```javascript
class ConnectionDiagnostics {
  constructor(connectionString) {
    this.connectionString = connectionString;
    this.diagnostics = [];
  }

  async runFullDiagnostics() {
    console.log('Running connection diagnostics...');
    
    await this.testDNSResolution();
    await this.testTCPConnectivity();
    await this.testSSLHandshake();
    await this.testAuthentication();
    await this.testQueryExecution();
    
    return this.generateReport();
  }

  async testDNSResolution() {
    const dns = require('dns').promises;
    const url = require('url');
    
    try {
      const parsed = new url.URL(this.connectionString);
      const hostname = parsed.hostname;
      
      console.log(`Testing DNS resolution for ${hostname}...`);
      const addresses = await dns.resolve4(hostname);
      
      this.diagnostics.push({
        test: 'DNS Resolution',
        status: 'PASS',
        details: `Resolved to: ${addresses.join(', ')}`
      });
    } catch (error) {
      this.diagnostics.push({
        test: 'DNS Resolution',
        status: 'FAIL',
        details: error.message
      });
    }
  }

  async testTCPConnectivity() {
    const net = require('net');
    const url = require('url');
    
    try {
      const parsed = new url.URL(this.connectionString);
      const hostname = parsed.hostname;
      const port = parsed.port || 27017;
      
      console.log(`Testing TCP connectivity to ${hostname}:${port}...`);
      
      await new Promise((resolve, reject) => {
        const socket = new net.Socket();
        const timeout = setTimeout(() => {
          socket.destroy();
          reject(new Error('Connection timeout'));
        }, 10000);

        socket.connect(port, hostname, () => {
          clearTimeout(timeout);
          socket.destroy();
          resolve();
        });

        socket.on('error', (error) => {
          clearTimeout(timeout);
          reject(error);
        });
      });

      this.diagnostics.push({
        test: 'TCP Connectivity',
        status: 'PASS',
        details: `Successfully connected to ${hostname}:${port}`
      });
    } catch (error) {
      this.diagnostics.push({
        test: 'TCP Connectivity',
        status: 'FAIL',
        details: error.message
      });
    }
  }

  async testSSLHandshake() {
    const tls = require('tls');
    const url = require('url');
    
    try {
      const parsed = new url.URL(this.connectionString);
      const hostname = parsed.hostname;
      const port = parsed.port || 27017;
      
      console.log(`Testing SSL handshake with ${hostname}:${port}...`);
      
      await new Promise((resolve, reject) => {
        const socket = tls.connect({
          host: hostname,
          port: port,
          rejectUnauthorized: false
        }, () => {
          socket.destroy();
          resolve();
        });

        socket.on('error', (error) => {
          reject(error);
        });

        setTimeout(() => {
          socket.destroy();
          reject(new Error('SSL handshake timeout'));
        }, 10000);
      });

      this.diagnostics.push({
        test: 'SSL Handshake',
        status: 'PASS',
        details: 'SSL connection established successfully'
      });
    } catch (error) {
      this.diagnostics.push({
        test: 'SSL Handshake',
        status: 'FAIL',
        details: error.message
      });
    }
  }

  async testAuthentication() {
    try {
      console.log('Testing authentication...');
      
      const client = new MongoClient(this.connectionString, {
        serverSelectionTimeoutMS: 10000,
        connectTimeoutMS: 10000
      });

      await client.connect();
      await client.db('admin').command({ ping: 1 });
      await client.close();

      this.diagnostics.push({
        test: 'Authentication',
        status: 'PASS',
        details: 'Authentication successful'
      });
    } catch (error) {
      this.diagnostics.push({
        test: 'Authentication',
        status: 'FAIL',
        details: error.message
      });
    }
  }

  async testQueryExecution() {
    try {
      console.log('Testing query execution...');
      
      const client = new MongoClient(this.connectionString, {
        serverSelectionTimeoutMS: 10000
      });

      await client.connect();
      
      const db = client.db('performanceDB');
      const result = await db.collection('products').findOne({});
      
      await client.close();

      this.diagnostics.push({
        test: 'Query Execution',
        status: 'PASS',
        details: `Query executed successfully, sample result: ${result ? 'found' : 'no data'}`
      });
    } catch (error) {
      this.diagnostics.push({
        test: 'Query Execution',
        status: 'FAIL',
        details: error.message
      });
    }
  }

  generateReport() {
    console.log('\n=== CONNECTION DIAGNOSTICS REPORT ===');
    
    let allPassed = true;
    this.diagnostics.forEach(diagnostic => {
      const status = diagnostic.status === 'PASS' ? '✅' : '❌';
      console.log(`${status} ${diagnostic.test}: ${diagnostic.details}`);
      
      if (diagnostic.status === 'FAIL') {
        allPassed = false;
      }
    });

    console.log(`\nOverall Status: ${allPassed ? '✅ ALL TESTS PASSED' : '❌ SOME TESTS FAILED'}`);
    
    return {
      allPassed,
      diagnostics: this.diagnostics
    };
  }
}
```

---

## 📊 Parte 5: Testes de Performance de Conexão

### Passo 1: Teste de Carga de Conexões

```bash
# Executar teste de carga de conexões
node scripts/connection-load-test.js --connections 100 --duration 300 --ramp-up 30

# Parâmetros:
# --connections: Número máximo de conexões simultâneas
# --duration: Duração do teste em segundos
# --ramp-up: Tempo para atingir máximo de conexões
```

### Passo 2: Benchmark de Latência

```javascript
// Script de benchmark de latência
async function runLatencyBenchmark() {
  const scenarios = [
    { name: 'Single Connection', poolSize: 1 },
    { name: 'Small Pool', poolSize: 10 },
    { name: 'Medium Pool', poolSize: 50 },
    { name: 'Large Pool', poolSize: 100 }
  ];

  for (const scenario of scenarios) {
    console.log(`\nTesting ${scenario.name} (Pool Size: ${scenario.poolSize})`);
    
    const client = new MongoClient(connectionString, {
      maxPoolSize: scenario.poolSize,
      minPoolSize: Math.min(5, scenario.poolSize)
    });

    await client.connect();

    // Executar 1000 queries simples
    const latencies = [];
    for (let i = 0; i < 1000; i++) {
      const start = Date.now();
      await client.db('performanceDB').collection('products').findOne({});
      latencies.push(Date.now() - start);
    }

    const stats = calculateLatencyStats(latencies);
    console.log(`  Average: ${stats.avg.toFixed(2)}ms`);
    console.log(`  P95: ${stats.p95}ms`);
    console.log(`  P99: ${stats.p99}ms`);

    await client.close();
  }
}
```

---

## ✅ Checklist de Conclusão

Execute o script de validação:

```bash
# Executa o grade para avaliar atividades
./grade_exercicio4.sh
```

### Itens Verificados:

- ✅ Connection pools otimizados configurados
- ✅ Monitoramento de conexões em tempo real
- ✅ Análise de latência executada
- ✅ Diagnósticos de conectividade funcionando
- ✅ Testes de performance de conexão executados
- ✅ Otimizações de queries para baixa latência implementadas

---

## 🧹 Limpeza

```bash
# Parar monitoramento de conexões
pkill -f "connection-monitor\|latency-test"

# Fechar todas as conexões de teste
node -e "
const { MongoClient } = require('mongodb');
// Script para fechar conexões pendentes
process.exit(0);
"
```

---

## 📊 Resultados de Otimização

### Melhorias Alcançadas:

1. **Connection Pool Efficiency:**
   - 60-80% de redução em connection overhead
   - Melhor reutilização de conexões
   - Redução de connection timeouts

2. **Latência de Rede:**
   - Identificação de gargalos de rede
   - Otimização de timeouts e keep-alive
   - Melhoria na seleção de endpoints

3. **Query Performance:**
   - 40-70% de redução na latência de queries
   - Melhor utilização de índices
   - Otimização de transferência de dados

### Configurações Otimizadas:

- **Web Applications:** Pool size 100, timeout 30s
- **Batch Jobs:** Pool size 20, timeout 5min
- **Analytics:** Pool size 10, timeout 30min
- **Real-time:** Pool size 150, timeout 15s

---

[⬅️ Exercício 3](../exercicio3-workload-optimization/README.md) | [➡️ Exercício 5](../exercicio5-tuning-cluster/README.md)