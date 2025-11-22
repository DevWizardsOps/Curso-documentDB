# Exercício: Backup de Dados para S3

## 🎯 Objetivos

- Implementar estratégias de backup do DocumentDB para S3
- Configurar backup incremental e completo
- Estabelecer políticas de retenção e compliance
- Testar procedimentos de restore e validação de integridade

## ⏱️ Duração Estimada
75 minutos

> ⚠️ **Atenção:** Use seu número de aluno como prefixo em todos os recursos (ex: `aluno01`, `aluno02`). A variável `$ID` já está configurada no seu ambiente.

---

## 🗄️ Parte 1: Configuração do Ambiente de Backup

### Passo 1: Preparar Ambiente

```bash
# A variável $ID já está configurada automaticamente
# Verifique com: echo $ID
# Resultado esperado: aluno01, aluno02, etc.
export CLUSTER_ID="$ID-lab-cluster-console"
export BACKUP_BUCKET="$ID-docdb-backups-$(date +%Y%m%d)"
export REGION="us-east-2"

# Obter endpoint do cluster
export CLUSTER_ENDPOINT=$(aws docdb describe-db-clusters \
--db-cluster-identifier $CLUSTER_ID \
--query 'DBClusters[0].Endpoint' \
--output text)

export DB_USERNAME="docdbadmin"
export DB_PASSWORD="Lab12345!"

echo "Cluster endpoint: $CLUSTER_ENDPOINT"
```

### Passo 2: Criar Bucket S3 para Backups

```bash
# Criar bucket S3 para backups
aws s3 mb s3://$BACKUP_BUCKET --region $REGION

# Configurar versionamento para proteção adicional
aws s3api put-bucket-versioning \
--bucket $BACKUP_BUCKET \
--versioning-configuration Status=Enabled

# Configurar políticas de retenção para compliance
aws s3api put-bucket-lifecycle-configuration \
--bucket $BACKUP_BUCKET \
--lifecycle-configuration '{
  "Rules": [
    {
      "ID": "BackupRetentionPolicy",
      "Status": "Enabled",
      "Filter": {"Prefix": "backups/"},
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        },
        {
          "Days": 2555,
          "StorageClass": "DEEP_ARCHIVE"
        }
      ],
      "Expiration": {
        "Days": 2920
      }
    }
  ]
}'

echo "Bucket de backup criado: $BACKUP_BUCKET"
```

### Passo 3: Baixar Certificado SSL e Verificar Ferramentas

```bash
# Baixar certificado SSL do DocumentDB (se não existir)
if [ ! -f "global-bundle.pem" ]; then
  wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
fi

# Verificar se mongoexport está disponível
mongoexport --version

# Se não estiver instalado, instalar MongoDB tools
if ! command -v mongoexport &> /dev/null; then
    echo "Instalando MongoDB Database Tools..."
    # Para Amazon Linux 2
    sudo yum install -y mongodb-database-tools
    # Ou baixar diretamente
    # wget https://fastdl.mongodb.org/tools/db/mongodb-database-tools-amazon2-x86_64-100.9.4.tgz
fi
```

---

## 💾 Parte 2: Backup Completo (Full Backup)

### Passo 1: Criar Dados de Teste

**1.1. Conectar ao DocumentDB**

```bash
mongosh --host $CLUSTER_ENDPOINT:27017 \
--username $DB_USERNAME \
--password $DB_PASSWORD \
--tls \
--tlsCAFile ~/global-bundle.pem
```

**1.2. Executar comandos no mongosh**

Após conectar, execute os seguintes comandos no terminal do mongosh:

```javascript
// Usar o database de teste
use backupTestDB
```

```javascript
// Limpar dados existentes (se houver)
db.products.drop()
db.orders.drop()
```

```javascript
// Criar dados de produtos
db.products.insertMany([
  {_id: 1, name: 'Laptop', category: 'electronics', price: 999.99, createdAt: new Date()},
  {_id: 2, name: 'Mouse', category: 'electronics', price: 29.99, createdAt: new Date()},
  {_id: 3, name: 'Book', category: 'books', price: 19.99, createdAt: new Date()}
])
```

```javascript
// Criar dados de pedidos
db.orders.insertMany([
  {_id: 1, customerId: 101, productId: 1, quantity: 1, total: 999.99, orderDate: new Date()},
  {_id: 2, customerId: 102, productId: 2, quantity: 2, total: 59.98, orderDate: new Date()}
])
```

