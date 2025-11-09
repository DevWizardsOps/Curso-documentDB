#!/usr/bin/env node

const AWS = require('aws-sdk');
const { MongoClient } = require('mongodb');

class RTOCalculator {
  constructor(clusterIdentifier, region = 'us-east-1') {
    this.clusterIdentifier = clusterIdentifier;
    this.region = region;
    this.docdb = new AWS.DocDB({ region });
    this.cloudwatch = new AWS.CloudWatch({ region });
    this.results = {};
  }

  async analyzeCurrentRTO() {
    console.log('🔍 Analisando RTO/RPO atual...');
    console.log(`Cluster: ${this.clusterIdentifier}`);
    console.log(`Região: ${this.region}\n`);

    try {
      // Obter informações do cluster
      const clusterInfo = await this.getClusterInfo();
      
      // Calcular RTO para diferentes cenários
      const rtoScenarios = await this.calculateRTOScenarios(clusterInfo);
      
      // Calcular RPO baseado em configurações de backup
      const rpoAnalysis = await this.calculateRPO(clusterInfo);
      
      // Analisar métricas históricas
      const historicalMetrics = await this.analyzeHistoricalMetrics();
      
      // Gerar recomendações
      const recommendations = this.generateRecommendations(rtoScenarios, rpoAnalysis);
      
      this.results = {
        clusterInfo,
        rtoScenarios,
        rpoAnalysis,
        historicalMetrics,
        recommendations,
        timestamp: new Date()
      };

      this.displayResults();
      return this.results;

    } catch (error) {
      console.error('❌ Erro na análise:', error);
      throw error;
    }
  }

  async getClusterInfo() {
    console.log('📋 Coletando informações do cluster...');
    
    const response = await this.docdb.describeDBClusters({
      DBClusterIdentifier: this.clusterIdentifier
    }).promise();

    const cluster = response.DBClusters[0];
    
    const instancesResponse = await this.docdb.describeDBInstances({
      Filters: [
        {
          Name: 'db-cluster-id',
          Values: [this.clusterIdentifier]
        }
      ]
    }).promise();

    const instances = instancesResponse.DBInstances;

    return {
      clusterIdentifier: cluster.DBClusterIdentifier,
      engine: cluster.Engine,
      engineVersion: cluster.EngineVersion,
      status: cluster.Status,
      multiAZ: cluster.MultiAZ,
      backupRetentionPeriod: cluster.BackupRetentionPeriod,
      preferredBackupWindow: cluster.PreferredBackupWindow,
      instances: instances.map(instance => ({
        identifier: instance.DBInstanceIdentifier,
        class: instance.DBInstanceClass,
        availabilityZone: instance.AvailabilityZone,
        isWriter: instance.IsClusterWriter || false,
        promotionTier: instance.PromotionTier
      })),
      availabilityZones: cluster.AvailabilityZones,
      endpoint: cluster.Endpoint,
      readerEndpoint: cluster.ReaderEndpoint
    };
  }

  async calculateRTOScenarios(clusterInfo) {
    console.log('⏱️  Calculando RTO para diferentes cenários...');

    const scenarios = {
      instanceFailure: {
        description: 'Falha de instância primária (failover automático)',
        estimatedRTO: this.calculateInstanceFailoverRTO(clusterInfo),
        factors: [
          'Número de read replicas disponíveis',
          'Promotion tier configuration',
          'Health check interval',
          'DNS propagation time'
        ]
      },
      
      azFailure: {
        description: 'Falha de Availability Zone completa',
        estimatedRTO: this.calculateAZFailureRTO(clusterInfo),
        factors: [
          'Distribuição de instâncias por AZ',
          'Cross-AZ network latency',
          'Application connection timeout',
          'Load balancer health checks'
        ]
      },
      
      snapshotRestore: {
        description: 'Restauração completa de snapshot',
        estimatedRTO: this.calculateSnapshotRestoreRTO(clusterInfo),
        factors: [
          'Tamanho do cluster/dados',
          'Tipo de instância de destino',
          'Network bandwidth',
          'Snapshot location (same region vs cross-region)'
        ]
      },
      
      pointInTimeRecovery: {
        description: 'Point-in-time recovery',
        estimatedRTO: this.calculatePITRTO(clusterInfo),
        factors: [
          'Tamanho dos dados',
          'Período de recovery (quão longe no passado)',
          'Tipo de instância',
          'Configuração de rede'
        ]
      }
    };

    return scenarios;
  }

