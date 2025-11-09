#!/usr/bin/env node

const { MongoClient } = require('mongodb');
const AWS = require('aws-sdk');

class ReplicationLagTester {
  constructor(clusterEndpoint, credentials) {
    this.clusterEndpoint = clusterEndpoint;
    this.credentials = credentials;
    this.clients = new Map();
    this.lagHistory = [];
    this.cloudwatch = new AWS.CloudWatch();
  }

  async connect() {
    // Conectar ao cluster endpoint (writer)
    const writerConnectionString = `mongodb://${this.credentials.username}:${this.credentials.password}@${this.clusterEndpoint}:27017/replicationTest?ssl=true&readPreference=primary`;
    
    this.writerClient = new MongoClient(writerConnectionString, {
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 5000
    });
    
    await this.writerClient.connect();
    console.log('✅ Conectado ao writer endpoint');

    // Descobrir read replicas
    await this.discoverReadReplicas();
  }

  async discoverReadReplicas() {
    // Simular descoberta de read replicas
    // Em um ambiente real, você obteria os endpoints das replicas via AWS API
    const replicaEndpoints = [
      this.clusterEndpoint.replace('.cluster-', '.cluster-ro-'),
      // Adicionar endpoints específicos de instâncias se necessário
    ];

    for (const endpoint of replicaEndpoints) {
      try {
        const connectionString = `mongodb://${this.credentials.username}:${this.credentials.password}@${endpoint}:27017/replicationTest?ssl=true&readPreference=secondary`;
        
        const client = new MongoClient(connectionString, {
          maxPoolSize: 10,
          serverSelectionTimeoutMS: 5000
        });
        
        await client.connect();
        this.clients.set(endpoint, client);
        console.log(`✅ Conectado à read replica: ${endpoint}`);
      } catch (error) {
        console.log(`⚠️  Não foi possível conectar à replica ${endpoint}: ${error.message}`);
      }
    }
  }

  async startLagTesting(intervalSeconds = 30, durationMinutes = 10) {
    console.log(`\n🔄 Iniciando teste de replication lag...`);
    console.log(`Intervalo: ${intervalSeconds}s, Duração: ${durationMinutes}min`);
    
    const endTime = Date.now() + (durationMinutes * 60 * 1000);
    let testCounter = 0;

    while (Date.now() < endTime) {
      testCounter++;
      console.log(`\n--- Teste ${testCounter} ---`);
      
      try {
        const lagResults = await this.measureReplicationLag();
        this.lagHistory.push({
          timestamp: new Date(),
          results: lagResults
        });

        // Enviar métricas para CloudWatch
        await this.sendMetricsToCloudWatch(lagResults);

        // Exibir resultados
        this.displayLagResults(lagResults);

      } catch (error) {
        console.error(`❌ Erro no teste ${testCounter}:`, error.message);
      }

      // Aguardar próximo teste
      await this.sleep(intervalSeconds * 1000);
    }

    // Gerar relatório final
    this.generateFinalReport();
  }

  async measureReplicationLag() {
    const testDoc = {
      _id: `lag-test-${Date.now()}`,
      timestamp: new Date(),
      testCounter: Math.random(),
      data: 'replication-lag-test'
    };

    // Inserir no writer
    const writeStart = Date.now();
    await this.writerClient.db('replicationTest').collection('lagTest').insertOne(testDoc);
    const writeTime = Date.now() - writeStart;

    console.log(`📝 Documento inserido no writer (${writeTime}ms)`);

    // Testar leitura em cada replica
    const replicaResults = [];
    
    for (const [endpoint, client] of this.clients) {
      const replicaResult = await this.testReplicaLag(client, testDoc._id, endpoint);
      replicaResults.push(replicaResult);
    }

    return {
      testId: testDoc._id,
      writeTime,
      replicaResults,
      timestamp: new Date()
    };
  }

