# Exercício 5: Operações de Manutenção e Atualizações

## 🎯 Objetivos

- Realizar upgrades de versão do DocumentDB
- Modificar parâmetros de cluster e instâncias
- Aplicar patches de segurança
- Escalar recursos (vertical e horizontal)
- Planejar e executar manutenções programadas
- Implementar janelas de manutenção

## ⏱️ Duração Estimada
60 minutos

---

## 📚 Conceitos

### Tipos de Manutenção

1. **Manutenção Automática**
   - Patches de segurança críticos
   - Correções de bugs
   - Executada na janela de manutenção configurada

2. **Manutenção Manual**
   - Upgrades de versão major/minor
   - Mudança de instance class
   - Modificação de parâmetros
   - Requer planejamento

3. **Manutenção Emergencial**
   - Patches críticos de segurança
   - Pode ocorrer fora da janela configurada

### Janela de Manutenção

- Período semanal de 30 minutos
- Configurável para horário de baixo tráfego
- Formato: `dia:hh24:mi-dia:hh24:mi` (UTC)
- Exemplo: `sun:03:00-sun:03:30`

---

## 🔧 Parte 1: Configurar Janela de Manutenção

### Via Console

1. Acesse o console DocumentDB
2. Selecione o cluster
3. Clique em **Modify**
4. Em **Maintenance window**, configure:
   - **Preferred maintenance window:** `sun:03:00-sun:03:30`
5. **Apply immediately:** No (para próxima janela)
6. Clique em **Modify cluster**

### Via AWS CLI

```bash
# Configurar janela de manutenção
aws docdb modify-db-cluster \
  --db-cluster-identifier lab-cluster-console \
  --preferred-maintenance-window "sun:03:00-sun:03:30" \
  --no-apply-immediately

# Verificar configuração
aws docdb describe-db-clusters \
  --db-cluster-identifier lab-cluster-console \
  --query 'DBClusters[0].[PreferredMaintenanceWindow, AutoMinorVersionUpgrade]' \
  --output table
```

### Horários Recomendados por Timezone

```
UTC:        sun:03:00-sun:03:30
EST/EDT:    sun:22:00-sun:22:30 (sábado à noite)
PST/PDT:    mon:02:00-mon:02:30 (domingo à noite)
BRT/BRST:   sun:00:00-sun:00:30 (sábado à noite)
```

---

## 📊 Parte 2: Verificar Versão Atual

### Identificar Versão

```bash
# Via CLI
aws docdb describe-db-clusters \
  --db-cluster-identifier lab-cluster-console \
  --query 'DBClusters[0].[EngineVersion, Engine]' \
  --output table

# Versões disponíveis
aws docdb describe-db-engine-versions \
  --engine docdb \
  --query 'DBEngineVersions[*].[EngineVersion, DBParameterGroupFamily]' \
  --output table
```

### Via mongosh

```bash
mongosh --host $CLUSTER_ENDPOINT:27017 \
  --username docdbadmin \
  --password Lab12345! \
  --tls \
  --tlsCAFile global-bundle.pem \
  --eval "db.version()"
```

---

## ⬆️ Parte 3: Upgrade de Versão

### Preparação

**Checklist Pré-Upgrade:**

- [ ] Criar snapshot manual (backup de segurança)
- [ ] Testar upgrade em ambiente de dev/staging
- [ ] Revisar release notes da nova versão
- [ ] Verificar compatibilidade de aplicações
- [ ] Notificar equipes e stakeholders
- [ ] Planejar rollback se necessário
- [ ] Documentar baseline de performance

### Criar Backup Antes do Upgrade

```bash
# Criar snapshot manual
aws docdb create-db-cluster-snapshot \
  --db-cluster-snapshot-identifier pre-upgrade-snapshot-$(date +%Y%m%d) \
  --db-cluster-identifier lab-cluster-console

# Aguardar snapshot completar
aws docdb wait db-cluster-snapshot-available \
  --db-cluster-snapshot-identifier pre-upgrade-snapshot-$(date +%Y%m%d)
```

