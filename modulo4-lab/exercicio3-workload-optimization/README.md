# Exercício 3: Estratégias para Workloads de Leitura e Escrita

## 🎯 Objetivos

- Configurar read replicas para otimizar workloads de leitura
- Implementar estratégias de caching e distribuição de carga
- Otimizar operações de escrita em lote (bulk operations)
- Balancear consistência e performance em diferentes cenários

## ⏱️ Duração Estimada
90 minutos

> ⚠️ **Atenção:** Lembre-se de usar seu prefixo de aluno (`<seu-id>`) em todos os nomes de recursos e comandos.

---

## 📖 Parte 1: Configuração de Read Replicas

### Passo 1: Criar Read Replica

```bash
# Configurar variáveis
export ID="<seu-id>"
export CLUSTER_ID="$ID-lab-cluster-console"

# Criar read replica
aws docdb create-db-instance \
--db-instance-identifier $ID-read-replica-1 \
--db-instance-class db.t3.medium \
--engine docdb \
--db-cluster-identifier $CLUSTER_ID \
--promotion-tier 1

# Aguardar criação da replica
aws docdb wait db-instance-available \
--db-instance-identifier $ID-read-replica-1

# Obter endpoint da read replica
READ_REPLICA_ENDPOINT=$(aws docdb describe-db-instances \
--db-instance-identifier $ID-read-replica-1 \
--query 'DBInstances[0].Endpoint.Address' \
--output text)

echo "Read Replica Endpoint: $READ_REPLICA_ENDPOINT"
```

### Passo 2: Configurar Connection Strings

```javascript
// Configuração de conexões separadas para leitura e escrita
const { MongoClient } = require('mongodb');

// Connection string para escritas (primary)
const writeConnectionString = `mongodb://${process.env.DB_USERNAME}:${process.env.DB_PASSWORD}@${process.env.CLUSTER_ENDPOINT}:27017/performanceDB?ssl=true&replicaSet=rs0&readPreference=primary`;

// Connection string para leituras (read replica)
const readConnectionString = `mongodb://${process.env.DB_USERNAME}:${process.env.DB_PASSWORD}@${process.env.READ_REPLICA_ENDPOINT}:27017/performanceDB?ssl=true&replicaSet=rs0&readPreference=secondary`;

// Clientes separados
const writeClient = new MongoClient(writeConnectionString);
const readClient = new MongoClient(readConnectionString);
```

---

## 🔄 Parte 2: Implementação de Estratégias de Caching

### Passo 1: Cache em Memória com Redis (Simulado)

```javascript
// Simulação de cache em memória para o laboratório
class MemoryCache {
  constructor(ttl = 300000) { // 5 minutos TTL
    this.cache = new Map();
    this.ttl = ttl;
  }

  set(key, value) {
    this.cache.set(key, {
      value,
      timestamp: Date.now()
    });
  }

  get(key) {
    const item = this.cache.get(key);
    if (!item) return null;
    
    if (Date.now() - item.timestamp > this.ttl) {
      this.cache.delete(key);
      return null;
    }
    
    return item.value;
  }

  clear() {
    this.cache.clear();
  }
}

// Implementação de cache para queries frequentes
class CachedProductService {
  constructor(readClient, writeClient) {
    this.readClient = readClient;
    this.writeClient = writeClient;
    this.cache = new MemoryCache();
  }

  async getProductsByCategory(category) {
    const cacheKey = `products:category:${category}`;
    let products = this.cache.get(cacheKey);
    
    if (!products) {
      console.log(`Cache miss for category: ${category}`);
      const db = this.readClient.db('performanceDB');
      products = await db.collection('products')
        .find({category})
        .toArray();
      
      this.cache.set(cacheKey, products);
    } else {
      console.log(`Cache hit for category: ${category}`);
    }
    
    return products;
  }

  async updateProduct(productId, updates) {
    const db = this.writeClient.db('performanceDB');
    const result = await db.collection('products')
      .updateOne({_id: productId}, {$set: updates});
    
    // Invalidar cache relacionado
    this.cache.clear(); // Estratégia simples - invalidar tudo
    
    return result;
  }
}
```

### Passo 2: Estratégia de Cache Write-Through

```javascript
class WriteThoughCache {
  constructor(readClient, writeClient) {
    this.readClient = readClient;
    this.writeClient = writeClient;
    this.cache = new MemoryCache();
  }

  async createProduct(product) {
    // Escrever no banco primeiro
    const db = this.writeClient.db('performanceDB');
    const result = await db.collection('products').insertOne(product);
    
    // Atualizar cache
    const cacheKey = `product:${result.insertedId}`;
    this.cache.set(cacheKey, {...product, _id: result.insertedId});
    
    return result;
  }