**1.3. Verificar se os dados foram criados**

```javascript
// Verificar collections criadas
db.getCollectionNames()

// Contar documentos
db.products.countDocuments()
db.orders.countDocuments()

// Ver exemplos dos dados
db.products.findOne()
db.orders.findOne()
```

**Resultado esperado:**
- Collections: `['products', 'orders']`
- Produtos: `3`
- Pedidos: `2`

**1.4. Sair do mongosh**

```javascript
exit
```

### Passo 2: Executar Backup Completo

**2.1. Preparar diretório de backup**

```bash
# Criar diretório local para backup temporário
mkdir -p $HOME/docdb-backup

# Criar diretório específico para este backup
BACKUP_DIR="$HOME$HOME/docdb-backup/full-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR

echo "Criando backup em: $BACKUP_DIR"
```

**2.2. Fazer backup da collection products**

```bash
echo "Fazendo backup da collection 'products'..."

mongoexport \
--host $CLUSTER_ENDPOINT:27017 \
--username $DB_USERNAME \
--password $DB_PASSWORD \
--ssl \
--sslCAFile ~/global-bundle.pem \
--db backupTestDB \
--collection products \
--out $BACKUP_DIR/products.json \
--jsonArray \
--pretty
```

**Verificar resultado:**

```bash
# Verificar se o arquivo foi criado
ls -la $BACKUP_DIR/products.json

# Contar documentos no backup
grep -c "_id" $BACKUP_DIR/products.json

# Ver primeiras linhas do backup
head -10 $BACKUP_DIR/products.json
```

**Resultado esperado:** Arquivo JSON com 3 produtos

**2.3. Fazer backup da collection orders**

```bash
echo "Fazendo backup da collection 'orders'..."

mongoexport \
--host $CLUSTER_ENDPOINT:27017 \
--username $DB_USERNAME \
--password $DB_PASSWORD \
--ssl \
--sslCAFile ~/global-bundle.pem \
--db backupTestDB \
--collection orders \
--out $BACKUP_DIR/orders.json \
--jsonArray \
--pretty
```

**Verificar resultado:**

```bash
# Verificar se o arquivo foi criado
ls -la $BACKUP_DIR/orders.json

# Contar documentos no backup
grep -c "_id" $BACKUP_DIR/orders.json

# Ver primeiras linhas do backup
head -10 $BACKUP_DIR/orders.json
```

**Resultado esperado:** Arquivo JSON com 2 pedidos

**2.4. Criar manifesto do backup**

```bash
# Criar arquivo de manifesto com informações do backup
cat > $BACKUP_DIR/manifest.json << EOF
{
  "backup_type": "full",
  "database": "backupTestDB",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "collections": ["products", "orders"],
  "backup_directory": "$BACKUP_DIR"
}
EOF
```

**2.5. Verificar backup completo**

```bash
echo "✅ Backup completo criado!"
echo "📁 Diretório: $BACKUP_DIR"
echo "📄 Arquivos criados:"
ls -la $BACKUP_DIR/
```

**Você deve ver 3 arquivos:**
- `products.json` - Backup dos produtos
- `orders.json` - Backup dos pedidos  
- `manifest.json` - Informações do backup

### Passo 3: Comprimir e Enviar para S3

```bash
# Comprimir backup
cd $HOME/docdb-backup
BACKUP_NAME=$(basename $BACKUP_DIR)
tar -czf ${BACKUP_NAME}.tar.gz $BACKUP_NAME

# Verificar tamanho do arquivo
BACKUP_SIZE=$(stat -c%s ${BACKUP_NAME}.tar.gz 2>/dev/null || stat -f%z ${BACKUP_NAME}.tar.gz)
echo "Tamanho do backup comprimido: $BACKUP_SIZE bytes"

# Enviar para S3
aws s3 cp ${BACKUP_NAME}.tar.gz s3://$BACKUP_BUCKET/backups/full/

# Criar arquivo de metadados
cat > backup-metadata.json << EOF
{
  "backup_id": "${BACKUP_NAME}",
  "backup_type": "full",
  "database": "backupTestDB",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "cluster_endpoint": "$CLUSTER_ENDPOINT",
  "size_bytes": $BACKUP_SIZE,
  "compression": "gzip",
  "retention_days": 2920
}
EOF

# Enviar metadados
aws s3 cp backup-metadata.json s3://$BACKUP_BUCKET/metadata/full/${BACKUP_NAME}-metadata.json

echo "✅ Backup completo enviado para S3!"
echo "📁 Arquivo: ${BACKUP_NAME}.tar.gz"
echo "📊 Tamanho: $BACKUP_SIZE bytes"
```

