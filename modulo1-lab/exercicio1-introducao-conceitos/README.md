# Exercício 1: Introdução e Conceitos Fundamentais

## 🎯 Objetivos

- Compreender o que é o AWS DocumentDB e como se posiciona
- Analisar a arquitetura gerenciada e suas vantagens
- Comparar DocumentDB com MongoDB tradicional
- Identificar casos de uso apropriados

## ⏱️ Duração Estimada
90 minutos

---

## 📚 Parte 1: O que é o AWS DocumentDB

### Definição e Posicionamento

O **AWS DocumentDB** é um serviço de banco de dados de documentos totalmente gerenciado que oferece compatibilidade com a API do MongoDB. Ele foi projetado para fornecer a flexibilidade e facilidade de uso de bancos de dados de documentos com a confiabilidade, escalabilidade e segurança da AWS.

### Características Principais

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS DocumentDB                           │
├─────────────────────────────────────────────────────────────┤
│  ✅ Totalmente Gerenciado    │  ✅ Compatível com MongoDB   │
│  ✅ Separação Compute/Storage │  ✅ Backup Automático        │
│  ✅ Multi-AZ por Padrão      │  ✅ Encryption Nativo        │
│  ✅ Integração AWS Nativa    │  ✅ Scaling Automático       │
└─────────────────────────────────────────────────────────────┘
```

### Posicionamento no Mercado

1. **vs. MongoDB Atlas:**
   - Integração mais profunda com AWS
   - Menor flexibilidade de configuração
   - Custo potencialmente menor para workloads AWS

2. **vs. Amazon DynamoDB:**
   - Modelo de dados mais flexível (documentos vs. key-value)
   - Queries mais complexas suportadas
   - Familiar para desenvolvedores MongoDB

3. **vs. Amazon RDS:**
   - Modelo NoSQL vs. SQL
   - Melhor para dados semi-estruturados
   - Schema flexível

---

## 🏗️ Parte 2: Arquitetura Gerenciada

### Arquitetura de Separação Compute/Storage

```
┌─────────────────────────────────────────────────────────────┐
│                    Aplicação                                │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                 Cluster DocumentDB                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Primary   │  │ Read Replica│  │ Read Replica│        │
│  │  Instance   │  │      1      │  │      2      │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              Storage Distribuído                            │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐       │
│  │ Volume  │  │ Volume  │  │ Volume  │  │ Volume  │       │
│  │   AZ-A  │  │   AZ-B  │  │   AZ-C  │  │ Backup  │       │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### Vantagens da Arquitetura Gerenciada

1. **Separação de Responsabilidades:**
   - AWS gerencia infraestrutura
   - Você foca na aplicação
   - Atualizações automáticas

2. **Escalabilidade Independente:**
   - Compute: Adicionar/remover instâncias
   - Storage: Crescimento automático até 64TB
   - Read Replicas: Até 15 réplicas

3. **Alta Disponibilidade:**
   - Multi-AZ por padrão
   - Failover automático
   - Backup contínuo

---

## 🔄 Parte 3: Compatibilidade com MongoDB

### Versões Suportadas

O DocumentDB oferece compatibilidade com:
- **MongoDB 3.6 API** (padrão)
- **MongoDB 4.0 API** (disponível)

### APIs e Operações Suportadas

```javascript
// ✅ SUPORTADO - Operações básicas CRUD
db.collection.insertOne({name: "produto", price: 100})
db.collection.find({category: "electronics"})
db.collection.updateOne({_id: id}, {$set: {price: 120}})
db.collection.deleteOne({_id: id})

// ✅ SUPORTADO - Agregações básicas
db.collection.aggregate([
  {$match: {category: "electronics"}},
  {$group: {_id: "$brand", count: {$sum: 1}}},
  {$sort: {count: -1}}
])

// ✅ SUPORTADO - Índices
db.collection.createIndex({name: 1})
db.collection.createIndex({category: 1, price: -1})

// ❌ NÃO SUPORTADO - Algumas operações avançadas
db.collection.mapReduce(...)  // Use aggregation pipeline
db.fs.files.find(...)        // GridFS não suportado
```

### Drivers Compatíveis

```bash
# Node.js
npm install mongodb

# Python
pip install pymongo

# Java
<dependency>
  <groupId>org.mongodb</groupId>
  <artifactId>mongodb-driver-sync</artifactId>
</dependency>
```

---

## ⚠️ Parte 4: Limitações Importantes

### Limitações Funcionais

1. **Transações:**
   - Suporte limitado a transações multi-documento
   - Transações single-document funcionam normalmente

2. **Sharding:**
   - Não suportado nativamente
   - Use read replicas para distribuir carga de leitura

3. **Operações Não Suportadas:**
   - GridFS
   - Algumas operações de agregação avançadas
   - Map-Reduce (use aggregation pipeline)

### Limitações de Configuração

