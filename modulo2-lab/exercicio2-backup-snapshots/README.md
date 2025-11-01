# Exercício 2: Backup e Snapshots Automáticos

## 🎯 Objetivos

- Entender políticas de backup automático do DocumentDB
- Criar snapshots manuais
- Restaurar clusters a partir de snapshots
- Configurar janelas de backup
- Gerenciar retenção de backups

## ⏱️ Duração Estimada
45 minutos

---

## 📚 Conceitos

### Backup Automático
- Backups incrementais contínuos
- Retenção configurável (1-35 dias)
- Armazenados no S3 (transparente)
- Permite Point-in-Time Recovery (PITR)

### Snapshots Manuais
- Backups sob demanda
- Persistem até serem deletados manualmente
- Úteis para marcos importantes (releases, migrações)
- Podem ser compartilhados entre contas

---

## 🔧 Parte 1: Configurar Backup Automático

### Via Console

1. Acesse o console DocumentDB
2. Selecione seu cluster
3. Clique em **Modify**
4. Em **Backup:**
   - **Backup retention period:** 7 dias
   - **Backup window:** 03:00-04:00 UTC
5. Clique em **Continue**
6. **Apply immediately:** Yes
7. Clique em **Modify cluster**

### Via AWS CLI

```bash
# Modificar política de backup
aws docdb modify-db-cluster \
  --db-cluster-identifier lab-cluster-console \
  --backup-retention-period 7 \
  --preferred-backup-window "03:00-04:00" \
  --apply-immediately

# Verificar configuração
aws docdb describe-db-clusters \
  --db-cluster-identifier lab-cluster-console \
  --query 'DBClusters[0].[BackupRetentionPeriod, PreferredBackupWindow]' \
  --output table
```

---

## 📸 Parte 2: Criar Snapshot Manual

### Via Console

1. No console DocumentDB, selecione o cluster
2. Clique em **Actions** → **Take snapshot**
3. Configure:
   - **Snapshot identifier:** `lab-snapshot-manual-001`
   - **Tags:** (opcional)
     - Key: `Purpose`, Value: `Lab Exercise`
4. Clique em **Take snapshot**
5. Aguarde até status = **Available** (~5-10 minutos)

### Via AWS CLI

```bash
# Criar snapshot
aws docdb create-db-cluster-snapshot \
  --db-cluster-snapshot-identifier lab-snapshot-manual-001 \
  --db-cluster-identifier lab-cluster-console \
  --tags Key=Purpose,Value=LabExercise

# Verificar progresso
aws docdb describe-db-cluster-snapshots \
  --db-cluster-snapshot-identifier lab-snapshot-manual-001 \
  --query 'DBClusterSnapshots[0].[Status, PercentProgress]' \
  --output table

# Listar todos os snapshots
aws docdb describe-db-cluster-snapshots \
  --query 'DBClusterSnapshots[*].[DBClusterSnapshotIdentifier, Status, SnapshotCreateTime]' \
  --output table
```

### Via Script

Use o script fornecido:

```bash
cd scripts/
chmod +x backup-manual.sh
./backup-manual.sh lab-cluster-console
```

---

## 🔄 Parte 3: Restaurar a partir de Snapshot

### Cenário
Você precisa criar um cluster de desenvolvimento a partir do snapshot de produção.

### Via Console

1. No console DocumentDB, vá para **Snapshots**
2. Selecione `lab-snapshot-manual-001`
3. Clique em **Actions** → **Restore snapshot**
4. Configure:
   - **DB cluster identifier:** `lab-cluster-restored`
   - **DB instance class:** `db.t3.medium`
   - **Number of instances:** 1 (para economizar)
   - **VPC:** Mesma VPC
   - **Subnet group:** `docdb-lab-subnet-group`
   - **Security groups:** `docdb-lab-sg`
5. Clique em **Restore DB cluster**
6. Aguarde ~15-20 minutos

### Via AWS CLI

```bash
# Restaurar snapshot
aws docdb restore-db-cluster-from-snapshot \
  --db-cluster-identifier lab-cluster-restored \
  --snapshot-identifier lab-snapshot-manual-001 \
  --engine docdb \
  --db-subnet-group-name docdb-lab-subnet-group \
  --vpc-security-group-ids sg-xxxxxxxx

# Criar instância no cluster restaurado
aws docdb create-db-instance \
  --db-instance-identifier lab-cluster-restored-1 \
  --db-instance-class db.t3.medium \
  --db-cluster-identifier lab-cluster-restored \
  --engine docdb

# Verificar restauração
aws docdb describe-db-clusters \
  --db-cluster-identifier lab-cluster-restored \
  --query 'DBClusters[0].Status'
```

### Via Script

```bash
cd scripts/
chmod +x restore-snapshot.sh
./restore-snapshot.sh lab-snapshot-manual-001 lab-cluster-restored
```

---

## ⏰ Parte 4: Point-in-Time Recovery (PITR)

### Conceito
Permite restaurar o cluster para qualquer ponto no tempo dentro do período de retenção.

### Via Console

1. Selecione o cluster original
2. **Actions** → **Restore to point in time**
3. Configure:
   - **Restore to:** Custom date and time
   - **Date and time:** Escolha um momento específico
   - **DB cluster identifier:** `lab-cluster-pitr`
   - Demais configurações similares
