# Exercício 1: Provisionamento de Clusters DocumentDB

## 🎯 Objetivos

- Provisionar um cluster DocumentDB via AWS Console
- Provisionar um cluster DocumentDB via Terraform
- Entender as configurações principais de um cluster
- Comparar as duas abordagens

## ⏱️ Duração Estimada
60 minutos

## 📚 Parte 1: Provisionamento via AWS Console

### Passo 1: Criar Subnet Group

1. Acesse o console AWS DocumentDB
2. Navegue até **Subnet groups**
3. Clique em **Create**
4. Configure:
   - **Name:** `docdb-lab-subnet-group`
   - **Description:** `Subnet group para laboratório`
   - **VPC:** Selecione a VPC padrão
   - **Availability Zones:** Selecione 2 ou mais AZs
   - **Subnets:** Selecione subnets correspondentes

### Passo 2: Criar Security Group

1. Acesse **EC2 > Security Groups**
2. Clique em **Create security group**
3. Configure:
   - **Name:** `docdb-lab-sg`
   - **Description:** `Security group para DocumentDB`
   - **VPC:** Mesma VPC do subnet group
4. Adicione regra de entrada:
   - **Type:** Custom TCP
   - **Port:** 27017
   - **Source:** IP da sua instância EC2 (DocumentDB não expõe IP Público) ou security group da aplicação

### Passo 3: Criar o Cluster

1. No console DocumentDB, clique em **Create**
2. Configure:

**Configurações do Cluster:**
- **Cluster identifier:** `lab-cluster-console`
- **Engine version:** 5.0.0 (ou mais recente)
- **Instance class:** `db.t3.medium`
- **Number of instances:** 3 (1 primária + 2 réplicas)

**Autenticação:**
- **Master username:** `docdbadmin`
- **Master password:** `Lab12345!` (ou uma senha forte)

**Configurações de Rede:**
- **Subnet group:** `docdb-lab-subnet-group`
- **Security group:** `docdb-lab-sg`

**Backup:**
- **Backup retention period:** 7 dias
- **Preferred backup window:** 03:00-04:00 UTC

**Manutenção:**
- **Auto minor version upgrade:** Enabled
- **Maintenance window:** dom:04:00-dom:05:00 UTC

3. Clique em **Create cluster**
4. Aguarde ~15-20 minutos para provisionamento

### Passo 4: Verificar o Cluster

```bash
# Listar clusters
aws docdb describe-db-clusters \
  --query 'DBClusters[?DBClusterIdentifier==`lab-cluster-console`]'

# Obter endpoint de conexão
aws docdb describe-db-clusters \
  --db-cluster-identifier lab-cluster-console \
  --query 'DBClusters[0].Endpoint' \
  --output text
```

### Passo 5: Testar Conexão

```bash
# Baixar certificado SSL
wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

# Conectar ao cluster (substitua o endpoint)
mongosh --host lab-cluster-console.cluster-xxxxx.us-east-1.docdb.amazonaws.com:27017 \
  --username docdbadmin \
  --password Lab12345! \
  --tls \
  --tlsCAFile global-bundle.pem
```

---

## 📚 Parte 2: Provisionamento via Terraform

### Passo 1: Instalar

Siga processo de instalação do terraform conforme documentação oficial: https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

### Passo 2: Revisar Configuração

Abra e revise os arquivos:
- `main.tf` - Recursos principais
- `variables.tf` - Variáveis configuráveis
- `outputs.tf` - Outputs do cluster

### Passo 3: Configurar Variáveis

Crie um arquivo `terraform.tfvars`:

```hcl
cluster_identifier = "lab-cluster-terraform"
master_username    = "docdbadmin"
master_password    = "Lab12345!"
instance_count     = 3
instance_class     = "db.t3.medium"
```

### Passo 4: Inicializar Planejar e Aplicar

Após instalado e arquivos configurados, inicialize o Terraform visualize o plano e aplique as mudanças.

```bash
cd terraform/

# Inicializar o Terraform
terraform init

# Visualizar o plano
terraform plan

# Aplicar as mudanças
terraform apply -auto-approve
```

### Passo 5: Verificar Outputs

```bash
# Ver todos os outputs
terraform output

# Ver endpoint específico
terraform output cluster_endpoint
```

### Passo 6: Testar Conexão

```bash
# Obter endpoint do Terraform
ENDPOINT=$(terraform output -raw cluster_endpoint)

# Conectar
mongosh --host $ENDPOINT:27017 \
  --username docdbadmin \
  --password Lab12345! \
  --tls \
  --tlsCAFile ../global-bundle.pem
```

---

## 🔍 Comparação: Console vs Terraform

| Aspecto | Console | Terraform |
|---------|---------|-----------|
| **Velocidade inicial** | Mais rápido para começar | Requer setup inicial |
| **Reprodutibilidade** | Manual, sujeito a erros | Automatizado, consistente |
| **Versionamento** | Não versionável | Git-friendly |
| **Gestão de múltiplos ambientes** | Trabalhoso | Fácil com workspaces |
| **Documentação** | Separada | Código é a documentação |
| **Curva de aprendizado** | Baixa | Média |
| **Ideal para** | Protótipos, testes rápidos | Produção, IaC |

---

## ✅ Checklist de Conclusão

- [ ] Cluster via Console provisionado
- [ ] Conexão testada via Console
- [ ] Terraform inicializado
- [ ] Cluster via Terraform provisionado
- [ ] Conexão testada via Terraform
- [ ] Outputs do Terraform verificados
- [ ] Compreendeu diferenças entre abordagens

---

## 🧹 Limpeza

### Console:
1. Vá para AWS DocumentDB Console
2. Selecione o cluster `lab-cluster-console`
3. Actions > Delete
4. Desmarque "Create final snapshot"
5. Digite "delete me" e confirme

### Terraform:
```bash
cd terraform/
terraform destroy -auto-approve
```

---

## 📝 Exercícios Extras

1. **Modificar instâncias:** Altere o instance_class para `db.r5.large`
2. **Adicionar tags:** Adicione tags customizadas ao cluster
3. **Multi-região:** Crie um cluster em outra região
4. **Parameter group:** Crie um parameter group customizado

---

## 🆘 Troubleshooting

**Erro: Subnet group não tem subnets suficientes**
- Certifique-se de selecionar pelo menos 2 AZs diferentes

**Erro: Conexão recusada**
- Verifique as regras do security group
- Confirme que está conectando da origem permitida

**Terraform: Error creating cluster**
- Verifique se já existe um cluster com o mesmo nome
- Confirme que tem permissões IAM adequadas

---

[⬅️ Voltar ao README principal](../README.md) | [➡️ Próximo: Exercício 2](../exercicio2-backup-snapshots/README.md)
