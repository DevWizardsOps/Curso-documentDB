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
      serverSelectionTimeoutMS: 10000,
      tls: true,
      tlsCAFile: 'global-bundle.pem'
    });
    await this.client.connect();
    console.log('Connected to DocumentDB for explain analysis');
  }

  async analyzeQuery(collection, query, options = {}) {
    const db = this.client.db('performanceDB');
    const coll = db.collection(collection);

    console.log(`\nAnalyzing query on ${collection}:`);
    console.log('Query:', JSON.stringify(query, null, 2));

    // Verificar se a coleção tem dados
    const count = await coll.countDocuments();
    console.log(`Collection ${collection} has ${count} documents`);

    if (count === 0) {
      console.log('⚠️  Collection is empty - create test data first');
      return {
        performance: 'NO_DATA',
        issues: ['Collection is empty'],
        recommendations: ['Create test data using the README instructions'],
        stats: {}
      };
    }

    // Executar explain com níveis suportados pelo DocumentDB
    const explainResults = {
      queryPlanner: await coll.find(query).explain('queryPlanner'),
      executionStats: await coll.find(query).explain('executionStats')
    };

    // Debug: mostrar estrutura do explain
    if (options.debug) {
      console.log('DEBUG - Explain structure:');
      console.log(JSON.stringify(explainResults.executionStats, null, 2));
    }

    return this.analyzeExplainResults(explainResults);
  }

  analyzeExplainResults(results) {
    const analysis = {
      performance: 'UNKNOWN',
      issues: [],
      recommendations: [],
      stats: {}
    };

    // DocumentDB tem estrutura aninhada - corrigindo baseado no debug
    const execStatsOuter = results.executionStats;
    const execStats = execStatsOuter?.executionStats || {};
    const execStages = execStats?.executionStages || {};
    const queryPlannerOuter = results.queryPlanner;
    const queryPlanner = queryPlannerOuter?.queryPlanner || {};

    // Extrair estatísticas importantes do DocumentDB
    analysis.stats = {
      executionTimeMs: parseFloat(execStats?.executionTimeMillis) || 0,
      totalDocsExamined: parseInt(execStages?.docsExamined) || parseInt(execStages?.nReturned) || 0,
      totalDocsReturned: parseInt(execStages?.nReturned) || 0,
      stage: execStages?.stage || queryPlanner?.winningPlan?.stage || 'UNKNOWN',
      indexesUsed: this.extractIndexesUsed(queryPlanner)
    };

    // Analisar performance
    const stage = analysis.stats.stage;
    const docsExamined = analysis.stats.totalDocsExamined;
    const docsReturned = analysis.stats.totalDocsReturned;
    const indexesUsed = analysis.stats.indexesUsed;

    if (stage === 'COLLSCAN') {
      analysis.performance = 'POOR';
      analysis.issues.push('Collection scan detected - no suitable index found');
      analysis.recommendations.push('Create appropriate index for the query filter');
    } else if (stage === 'IXSCAN') {
      analysis.performance = 'GOOD';
      if (indexesUsed.length > 0) {
        analysis.issues.push(`Using index: ${indexesUsed.join(', ')}`);
      }

      // Verificar eficiência se temos dados de documentos examinados
      if (docsExamined > 0 && docsReturned > 0) {
        const efficiency = docsReturned / docsExamined;
        if (efficiency < 0.1) {
          analysis.performance = 'FAIR';
          analysis.issues.push(`Low selectivity: examined ${docsExamined}, returned ${docsReturned}`);
          analysis.recommendations.push('Consider more selective index or compound index');
        }
      }
    } else if (stage === 'FETCH') {
      analysis.performance = 'GOOD';
      analysis.issues.push('Using index with document fetch');
    } else {
      analysis.performance = 'UNKNOWN';
      analysis.issues.push(`Unknown stage: ${stage}`);
      analysis.recommendations.push('Review query execution plan');
    }

    // Verificar tempo de execução
    const execTime = analysis.stats.executionTimeMs;
    if (execTime > 100) {
      analysis.issues.push(`High execution time: ${execTime}ms`);
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
  const connectionString = `mongodb://${process.env.DB_USERNAME}:${process.env.DB_PASSWORD}@${process.env.CLUSTER_ENDPOINT}:27017/performanceDB?ssl=true&retryWrites=false&authMechanism=SCRAM-SHA-1`;

  const analyzer = new ExplainAnalyzer(connectionString);

  try {
    await analyzer.connect();

    if (args.includes('--analyze-all')) {
      await analyzer.runCommonQueryAnalysis();
    } else {
      // Análise de query específica via argumentos
      const collection = args[args.indexOf('--collection') + 1] || 'products';
      const query = { category: 'electronics' }; // Query padrão
      const debug = args.includes('--debug');

      await analyzer.analyzeQuery(collection, query, { debug });
    }
  } finally {
    await analyzer.disconnect();
  }
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = ExplainAnalyzer;