---

## 🔄 Parte 3: Backup Incremental

### Passo 1: Adicionar Mais Dados

**1.1. Conectar ao DocumentDB**

```bash
mongosh --host $CLUSTER_ENDPOINT:27017 \
--username $DB_USERNAME \
--password $DB_PASSWORD \
--tls \
--tlsCAFile global-bundle.pem \
--retryWrites false
```

**1.2. Adicionar novos dados**

```javascript
use backupTestDB

// Adicionar novos produtos
db.products.insertMany([
  {_id: 4, name: 'Keyboard', category: 'electronics', price: 79.99, createdAt: new Date()},
  {_id: 5, name: 'Monitor', category: 'electronics', price: 299.99, createdAt: new Date()}
])

// Atualizar produto existente
db.products.updateOne({_id: 1}, {$set: {price: 899.99, updatedAt: new Date()}})

// Verificar novos dados
db.products.countDocuments()
db.products.find({_id: {$in: [4, 5]}})

exit
```

**Resultado esperado:** Agora temos 5 produtos no total

### Passo 2: Executar Backup Incremental

```bash
# Criar diretório para backup incremental
INCREMENTAL_DIR="$HOME/docdb-backup/incremental-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p $INCREMENTAL_DIR

echo "Criando backup incremental em: $INCREMENTAL_DIR"

# Data de ontem para filtro incremental
YESTERDAY=$(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%SZ)

# Backup incremental da collection products (documentos das últimas 24h)
echo "Fazendo backup incremental da collection 'products'..."

# Para backup incremental, usar query com mongoexport
mongoexport \
--host $CLUSTER_ENDPOINT:27017 \
--username $DB_USERNAME \
--password $DB_PASSWORD \
--ssl \
--sslCAFile ~/global-bundle.pem \
--db backupTestDB \
--collection products \
--query "{\"createdAt\": {\"\$gte\": {\"\$date\": \"$YESTERDAY\"}}}" \
--out $INCREMENTAL_DIR/products_incremental.json \
--jsonArray \
--pretty

# Verificar resultado
ls -la $INCREMENTAL_DIR/products_incremental.json
grep -c "_id" $INCREMENTAL_DIR/products_incremental.json

# Criar manifesto do backup incremental
cat > $INCREMENTAL_DIR/manifest.json << EOF
{
  "backup_type": "incremental",
  "database": "backupTestDB",
  "since_date": "$YESTERDAY",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "collections": ["products"],
  "backup_directory": "$INCREMENTAL_DIR"
}
EOF

# Comprimir e enviar
cd $HOME/docdb-backup
INCREMENTAL_NAME=$(basename $INCREMENTAL_DIR)
tar -czf ${INCREMENTAL_NAME}.tar.gz $INCREMENTAL_NAME

aws s3 cp ${INCREMENTAL_NAME}.tar.gz s3://$BACKUP_BUCKET/backups/incremental/

echo "✅ Backup incremental concluído e enviado para S3!"
```

---

## 🔧 Parte 4: Restore e Validação

### Passo 1: Simular Perda de Dados

**1.1. Conectar ao DocumentDB**

```bash
mongosh --host $CLUSTER_ENDPOINT:27017 \
--username $DB_USERNAME \
--password $DB_PASSWORD \
--tls \
--tlsCAFile global-bundle.pem
```

**1.2. Simular perda acidental de dados**

```javascript
use backupTestDB

// Simular perda de dados removendo produtos eletrônicos
db.products.deleteMany({category: 'electronics'})

// Verificar quantos produtos restaram
db.products.countDocuments()

// Ver quais produtos ainda existem
db.products.find()

exit
```

**Resultado esperado:** Apenas 1 produto restante (o livro)

### Passo 2: Restaurar do Backup

```bash
# Criar diretório para restore
mkdir -p $HOME/restore

# Baixar backup mais recente do S3
LATEST_BACKUP=$(aws s3 ls s3://$BACKUP_BUCKET/backups/full/ | tail -1 | awk '{print $4}')
echo "Restaurando backup: $LATEST_BACKUP"

aws s3 cp s3://$BACKUP_BUCKET/backups/full/$LATEST_BACKUP $HOME/restore/

# Extrair backup
cd $HOME/restore
tar -xzf $LATEST_BACKUP

# Encontrar diretório extraído
BACKUP_FOLDER=$(ls -d */ | head -1)
echo "Diretório do backup: $BACKUP_FOLDER"
```

