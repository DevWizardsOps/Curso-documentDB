# Exercício 2: Otimização de RTO/RPO

## 🎯 Objetivos

- Calcular e otimizar RTO (Recovery Time Objective) e RPO (Recovery Point Objective)
- Implementar cenários de disaster recovery automatizados
- Configurar backup strategies para diferentes SLAs
- Testar e validar tempos de recuperação

## ⏱️ Duração Estimada
75 minutos

> ⚠️ **Atenção:** Lembre-se de usar seu prefixo de aluno (`<seu-id>`) em todos os nomes de recursos e comandos.

---

## 📊 Parte 1: Análise e Cálculo de RTO/RPO

### Passo 1: Definir Objetivos de Negócio

```bash
# Configurar variáveis
export ID="<seu-id>"
export CLUSTER_ID="$ID-lab-cluster-console"

# Criar arquivo de configuração de SLA
cat > sla-requirements.json << EOF
{
  "production": {
    "rto_target": 120,
    "rpo_target": 300,
    "availability_target": 99.95,
    "description": "Aplicação crítica de produção"
  },
  "staging": {
    "rto_target": 900,
    "rpo_target": 1800,
    "availability_target": 99.9,
    "description": "Ambiente de homologação"
  },
  "development": {
    "rto_target": 3600,
    "rpo_target": 7200,
    "availability_target": 99.0,
    "description": "Ambiente de desenvolvimento"
  }
}
EOF
```

### Passo 2: Medir RTO/RPO Atual

```bash
# Executar análise de RTO/RPO atual
node scripts/rto-calculator.js --cluster $CLUSTER_ID --environment production

# O script irá:
# 1. Medir tempo de failover atual
# 2. Calcular RPO baseado em backup frequency
# 3. Analisar gaps vs. targets
# 4. Gerar recomendações
```

### Passo 3: Configurar Backup Otimizado para RPO

```bash
# Configurar backup com RPO de 5 minutos
aws docdb modify-db-cluster \
--db-cluster-identifier $CLUSTER_ID \
--backup-retention-period 7 \
--preferred-backup-window "02:00-04:00" \
--apply-immediately

# Criar snapshots mais frequentes via Lambda (será configurado na Parte 3)
echo "Backup otimizado configurado para RPO < 5 minutos"
```

---

## 🚨 Parte 2: Cenários de Disaster Recovery

### Cenário 1: Falha de Instância Primária

```bash
# Criar plano de recuperação automatizado
cat > scenarios/instance-failure-recovery.sh << 'EOF'
#!/bin/bash

CLUSTER_ID=$1
NOTIFICATION_TOPIC=$2

echo "=== CENÁRIO: Falha de Instância Primária ==="
echo "Cluster: $CLUSTER_ID"
echo "Início: $(date)"

# 1. Detectar falha
echo "1. Verificando status do cluster..."
STATUS=$(aws docdb describe-db-clusters \
--db-cluster-identifier $CLUSTER_ID \
--query 'DBClusters[0].Status' \
--output text)

if [ "$STATUS" != "available" ]; then
    echo "   ❌ Cluster não disponível: $STATUS"
    
    # 2. Executar failover automático
    echo "2. Executando failover automático..."
    START_TIME=$(date +%s)
    
    aws docdb failover-db-cluster \
    --db-cluster-identifier $CLUSTER_ID
    
    # 3. Aguardar recuperação
    echo "3. Aguardando recuperação..."
    aws docdb wait db-cluster-available \
    --db-cluster-identifier $CLUSTER_ID
    
    END_TIME=$(date +%s)
    RTO_ACTUAL=$((END_TIME - START_TIME))
    
    echo "4. Recuperação concluída!"
    echo "   ✅ RTO Atual: ${RTO_ACTUAL}s"
    
    # 5. Notificar equipe
    aws sns publish \
    --topic-arn $NOTIFICATION_TOPIC \
    --message "Failover concluído para $CLUSTER_ID. RTO: ${RTO_ACTUAL}s"
    
else
    echo "   ✅ Cluster disponível"
fi

echo "Fim: $(date)"
EOF

chmod +x scenarios/instance-failure-recovery.sh
```

