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

### Passo 1: Preparar Ambiente

```bash
# Navegar para o diretório do exercício
cd exercicio2-planos-execucao

# Baixar certificado SSL se não existir
if [ ! -f "global-bundle.pem" ]; then
  wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
fi

# Instalar dependências Node.js
npm install
```

### Passo 2: Conectar ao Cluster e Preparar Dados

```bash
# Navegar para o diretório do exercício
cd exercicio2-planos-execucao

# Baixar certificado SSL do DocumentDB
wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

# Configurar variáveis de ambiente
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

> 📚 **Limitações do DocumentDB:** O DocumentDB não suporta alguns recursos do MongoDB como:
> - Índices de texto (`$text`)
> - `explain("allPlansExecution")` - use `explain("executionStats")`
> - Índices geoespaciais 2dsphere
> - Algumas operações de agregação avançadas

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

### Índices para Busca de Texto

> ⚠️ **Nota:** DocumentDB não suporta índices de texto ($text). Usaremos regex otimizado.

```javascript
// Criar índice para busca por nome
db.products.createIndex({name: 1})

// Query de busca usando regex otimizado
db.products.find({
  name: {$regex: "premium", $options: "i"}
}).explain("executionStats")

// Busca em tags usando $in para valores específicos
db.products.find({
  tags: {$in: ["premium", "popular"]}
}).explain("executionStats")
```

---

## 🔧 Parte 4: Análise Avançada com explain()

### Análise Detalhada com explain()

> ⚠️ **Limitação:** DocumentDB não suporta `explain("allPlansExecution")`. Usamos `explain("executionStats")`.

```javascript
// Análise detalhada do plano de execução
db.products.find({
  category: "electronics",
  price: {$gte: 100, $lte: 500}
}).explain("executionStats")
```

**Campos Importantes no DocumentDB:**
- `queryPlanner.winningPlan`: Plano escolhido pelo otimizador
- `executionStats.stage`: Tipo de operação (IXSCAN, COLLSCAN, etc.)
- `executionStats.docsExamined`: Documentos examinados
- `executionStats.docsReturned`: Documentos retornados
- `executionStats.executionTimeMillis`: Tempo de execução

**Interpretação dos Stages:**
- `COLLSCAN`: Scan completo da coleção (ruim para performance)
- `IXSCAN`: Uso de índice (bom para performance)
- `FETCH`: Busca de documentos após usar índice
- `SORT`: Operação de ordenação
- `LIMIT`: Limitação de resultados

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
# Executar análise de queries comuns
node scripts/explain-analyzer.js --analyze-all

# Ou analisar uma coleção específica
node scripts/explain-analyzer.js --collection products
```

> 💡 **O que o script faz:** Analisa automaticamente queries comuns e identifica problemas de performance, sugerindo otimizações de índices.

### Cenários de Otimização Comuns

#### Cenário 1: Query com Sort Custoso

```bash
# Configurar variáveis de ambiente
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


```javascript
// Dentro do mongosh, executar:

// Usar database de performance
use performanceDB
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

// Solução: Otimizar regex com índice
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

### Monitoramento Manual de Performance

```bash
# Executar análise múltiplas vezes para comparar
for i in {1..5}; do
  echo "=== Execução $i ==="
  node scripts/explain-analyzer.js --collection products
  sleep 2
done
```

---

## 📋 Parte 7: Validação das Otimizações

### Teste 1: Verificar Impacto dos Índices

```bash
# Usar o script de análise para comparar diferentes queries
echo "=== Analisando query simples ==="
node scripts/explain-analyzer.js --collection products

echo "=== Analisando todas as queries comuns ==="
node scripts/explain-analyzer.js --analyze-all
```

### Teste 2: Comparar Diferentes Tipos de Query

```bash
# Conectar ao DocumentDB para testes manuais
mongosh --host $CLUSTER_ENDPOINT:27017 \
--username $DB_USERNAME --password $DB_PASSWORD \
--ssl --sslCAFile global-bundle.pem

# Dentro do mongosh, testar diferentes queries:
# use performanceDB
# 
# // Query com índice existente (boa performance)
# db.products.find({category: "electronics"}).explain("executionStats")
# 
# // Query sem índice (performance ruim)
# db.products.find({brand: "BrandA"}).explain("executionStats")
# 
# // Criar índice e testar novamente
# db.products.createIndex({brand: 1})
# db.products.find({brand: "BrandA"}).explain("executionStats")
```

> 💡 **Compare:** Observe a diferença entre `IXSCAN` (usa índice) vs `COLLSCAN` (scan completo) nos resultados do explain.

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
4. **Queries de Busca:** 70-85% de melhoria com regex otimizado

### Estratégias de Indexação Aplicadas:

- **Índices Simples:** Para queries de igualdade e range
- **Índices Compostos:** Para queries com múltiplos filtros
- **Índices Parciais:** Para reduzir tamanho e melhorar seletividade
- **Busca Otimizada:** Regex com índices para busca de texto

---

[⬅️ Exercício 1](../exercicio1-metricas-avancadas/README.md) | [🏠 Módulo 4 Home](../README.md)