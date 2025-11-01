# Exercício 3: Gerenciamento de Failover

## 🎯 Objetivos

- Entender como funciona o failover no DocumentDB
- Testar failover automático e manual
- Configurar aplicações para lidar com failover
- Monitorar o processo de failover
- Medir tempo de recuperação (RTO)

## ⏱️ Duração Estimada
60 minutos

---

## 📚 Conceitos

### O que é Failover?

Failover é o processo de promover uma réplica a primária quando a instância primária atual falha ou fica indisponível.

### Tipos de Failover

1. **Failover Automático**
   - Ocorre automaticamente em caso de falha
   - Tempo típico: 30-120 segundos
   - Não requer intervenção

2. **Failover Manual**
   - Iniciado pelo administrador
   - Útil para manutenção planejada
   - Permite escolher a réplica específica

### Arquitetura de Alta Disponibilidade

```
┌─────────────────────────────────────────────┐
│         Cluster Endpoint (Writer)           │
│    lab-cluster.cluster-xxx.docdb.aws.com    │
└────────────────┬────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
   ┌────▼────┐      ┌────▼────┐      ┌─────────┐
   │ Primary │      │ Replica │      │ Replica │
   │  (AZ-a) │      │  (AZ-b) │      │  (AZ-c) │
   └─────────┘      └─────────┘      └─────────┘
        │                 │                 │
        └─────────────────┴─────────────────┘
                         │
        ┌────────────────▼──────────────────┐
        │  Reader Endpoint (Read-Only)      │
        │ lab-cluster.cluster-ro-xxx...com  │
        └───────────────────────────────────┘
```

---

## 🔧 Parte 1: Configurar Ambiente de Teste

### Passo 1: Verificar Cluster

```bash
# Listar instâncias do cluster
aws docdb describe-db-cluster-members \
  --db-cluster-identifier lab-cluster-console \
  --query 'DBClusterMembers[*].[DBInstanceIdentifier, IsClusterWriter, PromotionTier]' \
  --output table

# Verificar status das instâncias
aws docdb describe-db-instances \
  --query 'DBInstances[*].[DBInstanceIdentifier, DBInstanceStatus, AvailabilityZone]' \
  --output table
```

### Passo 2: Identificar a Primária Atual

```bash
# Obter a instância primária
PRIMARY=$(aws docdb describe-db-cluster-members \
  --db-cluster-identifier lab-cluster-console \
  --query 'DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' \
  --output text)

echo "Instância Primária Atual: $PRIMARY"
```

### Passo 3: Configurar Monitoramento

Abra o CloudWatch em outra janela para monitorar métricas durante o failover:
- `DatabaseConnections`
- `CPUUtilization`
- `ReadLatency` / `WriteLatency`

---

## 🔄 Parte 2: Failover Manual

### Via Console AWS

1. Acesse o console DocumentDB
2. Selecione o cluster `lab-cluster-console`
3. Clique em **Actions** → **Failover**
4. Confirme a ação
5. Observe o processo (leva ~60-90 segundos)

### Via AWS CLI

```bash
# Executar failover manual
aws docdb failover-db-cluster \
  --db-cluster-identifier lab-cluster-console

echo "Failover iniciado! Aguardando conclusão..."

# Monitorar até completar
while true; do
  STATUS=$(aws docdb describe-db-clusters \
    --db-cluster-identifier lab-cluster-console \
    --query 'DBClusters[0].Status' \
    --output text)
  
  echo "Status do cluster: $STATUS"
  
  if [ "$STATUS" == "available" ]; then
    echo "Failover concluído!"
    break
  fi
  
  sleep 5
done

# Verificar nova primária
NEW_PRIMARY=$(aws docdb describe-db-cluster-members \
  --db-cluster-identifier lab-cluster-console \
  --query 'DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' \
  --output text)

echo "Nova Instância Primária: $NEW_PRIMARY"
```

### Via Script Automatizado

```bash
cd scripts/
chmod +x test-failover.sh
./test-failover.sh lab-cluster-console
```

---

## ⚡ Parte 3: Simular Falha de Instância

### Reboot com Failover

```bash
# Reiniciar a instância primária (força failover)
aws docdb reboot-db-instance \
  --db-instance-identifier $PRIMARY \
  --force-failover

echo "Reboot com failover iniciado..."

# Monitorar o processo
watch -n 2 "aws docdb describe-db-cluster-members \
  --db-cluster-identifier lab-cluster-console \
  --query 'DBClusterMembers[*].[DBInstanceIdentifier, IsClusterWriter]' \
  --output table"
```

---

## 📊 Parte 4: Medir Tempo de Recuperação (RTO)

### Script para Medir RTO

Crie um script que monitora continuamente a disponibilidade:

```bash
cd scripts/
chmod +x monitor-endpoints.sh

# Em um terminal, inicie o monitoramento
./monitor-endpoints.sh lab-cluster-console

# Em outro terminal, execute o failover
aws docdb failover-db-cluster \
  --db-cluster-identifier lab-cluster-console
```

O script registrará:
- Tempo de detecção da falha
- Tempo até nova primária estar disponível
- Tempo total de indisponibilidade

---

## 🔌 Parte 5: Aplicação Resiliente a Failover

### Exemplo Node.js com Retry Logic

