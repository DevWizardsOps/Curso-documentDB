# Exercício 1: Replicação Avançada e Multi-AZ

## 🎯 Objetivos

- Configurar replicação otimizada em múltiplas Availability Zones
- Monitorar e otimizar replication lag
- Implementar failover automático avançado
- Testar cenários de falha de AZ completa

## ⏱️ Duração Estimada
90 minutos

> ⚠️ **Atenção:** Lembre-se de usar seu prefixo de aluno (`<seu-id>`) em todos os nomes de recursos e comandos.

---

## 🏗️ Parte 1: Configuração Multi-AZ Avançada

### Passo 1: Analisar Configuração Atual

```bash
# Configurar variáveis
export ID="<seu-id>"
export CLUSTER_ID="$ID-lab-cluster-console"

# Verificar distribuição atual de instâncias por AZ
aws docdb describe-db-instances \
--query "DBInstances[?DBClusterIdentifier=='$CLUSTER_ID'].{Instance:DBInstanceIdentifier,AZ:AvailabilityZone,Class:DBInstanceClass,Status:DBInstanceStatus}" \
--output table

# Verificar configuração do cluster
aws docdb describe-db-clusters \
--db-cluster-identifier $CLUSTER_ID \
--query 'DBClusters[0].{MultiAZ:MultiAZ,BackupRetention:BackupRetentionPeriod,AvailabilityZones:AvailabilityZones}' \
--output table
```

### Passo 2: Criar Read Replicas em AZs Diferentes

```bash
# Obter AZs disponíveis na região
AVAILABLE_AZS=$(aws ec2 describe-availability-zones \
--query 'AvailabilityZones[?State==`available`].ZoneName' \
--output text)

echo "AZs disponíveis: $AVAILABLE_AZS"

# Criar read replica na segunda AZ
aws docdb create-db-instance \
--db-instance-identifier $ID-replica-az2 \
--db-instance-class db.t3.medium \
--engine docdb \
--db-cluster-identifier $CLUSTER_ID \
--availability-zone $(echo $AVAILABLE_AZS | cut -d' ' -f2) \
--promotion-tier 1

# Criar read replica na terceira AZ
aws docdb create-db-instance \
--db-instance-identifier $ID-replica-az3 \
--db-instance-class db.t3.medium \
--engine docdb \
--db-cluster-identifier $CLUSTER_ID \
--availability-zone $(echo $AVAILABLE_AZS | cut -d' ' -f3) \
--promotion-tier 2

# Aguardar criação das replicas
echo "Aguardando criação das read replicas..."
aws docdb wait db-instance-available --db-instance-identifier $ID-replica-az2
aws docdb wait db-instance-available --db-instance-identifier $ID-replica-az3

echo "Read replicas criadas com sucesso!"
```

### Passo 3: Configurar Promotion Tiers Otimizados

```bash
# Configurar tiers de promoção para failover otimizado
# Tier 0 = maior prioridade, Tier 15 = menor prioridade

# Primary instance (tier 0)
PRIMARY_INSTANCE=$(aws docdb describe-db-clusters \
--db-cluster-identifier $CLUSTER_ID \
--query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' \
--output text)

aws docdb modify-db-instance \
--db-instance-identifier $PRIMARY_INSTANCE \
--promotion-tier 0 \
--apply-immediately

# Read replica AZ2 (tier 1 - primeira opção de failover)
aws docdb modify-db-instance \
--db-instance-identifier $ID-replica-az2 \
--promotion-tier 1 \
--apply-immediately

# Read replica AZ3 (tier 2 - segunda opção de failover)
aws docdb modify-db-instance \
--db-instance-identifier $ID-replica-az3 \
--promotion-tier 2 \
--apply-immediately

echo "Promotion tiers configurados!"
```

---

## 📊 Parte 2: Monitoramento de Replication Lag

### Passo 1: Configurar Métricas de Replicação

```bash
# Criar alarme para replication lag
aws cloudwatch put-metric-alarm \
--alarm-name "$ID-ReplicationLag-High" \
--alarm-description "Replication lag alto detectado" \
--metric-name DatabaseConnections \
--namespace AWS/DocDB \
--statistic Average \
--period 300 \
--evaluation-periods 2 \
--threshold 10 \
--comparison-operator GreaterThanThreshold \
--dimensions Name=DBClusterIdentifier,Value=$CLUSTER_ID

# Criar dashboard para monitoramento de replicação
aws cloudwatch put-dashboard \
--dashboard-name $ID-Replication-Monitoring \
--dashboard-body file://cloudwatch/replication-dashboard.json
```

### Passo 2: Script de Monitoramento Contínuo

```bash
# Executar script de monitoramento de lag
node scripts/test-replication-lag.js --cluster $CLUSTER_ID --interval 30
```

### Passo 3: Teste de Carga para Medir Lag

```javascript
// O script test-replication-lag.js irá:
// 1. Inserir dados no primary
// 2. Verificar quando aparecem nas replicas
// 3. Medir o lag de replicação
// 4. Gerar relatório de performance
```