  async testReplicaLag(replicaClient, documentId, endpoint) {
    const startTime = Date.now();
    let found = false;
    let attempts = 0;
    const maxAttempts = 60; // 60 segundos máximo

    while (!found && attempts < maxAttempts) {
      try {
        const result = await replicaClient.db('replicationTest')
          .collection('lagTest')
          .findOne({_id: documentId});

        if (result) {
          found = true;
          const lagTime = Date.now() - startTime;
          
          console.log(`  ✅ ${endpoint}: ${lagTime}ms (${attempts + 1} tentativas)`);
          
          return {
            endpoint,
            lagTime,
            attempts: attempts + 1,
            status: 'success'
          };
        } else {
          attempts++;
          await this.sleep(1000); // Aguardar 1 segundo
        }
      } catch (error) {
        attempts++;
        console.log(`  ⚠️  ${endpoint}: Erro na tentativa ${attempts} - ${error.message}`);
        await this.sleep(1000);
      }
    }

    console.log(`  ❌ ${endpoint}: Timeout após ${maxAttempts}s`);
    return {
      endpoint,
      lagTime: -1,
      attempts,
      status: 'timeout'
    };
  }

  async sendMetricsToCloudWatch(lagResults) {
    const metricData = [];

    // Métrica de lag médio
    const successfulReplicas = lagResults.replicaResults.filter(r => r.status === 'success');
    
    if (successfulReplicas.length > 0) {
      const averageLag = successfulReplicas.reduce((sum, r) => sum + r.lagTime, 0) / successfulReplicas.length;
      
      metricData.push({
        MetricName: 'ReplicationLag',
        Value: averageLag,
        Unit: 'Milliseconds',
        Dimensions: [
          {
            Name: 'ClusterIdentifier',
            Value: process.env.ID + '-lab-cluster-console'
          }
        ]
      });
    }

    // Métrica de replicas saudáveis
    metricData.push({
      MetricName: 'HealthyReplicas',
      Value: successfulReplicas.length,
      Unit: 'Count',
      Dimensions: [
        {
          Name: 'ClusterIdentifier',
          Value: process.env.ID + '-lab-cluster-console'
        }
      ]
    });

    // Enviar para CloudWatch
    if (metricData.length > 0) {
      try {
        await this.cloudwatch.putMetricData({
          Namespace: 'Custom/DocumentDB/Replication',
          MetricData: metricData
        }).promise();
      } catch (error) {
        console.log(`⚠️  Erro ao enviar métricas: ${error.message}`);
      }
    }
  }

  displayLagResults(lagResults) {
    const successfulReplicas = lagResults.replicaResults.filter(r => r.status === 'success');
    
    if (successfulReplicas.length > 0) {
      const avgLag = successfulReplicas.reduce((sum, r) => sum + r.lagTime, 0) / successfulReplicas.length;
      const minLag = Math.min(...successfulReplicas.map(r => r.lagTime));
      const maxLag = Math.max(...successfulReplicas.map(r => r.lagTime));
      
      console.log(`📊 Lag médio: ${avgLag.toFixed(2)}ms (min: ${minLag}ms, max: ${maxLag}ms)`);
    } else {
      console.log(`❌ Nenhuma replica respondeu com sucesso`);
    }
  }

