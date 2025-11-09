# Exercício 1: Métricas Avançadas e Monitoramento de Performance

## 🎯 Objetivos

- Aprender a estrutura de métricas customizadas no CloudWatch
- Criar dashboard especializado para visualização de métricas
- Configurar alertas baseados em métricas customizadas
- Entender conceitos de monitoramento de performance do DocumentDB

> 📚 **Nota Educacional:** Este exercício usa métricas simuladas para demonstrar conceitos. O foco é aprender a mecânica de coleta, envio e visualização de métricas customizadas.

## ⏱️ Duração Estimada
75 minutos

> ⚠️ **Atenção:** Lembre-se de usar seu prefixo de aluno (`<seu-id>`) em todos os nomes de recursos e comandos.

---

## 📊 Parte 1: Configurar Métricas Customizadas

### Passo 1: Preparar Ambiente

```bash
# Navegar para o diretório do exercício
cd exercicio1-metricas-avancadas

# Baixar certificado SSL do DocumentDB
wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

# Instalar Node.js dependencies para coleta de métricas
npm install
```

### Passo 2: Script de Demonstração de Métricas

Execute o script para enviar métricas de exemplo ao CloudWatch:

```bash
# Configurar variáveis de ambiente
export ID="<seu-id>"
export CLUSTER_ENDPOINT=$(aws docdb describe-db-clusters \
--db-cluster-identifier $ID-lab-cluster-console \
--query 'DBClusters[0].Endpoint' \
--output text)
export DB_USERNAME="docdbadmin"
export DB_PASSWORD="Lab12345!"

# Executar script de exemplo
node scripts/collect-metrics.js
```

> 💡 **O que o script faz:** Conecta no DocumentDB e envia métricas simuladas para o CloudWatch, demonstrando:
> - Como estruturar métricas customizadas
> - Como usar o AWS SDK para CloudWatch
> - Como categorizar métricas (Time, Percent, Count)
> - Como usar dimensões e namespaces

**Métricas de exemplo enviadas:**
- `QueryExecutionTime` - Tempo simulado de execução de queries
- `IndexHitRatio` - Taxa simulada de acerto de índices  
- `ConnectionPoolUtilization` - Utilização simulada do pool de conexões
- `SlowQueries` - Contagem simulada de queries lentas

---

## 📈 Parte 2: Dashboard de Performance Avançado

> ⚠️ **Importante:** Execute primeiro o script de métricas (Parte 1, Passo 2) antes de criar o dashboard, para que as métricas customizadas apareçam disponíveis.

### Via Console AWS

1. Acesse **CloudWatch > Dashboards**
2. Clique em **Create dashboard**
3. Nome: `<seu-id>-Performance-Tuning-Dashboard`

#### Como encontrar as métricas customizadas:

Após executar o script, na tela que você está vendo:
1. **Não clique em nenhum serviço** (DocDB, EBS, etc.)
2. **Use a barra de busca** no topo: digite `Custom/DocumentDB`
3. **Ou role para baixo** até encontrar a seção "Custom namespaces"

#### Widget 1: Query Performance Metrics
- Tipo: Line chart
- Na busca, digite: `Custom/DocumentDB`
- Selecione as métricas:
  - `QueryExecutionTime`
  - `SlowQueries`
- Period: 1 minute
- Statistic: Average

**Widget 2: Index Efficiency**
- Tipo: Number
- Busque por: `Custom/DocumentDB`
- Selecione: `IndexHitRatio`
- Period: 5 minutes
- Statistic: Average

**Widget 3: Connection Pool Health**
- Tipo: Stacked area  
- Busque por: `Custom/DocumentDB`
- Selecione:
  - `ActiveConnections`
  - `IdleConnections`
  - `ConnectionWaitTime`
- Period: 1 minute

> 💡 **Dica:** Se as métricas não aparecerem, aguarde alguns minutos após executar o script ou execute-o novamente.

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

## 📊 Parte 4: Conceitos de Performance Baseline

### Entendendo Baselines de Performance

> 📖 **Conceito:** Um baseline é um conjunto de métricas de referência coletadas em condições normais de operação.

**Exemplos de métricas importantes para baseline:**

1. **Latência por Tipo de Operação**
   - Read operations: Tipicamente < 10ms
   - Write operations: Tipicamente < 20ms  
   - Update operations: Tipicamente < 15ms

2. **Throughput Esperado**
   - Reads per second: Varia por instância
   - Writes per second: Geralmente menor que reads
   - Mixed workload: Depende da proporção read/write

3. **Utilização de Recursos**
   - CPU utilization: Manter < 70% em operação normal
   - Memory utilization: Manter < 80%
   - Connection efficiency: Buscar > 90%

> 💡 **Dica:** Em um ambiente real, você coletaria essas métricas durante períodos de operação normal para estabelecer seus próprios baselines.

---

## 🔍 Parte 5: Conceitos de Monitoramento Contínuo

### Como Implementar Coleta Contínua (Conceitual)

> 📖 **Em um ambiente real**, você implementaria coleta contínua usando:

