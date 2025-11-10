# Exercício 2: Análise de Planos de Execução e Otimização de Índices

## 🎯 Objetivos

- Dominar o uso do comando explain() para análise de performance
- Identificar gargalos em queries através de planos de execução
- Implementar estratégias de indexação suportadas pelo DocumentDB
- Otimizar índices compostos e parciais para casos específicos

## ⏱️ Duração Estimada
90 minutos

> ⚠️ **Atenção:** Lembre-se de usar seu prefixo de aluno (`<seu-id>`) em todos os nomes de recursos e comandos.

---

## 🔍 Parte 1: Preparação do Ambiente e Dados de Teste

### Passo 1: Conectar ao Cluster e Preparar Dados

```bash
# Navegar para o diretório do exercício
cd exercicio2-planos-execucao

# Baixar certificado SSL do DocumentDB
wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

# Configurar variáveis de ambiente
export ID="<seu-id>"
export CLUSTER_ENDPOINT=$(aws docdb describe-db-clusters \
--db-cluster-identifier $ID-lab-cluster-console \
--query 'DBClusters[0].Endpoint' \
--output text)
export DB_USERNAME="docdbadmin"
export DB_PASSWORD="Lab12345!"

# Conectar ao DocumentDB
mongosh --host $CLUSTER_ENDPOINT:27017 \
--username $DB_USERNAME \
--password $DB_PASSWORD \
--ssl \
--sslCAFile global-bundle.pem \
--retryWrites=false
```

### Passo 2: Criar Base de Dados de Teste

```javascript
// Dentro do mongosh, executar:

// Usar database de performance
use performanceDB

// Criar coleção de produtos com dados variados
db.products.insertMany([
  // Inserir 10000 documentos de exemplo
  ...Array.from({length: 10000}, (_, i) => ({
    _id: i + 1,
    name: `Product ${i + 1}`,
    category: ['electronics', 'clothing', 'books', 'home', 'sports'][i % 5],
    price: Math.floor(Math.random() * 1000) + 10,
    brand: ['BrandA', 'BrandB', 'BrandC', 'BrandD'][i % 4],
    rating: Math.floor(Math.random() * 5) + 1,
    inStock: Math.random() > 0.3,
    tags: ['popular', 'new', 'sale', 'premium'].filter(() => Math.random() > 0.7),
    createdAt: new Date(Date.now() - Math.floor(Math.random() * 365 * 24 * 60 * 60 * 1000)),
    specifications: {
      weight: Math.floor(Math.random() * 5000) + 100,
      dimensions: {
        length: Math.floor(Math.random() * 100) + 10,
        width: Math.floor(Math.random() * 100) + 10,
        height: Math.floor(Math.random() * 100) + 10
      }
    }
  }))
])

// Criar coleção de pedidos
db.orders.insertMany([
  ...Array.from({length: 5000}, (_, i) => ({
    _id: i + 1,
    customerId: Math.floor(Math.random() * 1000) + 1,
    productIds: Array.from({length: Math.floor(Math.random() * 5) + 1}, 
      () => Math.floor(Math.random() * 10000) + 1),
    totalAmount: Math.floor(Math.random() * 5000) + 50,
    status: ['pending', 'processing', 'shipped', 'delivered'][Math.floor(Math.random() * 4)],
    orderDate: new Date(Date.now() - Math.floor(Math.random() * 180 * 24 * 60 * 60 * 1000)),
    shippingAddress: {
      country: ['US', 'CA', 'UK', 'DE', 'FR'][Math.floor(Math.random() * 5)],
      state: ['CA', 'NY', 'TX', 'FL'][Math.floor(Math.random() * 4)],
      zipCode: String(Math.floor(Math.random() * 90000) + 10000)
    }
  }))
])
```

---

## 📊 Parte 2: Análise de Planos de Execução Básicos

### Cenário 1: Query Sem Índice (Collection Scan)