  async getProduct(productId) {
    const cacheKey = `product:${productId}`;
    let product = this.cache.get(cacheKey);
    
    if (!product) {
      const db = this.readClient.db('performanceDB');
      product = await db.collection('products').findOne({_id: productId});
      if (product) {
        this.cache.set(cacheKey, product);
      }
    }
    
    return product;
  }
}
```

---

## ✍️ Parte 3: Otimização de Workloads de Escrita

### Passo 1: Bulk Operations Otimizadas

```javascript
class BulkWriteOptimizer {
  constructor(writeClient) {
    this.writeClient = writeClient;
    this.batchSize = 1000; // Tamanho otimizado do lote
  }

  async bulkInsertProducts(products) {
    const db = this.writeClient.db('performanceDB');
    const collection = db.collection('products');
    
    const results = [];
    
    // Processar em lotes para evitar timeout
    for (let i = 0; i < products.length; i += this.batchSize) {
      const batch = products.slice(i, i + this.batchSize);
      
      console.log(`Inserting batch ${Math.floor(i/this.batchSize) + 1}/${Math.ceil(products.length/this.batchSize)}`);
      
      const result = await collection.insertMany(batch, {
        ordered: false, // Permite inserções paralelas
        writeConcern: { w: 1, j: false } // Otimizado para performance
      });
      
      results.push(result);
    }
    
    return results;
  }

  async bulkUpdateProducts(updates) {
    const db = this.writeClient.db('performanceDB');
    const collection = db.collection('products');
    
    // Usar bulkWrite para operações mistas
    const operations = updates.map(update => ({
      updateOne: {
        filter: { _id: update._id },
        update: { $set: update.changes },
        upsert: false
      }
    }));

    // Processar em lotes
    const results = [];
    for (let i = 0; i < operations.length; i += this.batchSize) {
      const batch = operations.slice(i, i + this.batchSize);
      
      const result = await collection.bulkWrite(batch, {
        ordered: false,
        writeConcern: { w: 1, j: false }
      });
      
      results.push(result);
    }
    
    return results;
  }
}
```

### Passo 2: Write Concern Otimizado

```javascript
// Diferentes estratégias de write concern baseadas no caso de uso
class WriteStrategyManager {
  constructor(writeClient) {
    this.writeClient = writeClient;
  }

  // Para dados críticos - máxima durabilidade
  async criticalWrite(collection, document) {
    const db = this.writeClient.db('performanceDB');
    return await db.collection(collection).insertOne(document, {
      writeConcern: { 
        w: 'majority', 
        j: true,        // Journal sync
        wtimeout: 5000  // Timeout de 5s
      }
    });
  }

  // Para dados de alta frequência - performance otimizada
  async highFrequencyWrite(collection, document) {
    const db = this.writeClient.db('performanceDB');
    return await db.collection(collection).insertOne(document, {
      writeConcern: { 
        w: 1,           // Apenas primary
        j: false,       // Sem journal sync
        wtimeout: 1000  // Timeout de 1s
      }
    });
  }

  // Para logs e analytics - fire-and-forget
  async analyticsWrite(collection, document) {
    const db = this.writeClient.db('performanceDB');
    return await db.collection(collection).insertOne(document, {
      writeConcern: { 
        w: 0            // Sem confirmação
      }
    });
  }
}
```

---

## 📊 Parte 4: Balanceamento de Carga de Leitura

### Passo 1: Load Balancer de Conexões

```javascript
class ReadLoadBalancer {
  constructor(endpoints) {
    this.endpoints = endpoints;
    this.currentIndex = 0;
    this.clients = new Map();
    
    // Inicializar clientes para cada endpoint
    endpoints.forEach(endpoint => {
      const connectionString = `mongodb://${process.env.DB_USERNAME}:${process.env.DB_PASSWORD}@${endpoint}:27017/performanceDB?ssl=true&readPreference=secondary`;
      this.clients.set(endpoint, new MongoClient(connectionString));
    });
  }

  // Round-robin simples
  getNextClient() {
    const endpoint = this.endpoints[this.currentIndex];
    this.currentIndex = (this.currentIndex + 1) % this.endpoints.length;
    return this.clients.get(endpoint);
  }

  // Seleção baseada em latência (simulada)
  async getOptimalClient() {
    const latencies = await Promise.all(
      this.endpoints.map(async endpoint => {
        const start = Date.now();
        try {
          const client = this.clients.get(endpoint);
          await client.db('performanceDB').admin().ping();
          return { endpoint, latency: Date.now() - start };
        } catch (error) {
          return { endpoint, latency: Infinity };
        }
      })
    );

    const optimal = latencies.reduce((min, current) => 
      current.latency < min.latency ? current : min
    );

    return this.clients.get(optimal.endpoint);
  }
}
```

### Passo 2: Implementação de Read Preferences

```javascript
class ReadPreferenceManager {
  constructor(clients) {
    this.clients = clients;
  }

  // Leitura de dados críticos - sempre do primary
  async readCritical(collection, query) {
    const client = this.clients.primary;
    return await client.db('performanceDB')
      .collection(collection)
      .find(query)
      .readPref('primary')
      .toArray();
  }

