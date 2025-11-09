# Casos de Uso do AWS DocumentDB

## Casos de Uso Ideais ✅

### 1. Catálogos de Produtos E-commerce

**Cenário**: Loja online com milhares de produtos com atributos variados

**Por que DocumentDB?**
- Estrutura flexível para diferentes tipos de produtos
- Queries rápidas por categoria, preço, atributos
- Escalabilidade para picos de tráfego
- Integração com outros serviços AWS (Lambda, API Gateway)

**Exemplo de Documento**:
```json
{
  "_id": "prod_123",
  "name": "Smartphone XYZ",
  "category": "electronics",
  "price": 599.99,
  "attributes": {
    "brand": "TechCorp",
    "storage": "128GB",
    "color": "black",
    "screen_size": "6.1 inches"
  },
  "inventory": {
    "quantity": 50,
    "warehouse": "US-EAST-1"
  },
  "reviews": [
    {"rating": 5, "comment": "Excellent phone!"}
  ]
}
```

### 2. Perfis de Usuário e Personalização

**Cenário**: Aplicação com perfis complexos e preferências personalizadas

**Por que DocumentDB?**
- Dados semi-estruturados de usuários
- Rápida recuperação de perfis
- Flexibilidade para adicionar novos campos
- Queries eficientes por preferências

**Exemplo de Documento**:
```json
{
  "_id": "user_456",
  "email": "user@example.com",
  "profile": {
    "name": "João Silva",
    "age": 32,
    "location": "São Paulo, BR"
  },
  "preferences": {
    "language": "pt-BR",
    "notifications": {
      "email": true,
      "push": false
    },
    "interests": ["technology", "sports", "travel"]
  },
  "activity": {
    "last_login": "2024-01-15T10:30:00Z",
    "sessions": 45,
    "favorite_products": ["prod_123", "prod_789"]
  }
}
```

### 3. Gestão de Conteúdo (CMS)

**Cenário**: Sistema de gerenciamento de conteúdo com tipos variados

**Por que DocumentDB?**
- Estruturas flexíveis para diferentes tipos de conteúdo
- Versionamento de documentos
- Queries por tags, categorias, datas
- Integração com CloudFront para CDN

**Exemplo de Documento**:
```json
{
  "_id": "article_789",
  "type": "blog_post",
  "title": "Introdução ao DocumentDB",
  "slug": "introducao-documentdb",
  "content": {
    "body": "Conteúdo do artigo...",
    "summary": "Resumo do artigo",
    "word_count": 1200
  },
  "metadata": {
    "author": "Tech Writer",
    "published_date": "2024-01-15",
    "tags": ["aws", "database", "mongodb"],
    "category": "technology",
    "status": "published"
  },
  "seo": {
    "meta_description": "Aprenda sobre DocumentDB",
    "keywords": ["documentdb", "aws", "nosql"]
  }
}
```

### 4. Dados de IoT e Telemetria

**Cenário**: Coleta de dados de sensores e dispositivos IoT

**Por que DocumentDB?**
- Ingestão de dados JSON variados
- Queries por timestamp e device_id
- Integração com IoT Core e Kinesis
- TTL para limpeza automática de dados antigos

**Exemplo de Documento**:
```json
{
  "_id": "sensor_reading_001",
  "device_id": "temp_sensor_01",
  "timestamp": "2024-01-15T14:30:00Z",
  "location": {
    "building": "Factory A",
    "floor": 2,
    "room": "Production Line 1"
  },
  "readings": {
    "temperature": 23.5,
    "humidity": 45.2,
    "pressure": 1013.25
  },
  "metadata": {
    "battery_level": 85,
    "signal_strength": -45,
    "firmware_version": "1.2.3"
  },
  "ttl": "2024-02-15T14:30:00Z"
}
```

### 5. Aplicações Mobile Backend

**Cenário**: Backend para aplicativo móvel com sincronização offline

**Por que DocumentDB?**
- Estrutura flexível para dados móveis
- Queries rápidas para sincronização
- Integração com Cognito para autenticação
- Suporte a índices geoespaciais