```javascript
// Query que força collection scan
db.products.find({price: {$gte: 500}}).explain("executionStats")
```

**Análise do Resultado:**
- `executionStats.stage`: "COLLSCAN" (ruim para performance)
- `executionStats.docsExamined`: Número total de documentos examinados
- `executionStats.docsReturned`: Documentos retornados
- `executionStats.executionTimeMillis`: Tempo de execução

### Cenário 2: Query com Índice Simples

```javascript
// Criar índice simples
db.products.createIndex({price: 1})

// Executar mesma query
db.products.find({price: {$gte: 500}}).explain("executionStats")
```

**Análise do Resultado:**
- `executionStats.stage`: "IXSCAN" (bom para performance)
- Redução significativa em `docsExamined`
- Melhoria no `executionTimeMillis`

### Cenário 3: Query com Múltiplos Filtros

```javascript
// Query com múltiplos filtros (sem índice composto)
db.products.find({
  category: "electronics",
  price: {$gte: 100, $lte: 500},
  inStock: true
}).explain("executionStats")
```

---

## 🎯 Parte 3: Estratégias de Indexação Avançadas

### Índices Compostos

```javascript
// Criar índice composto otimizado
// Ordem: Igualdade -> Range -> Sort
db.products.createIndex({
  category: 1,      // Igualdade (mais seletivo primeiro)
  inStock: 1,       // Igualdade
  price: 1          // Range
})

// Testar performance
db.products.find({
  category: "electronics",
  inStock: true,
  price: {$gte: 100, $lte: 500}
}).explain("executionStats")
```

### Índices Parciais

```javascript
// Índice parcial para produtos em estoque
db.products.createIndex(
  {category: 1, price: 1},
  {partialFilterExpression: {inStock: true}}
)

// Query que utiliza o índice parcial
db.products.find({
  category: "electronics",
  price: {$gte: 100},
  inStock: true
}).explain("executionStats")
```

### Índices de Texto

```javascript
// Criar índice de texto para busca
db.products.createIndex({
  name: "text",
  "tags": "text"
})

// Query de busca textual
db.products.find({
  $text: {$search: "premium electronics"}
}).explain("executionStats")
```

---

## 🔧 Parte 4: Análise Avançada com explain()

### Usando explain("allPlansExecution")

```javascript
// Análise completa de todos os planos considerados
db.products.find({
  category: "electronics",
  price: {$gte: 100, $lte: 500}
}).explain("allPlansExecution")
```

**Campos Importantes:**
- `queryPlanner.winningPlan`: Plano escolhido pelo otimizador
- `queryPlanner.rejectedPlans`: Planos alternativos considerados
- `executionStats.allPlansExecution`: Estatísticas de todos os planos testados

### Análise de Queries de Agregação

```javascript
// Pipeline de agregação complexo
db.orders.aggregate([
  {$match: {status: "delivered"}},
  {$lookup: {
    from: "products",
    localField: "productIds",
    foreignField: "_id",
    as: "products"
  }},
  {$group: {
    _id: "$shippingAddress.country",
    totalRevenue: {$sum: "$totalAmount"},
    orderCount: {$sum: 1}
  }},
  {$sort: {totalRevenue: -1}}
]).explain("executionStats")
```

---

## 📈 Parte 5: Otimização Baseada em Análise

### Script de Análise Automatizada

```bash
# Executar script de análise de queries
node scripts/explain-analyzer.js --collection products --analyze-all

# Gerar relatório de otimização
node scripts/index-optimizer.sh --database performanceDB --recommendations
```

### Cenários de Otimização Comuns

#### Cenário 1: Query com Sort Custoso

```javascript
// Query com sort que não usa índice
db.products.find({category: "electronics"})
  .sort({createdAt: -1})
  .limit(10)
  .explain("executionStats")

// Solução: Índice composto incluindo sort
db.products.createIndex({category: 1, createdAt: -1})
```

#### Cenário 2: Agregação com $lookup Lento

