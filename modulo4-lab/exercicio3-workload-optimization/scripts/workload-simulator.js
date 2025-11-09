#!/usr/bin/env node

const { MongoClient } = require('mongodb');
const { Worker, isMainThread, parentPort, workerData } = require('worker_threads');

class WorkloadSimulator {
  constructor(config) {
    this.config = {
      scenario: 'mixed',
      duration: 300, // 5 minutes
      threads: 4,
      ...config
    };
    
    this.writeConnectionString = `mongodb://${process.env.DB_USERNAME}:${process.env.DB_PASSWORD}@${process.env.CLUSTER_ENDPOINT}:27017/performanceDB?ssl=true&retryWrites=false&readPreference=primary`;
    this.readConnectionString = `mongodb://${process.env.DB_USERNAME}:${process.env.DB_PASSWORD}@${process.env.READ_REPLICA_ENDPOINT || process.env.CLUSTER_ENDPOINT}:27017/performanceDB?ssl=true&retryWrites=false&readPreference=secondary`;
    
    this.metrics = {
      totalOperations: 0,
      readOperations: 0,
      writeOperations: 0,
      errors: 0,
      avgLatency: 0,
      startTime: null,
      endTime: null
    };
  }

  async start() {
    console.log(`Starting workload simulation: ${this.config.scenario}`);
    console.log(`Duration: ${this.config.duration}s, Threads: ${this.config.threads}`);
    
    this.metrics.startTime = Date.now();
    
    // Criar workers para simular carga
    const workers = [];
    for (let i = 0; i < this.config.threads; i++) {
      const worker = new Worker(__filename, {
        workerData: {
          workerId: i,
          scenario: this.config.scenario,
          duration: this.config.duration,
          writeConnectionString: this.writeConnectionString,
          readConnectionString: this.readConnectionString
        }
      });
      
      worker.on('message', (message) => {
        this.updateMetrics(message);
      });
      
      workers.push(worker);
    }

    // Aguardar conclusão de todos os workers
    await Promise.all(workers.map(worker => 
      new Promise(resolve => worker.on('exit', resolve))
    ));

    this.metrics.endTime = Date.now();
    this.printResults();
  }

  updateMetrics(workerMetrics) {
    this.metrics.totalOperations += workerMetrics.operations;
    this.metrics.readOperations += workerMetrics.reads;
    this.metrics.writeOperations += workerMetrics.writes;
    this.metrics.errors += workerMetrics.errors;
    
    // Calcular latência média ponderada
    const totalLatency = (this.metrics.avgLatency * (this.metrics.totalOperations - workerMetrics.operations)) + 
                        (workerMetrics.avgLatency * workerMetrics.operations);
    this.metrics.avgLatency = totalLatency / this.metrics.totalOperations;
  }

  printResults() {
    const duration = (this.metrics.endTime - this.metrics.startTime) / 1000;
    const throughput = this.metrics.totalOperations / duration;
    
    console.log('\n=== WORKLOAD SIMULATION RESULTS ===');
    console.log(`Scenario: ${this.config.scenario}`);
    console.log(`Duration: ${duration.toFixed(2)}s`);
    console.log(`Total Operations: ${this.metrics.totalOperations}`);
    console.log(`Read Operations: ${this.metrics.readOperations} (${(this.metrics.readOperations/this.metrics.totalOperations*100).toFixed(1)}%)`);
    console.log(`Write Operations: ${this.metrics.writeOperations} (${(this.metrics.writeOperations/this.metrics.totalOperations*100).toFixed(1)}%)`);
    console.log(`Errors: ${this.metrics.errors}`);
    console.log(`Throughput: ${throughput.toFixed(2)} ops/sec`);
    console.log(`Average Latency: ${this.metrics.avgLatency.toFixed(2)}ms`);
    console.log(`Success Rate: ${((this.metrics.totalOperations - this.metrics.errors) / this.metrics.totalOperations * 100).toFixed(2)}%`);
  }
}

