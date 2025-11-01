# Instruções Detalhadas: Provisionamento via Console AWS

## 📝 Checklist Pré-Provisionamento

- [ ] Conta AWS ativa
- [ ] Acesso ao console AWS
- [ ] VPC com pelo menos 2 subnets em AZs diferentes
- [ ] Permissões IAM adequadas

---

## 1️⃣ Criar Subnet Group

### Passo a Passo:

1. Acesse: https://console.aws.amazon.com/docdb/
2. No menu lateral, clique em **Subnet groups**
3. Clique no botão **Create**
4. Preencha:
   - **Name:** `docdb-lab-subnet-group`
   - **Description:** `Subnet group for DocumentDB lab`
   - **VPC:** Selecione a VPC padrão ou sua VPC preferida
5. Em **Add subnets:**
   - **Availability Zones:** Selecione ao menos 2 AZs (ex: us-east-1a, us-east-1b)
   - **Subnets:** Marque as subnets correspondentes às AZs selecionadas
6. Clique em **Create**

**Resultado esperado:** Subnet group criado com status "Complete"

---

## 2️⃣ Criar Security Group

### Passo a Passo:

1. Acesse: https://console.aws.amazon.com/ec2/
2. No menu lateral, clique em **Security Groups** (sob "Network & Security")
3. Clique em **Create security group**
4. Preencha:
   - **Security group name:** `docdb-lab-sg`
   - **Description:** `Security group for DocumentDB lab cluster`
   - **VPC:** Mesma VPC usada no subnet group
5. Em **Inbound rules:**
   - Clique em **Add rule**
   - **Type:** Custom TCP
   - **Port range:** 27017
   - **Source:** 
     - Para teste: `My IP` ou `0.0.0.0/0` (não recomendado para produção)
     - Para produção: Security group específico ou CIDR da sua aplicação
   - **Description:** `MongoDB protocol access`
6. Em **Outbound rules:**
   - Mantenha a regra padrão (All traffic para 0.0.0.0/0)
7. Clique em **Create security group**

**Resultado esperado:** Security group criado com ID no formato `sg-xxxxxxxxx`

---

## 3️⃣ Criar Cluster DocumentDB

### Passo a Passo:

1. Volte para: https://console.aws.amazon.com/docdb/
2. Clique em **Create**

### Seção: Configuration

- **Engine version:** 5.0.0 (ou versão mais recente disponível)

### Seção: DB cluster identifier

- **DB cluster identifier:** `lab-cluster-console`

### Seção: Credentials

- **Master username:** `docdbadmin`
- **Master password:** `Lab12345!` (mínimo 8 caracteres)
- **Confirm password:** `Lab12345!`

### Seção: DB instance class

- **Instance class:** `db.t3.medium`
  - Para ambientes de teste: `db.t3.medium` é adequado
  - Para produção: considere `db.r5.large` ou superior

### Seção: Number of instances

- **Number of instances:** 3
  - 1 instância primária (writer)
  - 2 réplicas (readers)

### Seção: Authentication

- **Username and password:** (já preenchido acima)

### Seção: Network settings

- **Virtual Private Cloud (VPC):** Selecione a mesma VPC
- **DB subnet group:** `docdb-lab-subnet-group`
- **VPC security groups:** Remova o padrão e selecione `docdb-lab-sg`
- **Show additional connectivity configuration:**
  - **Publicly accessible:** No (recomendado)
  - **Port:** 27017 (padrão)

### Seção: Cluster options

- **Cluster parameter group:** default.docdb5.0 (ou crie customizado)
- **Enable CloudWatch logs exports:** 
  - [ ] Audit logs (opcional)
  - [ ] Profiler logs (opcional)

### Seção: Backup

- **Backup retention period:** 7 days
- **Preferred backup window:** 03:00-04:00 UTC
  - Escolha um horário de baixo tráfego

### Seção: Encryption-at-rest

- **Enable encryption:** Yes (marcado por padrão)
- **Master key:** `(Default) aws/rds`
  - Em produção, considere usar uma CMK customizada

### Seção: Log exports

- **Audit logs:** Disabled (ative se necessário auditoria)
- **Profiler logs:** Disabled (ative para análise de performance)

### Seção: Maintenance

