# Exercício 2: Backup e Snapshots Automáticos

## 🎯 Objetivos

- Entender políticas de backup automático do DocumentDB
- Criar snapshots manuais
- Restaurar clusters a partir de snapshots
- Configurar janelas de backup
- Gerenciar retenção de backups

## ⏱️ Duração Estimada
45 minutos

> ⚠️ **Atenção:** Lembre-se de usar seu prefixo de aluno (`<seu-id>`) em todos os nomes de recursos e comandos, conforme definido no Exercício 1.

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
2. Selecione seu cluster (`<seu-id>-lab-cluster-console`)
3. Clique em **Modify**
4. Em **Backup:**
   - **Backup retention period:** 7 dias
   - **Backup window:** 02:00-04:00 UTC
5. Clique em **Continue**
6. **Apply immediately:** Yes
7. Clique em **Modify cluster**

### Via AWS CLI

```bash
# Definir ID
ID="seu-id"

# Modificar política de backup (substitua <seu-id>)
aws docdb modify-db-cluster \
--db-cluster-identifier $ID-lab-cluster-console \
--backup-retention-period 7 \
--preferred-backup-window "02:00-04:00" \
--apply-immediately

# Verificar configuração (substitua <seu-id>)
aws docdb describe-db-clusters \
--db-cluster-identifier $ID-lab-cluster-console \
--query 'DBClusters[0].[BackupRetentionPeriod, PreferredBackupWindow]' \
--output table
```

---

## 📸 Parte 2: Criar Snapshot Manual

### Via Console

1. No console DocumentDB, selecione o cluster `<seu-id>-lab-cluster-console`
2. Clique em **Actions** → **Take snapshot**
3. Configure:
   - **Snapshot identifier:** `<seu-id>-lab-snapshot-manual-console-001`
   - **Tags:** (opcional)
     - Key: `Purpose`, Value: `LabExercise`
     - Key: `Student`, Value: `<seu-id>`
4. Clique em **Take snapshot**
5. Aguarde até status = **Available** (~5-10 minutos)

### Via AWS CLI

```bash
ID="seu-id"

# Criar snapshot (substitua <seu-id>)
aws docdb create-db-cluster-snapshot \
--db-cluster-snapshot-identifier $ID-lab-snapshot-manual-001 \
--db-cluster-identifier $ID-lab-cluster-console \
--tags Key=Purpose,Value=LabExercise Key=Student,Value=$ID

# Verificar progresso (substitua <seu-id>)
aws docdb describe-db-cluster-snapshots \
--db-cluster-snapshot-identifier $ID-lab-snapshot-manual-001 \
--query 'DBClusterSnapshots[0].[Status, PercentProgress]' \
--output table

# Listar todos os seus snapshots manuais (substitua <seu-id>)
aws docdb describe-db-cluster-snapshots \
--snapshot-type manual \
--query "DBClusterSnapshots[?starts_with(DBClusterSnapshotIdentifier, '$ID')].[DBClusterSnapshotIdentifier, Status, SnapshotCreateTime]" \
--output table
```

### Via Script

Use o script fornecido, passando o nome do seu cluster:

```bash
cd scripts/
chmod +x backup-manual.sh
./backup-manual.sh $ID-lab-cluster-console
```

---

## 🔄 Parte 3: Restaurar a partir de Snapshot

### Cenário
Você precisa criar um cluster de desenvolvimento a partir do snapshot de produção.

### Via Console

1. No console DocumentDB, vá para **Snapshots**
2. Selecione `<seu-id>-lab-snapshot-manual-001`
3. Clique em **Actions** → **Restore snapshot**
4. Configure:
   - **DB cluster identifier:** `<seu-id>-lab-cluster-restored`
   - **DB instance class:** `db.t3.medium`
   - **Number of instances:** 1 (para economizar)
   - **VPC:** Mesma VPC
   - **Subnet group:** `<seu-id>-docdb-lab-subnet-group`
   - **Security groups:** `<seu-id>-docdb-lab-sg`
5. Clique em **Restore DB cluster**
6. Aguarde ~15-20 minutos

### Via AWS CLI

```bash
ID="seu-id"

# Obter o security group ID pelo nome
SG_ID=$(aws ec2 describe-security-groups \
--filters "Name=group-name,Values=$ID-docdb-lab-sg" \
--query 'SecurityGroups[0].GroupId' \
--output text)

echo "Security Group ID: $SG_ID"

# Restaurar snapshot (substitua <seu-id> e o ID do seu security group)
aws docdb restore-db-cluster-from-snapshot \
--db-cluster-identifier $ID-lab-cluster-restored \
--snapshot-identifier $ID-lab-snapshot-manual-001 \
--engine docdb \
--db-subnet-group-name $ID-docdb-lab-subnet-group \
--vpc-security-group-ids $SG_ID

# Criar instância no cluster restaurado (substitua <seu-id>)
aws docdb create-db-instance \
--db-instance-identifier $ID-lab-cluster-restored-1 \
--db-instance-class db.t3.medium \
--db-cluster-identifier $ID-lab-cluster-restored \
--engine docdb

# Verificar restauração (substitua <seu-id>)
aws docdb describe-db-clusters \
--db-cluster-identifier $ID-lab-cluster-restored \
--query 'DBClusters[0].Status'
```