// Worker thread code
if (!isMainThread) {
  const { workerId, scenario, duration, writeConnectionString, readConnectionString } = workerData;
  
  class WorkerThread {
    constructor() {
      this.writeClient = null;
      this.readClient = null;
      this.metrics = {
        operations: 0,
        reads: 0,
        writes: 0,
        errors: 0,
        totalLatency: 0,
        avgLatency: 0
      };
    }

    async connect() {
      this.writeClient = new MongoClient(writeConnectionString, {
        maxPoolSize: 10,
        minPoolSize: 2
      });
      
      this.readClient = new MongoClient(readConnectionString, {
        maxPoolSize: 10,
        minPoolSize: 2
      });

      await Promise.all([
        this.writeClient.connect(),
        this.readClient.connect()
      ]);
    }

    async runWorkload() {
      const endTime = Date.now() + (duration * 1000);
      
      while (Date.now() < endTime) {
        try {
          const operation = this.selectOperation(scenario);
          const latency = await this.executeOperation(operation);
          
          this.metrics.operations++;
          this.metrics.totalLatency += latency;
          this.metrics.avgLatency = this.metrics.totalLatency / this.metrics.operations;
          
          if (operation.type === 'read') {
            this.metrics.reads++;
          } else {
            this.metrics.writes++;
          }
          
          // Pequeno delay para simular aplicação real
          await this.sleep(Math.random() * 10);
          
        } catch (error) {
          this.metrics.errors++;
        }
      }

      // Enviar métricas para o thread principal
      parentPort.postMessage(this.metrics);
    }

    selectOperation(scenario) {
      const scenarios = {
        'read-heavy': { readRatio: 0.8 },
        'write-heavy': { readRatio: 0.2 },
        'mixed': { readRatio: 0.5 },
        'analytics': { readRatio: 0.9 }
      };

      const config = scenarios[scenario] || scenarios.mixed;
      const isRead = Math.random() < config.readRatio;

      if (isRead) {
        return this.getRandomReadOperation();
      } else {
        return this.getRandomWriteOperation();
      }
    }

    getRandomReadOperation() {
      const operations = [
        {
          type: 'read',
          name: 'findOne',
          execute: () => this.readClient.db('performanceDB').collection('products').findOne({category: 'electronics'})
        },
        {
          type: 'read',
          name: 'find',
          execute: () => this.readClient.db('performanceDB').collection('products').find({price: {$gte: 100}}).limit(10).toArray()
        },
        {
          type: 'read',
          name: 'aggregate',
          execute: () => this.readClient.db('performanceDB').collection('products').aggregate([
            {$match: {category: 'electronics'}},
            {$group: {_id: '$brand', count: {$sum: 1}}}
          ]).toArray()
        }
      ];

      return operations[Math.floor(Math.random() * operations.length)];
    }

    getRandomWriteOperation() {
      const operations = [
        {
          type: 'write',
          name: 'insertOne',
          execute: () => this.writeClient.db('performanceDB').collection('test_data').insertOne({
            timestamp: new Date(),
            value: Math.random() * 1000,
            workerId: workerId
          })
        },
        {
          type: 'write',
          name: 'updateOne',
          execute: () => this.writeClient.db('performanceDB').collection('products').updateOne(
            {_id: Math.floor(Math.random() * 1000) + 1},
            {$set: {lastAccessed: new Date()}}
          )
        },
        {
          type: 'write',
          name: 'deleteOne',
          execute: () => this.writeClient.db('performanceDB').collection('test_data').deleteOne({
            workerId: workerId,
            timestamp: {$lt: new Date(Date.now() - 60000)} // Delete dados > 1min
          })
        }
      ];

      return operations[Math.floor(Math.random() * operations.length)];
    }

    async executeOperation(operation) {
      const start = Date.now();
      await operation.execute();
      return Date.now() - start;
    }

    sleep(ms) {
      return new Promise(resolve => setTimeout(resolve, ms));
    }

    async disconnect() {
      await Promise.all([
        this.writeClient?.close(),
        this.readClient?.close()
      ]);
    }
  }

  // Executar worker
  async function runWorker() {
    const worker = new WorkerThread();
    try {
      await worker.connect();
      await worker.runWorkload();
    } finally {
      await worker.disconnect();
    }
  }

  runWorker().catch(console.error);
}

// CLI interface
if (isMainThread && require.main === module) {
  const args = process.argv.slice(2);
  
  const config = {
    scenario: args[args.indexOf('--scenario') + 1] || 'mixed',
    duration: parseInt(args[args.indexOf('--duration') + 1]) || 300,
    threads: parseInt(args[args.indexOf('--threads') + 1]) || 4
  };

  const simulator = new WorkloadSimulator(config);
  simulator.start().catch(console.error);
}

module.exports = WorkloadSimulator;