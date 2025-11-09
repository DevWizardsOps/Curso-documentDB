# Exercício 5: Ajustes Avançados de Cluster e Parâmetros

## 🎯 Objetivos

- Criar e configurar parameter groups customizados
- Ajustar parâmetros específicos para diferentes workloads
- Otimizar recursos de instância e configurações de cluster
- Monitorar impacto das mudanças de configuração

## ⏱️ Duração Estimada
90 minutos

> ⚠️ **Atenção:** Lembre-se de usar seu prefixo de aluno (`<seu-id>`) em todos os nomes de recursos e comandos.

---

## ⚙️ Parte 1: Criação de Parameter Groups Customizados

### Passo 1: Parameter Group para Performance

```bash
# Configurar variáveis
export ID="<seu-id>"
export CLUSTER_ID="$ID-lab-cluster-console"

# Criar parameter group otimizado para performance
aws docdb create-db-cluster-parameter-group \
--db-cluster-parameter-group-name $ID-performance-params \
--db-parameter-group-family docdb4.0 \
--description "Parameter group otimizado para performance - Aluno $ID"

# Verificar criação
aws docdb describe-db-cluster-parameter-groups \
--db-cluster-parameter-group-name $ID-performance-params
```

### Passo 2: Configurar Parâmetros de Performance

```bash
# Configurar parâmetros para workloads de alta performance
aws docdb modify-db-cluster-parameter-group \
--db-cluster-parameter-group-name $ID-performance-params \
--parameters \
'[
  {
    "ParameterName": "audit_logs",
    "ParameterValue": "disabled",
    "ApplyMethod": "pending-reboot"
  },
  {
    "ParameterName": "profiler",
    "ParameterValue": "disabled",
    "ApplyMethod": "pending-reboot"
  },
  {
    "ParameterName": "profiler_threshold_ms",
    "ParameterValue": "100",
    "ApplyMethod": "pending-reboot"
  },
  {
    "ParameterName": "profiler_sampling_rate",
    "ParameterValue": "1.0",
    "ApplyMethod": "pending-reboot"
  }
]'

# Verificar parâmetros configurados
aws docdb describe-db-cluster-parameters \
--db-cluster-parameter-group-name $ID-performance-params \
--query 'Parameters[?ParameterValue!=`null`].{Name:ParameterName,Value:ParameterValue,Method:ApplyMethod}'
```

### Passo 3: Parameter Group para Analytics

```bash
# Criar parameter group para workloads de analytics
aws docdb create-db-cluster-parameter-group \
--db-cluster-parameter-group-name $ID-analytics-params \
--db-parameter-group-family docdb4.0 \
--description "Parameter group otimizado para analytics - Aluno $ID"

# Configurar parâmetros para analytics (queries longas)
aws docdb modify-db-cluster-parameter-group \
--db-cluster-parameter-group-name $ID-analytics-params \
--parameters \
'[
  {
    "ParameterName": "audit_logs",
    "ParameterValue": "enabled",
    "ApplyMethod": "pending-reboot"
  },
  {
    "ParameterName": "profiler",
    "ParameterValue": "enabled",
    "ApplyMethod": "pending-reboot"
  },
  {
    "ParameterName": "profiler_threshold_ms",
    "ParameterValue": "1000",
    "ApplyMethod": "pending-reboot"
  },
  {
    "ParameterName": "profiler_sampling_rate",
    "ParameterValue": "0.1",
    "ApplyMethod": "pending-reboot"
  }
]'
```

---

## 🔧 Parte 2: Aplicação de Parameter Groups

### Passo 1: Aplicar Parameter Group de Performance

```bash
# Aplicar parameter group ao cluster
aws docdb modify-db-cluster \
--db-cluster-identifier $CLUSTER_ID \
--db-cluster-parameter-group-name $ID-performance-params \
--apply-immediately

# Aguardar aplicação das mudanças
aws docdb wait db-cluster-available --db-cluster-identifier $CLUSTER_ID

echo "Parameter group aplicado. Reinicializando instâncias para aplicar mudanças..."

# Obter lista de instâncias do cluster
INSTANCES=$(aws docdb describe-db-clusters \
--db-cluster-identifier $CLUSTER_ID \
--query 'DBClusters[0].DBClusterMembers[].DBInstanceIdentifier' \
--output text)

# Reinicializar cada instância para aplicar parâmetros
for instance in $INSTANCES; do
  echo "Reinicializando instância: $instance"
  aws docdb reboot-db-instance \
  --db-instance-identifier $instance
  
  # Aguardar instância ficar disponível
  aws docdb wait db-instance-available \
  --db-instance-identifier $instance
done

echo "Todas as instâncias foram reinicializadas e estão disponíveis."
```

