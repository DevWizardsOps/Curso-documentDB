# Exercício 4: Monitoramento com CloudWatch e EventBridge

## 🎯 Objetivos

- Configurar dashboards personalizados no CloudWatch
- Criar alarmes para métricas críticas
- Implementar notificações via SNS
- Configurar regras do EventBridge para eventos do cluster
- Monitorar performance e disponibilidade
- Criar automações baseadas em eventos

## ⏱️ Duração Estimada
75 minutos

---

## 📚 Conceitos

### Métricas Importantes do DocumentDB

#### Performance
- **CPUUtilization** - Uso de CPU (%)
- **DatabaseConnections** - Conexões ativas
- **FreeableMemory** - Memória disponível
- **ReadLatency / WriteLatency** - Latência de operações (ms)
- **ReadThroughput / WriteThroughput** - Taxa de operações
- **NetworkReceiveThroughput / NetworkTransmitThroughput** - Tráfego de rede

#### Replicação
- **DBClusterReplicaLagMaximum** - Lag máximo entre réplicas (ms)
- **DBClusterReplicaLagMinimum** - Lag mínimo entre réplicas (ms)

#### Storage
- **VolumeBytesUsed** - Espaço em disco usado
- **VolumeReadIOPs / VolumeWriteIOPs** - IOPS de leitura/escrita

---

## 📊 Parte 1: Criar Dashboard no CloudWatch

### Via Console

1. Acesse **CloudWatch > Dashboards**
2. Clique em **Create dashboard**
3. Nome: `DocumentDB-Production-Dashboard`
4. Adicione widgets conforme abaixo

#### Widget 1: CPU Utilization (Line)

```json
{
    "metrics": [
        [ "AWS/DocDB", "CPUUtilization", { "stat": "Average" } ]
    ],
    "view": "timeSeries",
    "stacked": false,
    "region": "us-east-1",
    "title": "CPU Utilization - All Instances",
    "period": 300
}
```

#### Widget 2: Database Connections (Line)

```json
{
    "metrics": [
        [ "AWS/DocDB", "DatabaseConnections", { "stat": "Sum" } ]
    ],
    "view": "timeSeries",
    "region": "us-east-1",
    "title": "Active Database Connections",
    "period": 300
}
```

#### Widget 3: Read/Write Latency (Line)

```json
{
    "metrics": [
        [ "AWS/DocDB", "ReadLatency", { "stat": "Average", "label": "Read" } ],
        [ ".", "WriteLatency", { "stat": "Average", "label": "Write" } ]
    ],
    "view": "timeSeries",
    "region": "us-east-1",
    "title": "Read/Write Latency (ms)",
    "period": 300,
    "yAxis": {
        "left": {
            "label": "Milliseconds"
        }
    }
}
```

#### Widget 4: Replica Lag (Line)

```json
{
    "metrics": [
        [ "AWS/DocDB", "DBClusterReplicaLagMaximum", { "stat": "Maximum" } ],
        [ ".", "DBClusterReplicaLagMinimum", { "stat": "Minimum" } ]
    ],
    "view": "timeSeries",
    "region": "us-east-1",
    "title": "Replica Lag (ms)",
    "period": 300
}
```

### Via CLI

```bash
# Criar dashboard
aws cloudwatch put-dashboard \
  --dashboard-name DocumentDB-Production-Dashboard \
  --dashboard-body file://cloudwatch/dashboard.json
```

### Via Terraform

Veja o arquivo `cloudwatch/dashboard.tf`

---

## 🚨 Parte 2: Configurar Alarmes

### Passo 1: Criar Tópico SNS

```bash
# Criar tópico SNS
aws sns create-topic \
  --name documentdb-alerts

# Obter ARN do tópico
TOPIC_ARN=$(aws sns list-topics \
  --query "Topics[?contains(TopicArn, 'documentdb-alerts')].TopicArn" \
  --output text)

echo "Topic ARN: $TOPIC_ARN"

# Adicionar seu email como subscriber
aws sns subscribe \
  --topic-arn $TOPIC_ARN \
  --protocol email \
  --notification-endpoint seu-email@example.com

# Confirme o email que você recebeu!
```

### Passo 2: Alarmes Essenciais

#### Alarme 1: CPU Alta

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "DocumentDB-HighCPU" \
  --alarm-description "CPU acima de 80% por 5 minutos" \
  --metric-name CPUUtilization \
  --namespace AWS/DocDB \
  --statistic Average \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=DBClusterIdentifier,Value=lab-cluster-console \
  --alarm-actions $TOPIC_ARN \
  --treat-missing-data notBreaching
```

#### Alarme 2: Conexões Altas

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "DocumentDB-HighConnections" \
  --alarm-description "Mais de 500 conexões ativas" \
  --metric-name DatabaseConnections \
  --namespace AWS/DocDB \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 500 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=DBClusterIdentifier,Value=lab-cluster-console \
  --alarm-actions $TOPIC_ARN
```

