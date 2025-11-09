# Exercício 1: Métricas Avançadas e Monitoramento de Performance

## 🎯 Objetivos

- Configurar métricas customizadas focadas em performance
- Criar dashboard especializado para análise de tuning
- Implementar alertas proativos para degradação de performance
- Estabelecer baseline de performance para comparações futuras

## ⏱️ Duração Estimada
75 minutos

> ⚠️ **Atenção:** Lembre-se de usar seu prefixo de aluno (`<seu-id>`) em todos os nomes de recursos e comandos.

---

## 📊 Parte 1: Configurar Métricas Customizadas

### Passo 1: Instalar Dependências

```bash
# Instalar Node.js dependencies para coleta de métricas
npm init -y
npm install mongodb aws-sdk
```

### Passo 2: Script de Coleta de Métricas Avançadas

Execute o script para começar a coletar métricas customizadas:

```bash
# Configurar variáveis de ambiente
export ID="<seu-id>"
export CLUSTER_ENDPOINT=$(aws docdb describe-db-clusters \
--db-cluster-identifier $ID-lab-cluster-console \
--query 'DBClusters[0].Endpoint' \
--output text)
export DB_USERNAME="docdbadmin"
export DB_PASSWORD="Lab12345!"


# Executar coleta de métricas
node scripts/collect-metrics.js
```

O script `collect-metrics.js` coleta as seguintes métricas customizadas:
- Tempo médio de execução de queries
- Número de operações por segundo
- Taxa de hit de índices
- Eficiência de connection pool
- Distribuição de tipos de operações

---

## 📈 Parte 2: Dashboard de Performance Avançado

### Via Console AWS

1. Acesse **CloudWatch > Dashboards**
2. Clique em **Create dashboard**
3. Nome: `<seu-id>-Performance-Tuning-Dashboard`

#### Widgets Especializados:

**Widget 1: Query Performance Metrics**
- Tipo: Line chart
- Métricas:
  - Custom/DocumentDB/QueryExecutionTime
  - Custom/DocumentDB/SlowQueries
- Period: 1 minute
- Statistic: Average

**Widget 2: Index Efficiency**
- Tipo: Number
- Métricas:
  - Custom/DocumentDB/IndexHitRatio
  - Custom/DocumentDB/IndexMisses
- Period: 5 minutes
- Statistic: Average

**Widget 3: Connection Pool Health**
- Tipo: Stacked area
- Métricas:
  - Custom/DocumentDB/ActiveConnections
  - Custom/DocumentDB/IdleConnections
  - Custom/DocumentDB/ConnectionWaitTime
- Period: 1 minute

**Widget 4: Operations Distribution**
- Tipo: Pie chart
- Métricas:
  - Custom/DocumentDB/ReadOperations
  - Custom/DocumentDB/WriteOperations
  - Custom/DocumentDB/UpdateOperations
- Period: 5 minutes

### Via CLI

```bash
# Criar dashboard usando arquivo JSON pré-configurado
aws cloudwatch put-dashboard \
--dashboard-name $ID-Performance-Tuning-Dashboard \
--dashboard-body file://cloudwatch/performance-dashboard.json

# Verificar criação
aws cloudwatch list-dashboards \
--query "DashboardEntries[?contains(DashboardName, '$ID-Performance')].DashboardName"
```

---

## 🚨 Parte 3: Alertas Proativos de Performance

### Passo 1: Criar Tópico SNS para Alertas de Performance

```bash
# Criar tópico específico para performance
aws sns create-topic \
--name $ID-performance-alerts

# Obter ARN do tópico
PERF_TOPIC_ARN=$(aws sns list-topics \
--query "Topics[?contains(TopicArn, '$ID-performance-alerts')].TopicArn" \
--output text)

echo "Performance Topic ARN: $PERF_TOPIC_ARN"

# Adicionar seu email como subscriber
aws sns subscribe \
--topic-arn $PERF_TOPIC_ARN \
--protocol email \
--notification-endpoint seu-email@example.com
```

### Passo 2: Alarmes de Performance Críticos

#### Alarme 1: Query Execution Time Alto

```bash
aws cloudwatch put-metric-alarm \
--alarm-name "$ID-HighQueryExecutionTime" \
--alarm-description "Tempo de execução de queries acima de 100ms" \
--metric-name QueryExecutionTime \
--namespace Custom/DocumentDB \
--statistic Average \
--period 300 \
--evaluation-periods 2 \
--threshold 100 \
--comparison-operator GreaterThanThreshold \
--dimensions Name=ClusterIdentifier,Value=$ID-lab-cluster-console \
--alarm-actions $PERF_TOPIC_ARN
```

#### Alarme 2: Index Hit Ratio Baixo

```bash
aws cloudwatch put-metric-alarm \
--alarm-name "$ID-LowIndexHitRatio" \
--alarm-description "Taxa de hit de índices abaixo de 95%" \
--metric-name IndexHitRatio \
--namespace Custom/DocumentDB \
--statistic Average \
--period 300 \
--evaluation-periods 3 \
--threshold 95 \
--comparison-operator LessThanThreshold \
--dimensions Name=ClusterIdentifier,Value=$ID-lab-cluster-console \
--alarm-actions $PERF_TOPIC_ARN
```