---

## 🔄 Parte 3: Testes de Failover Avançados

### Cenário 1: Failover Planejado com Validação

```bash
# Script automatizado de teste de failover
./scripts/advanced-failover-test.sh $CLUSTER_ID

# O script irá:
# 1. Medir performance baseline
# 2. Executar failover
# 3. Medir tempo de recuperação
# 4. Validar integridade dos dados
# 5. Gerar relatório
```

### Cenário 2: Simulação de Falha de AZ

```bash
# Simular falha de AZ removendo instância
CURRENT_PRIMARY=$(aws docdb describe-db-clusters \
--db-cluster-identifier $CLUSTER_ID \
--query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' \
--output text)

echo "Simulando falha da instância primária: $CURRENT_PRIMARY"

# Forçar reboot com failover (simula falha de AZ)
aws docdb reboot-db-instance \
--db-instance-identifier $CURRENT_PRIMARY \
--force-failover

# Monitorar processo de failover
echo "Monitorando failover..."
start_time=$(date +%s)

while true; do
    status=$(aws docdb describe-db-clusters \
    --db-cluster-identifier $CLUSTER_ID \
    --query 'DBClusters[0].Status' \
    --output text)
    
    if [ "$status" = "available" ]; then
        end_time=$(date +%s)
        failover_time=$((end_time - start_time))
        echo "Failover concluído em $failover_time segundos"
        break
    fi
    
    echo "Status: $status - aguardando..."
    sleep 5
done

# Verificar nova configuração
aws docdb describe-db-clusters \
--db-cluster-identifier $CLUSTER_ID \
--query 'DBClusters[0].DBClusterMembers[*].{Instance:DBInstanceIdentifier,Writer:IsClusterWriter,Tier:PromotionTier,AZ:AvailabilityZone}' \
--output table
```

---

## 🎯 Parte 4: Otimização de Performance de Replicação

### Passo 1: Configurar Connection Pooling para Read Replicas

```javascript
// Configuração otimizada para distribuição de leitura
const { MongoClient } = require('mongodb');

class ReplicationOptimizedClient {
  constructor(clusterEndpoint, replicaEndpoints) {
    this.writeClient = new MongoClient(`mongodb://${process.env.DB_USERNAME}:${process.env.DB_PASSWORD}@${clusterEndpoint}:27017/testDB?ssl=true&readPreference=primary`, {
      maxPoolSize: 50,
      minPoolSize: 5
    });
    
    this.readClients = replicaEndpoints.map(endpoint => 
      new MongoClient(`mongodb://${process.env.DB_USERNAME}:${process.env.DB_PASSWORD}@${endpoint}:27017/testDB?ssl=true&readPreference=secondary`, {
        maxPoolSize: 100,
        minPoolSize: 10
      })
    );
    
    this.currentReadIndex = 0;
  }

  async connect() {
    await this.writeClient.connect();
    await Promise.all(this.readClients.map(client => client.connect()));
  }

  getWriteClient() {
    return this.writeClient;
  }

  getReadClient() {
    // Round-robin entre read replicas
    const client = this.readClients[this.currentReadIndex];
    this.currentReadIndex = (this.currentReadIndex + 1) % this.readClients.length;
    return client;
  }

  async testReplicationLag() {
    const testDoc = {
      _id: new Date().getTime(),
      timestamp: new Date(),
      testData: 'replication-test'
    };

    // Inserir no primary
    const writeStart = Date.now();
    await this.writeClient.db('testDB').collection('replicationTest').insertOne(testDoc);
    const writeTime = Date.now() - writeStart;

    // Testar leitura em cada replica
    const replicationResults = [];
    
    for (let i = 0; i < this.readClients.length; i++) {
      const readStart = Date.now();
      let found = false;
      let attempts = 0;
      
      while (!found && attempts < 30) { // Máximo 30 segundos
        try {
          const result = await this.readClients[i].db('testDB')
            .collection('replicationTest')
            .findOne({_id: testDoc._id});
          
          if (result) {
            found = true;
            const replicationLag = Date.now() - readStart;
            replicationResults.push({
              replica: i,
              lag: replicationLag,
              attempts: attempts + 1
            });
          } else {
            attempts++;
            await new Promise(resolve => setTimeout(resolve, 1000));
          }
        } catch (error) {
          attempts++;
          await new Promise(resolve => setTimeout(resolve, 1000));
        }
      }
      
      if (!found) {
        replicationResults.push({
          replica: i,
          lag: -1,
          attempts: attempts,
          error: 'Timeout'
        });
      }
    }

    return {
      writeTime,
      replicationResults,
      averageLag: replicationResults
        .filter(r => r.lag > 0)
        .reduce((sum, r) => sum + r.lag, 0) / replicationResults.filter(r => r.lag > 0).length
    };
  }
}
```

### Passo 2: Benchmark de Performance Multi-AZ

```bash
# Executar benchmark de performance
node scripts/multi-az-benchmark.js --duration 300 --concurrent-connections 50