### Passo 2: Verificar Aplicação dos Parâmetros

```bash
# Verificar parâmetros ativos no cluster
aws docdb describe-db-clusters \
--db-cluster-identifier $CLUSTER_ID \
--query 'DBClusters[0].{ParameterGroup:DBClusterParameterGroup,Status:Status}'

# Conectar e verificar parâmetros via MongoDB
mongosh --host $CLUSTER_ENDPOINT:27017 \
--username $DB_USERNAME \
--password $DB_PASSWORD \
--ssl \
--sslCAFile global-bundle.pem \
--eval "
// Verificar configurações ativas
db.runCommand({getParameter: '*'})
"
```

---

## 📊 Parte 3: Monitoramento de Impacto das Mudanças

### Passo 1: Baseline Antes das Mudanças

```javascript
// Script para coletar baseline de performance
class PerformanceBaseline {
  constructor(client) {
    this.client = client;
    this.baseline = {};
  }

  async collectBaseline() {
    console.log('Collecting performance baseline...');
    
    // Teste de queries simples
    const simpleQueryTime = await this.measureSimpleQueries();
    
    // Teste de agregações
    const aggregationTime = await this.measureAggregations();
    
    // Teste de inserções
    const insertTime = await this.measureInserts();
    
    // Teste de atualizações
    const updateTime = await this.measureUpdates();

    this.baseline = {
      simpleQuery: simpleQueryTime,
      aggregation: aggregationTime,
      insert: insertTime,
      update: updateTime,
      timestamp: new Date()
    };

    console.log('Baseline collected:', this.baseline);
    return this.baseline;
  }

  async measureSimpleQueries(iterations = 100) {
    const db = this.client.db('performanceDB');
    const start = Date.now();
    
    for (let i = 0; i < iterations; i++) {
      await db.collection('products').findOne({category: 'electronics'});
    }
    
    return (Date.now() - start) / iterations;
  }

  async measureAggregations(iterations = 10) {
    const db = this.client.db('performanceDB');
    const start = Date.now();
    
    for (let i = 0; i < iterations; i++) {
      await db.collection('products').aggregate([
        {$match: {category: 'electronics'}},
        {$group: {_id: '$brand', count: {$sum: 1}, avgPrice: {$avg: '$price'}}},
        {$sort: {count: -1}}
      ]).toArray();
    }
    
    return (Date.now() - start) / iterations;
  }

  async measureInserts(iterations = 100) {
    const db = this.client.db('performanceDB');
    const start = Date.now();
    
    const documents = Array.from({length: iterations}, (_, i) => ({
      name: `Test Product ${i}`,
      category: 'test',
      price: Math.random() * 1000,
      createdAt: new Date()
    }));
    
    await db.collection('test_products').insertMany(documents);
    
    return (Date.now() - start) / iterations;
  }

  async measureUpdates(iterations = 100) {
    const db = this.client.db('performanceDB');
    const start = Date.now();
    
    for (let i = 0; i < iterations; i++) {
      await db.collection('products').updateOne(
        {_id: i + 1},
        {$set: {lastUpdated: new Date()}}
      );
    }
    
    return (Date.now() - start) / iterations;
  }
}
```

### Passo 2: Monitoramento Contínuo

```bash
# Script de monitoramento contínuo de performance
cat > scripts/parameter-impact-monitor.sh << 'EOF'
#!/bin/bash

ID="<seu-id>"
CLUSTER_ENDPOINT="$ID-lab-cluster-console.cluster-xxxxxxxxx.us-east-1.docdb.amazonaws.com"
INTERVAL=60

echo "Monitoring parameter impact for cluster: $ID-lab-cluster-console"
echo "Timestamp,AvgQueryTime,AvgAggregationTime,AvgInsertTime,AvgUpdateTime"

while true; do
    # Executar testes de performance
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Executar script Node.js para medir performance
    RESULTS=$(node scripts/measure-performance.js)
    
    echo "$TIMESTAMP,$RESULTS"
    
    # Enviar métricas para CloudWatch
    aws cloudwatch put-metric-data \
    --namespace Custom/DocumentDB/ParameterTuning \
    --metric-data file://metrics-data.json
    
    sleep $INTERVAL
done
EOF

chmod +x scripts/parameter-impact-monitor.sh
```