**Exemplo de Documento**:
```json
{
  "_id": "mobile_data_123",
  "user_id": "user_456",
  "app_version": "2.1.0",
  "device_info": {
    "platform": "iOS",
    "version": "15.2",
    "model": "iPhone 13"
  },
  "sync_data": {
    "last_sync": "2024-01-15T12:00:00Z",
    "pending_uploads": 3,
    "offline_changes": [
      {"action": "update", "collection": "notes", "id": "note_1"}
    ]
  },
  "location": {
    "type": "Point",
    "coordinates": [-23.5505, -46.6333]
  }
}
```

## Casos de Uso Problemáticos ❌

### 1. Sistemas Bancários com Transações Complexas

**Por que NÃO usar DocumentDB?**
- Necessidade de transações ACID multi-documento
- Consistência forte obrigatória
- Regulamentações rigorosas de auditoria

**Alternativa**: RDS PostgreSQL ou Aurora PostgreSQL

### 2. Data Warehousing e Analytics Pesados

**Por que NÃO usar DocumentDB?**
- Queries analíticas complexas
- Agregações pesadas em grandes volumes
- Necessidade de SQL padrão

**Alternativa**: Redshift, Athena, ou RDS para analytics

### 3. Aplicações com Sharding Intensivo

**Por que NÃO usar DocumentDB?**
- DocumentDB não suporta sharding nativo
- Aplicações que dependem de distribuição horizontal

**Alternativa**: MongoDB Atlas ou DynamoDB

### 4. Sistemas de Arquivos Distribuídos

**Por que NÃO usar DocumentDB?**
- Sem suporte a GridFS
- Necessidade de armazenar arquivos grandes no banco

**Alternativa**: S3 + metadata no DocumentDB ou EFS

## Padrões de Arquitetura Recomendados

### 1. Microserviços com DocumentDB

```
API Gateway → Lambda → DocumentDB
                ↓
            CloudWatch Logs
```

**Vantagens**:
- Escalabilidade automática
- Baixa latência
- Integração nativa AWS

### 2. Aplicação Web Tradicional

```
ALB → EC2/ECS → DocumentDB
        ↓
   ElastiCache (Redis)
```

**Vantagens**:
- Cache para performance
- Connection pooling
- Alta disponibilidade

### 3. Pipeline de Dados IoT

```
IoT Core → Kinesis → Lambda → DocumentDB
                              ↓
                         S3 (Archive)
```

**Vantagens**:
- Processamento em tempo real
- Arquivamento automático
- Escalabilidade para milhões de eventos

## Métricas de Decisão

### Use DocumentDB quando:
- ✅ Dados semi-estruturados ou JSON
- ✅ Queries por atributos variados
- ✅ Necessidade de escalabilidade de leitura
- ✅ Integração com ecossistema AWS
- ✅ Equipe familiarizada com MongoDB
- ✅ Workloads de leitura > escrita

### NÃO use DocumentDB quando:
- ❌ Transações complexas multi-documento
- ❌ Necessidade de sharding
- ❌ Queries analíticas pesadas
- ❌ Dependência de GridFS
- ❌ Necessidade de controle total sobre configuração
- ❌ Workloads de escrita muito intensivas

## Estimativa de Custos por Caso de Uso

### Pequeno (< 100GB, < 1000 conexões)
- **Instância**: db.t3.medium
- **Custo mensal**: ~$200-400 USD

### Médio (100GB-1TB, 1000-5000 conexões)
- **Instância**: db.r5.large + read replicas
- **Custo mensal**: ~$800-1500 USD

### Grande (> 1TB, > 5000 conexões)
- **Instância**: db.r5.xlarge + múltiplas read replicas
- **Custo mensal**: ~$2000-5000 USD

## Próximos Passos

Após entender os casos de uso, continue para:
- [Exercício 2: Console AWS](../../exercicio2-console-aws/README.md)
- [Exercício 3: CLI e SDKs](../../exercicio3-cli-sdks/README.md)