# O benchmark irá testar:
# - Latência de escrita no primary
# - Latência de leitura em cada replica
# - Throughput distribuído
# - Replication lag sob carga
```

---

## 📈 Parte 5: Monitoramento e Alertas Avançados

### Passo 1: Métricas Customizadas de Replicação

```bash
# Enviar métricas customizadas para CloudWatch
aws cloudwatch put-metric-data \
--namespace Custom/DocumentDB/Replication \
--metric-data \
MetricName=ReplicationLag,Value=150,Unit=Milliseconds,Dimensions=Name=ClusterIdentifier,Value=$CLUSTER_ID \
MetricName=ReplicaHealth,Value=3,Unit=Count,Dimensions=Name=ClusterIdentifier,Value=$CLUSTER_ID
```

### Passo 2: Configurar Alertas Proativos

```bash
# Alerta para lag de replicação crítico
aws cloudwatch put-metric-alarm \
--alarm-name "$ID-CriticalReplicationLag" \
--alarm-description "Lag de replicação crítico (>5s)" \
--metric-name ReplicationLag \
--namespace Custom/DocumentDB/Replication \
--statistic Average \
--period 60 \
--evaluation-periods 3 \
--threshold 5000 \
--comparison-operator GreaterThanThreshold \
--dimensions Name=ClusterIdentifier,Value=$CLUSTER_ID

# Alerta para falha de replica
aws cloudwatch put-metric-alarm \
--alarm-name "$ID-ReplicaFailure" \
--alarm-description "Uma ou mais replicas indisponíveis" \
--metric-name ReplicaHealth \
--namespace Custom/DocumentDB/Replication \
--statistic Average \
--period 300 \
--evaluation-periods 2 \
--threshold 2 \
--comparison-operator LessThanThreshold \
--dimensions Name=ClusterIdentifier,Value=$CLUSTER_ID
```

---

## 🧪 Parte 6: Testes de Stress e Recuperação

### Teste 1: Carga Sustentada com Failover

```bash
# Iniciar carga de trabalho sustentada
node scripts/sustained-workload.js --duration 1800 &
WORKLOAD_PID=$!

# Aguardar 5 minutos, depois executar failover
sleep 300
aws docdb failover-db-cluster --db-cluster-identifier $CLUSTER_ID

# Aguardar mais 10 minutos, depois parar carga
sleep 600
kill $WORKLOAD_PID

echo "Teste de stress com failover concluído"
```

### Teste 2: Recuperação de Múltiplas Falhas

```bash
# Simular falha de múltiplas instâncias
echo "Simulando falhas em cascata..."

# Falha da replica AZ3
aws docdb reboot-db-instance --db-instance-identifier $ID-replica-az3

sleep 60

# Falha da replica AZ2
aws docdb reboot-db-instance --db-instance-identifier $ID-replica-az2

sleep 60

# Failover do primary
aws docdb failover-db-cluster --db-cluster-identifier $CLUSTER_ID

echo "Monitorando recuperação..."
./scripts/monitor-recovery.sh $CLUSTER_ID
```

---

## ✅ Checklist de Conclusão

Execute o script de validação:

```bash
# Executa o grade para avaliar atividades
./grade_exercicio1.sh
```

### Itens Verificados:

- ✅ Read replicas criadas em múltiplas AZs
- ✅ Promotion tiers configurados otimamente
- ✅ Monitoramento de replication lag ativo
- ✅ Testes de failover executados com sucesso
- ✅ Métricas customizadas configuradas
- ✅ Alertas proativos funcionando

---

## 🧹 Limpeza

```bash
# Deletar read replicas adicionais
aws docdb delete-db-instance --db-instance-identifier $ID-replica-az2 --skip-final-snapshot
aws docdb delete-db-instance --db-instance-identifier $ID-replica-az3 --skip-final-snapshot

# Deletar alarmes
aws cloudwatch delete-alarms --alarm-names $ID-ReplicationLag-High $ID-CriticalReplicationLag $ID-ReplicaFailure

# Deletar dashboard
aws cloudwatch delete-dashboards --dashboard-names $ID-Replication-Monitoring

# Parar scripts de monitoramento
pkill -f "test-replication-lag\|sustained-workload"
```

---

## 📊 Resultados Esperados

### Métricas de Performance:

1. **Replication Lag:**
   - Normal: < 100ms
   - Sob carga: < 500ms
   - Crítico: > 5000ms

2. **Failover Time:**
   - Automático: 60-120 segundos
   - Manual: 30-60 segundos
   - Multi-AZ: < 2 minutos

3. **Disponibilidade:**
   - Single instance: 99.9%
   - Multi-AZ: 99.95%
   - Com monitoring: 99.99%

### Configurações Otimizadas:

- **3 AZs:** Proteção contra falha de datacenter
- **Promotion Tiers:** Failover determinístico
- **Connection Pooling:** Distribuição eficiente de carga
- **Monitoring:** Detecção proativa de problemas

---

[⬅️ Módulo 5 Home](../README.md) | [➡️ Exercício 2](../exercicio2-rto-rpo-optimization/README.md)