  calculateInstanceFailoverRTO(clusterInfo) {
    // Base time para failover automático
    let baseTime = 60; // 1 minuto base
    
    // Ajustar baseado no número de replicas
    const readReplicas = clusterInfo.instances.filter(i => !i.isWriter);
    if (readReplicas.length === 0) {
      baseTime += 300; // +5 min se não há replicas (precisa criar nova instância)
    } else if (readReplicas.length === 1) {
      baseTime += 30; // +30s com 1 replica
    }
    // Com 2+ replicas, mantém tempo base
    
    // Ajustar baseado na distribuição de AZ
    const azs = new Set(clusterInfo.instances.map(i => i.availabilityZone));
    if (azs.size === 1) {
      baseTime += 60; // +1 min se todas instâncias na mesma AZ
    }

    return {
      min: Math.max(30, baseTime - 30),
      max: baseTime + 60,
      typical: baseTime,
      unit: 'seconds'
    };
  }

  calculateAZFailureRTO(clusterInfo) {
    const azDistribution = {};
    clusterInfo.instances.forEach(instance => {
      azDistribution[instance.availabilityZone] = (azDistribution[instance.availabilityZone] || 0) + 1;
    });

    const azCount = Object.keys(azDistribution).length;
    
    let baseTime = 120; // 2 minutos base para AZ failure
    
    if (azCount === 1) {
      baseTime = 1800; // 30 min se todas instâncias na mesma AZ
    } else if (azCount === 2) {
      baseTime = 180; // 3 min com 2 AZs
    }
    // Com 3+ AZs, mantém tempo base

    return {
      min: Math.max(60, baseTime - 60),
      max: baseTime + 300,
      typical: baseTime,
      unit: 'seconds'
    };
  }

  calculateSnapshotRestoreRTO(clusterInfo) {
    // Estimar baseado no tamanho típico e classe de instância
    const instanceClass = clusterInfo.instances[0]?.class || 'db.t3.medium';
    
    let baseTimeMinutes = 15; // Base para cluster pequeno
    
    // Ajustar baseado na classe da instância
    if (instanceClass.includes('t3.small')) {
      baseTimeMinutes = 25;
    } else if (instanceClass.includes('t3.large')) {
      baseTimeMinutes = 10;
    } else if (instanceClass.includes('r5')) {
      baseTimeMinutes = 8;
    }

    // Adicionar tempo para múltiplas instâncias
    const instanceCount = clusterInfo.instances.length;
    baseTimeMinutes += (instanceCount - 1) * 5;

    return {
      min: Math.max(10, baseTimeMinutes - 5),
      max: baseTimeMinutes + 15,
      typical: baseTimeMinutes,
      unit: 'minutes'
    };
  }

  calculatePITRTO(clusterInfo) {
    // PITR geralmente leva mais tempo que snapshot restore
    const snapshotRTO = this.calculateSnapshotRestoreRTO(clusterInfo);
    
    return {
      min: snapshotRTO.min + 5,
      max: snapshotRTO.max + 20,
      typical: snapshotRTO.typical + 10,
      unit: 'minutes'
    };
  }

  async calculateRPO(clusterInfo) {
    console.log('📊 Analisando RPO (Recovery Point Objective)...');

    const rpoAnalysis = {
      automaticBackup: {
        description: 'Backup automático contínuo',
        rpo: {
          typical: 5,
          max: 15,
          unit: 'minutes'
        },
        details: `Retention: ${clusterInfo.backupRetentionPeriod} dias, Window: ${clusterInfo.preferredBackupWindow}`
      },
      
      manualSnapshot: {
        description: 'Snapshots manuais',
        rpo: {
          typical: 'Variável',
          max: 'Baseado na frequência',
          unit: 'hours/days'
        },
        details: 'Depende da estratégia de snapshots manuais implementada'
      },
      
      crossRegionBackup: {
        description: 'Backup cross-region',
        rpo: {
          typical: 60,
          max: 1440,
          unit: 'minutes'
        },
        details: 'Baseado na frequência de cópia de snapshots entre regiões'
      }
    };

    return rpoAnalysis;
  }