#### Alarme 3: Replica Lag Alto

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "DocumentDB-HighReplicaLag" \
  --alarm-description "Replica lag acima de 1 segundo" \
  --metric-name DBClusterReplicaLagMaximum \
  --namespace AWS/DocDB \
  --statistic Maximum \
  --period 60 \
  --evaluation-periods 3 \
  --threshold 1000 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=DBClusterIdentifier,Value=lab-cluster-console \
  --alarm-actions $TOPIC_ARN
```

#### Alarme 4: Memória Baixa

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "DocumentDB-LowMemory" \
  --alarm-description "Memória livre abaixo de 1GB" \
  --metric-name FreeableMemory \
  --namespace AWS/DocDB \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 1073741824 \
  --comparison-operator LessThanThreshold \
  --dimensions Name=DBInstanceIdentifier,Value=lab-cluster-console-1 \
  --alarm-actions $TOPIC_ARN
```

#### Alarme 5: Storage Alto

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "DocumentDB-HighStorage" \
  --alarm-description "Storage usado acima de 80%" \
  --metric-name VolumeBytesUsed \
  --namespace AWS/DocDB \
  --statistic Average \
  --period 3600 \
  --evaluation-periods 1 \
  --threshold 85899345920 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=DBClusterIdentifier,Value=lab-cluster-console \
  --alarm-actions $TOPIC_ARN
```

### Via Terraform

Veja o arquivo `cloudwatch/alarms.tf` para todos os alarmes em código

---

## 🎯 Parte 3: EventBridge para Eventos do Cluster

### Eventos Importantes

- **RDS-EVENT-0004** - DB instance created
- **RDS-EVENT-0006** - DB instance restarted
- **RDS-EVENT-0013** - Multi-AZ failover started
- **RDS-EVENT-0015** - Multi-AZ failover complete
- **RDS-EVENT-0034** - Backup started
- **RDS-EVENT-0035** - Backup complete

### Criar Regra para Failover

```bash
# Criar regra EventBridge
aws events put-rule \
  --name documentdb-failover-events \
  --description "Detectar eventos de failover" \
  --event-pattern '{
    "source": ["aws.rds"],
    "detail-type": ["RDS DB Instance Event"],
    "detail": {
      "EventCategories": ["failover"]
    }
  }'

# Adicionar SNS como target
aws events put-targets \
  --rule documentdb-failover-events \
  --targets "Id"="1","Arn"="$TOPIC_ARN"

# Dar permissão ao EventBridge para publicar no SNS
aws sns set-topic-attributes \
  --topic-arn $TOPIC_ARN \
  --attribute-name Policy \
  --attribute-value '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "events.amazonaws.com"},
      "Action": "SNS:Publish",
      "Resource": "'$TOPIC_ARN'"
    }]
  }'
```

### Criar Regra para Backups

```bash
aws events put-rule \
  --name documentdb-backup-events \
  --description "Notificar sobre backups" \
  --event-pattern '{
    "source": ["aws.rds"],
    "detail-type": ["RDS DB Cluster Snapshot Event"],
    "detail": {
      "EventCategories": ["backup"]
    }
  }'

aws events put-targets \
  --rule documentdb-backup-events \
  --targets "Id"="1","Arn"="$TOPIC_ARN"
```

### Criar Regra para Manutenção

```bash
aws events put-rule \
  --name documentdb-maintenance-events \
  --description "Alertas de manutenção" \
  --event-pattern '{
    "source": ["aws.rds"],
    "detail-type": ["RDS DB Instance Event"],
    "detail": {
      "EventCategories": ["maintenance"]
    }
  }'

aws events put-targets \
  --rule documentdb-maintenance-events \
  --targets "Id"="1","Arn"="$TOPIC_ARN"
```

---

## 📈 Parte 4: Métricas Customizadas

### Criar Métrica de Disponibilidade

```bash
#!/bin/bash
# Script para publicar métrica customizada

NAMESPACE="DocumentDB/Custom"
METRIC_NAME="ClusterAvailability"
CLUSTER_ID="lab-cluster-console"

# Verificar se o cluster está disponível
STATUS=$(aws docdb describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --query 'DBClusters[0].Status' \
  --output text)

if [ "$STATUS" == "available" ]; then
    VALUE=1
else
    VALUE=0
fi

# Publicar métrica
aws cloudwatch put-metric-data \
  --namespace $NAMESPACE \
  --metric-name $METRIC_NAME \
  --value $VALUE \
  --dimensions ClusterIdentifier=$CLUSTER_ID
```

### Agendar com Cron

```bash
# Adicionar ao crontab para executar a cada minuto
* * * * * /path/to/publish-availability-metric.sh
```

---

## 📊 Parte 5: Logs e Insights

### Habilitar Logs no CloudWatch

```bash
# Habilitar audit logs
aws docdb modify-db-cluster \
  --db-cluster-identifier lab-cluster-console \
  --cloudwatch-logs-export-configuration '{
    "LogTypesToEnable": ["audit", "profiler"]
  }' \
  --apply-immediately
