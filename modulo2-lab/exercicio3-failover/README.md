# Exercício 3: Gerenciamento de Failover

## 🎯 Objetivos

- Entender como funciona o failover no DocumentDB
- Testar failover automático e manual
- Configurar aplicações para lidar com failover
- Monitorar o processo de failover
- Medir tempo de recuperação (RTO)

## ⏱️ Duração Estimada
60 minutos

> ⚠️ **Atenção:** Lembre-se de usar seu prefixo de aluno (`<seu-id>`) em todos os nomes de recursos e comandos, conforme definido no Exercício 1.

---

## 📚 Conceitos

### O que é Failover?

Failover é o processo de promover uma réplica a primária quando a instância primária atual falha ou fica indisponível.

---

## 🔧 Parte 1: Configurar Ambiente de Teste

### Passo 1: Verificar Cluster

```bash
# Definir ID
ID="seu-id"

# Listar instâncias do seu cluster (substitua <seu-id>)
aws docdb describe-db-clusters \
--db-cluster-identifier $ID-lab-cluster-console \
--query 'DBClusters[0].DBClusterMembers[*].[DBInstanceIdentifier, IsClusterWriter, PromotionTier]' \
--output table
```

### Passo 2: Identificar a Primária Atual

```bash
# Obter a instância primária (substitua <seu-id>)
PRIMARY=$(aws docdb describe-db-clusters \
--db-cluster-identifier $ID-lab-cluster-console \
--query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' \
--output text)

echo "Instância Primária Atual: $PRIMARY"
```

---

## 🔄 Parte 2: Failover Manual

### Via Console AWS

1. Acesse o console DocumentDB
2. Selecione o seu cluster `<seu-id>-lab-cluster-console`
3. Clique em **Actions** → **Failover**
4. Confirme a ação
5. Observe o processo (leva ~60-90 segundos)

### Via AWS CLI

```bash
# Definir ID
ID="seu-id"

# Executar failover manual (substitua <seu-id>)
aws docdb failover-db-cluster \
--db-cluster-identifier $ID-lab-cluster-console

echo "Failover iniciado! Monitorando..."

# Monitorar até completar (substitua <seu-id>)
aws rds wait db-cluster-available --db-cluster-identifier $ID-lab-cluster-console

echo "Failover concluído!"

# Verificar nova primária (substitua <seu-id>)
NEW_PRIMARY=$(aws docdb describe-db-clusters \
--db-cluster-identifier $ID-lab-cluster-console \
--query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' \
--output text)

echo "Nova Instância Primária: $NEW_PRIMARY"
```

### Via Script Automatizado

```bash
cd scripts/
chmod +x test-failover.sh
./test-failover.sh $ID-lab-cluster-console
```

---

## ⚡ Parte 3: Simular Falha de Instância

### Reboot com Failover

```bash
# Reiniciar a instância primária (força failover)
# A variável $PRIMARY foi definida na Parte 1
aws docdb reboot-db-instance \
--db-instance-identifier $PRIMARY \
--force-failover

echo "Reboot com failover iniciado..."

# Monitorar o processo (substitua <seu-id>)
watch -n 2 "aws docdb describe-db-clusters \
--db-cluster-identifier $ID-lab-cluster-console \
--query 'DBClusters[0].DBClusterMembers[*].[DBInstanceIdentifier, IsClusterWriter]' \
--output table"
```

---

## 📊 Parte 4: Medir Tempo de Recuperação (RTO)

### Script para Medir RTO

```bash
cd scripts/
chmod +x monitor-endpoints.sh

# Em um terminal, inicie o monitoramento (substitua <seu-id>)
./monitor-endpoints.sh $ID-lab-cluster-console

# Em outro terminal, execute o failover (substitua <seu-id>)
aws docdb failover-db-cluster \
--db-cluster-identifier $ID-lab-cluster-console
```

---

## 🔌 Parte 5: Aplicação Resiliente a Failover

### Exemplo Node.js com Retry Logic

Veja o arquivo `exemplos/connection-failover.js`.

**Antes de executar, edite o arquivo `connection-failover.js` e atualize a variável `host` com o endpoint do seu cluster.**

```javascript
// exemplos/connection-failover.js
const CONFIG = {
    host: '<seu-id>-lab-cluster-console.cluster-xxxxx.us-east-1.docdb.amazonaws.com',
    // ...
};
```

Depois de editar, execute os comandos:

```bash
ID=<seu-id>

cd exemplos/
sudo dnf install npm wget -y
npm install mongodb
wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

# Executar aplicação de teste
node connection-failover.js

# Em outro terminal, force um failover (substitua <seu-id>)
aws docdb failover-db-cluster \
--db-cluster-identifier $ID-lab-cluster-console
```

---

## ✅ Checklist de Conclusão

Execute o script de validação a partir do diretório home do usuário, no diretório do exercício 3 do módulo 2.

```bash
# Executa o grade para avaliar atividades
./grade_exercicio3.sh
```

---

[⬅️ Exercício 2](../exercicio2-backup-snapshots/README.md) | [➡️ Exercício 4](../exercicio4-monitoramento/README.md)