  async analyzeHistoricalMetrics() {
    console.log('📈 Analisando métricas históricas...');

    try {
      const endTime = new Date();
      const startTime = new Date(endTime.getTime() - (7 * 24 * 60 * 60 * 1000)); // 7 dias atrás

      // Buscar métricas de CPU para avaliar carga
      const cpuMetrics = await this.cloudwatch.getMetricStatistics({
        Namespace: 'AWS/DocDB',
        MetricName: 'CPUUtilization',
        Dimensions: [
          {
            Name: 'DBClusterIdentifier',
            Value: this.clusterIdentifier
          }
        ],
        StartTime: startTime,
        EndTime: endTime,
        Period: 3600, // 1 hora
        Statistics: ['Average', 'Maximum']
      }).promise();

      // Buscar métricas de conexões
      const connectionMetrics = await this.cloudwatch.getMetricStatistics({
        Namespace: 'AWS/DocDB',
        MetricName: 'DatabaseConnections',
        Dimensions: [
          {
            Name: 'DBClusterIdentifier',
            Value: this.clusterIdentifier
          }
        ],
        StartTime: startTime,
        EndTime: endTime,
        Period: 3600,
        Statistics: ['Average', 'Maximum']
      }).promise();

      return {
        cpuUtilization: this.analyzeMetricData(cpuMetrics.Datapoints),
        connections: this.analyzeMetricData(connectionMetrics.Datapoints),
        analysisPeriod: {
          start: startTime,
          end: endTime,
          days: 7
        }
      };

    } catch (error) {
      console.log('⚠️  Não foi possível obter métricas históricas:', error.message);
      return {
        error: 'Métricas não disponíveis',
        reason: error.message
      };
    }
  }

  analyzeMetricData(datapoints) {
    if (!datapoints || datapoints.length === 0) {
      return { error: 'Sem dados disponíveis' };
    }

    const averages = datapoints.map(dp => dp.Average).filter(v => v !== undefined);
    const maximums = datapoints.map(dp => dp.Maximum).filter(v => v !== undefined);

    return {
      avgValue: averages.reduce((sum, val) => sum + val, 0) / averages.length,
      maxValue: Math.max(...maximums),
      minValue: Math.min(...averages),
      dataPoints: datapoints.length
    };
  }

  generateRecommendations(rtoScenarios, rpoAnalysis) {
    console.log('💡 Gerando recomendações...');

    const recommendations = [];

    // Analisar RTO
    const instanceFailoverRTO = rtoScenarios.instanceFailure.estimatedRTO.typical;
    
    if (instanceFailoverRTO > 120) {
      recommendations.push({
        category: 'RTO Optimization',
        priority: 'High',
        issue: 'RTO de failover acima de 2 minutos',
        recommendation: 'Adicionar mais read replicas e configurar promotion tiers',
        expectedImprovement: 'Reduzir RTO para 60-90 segundos'
      });
    }

    // Analisar distribuição de AZ
    const azFailoverRTO = rtoScenarios.azFailure.estimatedRTO.typical;
    
    if (azFailoverRTO > 300) {
      recommendations.push({
        category: 'High Availability',
        priority: 'Critical',
        issue: 'RTO alto para falha de AZ',
        recommendation: 'Distribuir instâncias em múltiplas AZs',
        expectedImprovement: 'Reduzir RTO para menos de 3 minutos'
      });
    }

    // Analisar RPO
    const backupRPO = rpoAnalysis.automaticBackup.rpo.typical;
    
    if (backupRPO > 10) {
      recommendations.push({
        category: 'RPO Optimization',
        priority: 'Medium',
        issue: 'RPO pode ser otimizado',
        recommendation: 'Implementar snapshots mais frequentes ou replicação cross-region',
        expectedImprovement: 'Reduzir RPO para menos de 5 minutos'
      });
    }

    // Recomendações gerais
    recommendations.push({
      category: 'Monitoring',
      priority: 'Medium',
      issue: 'Monitoramento proativo',
      recommendation: 'Implementar alertas para métricas de RTO/RPO',
      expectedImprovement: 'Detecção precoce de problemas'
    });

    recommendations.push({
      category: 'Disaster Recovery',
      priority: 'Low',
      issue: 'Preparação para disaster recovery',
      recommendation: 'Configurar backup cross-region e plano de DR',
      expectedImprovement: 'Proteção contra falhas regionais'
    });

    return recommendations;
  }