```

### Consultar Logs com Insights

```sql
-- Queries mais lentas
fields @timestamp, @message
| filter @message like /slow/
| sort @timestamp desc
| limit 20

-- Conexões por hora
fields @timestamp
| filter @message like /connection/
| stats count() by bin(1h)

-- Erros de autenticação
fields @timestamp, @message
| filter @message like /authentication failed/
| sort @timestamp desc
```

---

## 🔔 Parte 6: Notificações Avançadas

### Integração com Slack (via Lambda)

Veja `eventbridge/slack-notifier.py` para exemplo completo

### Integração com PagerDuty

```bash
# Criar subscription HTTPS para PagerDuty
aws sns subscribe \
  --topic-arn $TOPIC_ARN \
  --protocol https \
  --notification-endpoint https://events.pagerduty.com/integration/YOUR_KEY/enqueue
```

---

## ✅ Checklist de Conclusão

- [ ] Dashboard criado com métricas principais
- [ ] Tópico SNS configurado e email confirmado
- [ ] Alarmes de CPU, memória e conexões criados
- [ ] Alarme de replica lag configurado
- [ ] EventBridge configurado para failover
- [ ] EventBridge configurado para backups
- [ ] Logs habilitados no CloudWatch
- [ ] Testou recebimento de notificações

---

## 🧪 Teste dos Alarmes

### Testar Alarme de CPU

```bash
# Simular carga alta de CPU (não recomendado em produção!)
# Este comando deve ser executado em uma instância EC2 na mesma VPC

mongosh --host $CLUSTER_ENDPOINT:27017 \
  --username docdbadmin \
  --password Lab12345! \
  --tls \
  --tlsCAFile global-bundle.pem \
  --eval '
    for (let i = 0; i < 1000000; i++) {
      db.test.find().toArray();
    }
  '
```

### Testar Alarme de Conexões

```bash
# Abrir múltiplas conexões simultaneamente
for i in {1..100}; do
  mongosh --host $CLUSTER_ENDPOINT:27017 \
    --username docdbadmin \
    --password Lab12345! \
    --tls \
    --tlsCAFile global-bundle.pem \
    --eval 'sleep(60000)' &
done
```

### Verificar Alarmes

```bash
# Listar todos os alarmes
aws cloudwatch describe-alarms \
  --alarm-name-prefix "DocumentDB-" \
  --query 'MetricAlarms[*].[AlarmName, StateValue]' \
  --output table

# Ver histórico de um alarme
aws cloudwatch describe-alarm-history \
  --alarm-name "DocumentDB-HighCPU" \
  --max-records 10
```

---

## 🧹 Limpeza

```bash
# Deletar alarmes
aws cloudwatch delete-alarms \
  --alarm-names \
    DocumentDB-HighCPU \
    DocumentDB-HighConnections \
    DocumentDB-HighReplicaLag \
    DocumentDB-LowMemory \
    DocumentDB-HighStorage

# Deletar regras EventBridge
aws events remove-targets --rule documentdb-failover-events --ids 1
aws events delete-rule --name documentdb-failover-events

aws events remove-targets --rule documentdb-backup-events --ids 1
aws events delete-rule --name documentdb-backup-events

# Deletar dashboard
aws cloudwatch delete-dashboards \
  --dashboard-names DocumentDB-Production-Dashboard

# Deletar tópico SNS
aws sns delete-topic --topic-arn $TOPIC_ARN
```

---

## 📝 Exercícios Extras

1. **Custom Metrics:** Crie métricas para número de documentos por collection
2. **Composite Alarms:** Combine múltiplos alarmes com lógica AND/OR
3. **Auto-scaling:** Configure scaling automático baseado em métricas
4. **Log Analysis:** Use CloudWatch Insights para análise de padrões

---

## 💡 Best Practices

- ✅ Configure alarmes para todas as métricas críticas
- ✅ Use múltiplos canais de notificação (email, Slack, PagerDuty)
- ✅ Ajuste thresholds baseado em baseline histórico
- ✅ Teste alarmes regularmente
- ✅ Documente runbooks para cada alarme
- ✅ Use tags para organizar recursos
- ✅ Configure retention policies para logs
- ✅ Monitore custos do CloudWatch

---

## 🆘 Troubleshooting

**Não estou recebendo emails do SNS**
- Confirme subscription no email recebido
- Verifique spam/lixeira
- Teste com: `aws sns publish --topic-arn $TOPIC_ARN --message "Test"`

**Alarme não está disparando**
- Verifique se as dimensões estão corretas
- Confirme que há dados sendo gerados
- Use `get-metric-statistics` para validar dados

**Dashboard não mostra dados**
- Verifique região correta
- Confirme que cluster está ativo
- Valide período de tempo selecionado

---

[⬅️ Exercício 3](../exercicio3-failover/README.md) | [➡️ Exercício 5](../exercicio5-manutencao/README.md)