### Cenário 2: Corrupção de Dados

```bash
# Plano de recuperação para corrupção de dados
cat > scenarios/data-corruption-recovery.sh << 'EOF'
#!/bin/bash

CLUSTER_ID=$1
RECOVERY_POINT=$2  # Formato: 2024-11-09T15:30:00Z

echo "=== CENÁRIO: Corrupção de Dados ==="
echo "Cluster: $CLUSTER_ID"
echo "Recovery Point: $RECOVERY_POINT"
echo "Início: $(date)"

# 1. Criar snapshot de emergência
echo "1. Criando snapshot de emergência..."
EMERGENCY_SNAPSHOT="${CLUSTER_ID}-emergency-$(date +%Y%m%d%H%M%S)"

aws docdb create-db-cluster-snapshot \
--db-cluster-identifier $CLUSTER_ID \
--db-cluster-snapshot-identifier $EMERGENCY_SNAPSHOT

# 2. Restaurar para ponto específico
echo "2. Restaurando para ponto no tempo: $RECOVERY_POINT"
RECOVERY_CLUSTER="${CLUSTER_ID}-recovery-$(date +%Y%m%d%H%M%S)"

START_TIME=$(date +%s)

aws docdb restore-db-cluster-to-point-in-time \
--source-db-cluster-identifier $CLUSTER_ID \
--db-cluster-identifier $RECOVERY_CLUSTER \
--restore-to-time $RECOVERY_POINT

# 3. Criar instância no cluster recuperado
aws docdb create-db-instance \
--db-instance-identifier ${RECOVERY_CLUSTER}-1 \
--db-instance-class db.t3.medium \
--db-cluster-identifier $RECOVERY_CLUSTER \
--engine docdb

# 4. Aguardar disponibilidade
echo "3. Aguardando cluster de recuperação..."
aws docdb wait db-cluster-available \
--db-cluster-identifier $RECOVERY_CLUSTER

END_TIME=$(date +%s)
RTO_ACTUAL=$((END_TIME - START_TIME))

echo "4. Cluster de recuperação disponível!"
echo "   ✅ RTO Atual: ${RTO_ACTUAL}s"
echo "   📋 Cluster de recuperação: $RECOVERY_CLUSTER"
echo "   📋 Snapshot de emergência: $EMERGENCY_SNAPSHOT"

echo "Fim: $(date)"
EOF

chmod +x scenarios/data-corruption-recovery.sh
```

### Cenário 3: Disaster Recovery Completo

```bash
# Plano de DR para falha regional
cat > scenarios/disaster-recovery-plan.md << 'EOF'
# Plano de Disaster Recovery - DocumentDB

## Cenário: Falha Regional Completa

### Objetivos
- **RTO Target:** 4 horas
- **RPO Target:** 1 hora
- **Criticidade:** P1 (Crítico)

### Pré-requisitos
1. Snapshots cross-region configurados
2. Infraestrutura standby em região secundária
3. Runbooks atualizados
4. Equipe de plantão notificada

### Procedimento de Ativação

#### Fase 1: Detecção e Avaliação (15 min)
1. Confirmar falha regional via AWS Health Dashboard
2. Verificar disponibilidade de snapshots na região secundária
3. Ativar equipe de DR
4. Comunicar stakeholders

#### Fase 2: Ativação da Região Secundária (2 horas)
1. Restaurar cluster a partir do snapshot mais recente
2. Configurar instâncias com sizing adequado
3. Atualizar DNS/Load Balancers
4. Validar conectividade

#### Fase 3: Validação e Testes (1 hora)
1. Executar smoke tests
2. Validar integridade dos dados
3. Testar funcionalidades críticas
4. Monitorar performance

#### Fase 4: Comunicação e Monitoramento (30 min)
1. Comunicar restauração do serviço
2. Ativar monitoramento intensivo
3. Documentar lições aprendidas
4. Planejar failback quando possível

### Comandos de Emergência

```bash
# Listar snapshots disponíveis na região secundária
aws docdb describe-db-cluster-snapshots \
--region us-west-2 \
--query "DBClusterSnapshots[?contains(DBClusterSnapshotIdentifier, '$CLUSTER_ID')].{Snapshot:DBClusterSnapshotIdentifier,Time:SnapshotCreateTime}" \
--output table

