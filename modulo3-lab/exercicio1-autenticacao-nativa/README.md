# Exercício 1: Autenticação Nativa de Banco de Dados

Neste exercício, vamos implementar autenticação segura no Amazon DocumentDB através da criação de usuários nativos com diferentes níveis de acesso.

## 📋 Objetivos

- Obter informações de conexão do cluster DocumentDB
- Baixar e configurar certificados SSL/TLS
- Conectar-se ao cluster usando credenciais do usuário mestre
- Criar usuários nativos com diferentes roles
- Testar autenticação com os novos usuários

## 🚀 Pré-requisitos

- Cluster DocumentDB `<seu-id>-lab-cluster-console` ativo (criado no Módulo 2)
- MongoDB Shell (mongosh) instalado
- AWS CLI configurado
- Acesso de rede ao cluster (via EC2 na mesma VPC ou VPN)
- Credenciais do usuário mestre: `docdbadmin` / `Lab12345!`

## 📝 Passos do Exercício

### 0. Configurar Identificador Único

**Objetivo:** Definir o mesmo ID usado no Módulo 2 para localizar o cluster correto.

```bash
# Verificar se o cluster existe
aws docdb describe-db-clusters --db-cluster-identifier $ID-lab-cluster-console --query 'DBClusters[0].[DBClusterIdentifier,Status,Endpoint]' --output table
```

### 1. Obter Informações de Conexão do Cluster

**Objetivo:** Localizar endpoint, porta e credenciais do cluster DocumentDB.

**Via AWS Console:**
1. Navegue até Amazon DocumentDB no console AWS
2. Selecione **Clusters** no painel lateral
3. Clique no seu cluster (ex: `aluno01-lab-cluster-console`)
4. Na aba **Connectivity & security**, anote:
   - **Cluster endpoint**
   - **Port** (padrão: 27017)
   - **Master username**

**Via AWS CLI:**
```bash
# Listar clusters disponíveis
aws docdb describe-db-clusters --query "DBClusters[*].[DBClusterIdentifier,Endpoint,Port,MasterUsername]" --output table

# Obter detalhes do cluster criado no Módulo 2
aws docdb describe-db-clusters --db-cluster-identifier $ID-lab-cluster-console

# Obter apenas o endpoint
aws docdb describe-db-clusters \
--db-cluster-identifier $ID-lab-cluster-console \
--query 'DBClusters[0].Endpoint' \
--output text
```

### 2. Baixar Certificado SSL/TLS

**Objetivo:** Configurar conexão segura com TLS obrigatório.

```bash
# Baixar o certificado global do DocumentDB
wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

# Verificar o certificado
openssl x509 -in global-bundle.pem -text -noout | head -20
```

### 3. Conectar ao Cluster como Usuário Mestre

**Objetivo:** Estabelecer conexão inicial para administração.

```bash
# Obter endpoint do cluster (substitua ID)
export CLUSTER_ENDPOINT=$(aws docdb describe-db-clusters \
--db-cluster-identifier $ID-lab-cluster-console \
--query 'DBClusters[0].Endpoint' \
--output text)

# Conectar usando mongosh (recomendado) - IMPORTANTE: desabilitar retryWrites
mongosh --tls --host $CLUSTER_ENDPOINT:27017 \
--tlsCAFile global-bundle.pem \
--username docdbadmin \
--password Lab12345! \
--retryWrites false

# Ou usando mongo shell (versão antiga)
mongo --ssl --host $CLUSTER_ENDPOINT:27017 \
--sslCAFile global-bundle.pem \
--username docdbadmin \
--password Lab12345!
```

**Credenciais do Módulo 2:**
- **Cluster:** `<seu-id>-lab-cluster-console`
- **Usuário mestre:** `docdbadmin`
- **Senha mestre:** `Lab12345!`

### 4. Criar Base de Dados e Coleções de Teste

**Objetivo:** Preparar ambiente para testes de autenticação.

```javascript
// Criar e usar uma base de dados de laboratório
use labdb

// IMPORTANTE: DocumentDB não suporta retryWrites, use insertOne() para cada documento
// Ou desabilite retryWrites na conexão (--retryWrites=false)

// Opção 1: Inserir um documento por vez
db.produtos.insertOne({ nome: "Notebook", preco: 2500, categoria: "eletrônicos" })
db.produtos.insertOne({ nome: "Mouse", preco: 50, categoria: "eletrônicos" })
db.produtos.insertOne({ nome: "Livro", preco: 30, categoria: "educação" })

// Opção 2: Se conectou com --retryWrites=false, pode usar insertMany
db.produtos.insertMany([
  { nome: "Teclado", preco: 150, categoria: "eletrônicos" },
  { nome: "Monitor", preco: 800, categoria: "eletrônicos" }
])

// Verificar dados inseridos
db.produtos.find().pretty()

// Criar outra base para testes de permissão
use testdb
db.logs.insertOne({ evento: "teste", timestamp: new Date() })
```

### 5. Criar Usuários com Diferentes Roles

**Objetivo:** Implementar princípio do menor privilégio com roles específicas.

