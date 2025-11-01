#!/usr/bin/env node

/**
 * Exemplo de aplicação Node.js resiliente a failover do DocumentDB
 * 
 * Este exemplo demonstra:
 * - Configuração correta de connection string
 * - Retry logic automática
 * - Reconexão após falhas
 * - Logging de eventos
 * 
 * Uso:
 *   npm install mongodb
 *   node connection-failover.js
 */

const { MongoClient } = require('mongodb');
const fs = require('fs');

// ========================================
// CONFIGURAÇÃO
// ========================================

// IMPORTANTE: Substitua com suas credenciais reais
const CONFIG = {
    host: process.env.DOCDB_HOST || 'lab-cluster-console.cluster-xxxxx.us-east-1.docdb.amazonaws.com',
    port: process.env.DOCDB_PORT || '27017',
    username: process.env.DOCDB_USER || 'docdbadmin',
    password: process.env.DOCDB_PASSWORD || 'Lab12345!',
    database: process.env.DOCDB_DATABASE || 'testdb',
    tlsCAFile: process.env.DOCDB_CA_FILE || './global-bundle.pem'
};

// Opções de conexão otimizadas para failover
const CONNECTION_OPTIONS = {
    useNewUrlParser: true,
    useUnifiedTopology: true,
    
    // SSL/TLS
    tls: true,
    tlsCAFile: CONFIG.tlsCAFile,
    tlsAllowInvalidHostnames: true,
    
    // Replica Set (obrigatório para DocumentDB)
    replicaSet: 'rs0',
    readPreference: 'secondaryPreferred',
    
    // Retry automático
    retryWrites: false,  // DocumentDB não suporta retryable writes
    retryReads: true,
    
    // Timeouts
    serverSelectionTimeoutMS: 5000,  // 5 segundos
    socketTimeoutMS: 45000,           // 45 segundos
    connectTimeoutMS: 10000,          // 10 segundos
    
    // Connection Pool
    maxPoolSize: 50,
    minPoolSize: 10,
    maxIdleTimeMS: 30000,
    
    // Heartbeat
    heartbeatFrequencyMS: 10000,  // 10 segundos
};

// ========================================
// HELPER FUNCTIONS
// ========================================

function log(level, message, metadata = {}) {
    const timestamp = new Date().toISOString();
    const logEntry = {
        timestamp,
        level,
        message,
        ...metadata
    };
    
    const color = {
        INFO: '\x1b[36m',    // Cyan
        SUCCESS: '\x1b[32m', // Green
        WARNING: '\x1b[33m', // Yellow
        ERROR: '\x1b[31m',   // Red
        RESET: '\x1b[0m'
    };
    
    const prefix = {
        INFO: 'ℹ️ ',
        SUCCESS: '✅',
        WARNING: '⚠️ ',
        ERROR: '❌'
    };
    
    console.log(
        `${color[level]}[${timestamp}] ${prefix[level]} ${message}${color.RESET}`,
        Object.keys(metadata).length > 0 ? JSON.stringify(metadata, null, 2) : ''
    );
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function retryOperation(operation, maxRetries = 5, delay = 1000) {
    for (let i = 0; i < maxRetries; i++) {
        try {
            return await operation();
        } catch (error) {
            const isLastAttempt = i === maxRetries - 1;
            
            if (isLastAttempt) {
                throw error;
            }
            
            const backoffDelay = delay * Math.pow(2, i);
            log('WARNING', `Tentativa ${i + 1} falhou, tentando novamente em ${backoffDelay}ms`, {
                error: error.message
            });
            
            await sleep(backoffDelay);
        }
    }
}

// ========================================
// DATABASE OPERATIONS
// ========================================

class DocumentDBClient {
    constructor(config, options) {
        this.config = config;
        this.options = options;
        this.client = null;
        this.db = null;
        this.isConnected = false;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 10;
    }
    
    getConnectionString() {
        return `mongodb://${this.config.username}:${this.config.password}@${this.config.host}:${this.config.port}/?authSource=admin`;
    }
    
    async connect() {
        try {
            log('INFO', 'Conectando ao DocumentDB...', {
                host: this.config.host,
                port: this.config.port,
                database: this.config.database
            });
            
            const connectionString = this.getConnectionString();
            this.client = new MongoClient(connectionString, this.options);
            
            await this.client.connect();
            this.db = this.client.db(this.config.database);
            this.isConnected = true;
            this.reconnectAttempts = 0;
            
            log('SUCCESS', 'Conectado com sucesso ao DocumentDB!');
            
            // Configurar event listeners
            this.setupEventListeners();
            
            return true;
        } catch (error) {
            log('ERROR', 'Erro ao conectar', { error: error.message });
            throw error;
        }
    }
    
    setupEventListeners() {
        this.client.on('serverDescriptionChanged', (event) => {
            log('INFO', 'Servidor mudou', {
                address: event.address,
                previousType: event.previousDescription.type,
                newType: event.newDescription.type
            });
        });
        
        this.client.on('topologyDescriptionChanged', (event) => {
            log('INFO', 'Topologia mudou', {
                previousServers: event.previousDescription.servers.size,
                newServers: event.newDescription.servers.size
            });
        });
        
        this.client.on('serverHeartbeatFailed', (event) => {
            log('WARNING', 'Heartbeat falhou', {
                address: event.connectionId,
                failure: event.failure?.message
            });
        });
        
        this.client.on('connectionPoolCleared', (event) => {
            log('WARNING', 'Connection pool limpo (possível failover)', {
                address: event.address
            });
        });
    }
    
    async disconnect() {
        if (this.client) {
            await this.client.close();
            this.isConnected = false;
            log('INFO', 'Desconectado do DocumentDB');
        }
    }
    
    async executeOperation(operation) {
        if (!this.isConnected) {
            throw new Error('Cliente não está conectado');
        }
        
        try {
            return await operation(this.db);
        } catch (error) {
            log('ERROR', 'Erro na operação', { error: error.message });
            
            // Se for erro de conexão, tentar reconectar
            if (this.isConnectionError(error)) {
                await this.handleConnectionError();
            }
            
            throw error;
        }
    }
    
    isConnectionError(error) {
        const connectionErrors = [
            'connection',
            'network',
            'topology',
            'pool',
            'ECONNREFUSED',
            'ETIMEDOUT'
        ];
        
        const errorMessage = error.message.toLowerCase();
        return connectionErrors.some(keyword => errorMessage.includes(keyword));
    }
    
    async handleConnectionError() {
        log('WARNING', 'Detectada perda de conexão, tentando reconectar...');
        
        this.isConnected = false;
        this.reconnectAttempts++;
        
        if (this.reconnectAttempts > this.maxReconnectAttempts) {
            log('ERROR', 'Máximo de tentativas de reconexão atingido');
            throw new Error('Não foi possível reconectar ao banco');
        }
        
        const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);
        log('INFO', `Aguardando ${delay}ms antes de reconectar...`);
        await sleep(delay);
        
        await this.connect();
    }
}