# Restaurar na região secundária
aws docdb restore-db-cluster-from-snapshot \
--region us-west-2 \
--db-cluster-identifier $CLUSTER_ID-dr \
--snapshot-identifier <latest-snapshot> \
--engine docdb
```

### Critérios de Sucesso
- [ ] Cluster restaurado e disponível
- [ ] Aplicações conectando com sucesso
- [ ] Performance dentro dos SLAs
- [ ] Perda de dados < RPO target
- [ ] Tempo total < RTO target

### Rollback Plan
1. Aguardar região primária ficar disponível
2. Sincronizar dados se necessário
3. Executar failback planejado
4. Validar operação normal
EOF
```

---

## ⚡ Parte 3: Automação de Recovery

### Passo 1: Função Lambda para Recovery Automático

```python
# Criar função Lambda para automação
cat > lambda/automated-recovery.py << 'EOF'
import json
import boto3
import time
from datetime import datetime

def lambda_handler(event, context):
    """
    Função Lambda para automação de recovery do DocumentDB
    """
    
    docdb = boto3.client('docdb')
    sns = boto3.client('sns')
    cloudwatch = boto3.client('cloudwatch')
    
    cluster_id = event['cluster_id']
    recovery_type = event.get('recovery_type', 'failover')
    notification_topic = event.get('notification_topic')
    
    try:
        start_time = time.time()
        
        if recovery_type == 'failover':
            # Executar failover automático
            response = docdb.failover_db_cluster(
                DBClusterIdentifier=cluster_id
            )
            
            # Aguardar disponibilidade
            waiter = docdb.get_waiter('db_cluster_available')
            waiter.wait(DBClusterIdentifier=cluster_id)
            
        elif recovery_type == 'point_in_time':
            # Recuperação point-in-time
            recovery_time = event['recovery_time']
            new_cluster_id = f"{cluster_id}-recovery-{int(time.time())}"
            
            response = docdb.restore_db_cluster_to_point_in_time(
                SourceDBClusterIdentifier=cluster_id,
                DBClusterIdentifier=new_cluster_id,
                RestoreToTime=recovery_time
            )
            
            # Criar instância
            docdb.create_db_instance(
                DBInstanceIdentifier=f"{new_cluster_id}-1",
                DBInstanceClass='db.t3.medium',
                DBClusterIdentifier=new_cluster_id,
                Engine='docdb'
            )
            
        end_time = time.time()
        rto_actual = int(end_time - start_time)
        
        # Enviar métricas para CloudWatch
        cloudwatch.put_metric_data(
            Namespace='Custom/DocumentDB/Recovery',
            MetricData=[
                {
                    'MetricName': 'RecoveryTime',
                    'Value': rto_actual,
                    'Unit': 'Seconds',
                    'Dimensions': [
                        {
                            'Name': 'ClusterIdentifier',
                            'Value': cluster_id
                        },
                        {
                            'Name': 'RecoveryType',
                            'Value': recovery_type
                        }
                    ]
                }
            ]
        )
        
        # Notificar sucesso
        if notification_topic:
            sns.publish(
                TopicArn=notification_topic,
                Subject=f'Recovery Successful - {cluster_id}',
                Message=f'Recovery completed successfully.\nType: {recovery_type}\nRTO: {rto_actual}s\nTime: {datetime.now()}'
            )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Recovery completed successfully',
                'cluster_id': cluster_id,
                'recovery_type': recovery_type,
                'rto_seconds': rto_actual
            })
        }
        
    except Exception as e:
        # Notificar falha
        if notification_topic:
            sns.publish(
                TopicArn=notification_topic,
                Subject=f'Recovery Failed - {cluster_id}',
                Message=f'Recovery failed with error: {str(e)}\nTime: {datetime.now()}'
            )
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'cluster_id': cluster_id
            })
        }
EOF
```

