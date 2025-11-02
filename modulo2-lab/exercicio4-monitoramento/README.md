# Exercício 4: Monitoramento com CloudWatch e EventBridge

## 🎯 Objetivos

- Configurar dashboards personalizados no CloudWatch
- Criar alarmes para métricas críticas
- Implementar notificações via SNS
- Configurar regras do EventBridge para eventos do cluster
- Monitorar performance e disponibilidade

## ⏱️ Duração Estimada
75 minutos

> ⚠️ **Atenção:** Lembre-se de usar seu prefixo de aluno (`<seu-id>`) em todos os nomes de recursos e comandos.

---

## 📊 Parte 1: Criar Dashboard no CloudWatch

### Via Console

1. Acesse **CloudWatch > Dashboards**
2. Clique em **Create dashboard**
3. Nome: `<seu-id>-DocumentDB-Dashboard`
4. Adicione widgets para as métricas principais (CPUUtilization, DatabaseConnections, Read/Write Latency, etc.), filtrando pelo seu cluster (`<seu-id>-lab-cluster-console`).

### Via CLI

```bash
# Crie uma cópia do dashboard.json e adicione a dimensão do seu cluster
# Ex: "dimensions": { "DBClusterIdentifier": "<seu-id>-lab-cluster-console" }
aws cloudwatch put-dashboard \
  --dashboard-name <seu-id>-DocumentDB-Dashboard \
  --dashboard-body file://cloudwatch/dashboard.json
```

---

## 🚨 Parte 2: Configurar Alarmes

### Passo 1: Criar Tópico SNS

```bash
# Criar tópico SNS (substitua <seu-id>)
aws sns create-topic \
  --name <seu-id>-documentdb-alerts

# Obter ARN do tópico
TOPIC_ARN=$(aws sns list-topics \
  --query "Topics[?contains(TopicArn, '<seu-id>-documentdb-alerts')].TopicArn" \
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
# Substitua <seu-id> e $TOPIC_ARN
aws cloudwatch put-metric-alarm \
  --alarm-name "<seu-id>-DocumentDB-HighCPU" \
  --alarm-description "CPU acima de 80% por 5 minutos" \
  --metric-name CPUUtilization \
  --namespace AWS/DocDB \
  --statistic Average \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=DBClusterIdentifier,Value=<seu-id>-lab-cluster-console \
  --alarm-actions $TOPIC_ARN
```

---

## 🎯 Parte 3: EventBridge para Eventos do Cluster

### Criar Regra para Failover

```bash
# Criar regra EventBridge (substitua <seu-id>)
aws events put-rule \
  --name <seu-id>-documentdb-failover-events \
  --description "Detectar eventos de failover para o aluno <seu-id>" \
  --event-pattern '{
    "source": ["aws.rds"],
    "detail-type": ["RDS DB Instance Event"],
    "detail": {
      "EventCategories": ["failover"],
      "SourceIdentifier": [{
        "prefix": "<seu-id>-"
      }]
    }
  }'

# Adicionar SNS como target (substitua o ARN do seu tópico)
aws events put-targets \
  --rule <seu-id>-documentdb-failover-events \
  --targets "Id"="1","Arn"="$TOPIC_ARN"
```

---

## 📈 Parte 4: Métricas Customizadas

### Criar Métrica de Disponibilidade

No script `publish-availability-metric.sh`, lembre-se de alterar o `CLUSTER_ID` para o seu.

```bash
# Script para publicar métrica customizada

NAMESPACE="DocumentDB/Custom"
METRIC_NAME="ClusterAvailability"
CLUSTER_ID="<seu-id>-lab-cluster-console"

# ... (restante do script)
```

---

## ✅ Checklist de Conclusão

- [ ] Dashboard criado com prefixo e filtro para o seu cluster.
- [ ] Tópico SNS criado com prefixo.
- [ ] Alarmes criados com prefixo e dimensão correta.
- [ ] Regra do EventBridge criada com prefixo.

---

## 🧹 Limpeza

Lembre-se de usar seu prefixo `<seu-id>` para deletar todos os recursos criados.

```bash
# Deletar alarmes
aws cloudwatch delete-alarms --alarm-names <seu-id>-DocumentDB-HighCPU

# Deletar regra EventBridge
aws events remove-targets --rule <seu-id>-documentdb-failover-events --ids 1
aws events delete-rule --name <seu-id>-documentdb-failover-events

# Deletar dashboard
aws cloudwatch delete-dashboards --dashboard-names <seu-id>-DocumentDB-Dashboard

# Deletar tópico SNS
aws sns delete-topic --topic-arn $TOPIC_ARN
```

---

[⬅️ Exercício 3](../exercicio3-failover/README.md) | [➡️ Exercício 5](../exercicio5-manutencao/README.md)