**Opção 1: Cron Job**
```bash
# Exemplo de cron job para coleta a cada 5 minutos
*/5 * * * * cd /path/to/metrics && node collect-metrics.js
```

**Opção 2: Daemon/Serviço**
```javascript
// Loop contínuo com intervalo
setInterval(async () => {
  await collectRealMetrics();
}, 60000); // A cada 1 minuto
```

**Opção 3: AWS Lambda + EventBridge**
- Função Lambda executada periodicamente
- Coleta métricas e envia para CloudWatch
- Serverless e escalável

### Teste Opcional: Simular Coleta Contínua

```bash
# Execute o script algumas vezes para simular dados históricos
for i in {1..5}; do
  echo "Enviando métricas - execução $i"
  node scripts/collect-metrics.js
  sleep 30
done
```

---

## 📋 Parte 6: Validação e Testes

### Teste 1: Verificar se Métricas Foram Enviadas

```bash
# Verificar se métricas customizadas estão no CloudWatch
aws cloudwatch list-metrics --namespace Custom/DocumentDB

# Se não aparecer nada, verificar todas as métricas customizadas
aws cloudwatch list-metrics --query "Metrics[?Namespace=='Custom/DocumentDB']"

# Verificar se há erros de permissão
aws sts get-caller-identity
```

**Troubleshooting:**

Se as métricas não aparecerem no CloudWatch:

1. **Verificar execução do script:**
   ```bash
   # Execute novamente e observe as mensagens
   node scripts/collect-metrics.js
   ```

2. **Verificar variáveis de ambiente:**
   ```bash
   echo "ID: $ID"
   echo "CLUSTER_ENDPOINT: $CLUSTER_ENDPOINT" 
   echo "AWS_REGION: $AWS_REGION"
   ```

3. **Verificar permissões AWS:**
   ```bash
   # Testar permissões CloudWatch
   aws cloudwatch list-metrics --max-items 1
   ```

4. **Aguardar propagação:**
   - CloudWatch pode levar 2-5 minutos para mostrar métricas novas
   - Execute o script 2-3 vezes com intervalo de 1 minuto

### Teste 2: Verificar Configuração de Alertas

```bash
# Verificar se alarmes foram criados corretamente
aws cloudwatch describe-alarms \
--alarm-names $ID-HighQueryExecutionTime $ID-LowIndexHitRatio $ID-ConnectionPoolSaturation \
--query "MetricAlarms[].{Name:AlarmName,State:StateValue,Threshold:Threshold}"

# Listar todas as métricas customizadas criadas
aws cloudwatch list-metrics --namespace Custom/DocumentDB
```

> 💡 **Nota:** Os alarmes podem não disparar imediatamente pois as métricas são simuladas. Em um ambiente real, eles responderiam a condições reais de performance.

### Teste 3: Validar Dashboard

1. Acesse o dashboard criado no CloudWatch
2. Verifique se todos os widgets foram criados
3. Confirme que as métricas de exemplo aparecem nos gráficos
4. Teste diferentes períodos de tempo (1h, 6h, 24h)

> 📊 **Observação:** Como são métricas simuladas enviadas pontualmente, você verá apenas alguns pontos de dados. Em um sistema real, haveria dados contínuos.

---

## ✅ Checklist de Conclusão

Execute o script de validação:

```bash
# Executa o grade para avaliar atividades
./grade_exercicio1.sh
```

### Itens Verificados:

- ✅ Script de métricas executado com sucesso
- ✅ Métricas customizadas enviadas para CloudWatch
- ✅ Dashboard de performance criado com widgets
- ✅ Alertas configurados corretamente
- ✅ Conceitos de baseline compreendidos
- ✅ Estrutura de monitoramento demonstrada

---

## 🧹 Limpeza

```bash
# Deletar alarmes de performance
aws cloudwatch delete-alarms \
--alarm-names $ID-HighQueryExecutionTime $ID-LowIndexHitRatio $ID-ConnectionPoolSaturation

# Deletar dashboard
aws cloudwatch delete-dashboards \
--dashboard-names $ID-Performance-Tuning-Dashboard

# Deletar tópico SNS
aws sns delete-topic --topic-arn $PERF_TOPIC_ARN

# Nota: As métricas customizadas no CloudWatch são automaticamente removidas após 15 meses sem novos dados
```

---

## 📝 Próximos Passos

Com os conceitos de métricas customizadas aprendidos, você está pronto para:

1. **Exercício 2:** Analisar planos de execução reais do DocumentDB
2. **Aplicar conhecimento:** Implementar métricas reais em projetos futuros
3. **Expandir monitoramento:** Adicionar métricas específicas do seu caso de uso
4. **Integrar alertas:** Conectar métricas com ações automatizadas

> 🎯 **Aprendizado:** Você agora entende como estruturar, enviar e visualizar métricas customizadas no CloudWatch para monitoramento de performance do DocumentDB.

---

[⬅️ Módulo 4 Home](../README.md) | [➡️ Exercício 2](../exercicio2-planos-execucao/README.md)