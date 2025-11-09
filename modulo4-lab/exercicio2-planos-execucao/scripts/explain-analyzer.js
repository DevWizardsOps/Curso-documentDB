#!/usr/bin/env node

const { MongoClient } = require('mongodb');

class ExplainAnalyzer {
  constructor(connectionString) {
    this.connectionString = connectionString;
    this.client = null;
  }

  async connect() {
    this.client = new MongoClient(this.connectionString, {
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 5000
    });
    await this.client.connect();
    console.log('Connected to DocumentDB for explain analysis');
  }

  async analyzeQuery(collection, query, options = {}) {
    const db = this.client.db('performanceDB');
    const coll = db.collection(collection);

    console.log(`\nAnalyzing query on ${collection}:`);
    console.log('Query:', JSON.stringify(query, null, 2));

    // Executar explain com diferentes níveis
    const explainResults = {
      queryPlanner: await coll.find(query).explain('queryPlanner'),
      executionStats: await coll.find(query).explain('executionStats'),
      allPlansExecution: await coll.find(query).explain('allPlansExecution')
    };

    return this.analyzeExplainResults(explainResults);
  }

  analyzeExplainResults(results) {
    const analysis = {
      performance: 'UNKNOWN',
      issues: [],
      recommendations: [],
      stats: {}
    };

    const execStats = results.executionStats.executionStats;
    
    // Extrair estatísticas importantes
    analysis.stats = {
      executionTimeMs: execStats.executionTimeMillis,
      totalDocsExamined: execStats.totalDocsExamined,
      totalDocsReturned: execStats.totalDocsReturned,
      stage: execStats.stage,
      indexesUsed: this.extractIndexesUsed(results.queryPlanner)
    };

    // Analisar performance
    if (execStats.stage === 'COLLSCAN') {
      analysis.performance = 'POOR';
      analysis.issues.push('Collection scan detected - no suitable index found');
      analysis.recommendations.push('Create appropriate index for the query filter');
    } else if (execStats.stage === 'IXSCAN') {
      const efficiency = execStats.totalDocsReturned / execStats.totalDocsExamined;
      if (efficiency > 0.1) {
        analysis.performance = 'GOOD';
      } else {
        analysis.performance = 'FAIR';
        analysis.issues.push('Low index selectivity - examining many documents');
        analysis.recommendations.push('Consider more selective index or compound index');
      }
    }

    // Verificar tempo de execução
    if (execStats.executionTimeMillis > 100) {
      analysis.issues.push(`High execution time: ${execStats.executionTimeMillis}ms`);
      analysis.recommendations.push('Optimize query or add better indexes');
    }

    // Verificar rejected plans
    if (results.queryPlanner.rejectedPlans && results.queryPlanner.rejectedPlans.length > 0) {
      analysis.issues.push(`${results.queryPlanner.rejectedPlans.length} alternative plans were rejected`);
      analysis.recommendations.push('Review index strategy - multiple competing indexes detected');
    }

    this.printAnalysis(analysis);
    return analysis;
  }

  extractIndexesUsed(queryPlanner) {
    const indexes = [];
    
    function extractFromStage(stage) {
      if (stage.indexName) {
        indexes.push(stage.indexName);
      }
      if (stage.inputStage) {
        extractFromStage(stage.inputStage);
      }
      if (stage.inputStages) {
        stage.inputStages.forEach(extractFromStage);
      }
    }

    if (queryPlanner.winningPlan) {
      extractFromStage(queryPlanner.winningPlan);
    }

    return indexes;
  }

  printAnalysis(analysis) {
    console.log('\n=== QUERY ANALYSIS RESULTS ===');
    console.log(`Performance: ${analysis.performance}`);
    console.log(`Execution Time: ${analysis.stats.executionTimeMs}ms`);
    console.log(`Documents Examined: ${analysis.stats.totalDocsExamined}`);
    console.log(`Documents Returned: ${analysis.stats.totalDocsReturned}`);
    console.log(`Stage: ${analysis.stats.stage}`);
    console.log(`Indexes Used: ${analysis.stats.indexesUsed.join(', ') || 'None'}`);

    if (analysis.issues.length > 0) {
      console.log('\nISSUES FOUND:');
      analysis.issues.forEach((issue, i) => {
        console.log(`${i + 1}. ${issue}`);
      });
    }

    if (analysis.recommendations.length > 0) {
      console.log('\nRECOMMENDATIONS:');
      analysis.recommendations.forEach((rec, i) => {
        console.log(`${i + 1}. ${rec}`);
      });
    }
  }

  async runCommonQueryAnalysis() {
    console.log('Running analysis on common query patterns...');

    const testQueries = [
      {
        collection: 'products',
        query: { category: 'electronics' },
        description: 'Simple equality query'
      },
      {
        collection: 'products',
        query: { price: { $gte: 100, $lte: 500 } },
        description: 'Range query'
      },
      {
        collection: 'products',
        query: { category: 'electronics', price: { $gte: 100 } },
        description: 'Compound query'
      },
      {
        collection: 'products',
        query: { name: /^Product/ },
        description: 'Regex query'
      }
    ];

    const results = [];
    for (const testQuery of testQueries) {
      console.log(`\n--- ${testQuery.description} ---`);
      const result = await this.analyzeQuery(testQuery.collection, testQuery.query);
      results.push({
        ...testQuery,
        analysis: result
      });
    }

    return results;
  }

  async disconnect() {
    if (this.client) {
      await this.client.close();
    }
  }
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);
  const connectionString = `mongodb://${process.env.DB_USERNAME}:${process.env.DB_PASSWORD}@${process.env.CLUSTER_ENDPOINT}:27017/performanceDB?ssl=true&retryWrites=false`;
  
  const analyzer = new ExplainAnalyzer(connectionString);
  
  try {
    await analyzer.connect();
    
    if (args.includes('--analyze-all')) {
      await analyzer.runCommonQueryAnalysis();
    } else {
      // Análise de query específica via argumentos
      const collection = args[args.indexOf('--collection') + 1] || 'products';
      const query = { category: 'electronics' }; // Query padrão
      
      await analyzer.analyzeQuery(collection, query);
    }
  } finally {
    await analyzer.disconnect();
  }
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = ExplainAnalyzer;