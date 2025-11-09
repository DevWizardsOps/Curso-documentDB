// Estratégias de caching para otimização de workloads de leitura

class CacheStrategy {
  constructor(ttl = 300000) { // 5 minutos por padrão
    this.cache = new Map();
    this.ttl = ttl;
    this.stats = {
      hits: 0,
      misses: 0,
      sets: 0,
      evictions: 0
    };
  }

  get(key) {
    const item = this.cache.get(key);
    
    if (!item) {
      this.stats.misses++;
      return null;
    }

    if (Date.now() - item.timestamp > this.ttl) {
      this.cache.delete(key);
      this.stats.evictions++;
      this.stats.misses++;
      return null;
    }

    this.stats.hits++;
    return item.value;
  }

  set(key, value) {
    this.cache.set(key, {
      value,
      timestamp: Date.now()
    });
    this.stats.sets++;
  }

  getHitRatio() {
    const total = this.stats.hits + this.stats.misses;
    return total > 0 ? (this.stats.hits / total) * 100 : 0;
  }

  clear() {
    this.cache.clear();
    this.stats.evictions += this.cache.size;
  }

  getStats() {
    return {
      ...this.stats,
      hitRatio: this.getHitRatio(),
      cacheSize: this.cache.size
    };
  }
}

// Cache Write-Through
class WriteThroughCache extends CacheStrategy {
  constructor(database, ttl) {
    super(ttl);
    this.database = database;
  }

  async get(key) {
    // Tentar cache primeiro
    let value = super.get(key);
    
    if (value === null) {
      // Cache miss - buscar no banco
      value = await this.database.findOne({ _id: key });
      if (value) {
        this.set(key, value);
      }
    }
    
    return value;
  }

  async set(key, value) {
    // Escrever no banco primeiro
    await this.database.updateOne(
      { _id: key },
      { $set: value },
      { upsert: true }
    );
    
    // Depois atualizar cache
    super.set(key, value);
  }
}

// Cache Write-Behind (Lazy Write)
class WriteBehindCache extends CacheStrategy {
  constructor(database, ttl, flushInterval = 60000) {
    super(ttl);
    this.database = database;
    this.dirtyKeys = new Set();
    this.flushInterval = flushInterval;
    
    // Iniciar flush periódico
    this.flushTimer = setInterval(() => {
      this.flush();
    }, this.flushInterval);
  }

  set(key, value) {
    super.set(key, value);
    this.dirtyKeys.add(key);
  }

  async flush() {
    if (this.dirtyKeys.size === 0) return;

    const keysToFlush = Array.from(this.dirtyKeys);
    this.dirtyKeys.clear();

    // Escrever em lote no banco
    const operations = keysToFlush.map(key => {
      const item = this.cache.get(key);
      if (item) {
        return {
          updateOne: {
            filter: { _id: key },
            update: { $set: item.value },
            upsert: true
          }
        };
      }
    }).filter(Boolean);

    if (operations.length > 0) {
      await this.database.bulkWrite(operations);
    }
  }

  destroy() {
    if (this.flushTimer) {
      clearInterval(this.flushTimer);
    }
  }
}

// Cache com invalidação inteligente
class SmartCache extends CacheStrategy {
  constructor(ttl) {
    super(ttl);
    this.dependencies = new Map(); // key -> [dependent_keys]
    this.reverseDeps = new Map();  // dependent_key -> [keys]
  }

  set(key, value, dependencies = []) {
    super.set(key, value);
    
    // Configurar dependências
    if (dependencies.length > 0) {
      this.dependencies.set(key, dependencies);
      
      dependencies.forEach(dep => {
        if (!this.reverseDeps.has(dep)) {
          this.reverseDeps.set(dep, []);
        }
        this.reverseDeps.get(dep).push(key);
      });
    }
  }

  invalidate(key) {
    // Remover do cache
    this.cache.delete(key);
    
    // Invalidar dependentes
    const dependents = this.reverseDeps.get(key) || [];
    dependents.forEach(dependent => {
      this.cache.delete(dependent);
    });
    
    // Limpar dependências
    this.dependencies.delete(key);
    this.reverseDeps.delete(key);
  }

  invalidatePattern(pattern) {
    const regex = new RegExp(pattern);
    const keysToInvalidate = [];
    
    for (const key of this.cache.keys()) {
      if (regex.test(key)) {
        keysToInvalidate.push(key);
      }
    }
    
    keysToInvalidate.forEach(key => this.invalidate(key));
  }
}

// Cache distribuído simulado (para múltiplas instâncias)
class DistributedCache extends CacheStrategy {
  constructor(ttl, nodeId = 'node1') {
    super(ttl);
    this.nodeId = nodeId;
    this.peers = new Map(); // Simular outros nós
  }

  addPeer(nodeId, peerCache) {
    this.peers.set(nodeId, peerCache);
  }

  async get(key) {
    // Tentar cache local primeiro
    let value = super.get(key);
    
    if (value === null) {
      // Tentar peers
      for (const [nodeId, peer] of this.peers) {
        value = peer.get(key);
        if (value !== null) {
          // Copiar para cache local
          this.set(key, value);
          break;
        }
      }
    }
    
    return value;
  }

  set(key, value) {
    super.set(key, value);
    
    // Replicar para peers (eventual consistency)
    setTimeout(() => {
      for (const [nodeId, peer] of this.peers) {
        peer.set(key, value);
      }
    }, 10); // Delay pequeno para simular rede
  }
}

module.exports = {
  CacheStrategy,
  WriteThroughCache,
  WriteBehindCache,
  SmartCache,
  DistributedCache
};