- **Enable auto minor version upgrade:** Yes
- **Maintenance window:** 
  - **Select window:** `Sunday 04:00-05:00 UTC`
  - Escolha um horário de baixo tráfego

### Seção: Deletion protection

- **Enable deletion protection:** No (desabilitado para facilitar limpeza do lab)
  - Em produção, marque "Yes"

3. Clique em **Create cluster**

**Tempo de provisionamento:** ~15-20 minutos

---

## 4️⃣ Monitorar o Provisionamento

### Via Console:

1. Na lista de clusters, observe o status de `lab-cluster-console`
2. Status progression:
   - **Creating** → **Available**
3. Clique no cluster para ver detalhes
4. Verifique que todas as 3 instâncias estão **Available**

### Via AWS CLI:

```bash
# Verificar status do cluster
aws docdb describe-db-clusters \
  --db-cluster-identifier lab-cluster-console \
  --query 'DBClusters[0].[Status, Endpoint]' \
  --output table

# Listar instâncias
aws docdb describe-db-cluster-members \
  --db-cluster-identifier lab-cluster-console
```

---

## 5️⃣ Obter Informações de Conexão

### Endpoint do Cluster:

1. No console, clique no cluster `lab-cluster-console`
2. Na aba **Connectivity & security:**
   - **Endpoint:** `lab-cluster-console.cluster-xxxxx.us-east-1.docdb.amazonaws.com`
   - **Reader endpoint:** `lab-cluster-console.cluster-ro-xxxxx.us-east-1.docdb.amazonaws.com`
   - **Port:** 27017

### Via CLI:

```bash
# Obter endpoint
aws docdb describe-db-clusters \
  --db-cluster-identifier lab-cluster-console \
  --query 'DBClusters[0].Endpoint' \
  --output text
```

---

## 6️⃣ Configurar Certificado SSL

```bash
# Baixar certificado SSL da AWS
wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

# Verificar download
ls -lh global-bundle.pem
```

---

## 7️⃣ Testar Conexão

### Instalar MongoDB Shell (mongosh):

```bash
# macOS
brew install mongosh

# Linux (Ubuntu/Debian)
wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list
sudo apt update
sudo apt install -y mongodb-mongosh
```

### Conectar ao Cluster:

```bash
# Substituir o endpoint pelo seu
mongosh --host lab-cluster-console.cluster-xxxxx.us-east-1.docdb.amazonaws.com:27017 \
  --username docdbadmin \
  --password Lab12345! \
  --tls \
  --tlsCAFile global-bundle.pem
```

### Comandos de Teste:

```javascript
// Ver databases
show dbs

// Criar database de teste
use labdb

// Inserir documento
db.test.insertOne({ message: "Hello DocumentDB!", timestamp: new Date() })

// Consultar documentos
db.test.find()

// Ver status do replica set
rs.status()

// Sair
exit
```

---

## ✅ Verificação Final

- [ ] Cluster com status "Available"
- [ ] 3 instâncias ativas (1 primária + 2 réplicas)
- [ ] Endpoint do cluster obtido
- [ ] Certificado SSL baixado
- [ ] Conexão bem-sucedida via mongosh
- [ ] Comandos de teste executados com sucesso

---

## 📊 Informações do Cluster Provisionado

| Componente | Detalhes |
|------------|----------|
| **Cluster ID** | lab-cluster-console |
| **Engine** | DocumentDB 5.0.0 |
| **Instâncias** | 3 x db.t3.medium |
| **Storage** | Encrypted (storage dinâmico) |
| **Backup** | 7 dias de retenção |
| **Port** | 27017 |
| **TLS** | Obrigatório |

---

## 🔄 Próximos Passos

Agora que o cluster foi provisionado com sucesso:

1. Teste diferentes operações CRUD
2. Monitore métricas no CloudWatch
3. Teste failover manual (Exercício 3)
4. Configure alarmes (Exercício 4)

---

## 💡 Dicas

- **Performance:** O db.t3.medium tem burst credits. Para workloads constantes, use r5/r6g
- **Custo:** Lembre-se de deletar recursos após o lab para evitar cobranças
- **Monitoramento:** Habilite CloudWatch logs para troubleshooting
- **Segurança:** Em produção, NUNCA use 0.0.0.0/0 no security group

---

[⬅️ Voltar ao Exercício 1](../README.md)