Veja o arquivo `exemplos/connection-failover.js`:

```bash
cd exemplos/
npm install mongodb

# Executar aplicação de teste
node connection-failover.js

# Em outro terminal, force um failover
aws docdb failover-db-cluster \
  --db-cluster-identifier lab-cluster-console
```

A aplicação deve:
- ✅ Detectar perda de conexão
- ✅ Reconectar automaticamente
- ✅ Retomar operações sem erro

### Práticas Recomendadas para Aplicações

1. **Use Connection Strings Corretos**
   ```javascript
   mongodb://user:pass@cluster-endpoint:27017/?replicaSet=rs0&retryWrites=false
   ```

2. **Configure Retry Logic**
   - Timeout de conexão: 5-10 segundos
   - Retry automático: 3-5 tentativas
   - Backoff exponencial

3. **Use Connection Pooling**
   ```javascript
   {
     maxPoolSize: 50,
     minPoolSize: 10,
     serverSelectionTimeoutMS: 5000,
     socketTimeoutMS: 45000
   }
   ```

4. **Monitore Status de Conexão**
   - Implemente health checks
   - Log de reconexões
   - Alertas em falhas persistentes

---

## 🎯 Parte 6: Teste de Resiliência Completo

### Cenário: Manutenção sem Downtime

```bash
#!/bin/bash
# Cenário completo de manutenção planejada

CLUSTER="lab-cluster-console"

echo "1. Verificar cluster saudável..."
./scripts/health-check.sh $CLUSTER

echo "2. Iniciar aplicação de teste..."
node exemplos/connection-failover.js &
APP_PID=$!

echo "3. Aguardar 10 segundos..."
sleep 10

echo "4. Executar failover..."
aws docdb failover-db-cluster --db-cluster-identifier $CLUSTER

echo "5. Aguardar 60 segundos..."
sleep 60

echo "6. Verificar aplicação ainda está funcionando..."
if ps -p $APP_PID > /dev/null; then
   echo "✅ Aplicação continuou operando!"
else
   echo "❌ Aplicação falhou"
fi

# Parar aplicação
kill $APP_PID
```

---

## 📈 Parte 7: Análise de Métricas

### Métricas Importantes Durante Failover

```bash
# CPUUtilization da nova primária
aws cloudwatch get-metric-statistics \
  --namespace AWS/DocDB \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=$NEW_PRIMARY \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average

# DatabaseConnections
aws cloudwatch get-metric-statistics \
  --namespace AWS/DocDB \
  --metric-name DatabaseConnections \
  --dimensions Name=DBClusterIdentifier,Value=lab-cluster-console \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Maximum
```

### Criar Dashboard de Failover

1. Acesse CloudWatch > Dashboards
2. Crie dashboard "DocumentDB-Failover-Monitoring"
3. Adicione widgets:
   - Database Connections (linha)
   - Write Latency (linha)
   - CPU Utilization por instância (linha)
   - Replica Lag (linha)

---

## ✅ Checklist de Conclusão

- [ ] Identificou instância primária atual
- [ ] Executou failover manual com sucesso
- [ ] Mediu tempo de recuperação (RTO)
- [ ] Testou reboot com failover
- [ ] Implementou aplicação com retry logic
- [ ] Validou reconexão automática
- [ ] Analisou métricas do CloudWatch
- [ ] Entendeu diferença entre failover automático e manual

---

## 📊 Resultados Esperados

| Métrica | Valor Esperado |
|---------|----------------|
| **RTO (Recovery Time)** | 30-120 segundos |
| **Perda de Conexões** | Temporária (reconexão automática) |
| **Mudança de Endpoint** | Não (cluster endpoint permanece) |
| **Perda de Dados** | Zero (replicação síncrona) |

---

## 🧹 Limpeza

Não é necessário limpar recursos específicos deste exercício, pois apenas testamos funcionalidades do cluster existente.

---

## 📝 Exercícios Extras

1. **Failover Priority:** Configure promotion tiers diferentes
2. **Cross-AZ Failover:** Force failover para AZ específica
3. **Stress Test:** Simule carga durante failover
4. **Multi-Failover:** Execute múltiplos failovers consecutivos

---

## 💡 Best Practices

- ✅ Teste failover regularmente (ex: trimestralmente)
- ✅ Configure aplicações com retry automático
- ✅ Use cluster endpoint (nunca endpoint de instância)
- ✅ Monitore replica lag
- ✅ Mantenha 3+ instâncias em AZs diferentes
- ✅ Configure alarmes para eventos de failover
- ✅ Documente RTOs e RPOs esperados
- ✅ Treine equipe em procedimentos de failover

---

## 🆘 Troubleshooting

**Failover está demorando muito**
- Verifique replica lag antes do failover
- Confirme que réplicas estão em AZs diferentes
- Check network connectivity entre AZs

**Aplicação não reconecta**
- Verifique connection string (deve usar cluster endpoint)
- Configure timeout adequado
- Implemente retry logic

**Perda de dados após failover**
- DocumentDB não deveria perder dados
- Verifique se write concern está correto
- Confirme que replicação estava saudável

---

[⬅️ Exercício 2](../exercicio2-backup-snapshots/README.md) | [➡️ Exercício 4](../exercicio4-monitoramento/README.md)