#### Alarme 3: Connection Pool Saturation

```bash
aws cloudwatch put-metric-alarm \
--alarm-name "$ID-ConnectionPoolSaturation" \
--alarm-description "Pool de conexões com mais de 80% de utilização" \
--metric-name ConnectionPoolUtilization \
--namespace Custom/DocumentDB \
--statistic Average \
--period 180 \
--evaluation-periods 2 \
--threshold 80 \
--comparison-operator GreaterThanThreshold \
--dimensions Name=ClusterIdentifier,Value=$ID-lab-cluster-console \
--alarm-actions $PERF_TOPIC_ARN
```

---

## 📊 Parte 4: Análise de Performance Baseline

### Executar Teste de Baseline

```bash
# Executar análise de performance para estabelecer baseline
node scripts/analyze-performance.js --baseline

# Gerar relatório de baseline
node scripts/analyze-performance.js --report --output baseline-report.json
```

### Métricas de Baseline Coletadas:

1. **Latência Média por Tipo de Operação**
   - Read operations: < 10ms
   - Write operations: < 20ms
   - Update operations: < 15ms

2. **Throughput Máximo**
   - Reads per second: > 1000
   - Writes per second: > 500
   - Mixed workload: > 750 ops/sec

3. **Eficiência de Recursos**
   - CPU utilization: < 70% under normal load
   - Memory utilization: < 80%
   - Connection efficiency: > 90%

---

## 🔍 Parte 5: Monitoramento Contínuo

### Configurar Coleta Automática

```bash
# Criar cron job para coleta contínua de métricas
(crontab -l 2>/dev/null; echo "*/5 * * * * cd $(pwd) && node scripts/collect-metrics.js") | crontab -

# Verificar cron job
crontab -l | grep collect-metrics
```

### Script de Monitoramento em Tempo Real

```bash
# Executar monitoramento em tempo real (deixe rodando em terminal separado)
./scripts/real-time-monitor.sh
```

---

## 📋 Parte 6: Validação e Testes

### Teste 1: Verificar Coleta de Métricas

```bash
# Verificar se métricas customizadas estão sendo enviadas
aws cloudwatch list-metrics \
--namespace Custom/DocumentDB \
--query "Metrics[?contains(MetricName, 'Query') || contains(MetricName, 'Index')].MetricName"
```

### Teste 2: Validar Alertas

```bash
# Simular carga para testar alertas
node scripts/load-simulator.js --duration 300 --high-load

# Verificar se alarmes foram disparados
aws cloudwatch describe-alarms \
--alarm-names $ID-HighQueryExecutionTime $ID-LowIndexHitRatio $ID-ConnectionPoolSaturation \
--query "MetricAlarms[].{Name:AlarmName,State:StateValue,Reason:StateReason}"
```

### Teste 3: Dashboard Functionality

1. Acesse o dashboard criado no CloudWatch
2. Verifique se todos os widgets estão mostrando dados
3. Confirme que as métricas estão sendo atualizadas em tempo real
4. Teste diferentes períodos de tempo (1h, 6h, 24h)

---

## ✅ Checklist de Conclusão

Execute o script de validação:

```bash
# Executa o grade para avaliar atividades
./grade_exercicio1.sh
```

### Itens Verificados:

- ✅ Métricas customizadas configuradas e coletando dados
- ✅ Dashboard de performance criado com widgets especializados
- ✅ Alertas proativos configurados e funcionando
- ✅ Baseline de performance estabelecido
- ✅ Monitoramento contínuo ativo
- ✅ Testes de validação executados com sucesso

---

## 🧹 Limpeza

```bash
# Parar coleta automática de métricas
crontab -l | grep -v collect-metrics | crontab -

# Deletar alarmes de performance
aws cloudwatch delete-alarms \
--alarm-names $ID-HighQueryExecutionTime $ID-LowIndexHitRatio $ID-ConnectionPoolSaturation

# Deletar dashboard
aws cloudwatch delete-dashboards \
--dashboard-names $ID-Performance-Tuning-Dashboard

# Deletar tópico SNS
aws sns delete-topic --topic-arn $PERF_TOPIC_ARN

# Parar scripts de monitoramento
pkill -f "collect-metrics\|real-time-monitor"
```

---

## 📝 Próximos Passos

Com o monitoramento avançado configurado, você está pronto para:

1. **Exercício 2:** Analisar planos de execução usando as métricas coletadas
2. **Identificar gargalos:** Use os dados do dashboard para encontrar problemas
3. **Otimizar queries:** Baseado nas métricas de tempo de execução
4. **Ajustar índices:** Usando dados de eficiência de índices

---

[⬅️ Módulo 4 Home](../README.md) | [➡️ Exercício 2](../exercicio2-planos-execucao/README.md)