### Executar Upgrade (Minor Version)

```bash
# Upgrade minor version (ex: 5.0.0 -> 5.0.1)
aws docdb modify-db-cluster \
  --db-cluster-identifier lab-cluster-console \
  --engine-version 5.0.1 \
  --allow-major-version-upgrade \
  --apply-immediately

# Monitorar progresso
watch -n 10 "aws docdb describe-db-clusters \
  --db-cluster-identifier lab-cluster-console \
  --query 'DBClusters[0].[Status, EngineVersion]' \
  --output table"
```

### Upgrade Major Version (ex: 4.0 -> 5.0)

```bash
# Major version upgrade requer mais atenção
aws docdb modify-db-cluster \
  --db-cluster-identifier lab-cluster-console \
  --engine-version 5.0.0 \
  --allow-major-version-upgrade \
  --apply-immediately

# IMPORTANTE: Teste extensivamente em staging primeiro!
```

### Via Script Automatizado

```bash
cd scripts/
chmod +x upgrade-cluster.sh
./upgrade-cluster.sh lab-cluster-console 5.0.1
```

---

## 🔄 Parte 4: Modificar Instâncias

### Escalonamento Vertical (Resize)

#### Via Console

1. Selecione a instância no console
2. Clique em **Modify**
3. Altere **DB instance class**:
   - De: `db.t3.medium`
   - Para: `db.r5.large`
4. Escolha quando aplicar:
   - **Apply immediately:** Sim (downtime)
   - **Apply during maintenance window:** Não (downtime mínimo)

#### Via AWS CLI

```bash
# Modificar instance class
aws docdb modify-db-instance \
  --db-instance-identifier lab-cluster-console-1 \
  --db-instance-class db.r5.large \
  --apply-immediately

# Verificar progresso
aws docdb describe-db-instances \
  --db-instance-identifier lab-cluster-console-1 \
  --query 'DBInstances[0].[DBInstanceStatus, DBInstanceClass]'
```

### Escalonamento Horizontal (Add/Remove Replicas)

#### Adicionar Réplica

```bash
# Adicionar nova réplica
aws docdb create-db-instance \
  --db-instance-identifier lab-cluster-console-4 \
  --db-instance-class db.t3.medium \
  --db-cluster-identifier lab-cluster-console \
  --engine docdb

# Aguardar disponibilidade
aws docdb wait db-instance-available \
  --db-instance-identifier lab-cluster-console-4
```

#### Remover Réplica

```bash
# Deletar réplica (NUNCA delete a primária diretamente!)
aws docdb delete-db-instance \
  --db-instance-identifier lab-cluster-console-4 \
  --skip-final-snapshot
```

---

## ⚙️ Parte 5: Modificar Parâmetros

### Parameter Groups

#### Criar Custom Parameter Group

```bash
# Criar parameter group customizado
aws docdb create-db-cluster-parameter-group \
  --db-cluster-parameter-group-name custom-docdb-params \
  --db-parameter-group-family docdb5.0 \
  --description "Custom parameters for production cluster"

# Modificar parâmetros
aws docdb modify-db-cluster-parameter-group \
  --db-cluster-parameter-group-name custom-docdb-params \
  --parameters \
    "ParameterName=audit_logs,ParameterValue=enabled,ApplyMethod=immediate" \
    "ParameterName=tls,ParameterValue=enabled,ApplyMethod=pending-reboot" \
    "ParameterName=ttl_monitor,ParameterValue=enabled,ApplyMethod=immediate"

# Listar parâmetros
aws docdb describe-db-cluster-parameters \
  --db-cluster-parameter-group-name custom-docdb-params \
  --query 'Parameters[*].[ParameterName, ParameterValue, ApplyMethod]' \
  --output table
```

#### Aplicar Parameter Group ao Cluster

