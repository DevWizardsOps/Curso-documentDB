// Configurações otimizadas de connection pools para diferentes cenários

const poolConfigurations = {
  // Configuração para aplicações web (alta concorrência)
  webApplication: {
    maxPoolSize: 100,
    minPoolSize: 10,
    maxIdleTimeMS: 30000,
    waitQueueTimeoutMS: 5000,
    serverSelectionTimeoutMS: 5000,
    socketTimeoutMS: 45000,
    keepAlive: true,
    keepAliveInitialDelay: 120000,
    compression: 'snappy'
  },

  // Configuração para batch jobs (processamento em lote)
  batchProcessing: {
    maxPoolSize: 20,
    minPoolSize: 5,
    maxIdleTimeMS: 300000,
    waitQueueTimeoutMS: 30000,
    serverSelectionTimeoutMS: 10000,
    socketTimeoutMS: 300000,
    keepAlive: true,
    keepAliveInitialDelay: 300000,
    compression: 'zlib'
  },

  // Configuração para analytics (queries longas)
  analytics: {
    maxPoolSize: 10,
    minPoolSize: 2,
    maxIdleTimeMS: 600000,
    waitQueueTimeoutMS: 60000,
    serverSelectionTimeoutMS: 15000,
    socketTimeoutMS: 1800000,
    keepAlive: true,
    keepAliveInitialDelay: 600000,
    readPreference: 'secondary',
    compression: 'zlib'
  },

  // Configuração para aplicações real-time
  realTime: {
    maxPoolSize: 150,
    minPoolSize: 20,
    maxIdleTimeMS: 15000,
    waitQueueTimeoutMS: 2000,
    serverSelectionTimeoutMS: 3000,
    socketTimeoutMS: 30000,
    keepAlive: true,
    keepAliveInitialDelay: 60000,
    compression: 'snappy'
  }
};

module.exports = poolConfigurations;