```javascript
// ❌ Configurações não disponíveis
// - Configuração de sharding
// - Ajustes de storage engine
// - Configurações de replicação manual

// ✅ Configurações disponíveis via Parameter Groups
// - Profiler settings
// - Audit log settings
// - Connection limits
```

---

## 🔗 Parte 5: Integrações com AWS

### Integrações Nativas

1. **Rede e Segurança:**
   - **VPC:** Isolamento de rede obrigatório
   - **Security Groups:** Controle de acesso de rede
   - **Encryption:** Criptografia em repouso e trânsito

2. **Monitoramento:**
   - **CloudWatch:** Métricas e logs integrados
   - **CloudTrail:** Auditoria de chamadas de API
   - **Events:** Notificações de eventos do cluster

3. **Backup e Recovery:**
   - **Automated Backups:** Backup contínuo automático
   - **Manual Snapshots:** Snapshots sob demanda
   - **Point-in-time Recovery:** Restauração precisa

### Arquitetura de Integração Típica

```
┌─────────────────────────────────────────────────────────────┐
│                    Aplicação Web                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Lambda    │  │     ECS     │  │     EC2     │        │
│  │ Functions   │  │  Containers │  │ Instances   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                 DocumentDB Cluster                          │
│              (Private Subnets)                              │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              Serviços de Suporte                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ CloudWatch  │  │   S3 Backup │  │ EventBridge │        │
│  │ Monitoring  │  │   Storage   │  │   Events    │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 Parte 6: Casos de Uso Ideais

### 1. Aplicações Web Modernas

```javascript
// Exemplo: Catálogo de produtos e-commerce
{
  "_id": ObjectId("..."),
  "name": "Smartphone XYZ",
  "category": "electronics",
  "price": 599.99,
  "specifications": {
    "screen": "6.1 inch",
    "storage": "128GB",
    "camera": "12MP"
  },
  "reviews": [
    {
      "user": "john_doe",
      "rating": 5,
      "comment": "Excelente produto!"
    }
  ],
  "inventory": {
    "quantity": 50,
    "warehouse": "SP-001"
  }
}
```

### 2. Content Management Systems

```javascript
// Exemplo: Sistema de blog/CMS
{
  "_id": ObjectId("..."),
  "title": "Introdução ao DocumentDB",
  "slug": "introducao-documentdb",
  "content": "Conteúdo do artigo...",
  "author": {
    "name": "João Silva",
    "email": "joao@example.com"
  },
  "tags": ["aws", "database", "nosql"],
  "metadata": {
    "publishedAt": ISODate("2024-01-15"),
    "views": 1250,
    "likes": 45
  },
  "comments": [...]
}
```

### 3. IoT e Analytics

```javascript
// Exemplo: Dados de sensores IoT
{
  "_id": ObjectId("..."),
  "deviceId": "sensor-001",
  "timestamp": ISODate("2024-01-15T10:30:00Z"),
  "location": {
    "type": "Point",
    "coordinates": [-23.5505, -46.6333]
  },
  "readings": {
    "temperature": 23.5,
    "humidity": 65.2,
    "pressure": 1013.25
  },
  "metadata": {
    "batteryLevel": 85,
    "signalStrength": -45
  }
}
```

---

## ✅ Checklist de Conclusão

Execute o script de validação:

```bash
# Executa o grade para avaliar atividades
./grade_exercicio1.sh
```

### Conceitos Verificados:

- ✅ Compreensão do posicionamento do DocumentDB
- ✅ Conhecimento da arquitetura gerenciada
- ✅ Identificação de compatibilidades e limitações
- ✅ Reconhecimento de integrações AWS
- ✅ Identificação de casos de uso apropriados

---

## 📝 Resumo dos Conceitos

### Pontos Fortes do DocumentDB:
1. **Gerenciamento Automático:** Menos overhead operacional
2. **Integração AWS:** Ecossistema nativo
3. **Escalabilidade:** Compute e storage independentes
4. **Segurança:** Encryption e VPC por padrão
5. **Disponibilidade:** Multi-AZ automático

### Considerações Importantes:
1. **Limitações:** Nem tudo do MongoDB é suportado
2. **Versão:** Baseado em MongoDB 3.6/4.0
3. **Vendor Lock-in:** Específico da AWS
4. **Custo:** Avaliar vs. alternativas
5. **Migração:** Pode requerer adaptações de código

### Quando Usar DocumentDB:
- ✅ Aplicações já na AWS
- ✅ Necessidade de integração com serviços AWS
- ✅ Preferência por serviços gerenciados
- ✅ Workloads que se beneficiam de read replicas
- ✅ Requisitos de compliance e segurança

### Quando Considerar Alternativas:
- ❌ Necessidade de features específicas do MongoDB
- ❌ Aplicações multi-cloud
- ❌ Workloads que requerem sharding
- ❌ Necessidade de controle total sobre configuração

---

[⬅️ Módulo 1 Home](../README.md) | [➡️ Exercício 2](../exercicio2-console-aws/README.md)