```bash
# Aplicar novo parameter group
aws docdb modify-db-cluster \
  --db-cluster-identifier lab-cluster-console \
  --db-cluster-parameter-group-name custom-docdb-params \
  --apply-immediately

# Reiniciar instâncias para aplicar parâmetros pending-reboot
aws docdb reboot-db-instance \
  --db-instance-identifier lab-cluster-console-1
```

### Parâmetros Importantes

| Parâmetro | Valores | Descrição | Apply Method |
|-----------|---------|-----------|--------------|
| `audit_logs` | enabled/disabled | Habilita audit logs | immediate |
| `tls` | enabled/disabled | Força TLS | pending-reboot |
| `ttl_monitor` | enabled/disabled | TTL automático | immediate |
| `profiler` | enabled/disabled | Profiler de queries | immediate |
| `profiler_threshold_ms` | 0-2147483647 | Threshold do profiler (ms) | immediate |

---

## 🛡️ Parte 6: Aplicar Patches de Segurança

### Verificar Patches Disponíveis

```bash
# Listar manutenções pendentes
aws docdb describe-pending-maintenance-actions \
  --resource-identifier arn:aws:rds:us-east-1:ACCOUNT_ID:cluster:lab-cluster-console

# Ver detalhes
aws docdb describe-pending-maintenance-actions \
  --resource-identifier arn:aws:rds:us-east-1:ACCOUNT_ID:cluster:lab-cluster-console \
  --query 'PendingMaintenanceActions[*].PendingMaintenanceActionDetails' \
  --output table
```

### Aplicar Patch Imediatamente

```bash
# Aplicar manutenção pendente agora
aws docdb apply-pending-maintenance-action \
  --resource-identifier arn:aws:rds:us-east-1:ACCOUNT_ID:cluster:lab-cluster-console \
  --apply-action system-update \
  --opt-in-type immediate
```

### Adiar para Próxima Janela

```bash
# Aplicar na próxima janela de manutenção
aws docdb apply-pending-maintenance-action \
  --resource-identifier arn:aws:rds:us-east-1:ACCOUNT_ID:cluster:lab-cluster-console \
  --apply-action system-update \
  --opt-in-type next-maintenance
```

---

## 📋 Parte 7: Checklist de Manutenção Completa

Veja o arquivo `checklists/manutencao.md` para checklist detalhado

### Resumo das Etapas

1. **Planejamento (1-2 semanas antes)**
   - [ ] Definir escopo da manutenção
   - [ ] Escolher data/hora (janela de manutenção)
   - [ ] Criar comunicação para stakeholders
   - [ ] Testar em ambiente de staging

2. **Preparação (1 dia antes)**
   - [ ] Criar snapshot manual
   - [ ] Verificar baseline de performance
   - [ ] Preparar scripts de rollback
   - [ ] Confirmar disponibilidade da equipe

3. **Execução (Durante manutenção)**
   - [ ] Notificar início da manutenção
   - [ ] Executar mudanças planejadas
   - [ ] Monitorar logs e métricas
   - [ ] Validar funcionalidade

4. **Pós-Manutenção**
   - [ ] Verificar performance
   - [ ] Confirmar aplicações funcionando
   - [ ] Documentar mudanças realizadas
   - [ ] Notificar conclusão

---

## 🔄 Parte 8: Rollback

### Quando Fazer Rollback

- Performance degradada significativamente
- Erros de compatibilidade com aplicações
- Instabilidade do cluster
- Falhas inesperadas

### Procedimento de Rollback (Downgrade)

```bash
# Opção 1: Restaurar snapshot pré-upgrade
aws docdb restore-db-cluster-from-snapshot \
  --db-cluster-identifier lab-cluster-rollback \
  --snapshot-identifier pre-upgrade-snapshot-20250101 \
  --engine docdb \
  --db-subnet-group-name docdb-lab-subnet-group

# Opção 2: Criar novo cluster da versão anterior
# e migrar dados (mais complexo)
```