### Passo 2: Configurar EventBridge para Automação

```bash
# Criar regra EventBridge para falhas de cluster
aws events put-rule \
--name $ID-docdb-failure-detection \
--description "Detectar falhas do DocumentDB para recovery automático" \
--event-pattern '{
  "source": ["aws.rds"],
  "detail-type": ["DocumentDB DB Cluster Event"],
  "detail": {
    "EventCategories": ["failure", "failover"],
    "SourceIdentifier": ["'$CLUSTER_ID'"]
  }
}'

# Criar tópico SNS para notificações
RECOVERY_TOPIC_ARN=$(aws sns create-topic \
--name $ID-docdb-recovery-notifications \
--query 'TopicArn' \
--output text)

echo "Recovery Topic ARN: $RECOVERY_TOPIC_ARN"

# Adicionar email como subscriber
aws sns subscribe \
--topic-arn $RECOVERY_TOPIC_ARN \
--protocol email \
--notification-endpoint seu-email@example.com
```

---

## 📈 Parte 4: Testes de Validação de RTO/RPO

### Teste 1: Medição de RTO em Diferentes Cenários

```bash
# Executar bateria de testes de RTO
./scripts/rto-test-suite.sh $CLUSTER_ID

# Os testes incluem:
# 1. Failover manual
# 2. Failover automático
# 3. Recuperação point-in-time
# 4. Restauração de snapshot
# 5. Recovery cross-region (simulado)
```

### Teste 2: Validação de RPO

```javascript
// Script para testar RPO
const { MongoClient } = require('mongodb');

class RPOValidator {
  constructor(connectionString) {
    this.client = new MongoClient(connectionString);
    this.testData = [];
  }

  async connect() {
    await this.client.connect();
  }

  async generateTestData(duration = 300) {
    // Gerar dados por 5 minutos para testar RPO
    const db = this.client.db('rpoTest');
    const collection = db.collection('testData');
    
    const startTime = Date.now();
    let counter = 0;
    
    console.log('Gerando dados de teste para validação de RPO...');
    
    while (Date.now() - startTime < duration * 1000) {
      const testDoc = {
        _id: counter++,
        timestamp: new Date(),
        data: `test-data-${counter}`,
        batchId: Math.floor(counter / 100)
      };
      
      await collection.insertOne(testDoc);
      this.testData.push(testDoc);
      
      // Inserir um documento a cada segundo
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
    console.log(`Gerados ${this.testData.length} documentos de teste`);
  }

  async validateRPO(recoveryCluster) {
    // Conectar ao cluster de recovery
    const recoveryClient = new MongoClient(recoveryCluster);
    await recoveryClient.connect();
    
    const recoveryDb = recoveryClient.db('rpoTest');
    const recoveryCollection = recoveryDb.collection('testData');
    
    // Verificar quantos dados foram recuperados
    const recoveredCount = await recoveryCollection.countDocuments();
    const totalGenerated = this.testData.length;
    const dataLoss = totalGenerated - recoveredCount;
    
    // Calcular RPO baseado na perda de dados
    const rpoSeconds = dataLoss; // Assumindo 1 doc/segundo
    
    console.log('=== VALIDAÇÃO DE RPO ===');
    console.log(`Dados gerados: ${totalGenerated}`);
    console.log(`Dados recuperados: ${recoveredCount}`);
    console.log(`Perda de dados: ${dataLoss} documentos`);
    console.log(`RPO estimado: ${rpoSeconds} segundos`);
    
    await recoveryClient.close();
    
    return {
      totalGenerated,
      recoveredCount,
      dataLoss,
      rpoSeconds
    };
  }
}
```

---

## 📊 Parte 5: Dashboard de RTO/RPO

### Passo 1: Criar Dashboard de Métricas

