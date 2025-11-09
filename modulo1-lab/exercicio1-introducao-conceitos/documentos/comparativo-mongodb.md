# Comparativo: DocumentDB vs MongoDB

## Visão Geral da Compatibilidade

O AWS DocumentDB oferece compatibilidade com a API do MongoDB versões 3.6 e 4.0, mas não é uma implementação completa do MongoDB.

## Recursos Suportados ✅

### Operações CRUD
- `find()`, `findOne()`
- `insert()`, `insertOne()`, `insertMany()`
- `update()`, `updateOne()`, `updateMany()`
- `delete()`, `deleteOne()`, `deleteMany()`
- `replaceOne()`

### Índices
- Índices simples e compostos
- Índices parciais
- Índices TTL (Time To Live)
- Índices de texto (limitado)
- Índices geoespaciais 2dsphere

### Agregação (Parcial)
- Pipeline básico de agregação
- `$match`, `$project`, `$sort`, `$limit`, `$skip`
- `$group` com operadores básicos
- `$lookup` (joins simples)
- `$unwind`

### Recursos de Administração
- Autenticação baseada em usuário/senha
- Roles e privilégios
- Backup e restore
- Monitoramento via CloudWatch

## Recursos NÃO Suportados ❌

### Transações
- Transações multi-documento
- Sessões com transações
- `startTransaction()`, `commitTransaction()`

### Sharding
- Sharding automático
- Shard keys
- Balanceamento de shards
- Operações específicas de shard

### Operações Avançadas
- GridFS (armazenamento de arquivos)
- Capped collections
- Map-reduce (deprecated no MongoDB também)
- Algumas operações de agregação complexas

### Features Específicas do MongoDB
- Change streams (parcialmente suportado)
- Collations avançadas
- Views (parcialmente suportado)
- Algumas operações de array complexas

## Tabela Comparativa Detalhada

| Recurso | MongoDB | DocumentDB | Notas |
|---------|---------|------------|-------|
| **Versão da API** | 5.0+ | 3.6/4.0 | DocumentDB baseado em versões antigas |
| **Transações ACID** | ✅ Multi-doc | ❌ Single-doc apenas | Limitação importante |
| **Sharding** | ✅ Nativo | ❌ Não suportado | Use read replicas para escala |
| **GridFS** | ✅ | ❌ | Use S3 para arquivos grandes |
| **Change Streams** | ✅ Completo | ⚠️ Limitado | Funcionalidade básica apenas |
| **Índices** | ✅ Completo | ✅ Maioria | Suporte robusto |
| **Agregação** | ✅ Completo | ⚠️ Parcial | Pipeline básico funciona |
| **Backup** | Manual/Ops Manager | ✅ Automático | Vantagem do DocumentDB |
| **Alta Disponibilidade** | Manual/Replica Sets | ✅ Automático | Multi-AZ por padrão |
| **Monitoramento** | Ferramentas externas | ✅ CloudWatch | Integração nativa AWS |
| **Escalabilidade** | Horizontal (sharding) | Vertical + Read Replicas | Abordagens diferentes |

## Migração: O que Considerar

### Aplicações Compatíveis
- CRUD operations básicas
- Queries simples e médias
- Índices padrão
- Agregações básicas

### Aplicações que Precisam Adaptação
- Uso de transações multi-documento
- GridFS para arquivos
- Sharding existente
- Change streams avançados
- Operações de agregação complexas

### Estratégias de Migração

#### 1. Lift and Shift (Mais Simples)
```javascript
// Código que funciona sem alteração
const users = await db.collection('users').find({status: 'active'});
const result = await db.collection('orders').insertOne({...});
```

#### 2. Adaptação Necessária
```javascript
// MongoDB com transação
const session = client.startSession();
session.startTransaction();
// ... operações
await session.commitTransaction();

// DocumentDB - sem transações multi-doc
// Redesenhar para operações atômicas single-document
```

#### 3. Workarounds Comuns
```javascript
// GridFS no MongoDB
const bucket = new GridFSBucket(db);

// Alternativa no DocumentDB
// Usar S3 + metadata no DocumentDB
const fileMetadata = {
  filename: 'document.pdf',
  s3Key: 'files/document.pdf',
  size: 1024000
};
```

## Ferramentas de Migração

### Suportadas
- **mongodump/mongorestore**: Para migração inicial
- **AWS DMS**: Para migração contínua
- **MongoDB Compass**: Para exploração (read-only)
- **Drivers oficiais**: Mesma connection string

### Limitadas
- **MongoDB Atlas Live Migration**: Não aplicável
- **Ops Manager**: Não compatível
- **MongoDB Charts**: Funcionalidade limitada

## Recomendações de Migração

### Antes de Migrar
1. **Auditoria de código**: Identifique recursos não suportados
2. **Teste de compatibilidade**: Execute testes em ambiente DocumentDB
3. **Plano de fallback**: Mantenha MongoDB como backup inicial
4. **Treinamento da equipe**: Entenda as limitações

### Durante a Migração
1. **Migração incremental**: Por módulos/funcionalidades
2. **Testes extensivos**: Valide cada funcionalidade
3. **Monitoramento**: Compare performance antes/depois
4. **Rollback plan**: Tenha plano de volta se necessário

### Após a Migração
1. **Otimização**: Aproveite recursos AWS nativos
2. **Monitoramento contínuo**: Use CloudWatch
3. **Backup strategy**: Configure políticas adequadas
4. **Documentação**: Atualize docs com mudanças

## Conclusão

O DocumentDB é ideal para aplicações que:
- Usam funcionalidades básicas/intermediárias do MongoDB
- Precisam de gerenciamento automático
- Querem integração com AWS
- Não dependem de sharding ou transações complexas

Considere manter MongoDB se:
- Usa recursos avançados não suportados
- Tem arquitetura baseada em sharding
- Precisa de transações multi-documento
- Requer controle total sobre configuração