**IMPORTANTE:** Downgrade direto não é suportado. Sempre use snapshots!

---

## 🧪 Parte 9: Teste Pós-Manutenção

### Performance Baseline

```bash
# Comparar métricas antes e depois
aws cloudwatch get-metric-statistics \
  --namespace AWS/DocDB \
  --metric-name CPUUtilization \
  --dimensions Name=DBClusterIdentifier,Value=lab-cluster-console \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

### Teste Funcional

```bash
# Conectar e executar queries de teste
mongosh --host $CLUSTER_ENDPOINT:27017 \
  --username docdbadmin \
  --password Lab12345! \
  --tls \
  --tlsCAFile global-bundle.pem \
  --eval '
    // Teste básico
    db.test.insertOne({test: "post-maintenance", timestamp: new Date()})
    db.test.findOne({test: "post-maintenance"})
    
    // Verificar replica set
    rs.status()
  '
```

---

## ✅ Checklist de Conclusão

- [ ] Janela de manutenção configurada
- [ ] Versão atual identificada
- [ ] Snapshot pré-upgrade criado
- [ ] Upgrade de versão executado (ou simulado)
- [ ] Instância modificada (resize)
- [ ] Parameter group customizado criado
- [ ] Parâmetros modificados e aplicados
- [ ] Testes pós-manutenção executados
- [ ] Documentação atualizada

---

## 🧹 Limpeza

```bash
# Deletar snapshots de teste
aws docdb delete-db-cluster-snapshot \
  --db-cluster-snapshot-identifier pre-upgrade-snapshot-20250101

# Deletar parameter group customizado (se não estiver em uso)
aws docdb delete-db-cluster-parameter-group \
  --db-cluster-parameter-group-name custom-docdb-params
```

---

## 📝 Exercícios Extras

1. **Blue/Green Deployment:** Crie cluster paralelo para upgrade zero-downtime
2. **Automated Maintenance:** Crie Lambda para automação de manutenções
3. **Maintenance Dashboard:** Dashboard CloudWatch específico para manutenções
4. **Rollback Drill:** Pratique procedimento completo de rollback

---

## 💡 Best Practices

- ✅ Sempre teste upgrades em ambiente não-produção primeiro
- ✅ Crie snapshots antes de qualquer manutenção
- ✅ Configure janelas de manutenção em horários de baixo tráfego
- ✅ Monitore métricas por 24-48h após manutenção
- ✅ Documente todas as mudanças realizadas
- ✅ Mantenha runbooks de rollback atualizados
- ✅ Configure alertas específicos durante manutenção
- ✅ Comunique mudanças com antecedência
- ✅ Tenha equipe de prontidão durante manutenções
- ✅ Use auto minor version upgrade em produção

---

## 🆘 Troubleshooting

**Upgrade está demorando muito**
- Upgrades podem levar 15-30 minutos
- Monitore logs do cluster
- Verifique se não há operações pesadas em andamento

**Erro após upgrade**
- Verifique compatibilidade de drivers
- Revise release notes para breaking changes
- Considere rollback via snapshot

**Parameter changes não aplicando**
- Alguns parâmetros requerem reboot
- Verifique ApplyMethod do parâmetro
- Reinicie instâncias se necessário

**Performance degradada após manutenção**
- Compare métricas com baseline
- Verifique se mudanças de configuração foram aplicadas
- Considere rollback se crítico

---

## 📚 Recursos Adicionais

- [DocumentDB Maintenance](https://docs.aws.amazon.com/documentdb/latest/developerguide/db-instance-maintain.html)
- [Upgrading Engine Version](https://docs.aws.amazon.com/documentdb/latest/developerguide/db-instance-update.html)
- [Parameter Groups](https://docs.aws.amazon.com/documentdb/latest/developerguide/db-cluster-parameter-group.html)

---

[⬅️ Exercício 4](../exercicio4-monitoramento/README.md) | [🏠 Voltar ao Início](../README.md)