---

## 🎯 Parte 4: Otimização Específica por Workload

### Cenário 1: Workload OLTP (Transacional)

```bash
# Parameter group para OLTP
aws docdb create-db-cluster-parameter-group \
--db-cluster-parameter-group-name $ID-oltp-params \
--db-parameter-group-family docdb4.0 \
--description "Otimizado para workloads OLTP - Aluno $ID"

# Configurações OLTP
aws docdb modify-db-cluster-parameter-group \
--db-cluster-parameter-group-name $ID-oltp-params \
--parameters \
'[
  {
    "ParameterName": "audit_logs",
    "ParameterValue": "disabled",
    "ApplyMethod": "pending-reboot"
  },
  {
    "ParameterName": "profiler",
    "ParameterValue": "disabled",
    "ApplyMethod": "pending-reboot"
  }
]'
```

### Cenário 2: Workload OLAP (Analítico)

```bash
# Parameter group para OLAP
aws docdb create-db-cluster-parameter-group \
--db-cluster-parameter-group-name $ID-olap-params \
--db-parameter-group-family docdb4.0 \
--description "Otimizado para workloads OLAP - Aluno $ID"

# Configurações OLAP
aws docdb modify-db-cluster-parameter-group \
--db-cluster-parameter-group-name $ID-olap-params \
--parameters \
'[
  {
    "ParameterName": "audit_logs",
    "ParameterValue": "enabled",
    "ApplyMethod": "pending-reboot"
  },
  {
    "ParameterName": "profiler",
    "ParameterValue": "enabled",
    "ApplyMethod": "pending-reboot"
  },
  {
    "ParameterName": "profiler_threshold_ms",
    "ParameterValue": "2000",
    "ApplyMethod": "pending-reboot"
  }
]'
```

---

## 🔍 Parte 5: Análise de Performance Pós-Tuning

### Passo 1: Comparação de Performance

```javascript
class PerformanceComparator {
  constructor(client) {
    this.client = client;
  }

  async comparePerformance(baseline, current) {
    console.log('\n=== PERFORMANCE COMPARISON ===');
    
    const metrics = ['simpleQuery', 'aggregation', 'insert', 'update'];
    
    metrics.forEach(metric => {
      const baselineValue = baseline[metric];
      const currentValue = current[metric];
      const improvement = ((baselineValue - currentValue) / baselineValue) * 100;
      
      console.log(`${metric}:`);
      console.log(`  Baseline: ${baselineValue.toFixed(2)}ms`);
      console.log(`  Current:  ${currentValue.toFixed(2)}ms`);
      console.log(`  Change:   ${improvement > 0 ? '+' : ''}${improvement.toFixed(2)}%`);
      console.log('');
    });

    return this.calculateOverallImprovement(baseline, current);
  }

  calculateOverallImprovement(baseline, current) {
    const metrics = ['simpleQuery', 'aggregation', 'insert', 'update'];
    let totalImprovement = 0;
    
    metrics.forEach(metric => {
      const improvement = ((baseline[metric] - current[metric]) / baseline[metric]) * 100;
      totalImprovement += improvement;
    });

    return totalImprovement / metrics.length;
  }

  async generateDetailedReport() {
    const report = {
      timestamp: new Date(),
      clusterInfo: await this.getClusterInfo(),
      parameterGroups: await this.getParameterGroups(),
      performanceMetrics: await this.getCurrentMetrics(),
      recommendations: this.generateRecommendations()
    };

    console.log('\n=== DETAILED PERFORMANCE REPORT ===');
    console.log(JSON.stringify(report, null, 2));
    
    return report;
  }

  async getClusterInfo() {
    // Simular obtenção de informações do cluster
    return {
      instanceClass: 'db.t3.medium',
      instanceCount: 1,
      engine: 'docdb',
      version: '4.0.0'
    };
  }

  async getParameterGroups() {
    // Simular obtenção de parameter groups
    return {
      current: process.env.ID + '-performance-params',
      applied: true,
      lastModified: new Date()
    };
  }

  async getCurrentMetrics() {
    const baseline = new PerformanceBaseline(this.client);
    return await baseline.collectBaseline();
  }

  generateRecommendations() {
    return [
      'Consider enabling profiler for detailed query analysis',
      'Monitor audit logs impact on write performance',
      'Evaluate instance scaling based on workload patterns',
      'Implement read replicas for read-heavy workloads'
    ];
  }
}
```