  displayResults() {
    console.log('\n' + '='.repeat(60));
    console.log('📊 RELATÓRIO DE ANÁLISE RTO/RPO');
    console.log('='.repeat(60));

    // Informações do cluster
    console.log('\n🏗️  INFORMAÇÕES DO CLUSTER');
    console.log(`Cluster: ${this.results.clusterInfo.clusterIdentifier}`);
    console.log(`Engine: ${this.results.clusterInfo.engine} ${this.results.clusterInfo.engineVersion}`);
    console.log(`Status: ${this.results.clusterInfo.status}`);
    console.log(`Multi-AZ: ${this.results.clusterInfo.multiAZ ? 'Sim' : 'Não'}`);
    console.log(`Instâncias: ${this.results.clusterInfo.instances.length}`);
    console.log(`AZs utilizadas: ${this.results.clusterInfo.availabilityZones.length}`);

    // RTO Scenarios
    console.log('\n⏱️  ANÁLISE DE RTO');
    Object.entries(this.results.rtoScenarios).forEach(([scenario, data]) => {
      console.log(`\n${scenario.toUpperCase()}:`);
      console.log(`  Descrição: ${data.description}`);
      console.log(`  RTO Típico: ${data.estimatedRTO.typical} ${data.estimatedRTO.unit}`);
      console.log(`  RTO Mínimo: ${data.estimatedRTO.min} ${data.estimatedRTO.unit}`);
      console.log(`  RTO Máximo: ${data.estimatedRTO.max} ${data.estimatedRTO.unit}`);
    });

    // RPO Analysis
    console.log('\n📊 ANÁLISE DE RPO');
    Object.entries(this.results.rpoAnalysis).forEach(([type, data]) => {
      console.log(`\n${type.toUpperCase()}:`);
      console.log(`  Descrição: ${data.description}`);
      console.log(`  RPO Típico: ${data.rpo.typical} ${data.rpo.unit}`);
      console.log(`  Detalhes: ${data.details}`);
    });

    // Recommendations
    console.log('\n💡 RECOMENDAÇÕES');
    this.results.recommendations.forEach((rec, index) => {
      const priority = rec.priority === 'Critical' ? '🔴' : 
                      rec.priority === 'High' ? '🟡' : 
                      rec.priority === 'Medium' ? '🟠' : '🟢';
      
      console.log(`\n${index + 1}. ${priority} ${rec.category} (${rec.priority})`);
      console.log(`   Problema: ${rec.issue}`);
      console.log(`   Recomendação: ${rec.recommendation}`);
      console.log(`   Melhoria esperada: ${rec.expectedImprovement}`);
    });

    console.log('\n' + '='.repeat(60));
  }

  async saveResults(filename) {
    const fs = require('fs').promises;
    
    try {
      await fs.writeFile(filename, JSON.stringify(this.results, null, 2));
      console.log(`📄 Resultados salvos em: ${filename}`);
    } catch (error) {
      console.error('❌ Erro ao salvar resultados:', error);
    }
  }
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);
  
  if (args.includes('--help')) {
    console.log('Uso: node rto-calculator.js [opções]');
    console.log('Opções:');
    console.log('  --cluster <identifier>  Identificador do cluster');
    console.log('  --region <region>       Região AWS (padrão: us-east-1)');
    console.log('  --environment <env>     Ambiente (production, staging, development)');
    console.log('  --output <file>         Salvar resultados em arquivo JSON');
    console.log('  --help                  Mostrar esta ajuda');
    return;
  }

  const clusterIdentifier = args[args.indexOf('--cluster') + 1] || process.env.CLUSTER_ID;
  const region = args[args.indexOf('--region') + 1] || 'us-east-1';
  const environment = args[args.indexOf('--environment') + 1] || 'production';
  const outputFile = args[args.indexOf('--output') + 1];

  if (!clusterIdentifier) {
    console.error('❌ Identificador do cluster é obrigatório');
    console.log('Use: --cluster <identifier> ou defina CLUSTER_ID');
    process.exit(1);
  }

  const calculator = new RTOCalculator(clusterIdentifier, region);

  try {
    await calculator.analyzeCurrentRTO();
    
    if (outputFile) {
      await calculator.saveResults(outputFile);
    }
    
    console.log('\n✅ Análise concluída com sucesso!');
  } catch (error) {
    console.error('❌ Erro na análise:', error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = RTOCalculator;