```javascript
// Otimizar lookup com índices apropriados
db.products.createIndex({_id: 1}) // Já existe por padrão
db.orders.createIndex({productIds: 1}) // Para o lookup

// Testar performance após índices
db.orders.aggregate([
  {$lookup: {
    from: "products",
    localField: "productIds",
    foreignField: "_id",
    as: "products"
  }}
]).explain("executionStats")
```

#### Cenário 3: Query com Regex Ineficiente

```javascript
// Query regex ineficiente
db.products.find({name: /^Product 1/}).explain("executionStats")

// Solução: Usar índice de texto ou otimizar regex
db.products.createIndex({name: 1})
db.products.find({name: {$regex: "^Product 1"}}).explain("executionStats")
```

---

## 🎯 Parte 6: Monitoramento de Performance de Índices

### Análise de Uso de Índices

```javascript
// Verificar estatísticas de uso de índices
db.products.aggregate([{$indexStats: {}}])

// Identificar índices não utilizados
db.runCommand({collStats: "products", indexDetails: true})
```

### Script de Monitoramento Contínuo

```bash
# Executar monitoramento de performance de queries
node scripts/query-performance-monitor.js --interval 60 --threshold 100ms
```

---

## 📋 Parte 7: Testes de Performance Comparativos

### Teste 1: Antes vs Depois da Otimização

```javascript
// Função para medir performance
function measureQuery(queryFunc, iterations = 100) {
  const start = Date.now()
  for(let i = 0; i < iterations; i++) {
    queryFunc()
  }
  const end = Date.now()
  return (end - start) / iterations
}

// Teste query sem índice
const timeWithoutIndex = measureQuery(() => {
  db.products.find({price: {$gte: 500}}).toArray()
})

// Teste query com índice
const timeWithIndex = measureQuery(() => {
  db.products.find({price: {$gte: 500}}).hint({price: 1}).toArray()
})

print(`Sem índice: ${timeWithoutIndex}ms`)
print(`Com índice: ${timeWithIndex}ms`)
print(`Melhoria: ${((timeWithoutIndex - timeWithIndex) / timeWithoutIndex * 100).toFixed(2)}%`)
```

### Teste 2: Comparação de Estratégias de Índice

```bash
# Executar teste comparativo automatizado
node scripts/index-performance-test.js --collection products --test-scenarios all
```

---

## ✅ Checklist de Conclusão

Execute o script de validação:

```bash
# Executa o grade para avaliar atividades
./grade_exercicio2.sh
```

### Itens Verificados:

- ✅ Dados de teste criados com volume adequado
- ✅ Análise de planos de execução executada
- ✅ Índices simples, compostos e parciais criados
- ✅ Queries otimizadas com base em explain()
- ✅ Comparações de performance documentadas
- ✅ Monitoramento de uso de índices configurado

---

## 🧹 Limpeza

```javascript
// Dentro do mongosh
use performanceDB

// Remover índices criados (manter apenas _id)
db.products.dropIndexes()
db.orders.dropIndexes()

// Opcional: Remover collections de teste
db.products.drop()
db.orders.drop()
```

---

## 📊 Resumo de Otimizações Implementadas

### Melhorias de Performance Alcançadas:

1. **Queries de Range:** 85-95% de melhoria com índices apropriados
2. **Queries Compostas:** 70-90% de redução no tempo de execução
3. **Agregações com Lookup:** 60-80% de melhoria
4. **Queries de Texto:** 90-95% de melhoria com índices de texto

### Estratégias de Indexação Aplicadas:

- **Índices Simples:** Para queries de igualdade e range
- **Índices Compostos:** Para queries com múltiplos filtros
- **Índices Parciais:** Para reduzir tamanho e melhorar seletividade
- **Índices de Texto:** Para busca textual eficiente

---

[⬅️ Exercício 1](../exercicio1-metricas-avancadas/README.md) | [➡️ Exercício 3](../exercicio3-workload-optimization/README.md)