  generateFinalReport() {
    console.log('\n' + '='.repeat(50));
    console.log('📋 RELATÓRIO FINAL DE REPLICATION LAG');
    console.log('='.repeat(50));

    if (this.lagHistory.length === 0) {
      console.log('❌ Nenhum dado coletado');
      return;
    }

    // Calcular estatísticas
    const allLags = [];
    let totalTests = 0;
    let successfulTests = 0;

    this.lagHistory.forEach(test => {
      totalTests++;
      const successfulReplicas = test.results.replicaResults.filter(r => r.status === 'success');
      
      if (successfulReplicas.length > 0) {
        successfulTests++;
        successfulReplicas.forEach(replica => {
          allLags.push(replica.lagTime);
        });
      }
    });

    if (allLags.length > 0) {
      allLags.sort((a, b) => a - b);
      
      const avgLag = allLags.reduce((sum, lag) => sum + lag, 0) / allLags.length;
      const minLag = allLags[0];
      const maxLag = allLags[allLags.length - 1];
      const p95Lag = allLags[Math.floor(allLags.length * 0.95)];
      const p99Lag = allLags[Math.floor(allLags.length * 0.99)];

      console.log(`\n📈 Estatísticas de Lag:`);
      console.log(`   Testes realizados: ${totalTests}`);
      console.log(`   Testes bem-sucedidos: ${successfulTests} (${(successfulTests/totalTests*100).toFixed(1)}%)`);
      console.log(`   Medições de lag: ${allLags.length}`);
      console.log(`   Lag médio: ${avgLag.toFixed(2)}ms`);
      console.log(`   Lag mínimo: ${minLag}ms`);
      console.log(`   Lag máximo: ${maxLag}ms`);
      console.log(`   P95: ${p95Lag}ms`);
      console.log(`   P99: ${p99Lag}ms`);

      // Classificação da performance
      let performance = 'EXCELENTE';
      if (avgLag > 100) performance = 'BOA';
      if (avgLag > 500) performance = 'REGULAR';
      if (avgLag > 1000) performance = 'RUIM';
      if (avgLag > 5000) performance = 'CRÍTICA';

      console.log(`\n🎯 Performance de Replicação: ${performance}`);

      // Recomendações
      console.log(`\n💡 Recomendações:`);
      if (avgLag < 100) {
        console.log(`   ✅ Replication lag excelente - nenhuma ação necessária`);
      } else if (avgLag < 500) {
        console.log(`   ⚠️  Considere monitorar workload de escrita`);
      } else if (avgLag < 1000) {
        console.log(`   ⚠️  Verifique network latency entre AZs`);
        console.log(`   ⚠️  Considere otimizar queries de escrita`);
      } else {
        console.log(`   ❌ Lag crítico - investigação necessária`);
        console.log(`   ❌ Verifique recursos de CPU/memória`);
        console.log(`   ❌ Analise workload de escrita`);
      }
    }

    console.log('\n' + '='.repeat(50));
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  async disconnect() {
    await this.writerClient?.close();
    
    for (const client of this.clients.values()) {
      await client.close();
    }
    
    console.log('🔌 Conexões fechadas');
  }
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);
  
  if (args.includes('--help')) {
    console.log('Uso: node test-replication-lag.js [opções]');
    console.log('Opções:');
    console.log('  --cluster <endpoint>    Endpoint do cluster');
    console.log('  --interval <seconds>    Intervalo entre testes (padrão: 30)');
    console.log('  --duration <minutes>    Duração do teste (padrão: 10)');
    console.log('  --help                  Mostrar esta ajuda');
    return;
  }

  const clusterEndpoint = process.env.CLUSTER_ENDPOINT || args[args.indexOf('--cluster') + 1];
  const interval = parseInt(args[args.indexOf('--interval') + 1]) || 30;
  const duration = parseInt(args[args.indexOf('--duration') + 1]) || 10;

  if (!clusterEndpoint) {
    console.error('❌ Endpoint do cluster é obrigatório');
    console.log('Use: --cluster <endpoint> ou defina CLUSTER_ENDPOINT');
    process.exit(1);
  }

  const credentials = {
    username: process.env.DB_USERNAME,
    password: process.env.DB_PASSWORD
  };

  if (!credentials.username || !credentials.password) {
    console.error('❌ Credenciais são obrigatórias');
    console.log('Defina DB_USERNAME e DB_PASSWORD');
    process.exit(1);
  }

  const tester = new ReplicationLagTester(clusterEndpoint, credentials);

  try {
    await tester.connect();
    await tester.startLagTesting(interval, duration);
  } catch (error) {
    console.error('❌ Erro no teste:', error);
  } finally {
    await tester.disconnect();
  }
}

if (require.main === module) {
  main();
}

module.exports = ReplicationLagTester;