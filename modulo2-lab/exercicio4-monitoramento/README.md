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
4. Clique em **Create dashboard**

#### Adicionando Widgets:

**Widget 1: CPU Utilization**
1. Clique em **Add widget**
2. Selecione **Line** (gráfico de linha)
3. Clique em **Next**
4. Em **Browse** procure por:
   - CPUUtilization
   - <seu-id>-lab-cluster-console
5. Em **Graphed metrics**:
   - Statistic: `Average`
   - Period: `5 minutes`
6. Widget title: `CPU Utilization (%)`
7. Clique em **Create widget**

**Widget 2: Database Connections**
1. Clique em **Add widget**
2. Selecione **Number** (valor numérico)
3. Clique em **Next**
4. Em **Browse** procure por:
   - DatabaseConnections
   - <seu-id>-lab-cluster-console
5. Em **Graphed metrics**:
   - Statistic: `Average`
   - Period: `5 minutes`
6. Widget title: `Active Connections`
7. Clique em **Create widget**

**Widget 3: Read/Write Latency**
1. Clique em **Add widget**
2. Selecione **Line** (gráfico de linha)
3. Clique em **Next**
4. Em **Browse** procure por:
   - <seu-id>-lab-cluster-console
   - ReadLatency
   - WriteLatency
5. Em **Graphed metrics**:
   - Statistic: `Average`
   - Period: `5 minutes`
6. Widget title: `Read/Write Latency (ms)`
7. Clique em **Create widget**

**Widget 4: Network Throughput**
1. Clique em **Add widget**
2. Selecione **Stacked area** (área empilhada)
3. Clique em **Next**
4. Em **Browse** procure por:
   - <seu-id>-lab-cluster-console
   - NetworkReceiveThroughput
   - NetworkTransmitThroughput
5. Em **Graphed metrics**:
   - Statistic: `Average`
   - Period: `5 minutes`
6. Widget title: `Network Throughput (Bytes/sec)`
7. Clique em **Create widget**

Clique em **Save dashboard** no canto superior direito

### Via CLI

```bash
# Defina sua variável de ID (substitua pelo seu ID de aluno)
export ID="<seu-id>"

# Primeiro, substitua YOUR_CLUSTER_IDENTIFIER no arquivo dashboard.json
sed -i.bak "s/YOUR_CLUSTER_IDENTIFIER/$ID-lab-cluster-console/g" cloudwatch/dashboard.json

# Crie o dashboard
aws cloudwatch put-dashboard \
--dashboard-name $ID-DocumentDB-Dashboard-ByAWSCli \
--dashboard-body file://cloudwatch/dashboard.json

# Verifique se foi criado
aws cloudwatch list-dashboards \
--query "DashboardEntries[?contains(DashboardName, '$ID')].DashboardName"
```

> 💡 **Dica:** O arquivo `dashboard.json` já contém todos os widgets configurados. Você só precisa substituir `YOUR_CLUSTER_IDENTIFIER` pelo nome do seu cluster.

---

## 🚨 Parte 2: Configurar Alarmes

### Passo 1: Criar Tópico SNS

```bash
# Criar tópico SNS (substitua <seu-id>)
aws sns create-topic \
--name $ID-documentdb-alerts

# Obter ARN do tópico
TOPIC_ARN=$(aws sns list-topics \
--query "Topics[?contains(TopicArn, '$ID-documentdb-alerts')].TopicArn" \
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
--alarm-name "$ID-DocumentDB-HighCPU" \
--alarm-description "CPU acima de 18% por 5 minutos" \
--metric-name CPUUtilization \
--namespace AWS/DocDB \
--statistic Average \
--period 300 \
--evaluation-periods 1 \
--threshold 18 \
--comparison-operator GreaterThanThreshold \
--dimensions Name=DBClusterIdentifier,Value=$ID-lab-cluster-console \
--alarm-actions $TOPIC_ARN
```

---

## 🎯 Parte 3: EventBridge para Eventos do Cluster

### Criar Regra para Failover

```bash
# Criar regra EventBridge (substitua <seu-id>)
aws events put-rule \
--name "${ID}-documentdb-failover-events" \
--description "Detectar eventos de failover para o aluno ${ID}" \
--event-pattern "$(jq -n --arg id "$ID" '{
  source: ["aws.docdb"],
  "detail-type": ["DocumentDB DB Instance Event"],
  detail: {
    EventCategories: ["failover"],
    SourceIdentifier: [{prefix: "\($id)-"}]
  }
}')"

# Adicionar SNS como target (substitua o ARN do seu tópico)
aws events put-targets \
--rule $ID-documentdb-failover-events \
--targets "Id"="1","Arn"="$TOPIC_ARN"
```
---

## ✅ Checklist de Conclusão

Execute o script de validação a partir do diretório home do usuário, no diretório do exercício 4 do módulo 2.

```bash
# Executa o grade para avaliar atividades
./grade_exercicio4.sh
```

---

## 🧹 Limpeza

Lembre-se de usar seu prefixo `<seu-id>` para deletar todos os recursos criados.

```bash
# Deletar alarmes
aws cloudwatch delete-alarms --alarm-names $ID-DocumentDB-HighCPU

# Deletar regra EventBridge
aws events remove-targets --rule $ID-documentdb-failover-events --ids 1
aws events delete-rule --name $ID-documentdb-failover-events

# Deletar dashboard
aws cloudwatch delete-dashboards --dashboard-names $ID-DocumentDB-Dashboard-ByAWSCli
aws cloudwatch delete-dashboards --dashboard-names $ID-DocumentDB-Dashboard

# Deletar tópico SNS
aws sns delete-topic --topic-arn $TOPIC_ARN
```

---

[⬅️ Exercício 3](../exercicio3-failover/README.md) | [➡️ Exercício 5](../exercicio5-manutencao/README.md)