**2.1. Restaurar collection products**

Primeiro, limpar a collection existente:

```bash
mongosh --host $CLUSTER_ENDPOINT:27017 \
--username $DB_USERNAME \
--password $DB_PASSWORD \
--tls \
--tlsCAFile ~/global-bundle.pem
```

No mongosh, execute:

```javascript
use backupTestDB
db.products.drop()
exit
```

Agora restaurar usando mongoimport:

```bash
mongoimport \
--host $CLUSTER_ENDPOINT:27017 \
--username $DB_USERNAME \
--password $DB_PASSWORD \
--ssl \
--sslCAFile ~/global-bundle.pem \
--db backupTestDB \
--collection products \
--file ${BACKUP_FOLDER}products.json \
--jsonArray
```

**2.2. Verificar restore**

```bash
mongosh --host $CLUSTER_ENDPOINT:27017 \
--username $DB_USERNAME \
--password $DB_PASSWORD \
--tls \
--tlsCAFile ~/global-bundle.pem
```

No mongosh, execute:

```javascript
use backupTestDB
db.products.countDocuments()
db.products.find()
exit
```

**Resultado esperado:** 3 produtos restaurados (incluindo os eletrônicos)

### Passo 3: Validar Integridade dos Dados

```bash
mongosh --host $CLUSTER_ENDPOINT:27017 \
--username $DB_USERNAME \
--password $DB_PASSWORD \
--tls \
--tlsCAFile ~/global-bundle.pem
```

No mongosh, execute:

```javascript
use backupTestDB

// Verificar contagens
db.products.countDocuments()
db.products.countDocuments({category: "electronics"})
db.orders.countDocuments()

// Verificar integridade referencial
db.orders.find().forEach(function(order) {
  var product = db.products.findOne({_id: order.productId})
  if (!product) {
    print('ERRO: Pedido', order._id, 'referencia produto inexistente', order.productId)
  } else {
    print('OK: Pedido', order._id, 'referencia produto válido:', product.name)
  }
})

exit
```

**Resultado esperado:**
- Produtos total: 3
- Produtos electronics: 2  
- Pedidos total: 2
- Todas as referências válidas

---

## ✅ Checklist de Conclusão

Execute o script de validação:

```bash
# Executa o grade para avaliar atividades
./grade_exercicio_backup.sh
```

### Itens Verificados:

- ✅ Bucket S3 configurado com políticas de retenção
- ✅ Backup completo executado com sucesso
- ✅ Backup incremental implementado
- ✅ Procedimento de restore testado e validado
- ✅ Integridade dos dados verificada

---

## 🧹 Limpeza

```bash
# Remover dados de teste
# Conectar ao DocumentDB
mongosh --host $CLUSTER_ENDPOINT:27017 \
--username $DB_USERNAME \
--password $DB_PASSWORD \
--tls \
--tlsCAFile ~/global-bundle.pem

# No mongosh, executar:
# use backupTestDB
# db.dropDatabase()
# exit

# Deletar bucket S3 (CUIDADO - remove todos os backups!)
# Descomente apenas se quiser remover TODOS os backups
# aws s3 rm s3://$BACKUP_BUCKET --recursive
# aws s3 rb s3://$BACKUP_BUCKET

# Limpar arquivos temporários locais
rm -rf $HOME/docdb-backup/*
rm -rf $HOME/restore/*

echo "Limpeza concluída!"
```

---

## 📊 Estratégias de Backup Implementadas

### Tipos de Backup Configurados:

1. **Backup Completo (Full Backup):**
   - Backup de todo o database
   - Frequência: Semanal ou mensal
   - Uso: Restore completo, baseline de dados

2. **Backup Incremental:**
   - Apenas dados modificados recentemente
   - Frequência: Diária
   - Uso: Redução de tempo e espaço

### Benefícios Alcançados:

- **Proteção de Dados:** Múltiplas camadas de backup
- **Otimização de Custos:** Lifecycle policies automáticas
- **Flexibilidade:** Restore completo ou seletivo
- **Simplicidade:** Procedimentos manuais claros e testados

### Casos de Uso Atendidos:

- **Disaster Recovery:** Restore rápido em caso de falha
- **Backup Operacional:** Proteção antes de mudanças
- **Compliance Básico:** Retenção estruturada no S3

---

[⬅️ Módulo 5 Home](../README.md)