### Passo 2: Teste A/B de Configurações

```bash
# Script para teste A/B de parameter groups
cat > scripts/ab-test-parameters.sh << 'EOF'
#!/bin/bash

ID="<seu-id>"
CLUSTER_ID="$ID-lab-cluster-console"

echo "Starting A/B test of parameter configurations..."

# Teste A: Performance parameters
echo "Testing Configuration A (Performance optimized)..."
aws docdb modify-db-cluster \
--db-cluster-identifier $CLUSTER_ID \
--db-cluster-parameter-group-name $ID-performance-params \
--apply-immediately

# Aguardar aplicação e reinicializar
sleep 60
./restart-cluster-instances.sh

# Executar testes de performance
node scripts/run-performance-test.js --config A --duration 300

# Teste B: Analytics parameters  
echo "Testing Configuration B (Analytics optimized)..."
aws docdb modify-db-cluster \
--db-cluster-identifier $CLUSTER_ID \
--db-cluster-parameter-group-name $ID-analytics-params \
--apply-immediately

# Aguardar aplicação e reinicializar
sleep 60
./restart-cluster-instances.sh

# Executar testes de performance
node scripts/run-performance-test.js --config B --duration 300

echo "A/B test completed. Check results in performance-results.json"
EOF

chmod +x scripts/ab-test-parameters.sh
```

---

## 📈 Parte 6: Otimização de Recursos de Instância

### Passo 1: Análise de Utilização de Recursos

```bash
# Coletar métricas de utilização de recursos
aws cloudwatch get-metric-statistics \
--namespace AWS/DocDB \
--metric-name CPUUtilization \
--dimensions Name=DBClusterIdentifier,Value=$CLUSTER_ID \
--start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
--end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
--period 300 \
--statistics Average,Maximum \
--query 'Datapoints[*].[Timestamp,Average,Maximum]' \
--output table

# Métricas de memória
aws cloudwatch get-metric-statistics \
--namespace AWS/DocDB \
--metric-name FreeableMemory \
--dimensions Name=DBClusterIdentifier,Value=$CLUSTER_ID \
--start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
--end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
--period 300 \
--statistics Average,Minimum \
--query 'Datapoints[*].[Timestamp,Average,Minimum]' \
--output table
```

### Passo 2: Recomendações de Scaling

```javascript
class ResourceOptimizer {
  constructor() {
    this.thresholds = {
      cpu: { high: 80, low: 20 },
      memory: { high: 85, low: 30 },
      connections: { high: 80, low: 10 }
    };
  }

  analyzeResourceUtilization(metrics) {
    const recommendations = [];

    // Análise de CPU
    if (metrics.avgCPU > this.thresholds.cpu.high) {
      recommendations.push({
        type: 'SCALE_UP',
        resource: 'CPU',
        reason: `CPU utilization (${metrics.avgCPU}%) exceeds threshold (${this.thresholds.cpu.high}%)`,
        action: 'Consider upgrading to a larger instance class'
      });
    } else if (metrics.avgCPU < this.thresholds.cpu.low) {
      recommendations.push({
        type: 'SCALE_DOWN',
        resource: 'CPU',
        reason: `CPU utilization (${metrics.avgCPU}%) is below threshold (${this.thresholds.cpu.low}%)`,
        action: 'Consider downgrading to a smaller instance class'
      });
    }

    // Análise de Memória
    const memoryUtilization = ((metrics.totalMemory - metrics.freeMemory) / metrics.totalMemory) * 100;
    if (memoryUtilization > this.thresholds.memory.high) {
      recommendations.push({
        type: 'SCALE_UP',
        resource: 'MEMORY',
        reason: `Memory utilization (${memoryUtilization.toFixed(1)}%) exceeds threshold (${this.thresholds.memory.high}%)`,
        action: 'Consider upgrading to a memory-optimized instance class'
      });
    }

    // Análise de Conexões
    const connectionUtilization = (metrics.activeConnections / metrics.maxConnections) * 100;
    if (connectionUtilization > this.thresholds.connections.high) {
      recommendations.push({
        type: 'OPTIMIZE',
        resource: 'CONNECTIONS',
        reason: `Connection utilization (${connectionUtilization.toFixed(1)}%) is high`,
        action: 'Optimize connection pooling or add read replicas'
      });
    }

    return recommendations;
  }

  generateScalingPlan(currentInstanceClass, recommendations) {
    const instanceClasses = {
      'db.t3.medium': { cpu: 2, memory: 4, next_up: 'db.r5.large', next_down: 'db.t3.small' },
      'db.r5.large': { cpu: 2, memory: 16, next_up: 'db.r5.xlarge', next_down: 'db.t3.medium' },
      'db.r5.xlarge': { cpu: 4, memory: 32, next_up: 'db.r5.2xlarge', next_down: 'db.r5.large' }
    };

    const plan = {
      current: currentInstanceClass,
      recommendations: recommendations,
      suggestedActions: []
    };

    recommendations.forEach(rec => {
      if (rec.type === 'SCALE_UP' && instanceClasses[currentInstanceClass]?.next_up) {
        plan.suggestedActions.push({
          action: 'UPGRADE_INSTANCE',
          from: currentInstanceClass,
          to: instanceClasses[currentInstanceClass].next_up,
          reason: rec.reason
        });
      } else if (rec.type === 'SCALE_DOWN' && instanceClasses[currentInstanceClass]?.next_down) {
        plan.suggestedActions.push({
          action: 'DOWNGRADE_INSTANCE',
          from: currentInstanceClass,
          to: instanceClasses[currentInstanceClass].next_down,
          reason: rec.reason
        });
      }
    });

    return plan;
  }
}
```