4. Clique em **Restore DB cluster**

### Via AWS CLI

```bash
# Obter janela de restauração disponível
aws docdb describe-db-clusters \
  --db-cluster-identifier lab-cluster-console \
  --query 'DBClusters[0].[EarliestRestorableTime, LatestRestorableTime]' \
  --output table

# Restaurar para ponto específico
aws docdb restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier lab-cluster-console \
  --db-cluster-identifier lab-cluster-pitr \
  --restore-to-time "2025-11-01T20:00:00Z" \
  --db-subnet-group-name docdb-lab-subnet-group \
  --vpc-security-group-ids sg-xxxxxxxx

# Adicionar instância
aws docdb create-db-instance \
  --db-instance-identifier lab-cluster-pitr-1 \
  --db-instance-class db.t3.medium \
  --db-cluster-identifier lab-cluster-pitr \
  --engine docdb
```

---

## 🔍 Parte 5: Gerenciar Snapshots

### Listar Snapshots

```bash
# Listar snapshots do cluster
aws docdb describe-db-cluster-snapshots \
  --db-cluster-identifier lab-cluster-console

# Listar todos os snapshots manuais
aws docdb describe-db-cluster-snapshots \
  --snapshot-type manual

# Listar snapshots automáticos
aws docdb describe-db-cluster-snapshots \
  --snapshot-type automated
```

### Copiar Snapshot para Outra Região

```bash
# Copiar snapshot
aws docdb copy-db-cluster-snapshot \
  --source-db-cluster-snapshot-identifier arn:aws:rds:us-east-1:123456789012:cluster-snapshot:lab-snapshot-manual-001 \
  --target-db-cluster-snapshot-identifier lab-snapshot-copy-us-west-2 \
  --region us-west-2
```

### Compartilhar Snapshot

```bash
# Tornar snapshot público (não recomendado)
aws docdb modify-db-cluster-snapshot-attribute \
  --db-cluster-snapshot-identifier lab-snapshot-manual-001 \
  --attribute-name restore \
  --values-to-add all

# Compartilhar com conta específica
aws docdb modify-db-cluster-snapshot-attribute \
  --db-cluster-snapshot-identifier lab-snapshot-manual-001 \
  --attribute-name restore \
  --values-to-add 987654321098
```

### Deletar Snapshot Manual

```bash
# Via CLI
aws docdb delete-db-cluster-snapshot \
  --db-cluster-snapshot-identifier lab-snapshot-manual-001

# Via Console
# 1. Vá para Snapshots
# 2. Selecione o snapshot
# 3. Actions > Delete snapshot
```

---

## 📊 Parte 6: Monitorar Backups

### Ver Tamanho dos Backups

```bash
# Tamanho total de backups
aws docdb describe-db-cluster-snapshots \
  --db-cluster-identifier lab-cluster-console \
  --query 'DBClusterSnapshots[*].[DBClusterSnapshotIdentifier, AllocatedStorage]' \
  --output table
```

### Verificar Último Backup

```bash
aws docdb describe-db-clusters \
  --db-cluster-identifier lab-cluster-console \
  --query 'DBClusters[0].[LatestRestorableTime, BackupRetentionPeriod]' \
  --output table
```

---

## ✅ Checklist de Conclusão

- [ ] Política de backup configurada (7 dias)
- [ ] Janela de backup definida
- [ ] Snapshot manual criado com sucesso
- [ ] Cluster restaurado a partir de snapshot
- [ ] PITR testado (opcional)
- [ ] Snapshots listados e verificados
- [ ] Entendeu diferença entre backups automáticos e manuais

---

## 🧹 Limpeza

```bash
# Deletar cluster restaurado
aws docdb delete-db-cluster \
  --db-cluster-identifier lab-cluster-restored \
  --skip-final-snapshot

# Deletar cluster PITR (se criado)
aws docdb delete-db-cluster \
  --db-cluster-identifier lab-cluster-pitr \
  --skip-final-snapshot

# Deletar snapshot manual
aws docdb delete-db-cluster-snapshot \
  --db-cluster-snapshot-identifier lab-snapshot-manual-001
```

---

## 📝 Exercícios Extras

1. **Automação:** Crie um Lambda para snapshots diários
2. **Disaster Recovery:** Simule recuperação de desastre
3. **Multi-região:** Configure replicação cross-region
4. **Monitoramento:** Configure alarme quando backup falha

---

## 💡 Best Practices

- ✅ Mantenha 7-14 dias de retenção para produção
- ✅ Crie snapshots antes de mudanças críticas
- ✅ Teste restaurações regularmente
- ✅ Use tags para organizar snapshots
- ✅ Configure janela de backup em horário de baixo tráfego
- ✅ Monitore falhas de backup
- ✅ Considere snapshots cross-region para DR

---

## 🆘 Troubleshooting

**Backup está demorando muito**
- Primeira backup é completo, subsequentes são incrementais
- Verifique tamanho do cluster

**Não consigo restaurar snapshot**
- Verifique subnet group e security groups
- Confirme que tem permissões IAM adequadas

**Snapshot não aparece**
- Snapshots manuais podem levar 5-10 min para ficarem disponíveis
- Verifique região correta

---

[⬅️ Exercício 1](../exercicio1-provisionamento/README.md) | [➡️ Exercício 3](../exercicio3-failover/README.md)
