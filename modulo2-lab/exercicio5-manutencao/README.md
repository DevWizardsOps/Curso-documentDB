# Exercício 5: Operações de Manutenção e Atualizações

## 🎯 Objetivos

- Realizar upgrades de versão do DocumentDB
- Modificar parâmetros de cluster e instâncias
- Escalar recursos (vertical e horizontal)
- Planejar e executar manutenções programadas

## ⏱️ Duração Estimada
60 minutos

> ⚠️ **Atenção:** Use seu número de aluno como prefixo em todos os recursos (ex: `aluno01`, `aluno02`). A variável `$ID` já está configurada no seu ambiente.

---

## 🔧 Parte 1: Configurar Janela de Manutenção

### Via AWS CLI

```bash
# Configurar janela de manutenção 
aws docdb modify-db-cluster \
--db-cluster-identifier $ID-lab-cluster-console \
--preferred-maintenance-window "sun:03:00-sun:03:30" \
--no-apply-immediately
```

---

## ⬆️ Parte 2: Upgrade de Versão

### Criar Backup Antes do Upgrade

```bash
# Criar snapshot manual 
aws docdb create-db-cluster-snapshot \
--db-cluster-snapshot-identifier $ID-pre-upgrade-snapshot-$(date +%Y%m%d) \
--db-cluster-identifier $ID-lab-cluster-console
```

### Executar Upgrade

```bash
# Upgrade de versão (substitua <seu-id> e a versão desejada)
aws docdb modify-db-cluster \
--db-cluster-identifier $ID-lab-cluster-console \
--engine-version 5.0.0 \
--allow-major-version-upgrade \
--apply-immediately
```

### Via Script Automatizado

```bash
cd scripts/
chmod +x upgrade-cluster.sh
./upgrade-cluster.sh $ID-lab-cluster-console 5.0.0
```

---

## 🔄 Parte 3: Modificar Instâncias

### Escalonamento Vertical (Resize)

```bash
# Modificar instance class 
aws docdb modify-db-instance \
--db-instance-identifier $ID-lab-cluster-console-1 \
--db-instance-class db.r5.large \
--apply-immediately
```

### Escalonamento Horizontal (Adicionar Réplica)

```bash
# Adicionar nova réplica 
aws docdb create-db-instance \
--db-instance-identifier $ID-lab-cluster-console-4 \
--db-instance-class db.t3.medium \
--db-cluster-identifier $ID-lab-cluster-console \
--engine docdb
```

---

## ⚙️ Parte 4: Modificar Parâmetros

### Criar e Aplicar Custom Parameter Group

```bash
# Criar parameter group customizado 
aws docdb create-db-cluster-parameter-group \
--db-cluster-parameter-group-name $ID-custom-docdb-params \
--db-parameter-group-family docdb5.0 \
--description "Custom parameters for <seu-id> cluster"

# Aplicar novo parameter group 
aws docdb modify-db-cluster \
--db-cluster-identifier $ID-lab-cluster-console \
--db-cluster-parameter-group-name $ID-custom-docdb-params \
--apply-immediately
```

---

## 🔄 Parte 5: Rollback

### Procedimento de Rollback (Downgrade)

```bash
# Restaurar snapshot pré-upgrade (substitua <seu-id> e o nome do snapshot)
aws docdb restore-db-cluster-from-snapshot \
--db-cluster-identifier $ID-lab-cluster-rollback \
--snapshot-identifier $ID-pre-upgrade-snapshot-YYYYMMDD \
--engine docdb
```

**IMPORTANTE:** Downgrade direto não é suportado. Sempre use snapshots!

---

## ✅ Checklist de Conclusão

```bash
# Executa o grade para avaliar atividades
/home/$ID/Curso-documentDB/modulo2-lab/exercicio5-manutencao/grade_exercicio5.sh
```

---

## 🧹 Limpeza

Lembre-se de usar seu prefixo `<seu-id>` para deletar todos os recursos.

```bash
# Deletar snapshots de teste
aws docdb delete-db-cluster-snapshot \
--db-cluster-snapshot-identifier $ID-pre-upgrade-snapshot-YYYYMMDD

# Deletar parameter group customizado
aws docdb delete-db-cluster-parameter-group \
--db-cluster-parameter-group-name $ID-custom-docdb-params
```

---

[⬅️ Exercício 4](../exercicio4-monitoramento/README.md) | [🏠 Voltar ao Início](../README.md)