---

## ✅ Checklist de Conclusão

Execute o script de validação:

```bash
# Executa o grade para avaliar atividades
./grade_exercicio5.sh
```

### Itens Verificados:

- ✅ Parameter groups customizados criados
- ✅ Parâmetros otimizados para diferentes workloads
- ✅ Monitoramento de impacto das mudanças
- ✅ Comparação de performance antes/depois
- ✅ Análise de utilização de recursos
- ✅ Recomendações de scaling geradas

---

## 🧹 Limpeza

```bash
# Reverter para parameter group padrão
aws docdb modify-db-cluster \
--db-cluster-identifier $CLUSTER_ID \
--db-cluster-parameter-group-name default.docdb4.0 \
--apply-immediately

# Deletar parameter groups customizados
aws docdb delete-db-cluster-parameter-group \
--db-cluster-parameter-group-name $ID-performance-params

aws docdb delete-db-cluster-parameter-group \
--db-cluster-parameter-group-name $ID-analytics-params

aws docdb delete-db-cluster-parameter-group \
--db-cluster-parameter-group-name $ID-oltp-params

aws docdb delete-db-cluster-parameter-group \
--db-cluster-parameter-group-name $ID-olap-params

# Parar monitoramento
pkill -f "parameter-impact-monitor"

# Limpar dados de teste
mongosh --host $CLUSTER_ENDPOINT:27017 \
--username $DB_USERNAME \
--password $DB_PASSWORD \
--ssl \
--sslCAFile global-bundle.pem \
--eval "db.test_products.drop()"
```

---

## 📊 Resumo de Otimizações

### Parâmetros Otimizados:

1. **Performance Workload:**
   - audit_logs: disabled (reduz overhead)
   - profiler: disabled (máxima performance)
   - Melhoria esperada: 15-25%

2. **Analytics Workload:**
   - audit_logs: enabled (rastreabilidade)
   - profiler: enabled (análise de queries)
   - profiler_threshold_ms: 1000ms (queries longas)

3. **OLTP Workload:**
   - Configuração otimizada para transações rápidas
   - Minimal logging overhead
   - Melhoria esperada: 20-30%

4. **OLAP Workload:**
   - Configuração para queries complexas
   - Profiling detalhado habilitado
   - Foco em throughput vs latência

### Melhorias de Performance Alcançadas:

- **Queries Simples:** 15-25% de melhoria
- **Agregações:** 10-20% de melhoria  
- **Inserções em Lote:** 20-35% de melhoria
- **Utilização de Recursos:** Otimizada por workload

---

[⬅️ Exercício 4](../exercicio4-conexoes-latencia/README.md) | [🏠 Módulo 4 Home](../README.md)