```javascript
// Usuário com acesso de leitura apenas
use labdb
db.createUser({
    user: "leitor",
    pwd: "senha123",
    roles: [
        { role: "read", db: "labdb" }
    ]
})

// Usuário com acesso de leitura e escrita
db.createUser({
    user: "editor",
    pwd: "senha456",
    roles: [
        { role: "readWrite", db: "labdb" }
    ]
})

// Usuário administrador de múltiplas bases
db.createUser({
    user: "admin_app",
    pwd: "senha789",
    roles: [
        { role: "readWrite", db: "labdb" },
        { role: "readWrite", db: "testdb" },
        { role: "dbAdmin", db: "labdb" }
    ]
})

// Listar usuários criados
db.getUsers()
```

### 6. Testar Autenticação dos Novos Usuários

**Objetivo:** Validar que as permissões estão funcionando corretamente.

**Teste 1: Usuário com permissão de leitura**
```bash
# Conectar como usuário 'leitor'
mongosh --tls --host $CLUSTER_ENDPOINT:27017 \
--tlsCAFile global-bundle.pem \
--username leitor \
--password senha123 \
--retryWrites false
```

```javascript
// Dentro da conexão do usuário 'leitor'
use labdb

// Deve funcionar (leitura)
db.produtos.find()

// Deve falhar (escrita)
db.produtos.insertOne({ nome: "Teste", preco: 10 })
```

**Teste 2: Usuário com permissão de escrita**
```bash
# Conectar como usuário 'editor'
mongosh --tls --host $CLUSTER_ENDPOINT:27017 \
--tlsCAFile global-bundle.pem \
--username editor \
--password senha456 \
--retryWrites false
```

```javascript
// Dentro da conexão do usuário 'editor'
use labdb

// Deve funcionar (leitura e escrita)
db.produtos.find()
db.produtos.insertOne({ nome: "Teclado", preco: 150, categoria: "eletrônicos" })

// Deve falhar (acesso a outra base)
use testdb
db.logs.find()
```

## 🔧 Scripts Automatizados

Execute o script fornecido para automatizar a criação de usuários:

```bash
# Executar script
./scripts/create_user.sh

# Testar conexões
./scripts/test_connection.sh
```

## ✅ Checklist de Conclusão

Execute o script de validação para verificar automaticamente se o exercício foi concluído:

```bash
# Executa o grade para avaliar atividades
/home/$ID/Curso-documentDB/modulo3-lab/exercicio1-autenticacao-nativa/grade_exercicio1.sh
```

### Validação Automatizada

Execute o script de validação para verificar automaticamente se o exercício foi concluído:

```bash
# Executar validação
/home/$ID/Curso-documentDB/modulo3-lab/exercicio1-autenticacao-nativa/grade_exercicio1.sh

# Ou passar o ID diretamente
./grade_exercicio1.sh $ID
```

O script irá verificar:
- ✅ Cluster do Módulo 2 disponível
- ✅ Certificado SSL configurado
- ✅ Conectividade com usuário mestre
- ✅ Base de dados `labdb` criada com dados
- ✅ Usuários nativos criados (`leitor`, `editor`, `admin_app`)
- ✅ Permissões funcionando corretamente
- ✅ Scripts automatizados disponíveis

## 🚨 Troubleshooting

**Erro "Retryable writes are not supported":**
```bash
# SOLUÇÃO 1: Conectar com --retryWrites false
mongosh --tls --host $CLUSTER_ENDPOINT:27017 \
--tlsCAFile global-bundle.pem \
--username docdbadmin \
--password Lab12345! \
--retryWrites false

# SOLUÇÃO 2: Usar insertOne() ao invés de insertMany()
# Dentro do mongosh:
db.produtos.insertOne({ nome: "Produto", preco: 100 })

# SOLUÇÃO 3: Usar string de conexão com retryWrites=false
mongosh "mongodb://docdbadmin:Lab12345!@$CLUSTER_ENDPOINT:27017/labdb?tls=true&tlsCAFile=global-bundle.pem&retryWrites=false"
```

**Erro de conexão SSL:**
```bash
# Verificar se o certificado foi baixado corretamente
ls -la global-bundle.pem

# Testar conectividade de rede
telnet $CLUSTER_ENDPOINT 27017

# Verificar se o cluster está ativo
aws docdb describe-db-clusters --db-cluster-identifier $ID-lab-cluster-console --query 'DBClusters[0].Status'
```

**Erro de autenticação:**
```bash
# Verificar se o usuário existe
db.getUsers()

# Verificar roles do usuário
db.getUser("nome_usuario")
```

**Erro de rede:**
```bash
# Testar conectividade
telnet $CLUSTER_ENDPOINT 27017

# Verificar security groups do cluster
aws docdb describe-db-clusters \
  --db-cluster-identifier $ID-lab-cluster-console \
  --query 'DBClusters[0].VpcSecurityGroups[*].VpcSecurityGroupId'

# Verificar regras do security group (substitua o ID)
aws ec2 describe-security-groups --group-ids <SECURITY_GROUP_ID>
```

## 📚 Conceitos Aprendidos

- **Autenticação nativa**: Usuários criados diretamente no DocumentDB
- **Roles baseadas em permissões**: read, readWrite, dbAdmin
- **Princípio do menor privilégio**: Cada usuário tem apenas as permissões necessárias
- **Autenticação por base de dados**: Usuários são específicos de cada database
- **Conexões TLS**: Criptografia obrigatória para segurança

## ➡️ Próximo Exercício

No [Exercício 2](../exercicio2-integracao-rede/README.md), você aprenderá a configurar security groups e controles de rede para proteger ainda mais o acesso ao cluster.