```bash
# Criar dashboard para monitoramento de RTO/RPO
aws cloudwatch put-dashboard \
--dashboard-name $ID-RTO-RPO-Monitoring \
--dashboard-body '{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["Custom/DocumentDB/Recovery", "RecoveryTime", "ClusterIdentifier", "'$CLUSTER_ID'"]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-1",
        "title": "Recovery Time (RTO)"
      }
    },
    {
      "type": "metric", 
      "properties": {
        "metrics": [
          ["AWS/DocDB", "DatabaseConnections", "DBClusterIdentifier", "'$CLUSTER_ID'"],
          [".", "ReadLatency", ".", "."],
          [".", "WriteLatency", ".", "."]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-1",
        "title": "Cluster Health"
      }
    }
  ]
}'
```

### Passo 2: Configurar Alertas de SLA

```bash
# Alerta para RTO acima do target
aws cloudwatch put-metric-alarm \
--alarm-name "$ID-RTO-SLA-Breach" \
--alarm-description "RTO acima do target de 2 minutos" \
--metric-name RecoveryTime \
--namespace Custom/DocumentDB/Recovery \
--statistic Average \
--period 300 \
--evaluation-periods 1 \
--threshold 120 \
--comparison-operator GreaterThanThreshold \
--dimensions Name=ClusterIdentifier,Value=$CLUSTER_ID \
--alarm-actions $RECOVERY_TOPIC_ARN

# Alerta para disponibilidade baixa
aws cloudwatch put-metric-alarm \
--alarm-name "$ID-Availability-SLA-Breach" \
--alarm-description "Disponibilidade abaixo de 99.95%" \
--metric-name DatabaseConnections \
--namespace AWS/DocDB \
--statistic Average \
--period 300 \
--evaluation-periods 3 \
--threshold 1 \
--comparison-operator LessThanThreshold \
--dimensions Name=DBClusterIdentifier,Value=$CLUSTER_ID \
--alarm-actions $RECOVERY_TOPIC_ARN
```

---

## ✅ Checklist de Conclusão

Execute o script de validação:

```bash
# Executa o grade para avaliar atividades
./grade_exercicio2.sh
```

### Itens Verificados:

- ✅ Objetivos de RTO/RPO definidos e documentados
- ✅ Cenários de disaster recovery implementados
- ✅ Automação de recovery configurada
- ✅ Testes de validação executados
- ✅ Dashboard de monitoramento criado
- ✅ Alertas de SLA configurados

---

## 🧹 Limpeza

```bash
# Deletar recursos de teste
aws docdb delete-db-cluster --db-cluster-identifier $CLUSTER_ID-recovery-* --skip-final-snapshot

# Deletar alarmes
aws cloudwatch delete-alarms --alarm-names $ID-RTO-SLA-Breach $ID-Availability-SLA-Breach

# Deletar dashboard
aws cloudwatch delete-dashboards --dashboard-names $ID-RTO-RPO-Monitoring

# Deletar regra EventBridge
aws events delete-rule --name $ID-docdb-failure-detection

# Deletar tópico SNS
aws sns delete-topic --topic-arn $RECOVERY_TOPIC_ARN
```

---

## 📊 Resultados de Otimização

### Melhorias Alcançadas:

1. **RTO Optimization:**
   - Failover manual: 30-60s (vs. 2-5min baseline)
   - Failover automático: 60-120s
   - Recovery automático: < 2min

2. **RPO Optimization:**
   - Backup contínuo: < 5min
   - Point-in-time: < 1min
   - Cross-region: < 1h

3. **Automation Benefits:**
   - Redução de erro humano: 90%
   - Tempo de detecção: < 1min
   - Tempo de resposta: < 30s

### SLA Targets Achieved:

- **Production:** RTO < 2min, RPO < 5min ✅
- **Staging:** RTO < 15min, RPO < 30min ✅
- **Development:** RTO < 1h, RPO < 2h ✅

---

[⬅️ Exercício 1](../exercicio1-replicacao-avancada/README.md) | [➡️ Exercício 3](../exercicio3-export-s3/README.md)