// ========================================
// APLICAÇÃO DE TESTE
// ========================================

async function testFailoverResilience() {
    log('INFO', '═══════════════════════════════════════════════════════');
    log('INFO', '  Teste de Resiliência a Failover - DocumentDB');
    log('INFO', '═══════════════════════════════════════════════════════');
    console.log('');
    
    const client = new DocumentDBClient(CONFIG, CONNECTION_OPTIONS);
    
    try {
        // Conectar
        await client.connect();
        console.log('');
        
        log('INFO', '🚀 Iniciando operações contínuas...');
        log('INFO', '💡 Execute um failover em outro terminal para testar');
        console.log('');
        
        const collection = client.db.collection('failover_test');
        let operationCount = 0;
        let errorCount = 0;
        
        // Loop infinito de operações
        while (true) {
            try {
                const timestamp = new Date();
                
                // Inserir documento
                await retryOperation(async () => {
                    await collection.insertOne({
                        timestamp,
                        operationId: ++operationCount,
                        message: 'Teste de resiliência a failover',
                        hostname: require('os').hostname()
                    });
                });
                
                log('SUCCESS', `Operação #${operationCount} executada com sucesso`);
                
                // Consultar documentos recentes
                const recentDocs = await retryOperation(async () => {
                    return await collection
                        .find({})
                        .sort({ timestamp: -1 })
                        .limit(5)
                        .toArray();
                });
                
                log('INFO', `Total de documentos recentes: ${recentDocs.length}`);
                
            } catch (error) {
                errorCount++;
                log('ERROR', `Erro na operação #${operationCount}`, {
                    error: error.message,
                    totalErrors: errorCount
                });
                
                // Se houver muitos erros consecutivos, pode ser um problema sério
                if (errorCount > 10) {
                    log('ERROR', 'Muitos erros consecutivos, encerrando...');
                    break;
                }
            }
            
            // Aguardar antes da próxima operação
            await sleep(2000);
        }
        
    } catch (error) {
        log('ERROR', 'Erro fatal na aplicação', { error: error.message });
    } finally {
        await client.disconnect();
    }
}

// ========================================
// EXEMPLO DE USO SIMPLES
// ========================================

async function simpleExample() {
    const client = new DocumentDBClient(CONFIG, CONNECTION_OPTIONS);
    
    await client.connect();
    
    // Inserir documento
    await client.executeOperation(async (db) => {
        const result = await db.collection('test').insertOne({
            message: 'Hello DocumentDB!',
            timestamp: new Date()
        });
        
        log('SUCCESS', 'Documento inserido', { id: result.insertedId });
    });
    
    // Consultar documentos
    await client.executeOperation(async (db) => {
        const docs = await db.collection('test').find({}).toArray();
        log('INFO', `${docs.length} documentos encontrados`);
    });
    
    await client.disconnect();
}

// ========================================
// INICIAR APLICAÇÃO
// ========================================

if (require.main === module) {
    // Verificar se o certificado SSL existe
    if (!fs.existsSync(CONFIG.tlsCAFile)) {
        log('ERROR', 'Certificado SSL não encontrado!');
        log('INFO', 'Baixe o certificado com:');
        console.log('  wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem');
        process.exit(1);
    }
    
    // Escolher qual exemplo executar
    const mode = process.argv[2] || 'test';
    
    if (mode === 'simple') {
        simpleExample().catch(console.error);
    } else {
        testFailoverResilience().catch(console.error);
    }
}

// Graceful shutdown
process.on('SIGINT', () => {
    log('INFO', 'Encerrando aplicação...');
    process.exit(0);
});

module.exports = { DocumentDBClient };