  // Leitura de relatórios - pode ser de secondary
  async readReports(collection, query) {
    const client = this.clients.secondary;
    return await client.db('performanceDB')
      .collection(collection)
      .find(query)
      .readPref('secondary')
      .toArray();
  }

  // Leitura com fallback - tenta secondary, fallback para primary
  async readWithFallback(collection, query) {
    try {
      const client = this.clients.secondary;
      return await client.db('performanceDB')
        .collection(collection)
        .find(query)
        .readPref('secondaryPreferred')
        .toArray();
    } catch (error) {
      console.log('Fallback to primary due to:', error.message);
      const client = this.clients.primary;
      return await client.db('performanceDB')
        .collection(collection)
        .find(query)
        .readPref('primary')
        .toArray();
    }
  }
}
```

---

## 🧪 Parte 5: Testes de Performance de Workloads

### Passo 1: Simulador de Workload Misto

```bash
# Executar simulador de workload
node scripts/workload-simulator.js --scenario mixed --duration 300 --threads 10

# Cenários disponíveis:
# - read-heavy: 80% leitura, 20% escrita
# - write-heavy: 20% leitura, 80% escrita
# - mixed: 50% leitura, 50% escrita
# - analytics: Queries complexas de agregação
```

### Passo 2: Teste de Performance Comparativo

```javascript
// Teste de performance read replica vs primary
async function compareReadPerformance() {
  const iterations = 1000;
  const query = { category: 'electronics', price: { $gte: 100 } };

  // Teste no primary
  console.log('Testing primary reads...');
  const primaryStart = Date.now();
  for (let i = 0; i < iterations; i++) {
    await primaryClient.db('performanceDB')
      .collection('products')
      .find(query)
      .toArray();
  }
  const primaryTime = Date.now() - primaryStart;

  // Teste na read replica
  console.log('Testing read replica...');
  const replicaStart = Date.now();
  for (let i = 0; i < iterations; i++) {
    await readClient.db('performanceDB')
      .collection('products')
      .find(query)
      .toArray();
  }
  const replicaTime = Date.now() - replicaStart;

  console.log(`Primary: ${primaryTime}ms (${primaryTime/iterations}ms per query)`);
  console.log(`Replica: ${replicaTime}ms (${replicaTime/iterations}ms per query)`);
  console.log(`Improvement: ${((primaryTime - replicaTime) / primaryTime * 100).toFixed(2)}%`);
}
```

---

## 📈 Parte 6: Monitoramento de Workloads

### Passo 1: Métricas de Workload

```bash
# Executar script de monitoramento de workload
node scripts/workload-monitor.js --interval 30 --metrics all

# Métricas coletadas:
# - Read/Write ratio
# - Average query time por tipo
# - Connection pool utilization
# - Cache hit ratio
# - Replica lag
```

### Passo 2: Dashboard de Workload Performance

```bash
# Criar dashboard específico para workloads
aws cloudwatch put-dashboard \
--dashboard-name $ID-Workload-Performance \
--dashboard-body file://cloudwatch/workload-dashboard.json
```

---

## ✅ Checklist de Conclusão

Execute o script de validação:

```bash
# Executa o grade para avaliar atividades
./grade_exercicio3.sh
```

### Itens Verificados:

- ✅ Read replica criada e configurada
- ✅ Estratégias de caching implementadas
- ✅ Bulk operations otimizadas
- ✅ Load balancing de leituras configurado
- ✅ Write concerns otimizados por caso de uso
- ✅ Testes de performance executados
- ✅ Monitoramento de workloads ativo

---

## 🧹 Limpeza

```bash
# Deletar read replica
aws docdb delete-db-instance \
--db-instance-identifier $ID-read-replica-1 \
--skip-final-snapshot

# Parar simuladores de workload
pkill -f "workload-simulator\|workload-monitor"

# Deletar dashboard
aws cloudwatch delete-dashboards \
--dashboard-names $ID-Workload-Performance
```

---

## 📊 Resultados Esperados

### Melhorias de Performance:

1. **Read Workloads:**
   - 40-60% de redução na latência com read replicas
   - 70-90% de melhoria com cache efetivo
   - Distribuição de carga entre instâncias

2. **Write Workloads:**
   - 80-95% de melhoria com bulk operations
   - 20-40% de ganho com write concerns otimizados
   - Redução de contenção de recursos

3. **Mixed Workloads:**
   - Separação efetiva de cargas de leitura/escrita
   - Melhor utilização de recursos
   - Maior throughput geral

### Estratégias Implementadas:

- **Read Scaling:** Read replicas + load balancing
- **Write Optimization:** Bulk operations + write concerns
- **Caching:** Memory cache + invalidation strategies
- **Connection Management:** Pool optimization + read preferences

---

[⬅️ Exercício 2](../exercicio2-planos-execucao/README.md) | [➡️ Exercício 4](../exercicio4-conexoes-latencia/README.md)