### Via Script

```bash
cd scripts/
chmod +x restore-snapshot.sh
./restore-snapshot.sh $ID-lab-snapshot-manual-001 $ID-lab-cluster-restored
```

---

## ⏰ Parte 4: Point-in-Time Recovery (PITR)

### Conceito
Permite restaurar o cluster para qualquer ponto no tempo dentro do período de retenção.

### Via Console

1. Selecione o cluster original (`<seu-id>-lab-cluster-console`)
2. **Actions** → **Restore to point in time**
3. Configure:
   - **Restore to:** Custom date and time
   - **Date and time:** Escolha um momento específico
   - **DB cluster identifier:** `<seu-id>-lab-cluster-pitr`
   - Demais configurações similares
4. Clique em **Restore DB cluster**

### Via AWS CLI

```bash
# Obter janela de restauração disponível (substitua <seu-id>)
aws docdb describe-db-clusters \
--db-cluster-identifier $ID-lab-cluster-console \
--query 'DBClusters[0].[EarliestRestorableTime, LatestRestorableTime]' \
--output table

# Restaurar para ponto específico (substitua <seu-id> e o ID do seu security group)
aws docdb restore-db-cluster-to-point-in-time \
--source-db-cluster-identifier $ID-lab-cluster-console \
--db-cluster-identifier $ID-lab-cluster-pitr \
--restore-to-time "2025-11-02T17:30:00Z" \
--db-subnet-group-name $ID-docdb-lab-subnet-group \
--vpc-security-group-ids $SG_ID

# Adicionar instância (substitua <seu-id>)
aws docdb create-db-instance \
--db-instance-identifier $ID-lab-cluster-pitr-1 \
--db-instance-class db.t3.medium \
--db-cluster-identifier $ID-lab-cluster-pitr \
--engine docdb

# Adicionar segunda instância (substitua <seu-id>)
aws docdb create-db-instance \
--db-instance-identifier $ID-lab-cluster-pitr-2 \
--db-instance-class db.t3.medium \
--db-cluster-identifier $ID-lab-cluster-pitr \
--engine docdb
```

---

## 🔍 Parte 5: Gerenciar Snapshots

### Listar Snapshots

```bash
# Listar snapshots do seu cluster (substitua <seu-id>)
aws docdb describe-db-cluster-snapshots \
--db-cluster-identifier $ID-lab-cluster-console

# Listar todos os seus snapshots manuais (substitua <seu-id>)
aws docdb describe-db-cluster-snapshots \
--snapshot-type manual \
--query "DBClusterSnapshots[?starts_with(DBClusterSnapshotIdentifier, '$ID')].DBClusterSnapshotIdentifier"
```

---

## ✅ Checklist de Conclusão

Execute o script de validação a partir do diretório home do usuário.

```bash
# Obter endpoint do Terraform
./grade_exercicio2.sh
```

---

## 🧹 Limpeza

```bash
# Detelar todas as instancias do cluster restaurado
aws docdb delete-db-instance --db-instance-identifier $ID-lab-cluster-restored-1

# Detelar todas cluster restaurado
aws docdb delete-db-cluster --db-cluster-identifier $ID-lab-cluster-restored --skip-final-snapshot

# Detelar todas as instancias do cluster restaurado PITR
aws docdb delete-db-instance --db-instance-identifier $ID-lab-cluster-pitr-1
aws docdb delete-db-instance --db-instance-identifier $ID-lab-cluster-pitr-2

# Detelar todas cluster restaurado PITR
aws docdb delete-db-cluster --db-cluster-identifier $ID-lab-cluster-pitr --skip-final-snapshot

# Deletar snapshot manual (substitua <seu-id>)
aws docdb delete-db-cluster-snapshot --db-cluster-snapshot-identifier $ID-lab-snapshot-manual-001

# Deletar snapshot manual da console (substitua <seu-id>)
aws docdb delete-db-cluster-snapshot --db-cluster-snapshot-identifier $ID-lab-snapshot-manual-console-001

# Deletar SubnetGroup
aws docdb delete-db-subnet-group --db-subnet-group-name $ID-docdb-lab-subnet-group
```

---

[⬅️ Exercício 1](../exercicio1-provisionamento/README.md) | [➡️ Exercício 3](../exercicio3-failover/README.md)
