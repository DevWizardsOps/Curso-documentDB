#!/usr/bin/env node

/**
 * Exemplos Básicos - AWS SDK Node.js para DocumentDB
 * Módulo 1 - Conceitos e Consultas (SEM criar recursos)
 * 
 * Este arquivo contém exemplos teóricos de como usar AWS SDK v3 com DocumentDB.
 * IMPORTANTE: Estes são exemplos conceituais para aprendizado.
 */

// Importações do AWS SDK v3
const { 
    DocDBClient, 
    DescribeDBClustersCommand,
    DescribeDBInstancesCommand,
    DescribeDBClusterSnapshotsCommand,
    DescribeDBClusterParameterGroupsCommand,
    DescribeDBClusterParametersCommand,
    DescribeEventsCommand
} = require('@aws-sdk/client-docdb');

const { 
    CloudWatchClient, 
    GetMetricStatisticsCommand,
    ListMetricsCommand 
} = require('@aws-sdk/client-cloudwatch');

const { 
    CloudWatchLogsClient,
    DescribeLogGroupsCommand,
    DescribeLogStreamsCommand 
} = require('@aws-sdk/client-cloudwatch-logs');

/**
 * Classe para gerenciar operações do DocumentDB via AWS SDK Node.js
 * Foco em operações de consulta e monitoramento
 */
class DocumentDBManager {
    /**
     * Construtor da classe
     * @param {string} region - Região AWS (padrão: us-east-1)
     */
    constructor(region = 'us-east-1') {
        this.region = region;
        
        // Inicializar clientes AWS SDK v3
        this.docdbClient = new DocDBClient({ region });
        this.cloudwatchClient = new CloudWatchClient({ region });
        this.logsClient = new CloudWatchLogsClient({ region });
        
        console.log(`✅ Cliente DocumentDB inicializado na região: ${region}`);
    }

    /**
     * Lista todos os clusters DocumentDB
     * @returns {Promise<Array>} Lista de clusters
     */
    async listClusters() {
        try {
            const command = new DescribeDBClustersCommand({});
            const response = await this.docdbClient.send(command);
            
            const clusters = response.DBClusters.map(cluster => ({
                identifier: cluster.DBClusterIdentifier,
                status: cluster.Status,
                engine: cluster.Engine,
                engineVersion: cluster.EngineVersion,
                endpoint: cluster.Endpoint || 'N/A',
                readerEndpoint: cluster.ReaderEndpoint || 'N/A',
                port: cluster.Port || 27017,
                multiAZ: cluster.MultiAZ || false,
                backupRetention: cluster.BackupRetentionPeriod || 0,
                createdTime: cluster.ClusterCreateTime || 'N/A'
            }));
            
            console.log(`📋 Encontrados ${clusters.length} clusters`);
            return clusters;
            
        } catch (error) {
            console.error('❌ Erro ao listar clusters:', error.message);
            return [];
        }
    }

    /**
     * Obtém detalhes específicos de um cluster
     * @param {string} clusterIdentifier - Identificador do cluster
     * @returns {Promise<Object|null>} Detalhes do cluster
     */
    async getClusterDetails(clusterIdentifier) {
        try {
            const command = new DescribeDBClustersCommand({
                DBClusterIdentifier: clusterIdentifier
            });
            
            const response = await this.docdbClient.send(command);
            
            if (!response.DBClusters || response.DBClusters.length === 0) {
                console.log(`❌ Cluster '${clusterIdentifier}' não encontrado`);
                return null;
            }
            
            const cluster = response.DBClusters[0];
            
            const details = {
                basicInfo: {
                    identifier: cluster.DBClusterIdentifier,
                    status: cluster.Status,
                    engine: `${cluster.Engine} ${cluster.EngineVersion}`,
                    created: cluster.ClusterCreateTime || 'N/A'
                },
                connectivity: {
                    endpoint: cluster.Endpoint || 'N/A',
                    readerEndpoint: cluster.ReaderEndpoint || 'N/A',
                    port: cluster.Port || 27017,
                    vpcSecurityGroups: cluster.VpcSecurityGroups?.map(sg => sg.VpcSecurityGroupId) || []
                },
                configuration: {
                    multiAZ: cluster.MultiAZ || false,
                    backupRetentionPeriod: cluster.BackupRetentionPeriod || 0,
                    preferredBackupWindow: cluster.PreferredBackupWindow || 'N/A',
                    preferredMaintenanceWindow: cluster.PreferredMaintenanceWindow || 'N/A',
                    storageEncrypted: cluster.StorageEncrypted || false,
                    kmsKeyId: cluster.KmsKeyId || 'Default'
                },
                network: {
                    dbSubnetGroupName: cluster.DBSubnetGroup || 'N/A',
                    availabilityZones: cluster.AvailabilityZones || []
                }
            };
            
            console.log(`✅ Detalhes obtidos para cluster: ${clusterIdentifier}`);
            return details;
            
        } catch (error) {
            console.error('❌ Erro ao obter detalhes do cluster:', error.message);
            return null;
        }
    }

    /**
     * Lista instâncias DocumentDB
     * @param {string} clusterIdentifier - Filtrar por cluster específico (opcional)
     * @returns {Promise<Array>} Lista de instâncias
     */
    async listInstances(clusterIdentifier = null) {
        try {
            const params = {};
            
            if (clusterIdentifier) {
                params.Filters = [{
                    Name: 'db-cluster-id',
                    Values: [clusterIdentifier]
                }];
            }
            
            const command = new DescribeDBInstancesCommand(params);
            const response = await this.docdbClient.send(command);
            
            const instances = response.DBInstances.map(instance => ({
                identifier: instance.DBInstanceIdentifier,
                status: instance.DBInstanceStatus,
                instanceClass: instance.DBInstanceClass,
                availabilityZone: instance.AvailabilityZone || 'N/A',
                clusterIdentifier: instance.DBClusterIdentifier || 'N/A',
                endpoint: instance.Endpoint?.Address || 'N/A',
                port: instance.Endpoint?.Port || 27017,
                promotionTier: instance.PromotionTier || 0,
                createdTime: instance.InstanceCreateTime || 'N/A'
            }));
            
            console.log(`📋 Encontradas ${instances.length} instâncias`);
            return instances;
            
        } catch (error) {
            console.error('❌ Erro ao listar instâncias:', error.message);
            return [];
        }
    }

    /**
     * Lista snapshots disponíveis
     * @param {string} clusterIdentifier - Filtrar por cluster (opcional)
     * @param {string} snapshotType - 'manual', 'automated', ou 'all'
     * @returns {Promise<Array>} Lista de snapshots
     */
    async listSnapshots(clusterIdentifier = null, snapshotType = 'all') {
        try {
            const params = {};
            
            if (clusterIdentifier) {
                params.DBClusterIdentifier = clusterIdentifier;
            }
            
            if (snapshotType !== 'all') {
                params.SnapshotType = snapshotType;
            }
            
            const command = new DescribeDBClusterSnapshotsCommand(params);
            const response = await this.docdbClient.send(command);
            
            const snapshots = response.DBClusterSnapshots.map(snapshot => ({
                identifier: snapshot.DBClusterSnapshotIdentifier,
                clusterIdentifier: snapshot.DBClusterIdentifier,
                status: snapshot.Status,
                snapshotType: snapshot.SnapshotType,
                createdTime: snapshot.SnapshotCreateTime || 'N/A',
                allocatedStorage: snapshot.AllocatedStorage || 0,
                engine: snapshot.Engine || 'N/A',
                engineVersion: snapshot.EngineVersion || 'N/A'
            }));
            
            console.log(`📋 Encontrados ${snapshots.length} snapshots`);
            return snapshots;
            
        } catch (error) {
            console.error('❌ Erro ao listar snapshots:', error.message);
            return [];
        }
    }

    /**
     * Obtém métricas do CloudWatch para um cluster
     * @param {string} clusterIdentifier - Identificador do cluster
     * @param {number} hours - Número de horas para buscar métricas
     * @returns {Promise<Object>} Métricas do cluster
     */
    async getClusterMetrics(clusterIdentifier, hours = 1) {
        try {
            const endTime = new Date();
            const startTime = new Date(endTime.getTime() - (hours * 60 * 60 * 1000));
            
            const metrics = {};
            
            // Lista de métricas importantes
            const metricNames = [
                'CPUUtilization',
                'DatabaseConnections',
                'ReadLatency',
                'WriteLatency',
                'ReadThroughput',
                'WriteThroughput'
            ];
            
            // Buscar cada métrica
            for (const metricName of metricNames) {
                try {
                    const command = new GetMetricStatisticsCommand({
                        Namespace: 'AWS/DocDB',
                        MetricName: metricName,
                        Dimensions: [{
                            Name: 'DBClusterIdentifier',
                            Value: clusterIdentifier
                        }],
                        StartTime: startTime,
                        EndTime: endTime,
                        Period: 300, // 5 minutos
                        Statistics: ['Average', 'Maximum']
                    });
                    
                    const response = await this.cloudwatchClient.send(command);
                    const datapoints = response.Datapoints || [];
                    
                    if (datapoints.length > 0) {
                        // Ordenar por timestamp
                        datapoints.sort((a, b) => new Date(a.Timestamp) - new Date(b.Timestamp));
                        
                        const latest = datapoints[datapoints.length - 1];
                        metrics[metricName] = {
                            latestAverage: latest.Average || 0,
                            latestMaximum: latest.Maximum || 0,
                            datapointsCount: datapoints.length,
                            periodHours: hours
                        };
                    } else {
                        metrics[metricName] = {
                            latestAverage: 0,
                            latestMaximum: 0,
                            datapointsCount: 0,
                            periodHours: hours
                        };
                    }
                    
                } catch (metricError) {
                    console.warn(`⚠️ Erro ao obter métrica ${metricName}:`, metricError.message);
                    metrics[metricName] = null;
                }
            }
            
            console.log(`📊 Métricas obtidas para cluster: ${clusterIdentifier}`);
            return metrics;
            
        } catch (error) {
            console.error('❌ Erro ao obter métricas:', error.message);
            return {};
        }
    }

    /**
     * Lista parameter groups disponíveis
     * @returns {Promise<Array>} Lista de parameter groups
     */
    async listParameterGroups() {
        try {
            const command = new DescribeDBClusterParameterGroupsCommand({});
            const response = await this.docdbClient.send(command);
            
            const parameterGroups = response.DBClusterParameterGroups.map(pg => ({
                name: pg.DBClusterParameterGroupName,
                family: pg.DBParameterGroupFamily,
                description: pg.Description || 'N/A'
            }));
            
            console.log(`📋 Encontrados ${parameterGroups.length} parameter groups`);
            return parameterGroups;
            
        } catch (error) {
            console.error('❌ Erro ao listar parameter groups:', error.message);
            return [];
        }
    }

    /**
     * Obtém parâmetros de um parameter group específico
     * @param {string} parameterGroupName - Nome do parameter group
     * @returns {Promise<Array>} Lista de parâmetros
     */
    async getParameterGroupParameters(parameterGroupName) {
        try {
            const command = new DescribeDBClusterParametersCommand({
                DBClusterParameterGroupName: parameterGroupName
            });
            
            const response = await this.docdbClient.send(command);
            
            const parameters = response.Parameters.map(param => ({
                name: param.ParameterName,
                value: param.ParameterValue || 'N/A',
                description: param.Description || 'N/A',
                isModifiable: param.IsModifiable || false,
                dataType: param.DataType || 'N/A',
                allowedValues: param.AllowedValues || 'N/A'
            }));
            
            console.log(`📋 Encontrados ${parameters.length} parâmetros`);
            return parameters;
            
        } catch (error) {
            console.error('❌ Erro ao obter parâmetros:', error.message);
            return [];
        }
    }

    /**
     * Verifica eventos recentes de um cluster
     * @param {string} clusterIdentifier - Identificador do cluster
     * @param {number} hours - Horas para buscar eventos
     * @returns {Promise<Array>} Lista de eventos
     */
    async checkClusterEvents(clusterIdentifier, hours = 24) {
        try {
            const startTime = new Date(Date.now() - (hours * 60 * 60 * 1000));
            
            const command = new DescribeEventsCommand({
                SourceIdentifier: clusterIdentifier,
                SourceType: 'db-cluster',
                StartTime: startTime,
                Duration: hours * 60 // em minutos
            });
            
            const response = await this.docdbClient.send(command);
            
            const events = response.Events.map(event => ({
                date: event.Date || 'N/A',
                message: event.Message || 'N/A',
                eventCategories: event.EventCategories || [],
                sourceId: event.SourceId || 'N/A'
            }));
            
            console.log(`📋 Encontrados ${events.length} eventos nas últimas ${hours} horas`);
            return events;
            
        } catch (error) {
            console.error('❌ Erro ao verificar eventos:', error.message);
            return [];
        }
    }

    /**
     * Gera string de conexão MongoDB para o cluster
     * @param {string} clusterIdentifier - Identificador do cluster
     * @param {string} username - Nome de usuário
     * @returns {Promise<string|null>} String de conexão MongoDB
     */
    async generateConnectionString(clusterIdentifier, username = 'docdbadmin') {
        try {
            const clusterDetails = await this.getClusterDetails(clusterIdentifier);
            if (!clusterDetails) {
                return null;
            }
            
            const endpoint = clusterDetails.connectivity.endpoint;
            const port = clusterDetails.connectivity.port;
            
            // String de conexão básica (sem senha por segurança)
            const connectionString = 
                `mongodb://${username}:PASSWORD@${endpoint}:${port}/` +
                `?tls=true&tlsCAFile=global-bundle.pem&replicaSet=rs0` +
                `&readPreference=secondaryPreferred&retryWrites=false`;
            
            console.log(`🔗 String de conexão gerada para: ${clusterIdentifier}`);
            console.log('⚠️ Substitua "PASSWORD" pela senha real');
            
            return connectionString;
            
        } catch (error) {
            console.error('❌ Erro ao gerar string de conexão:', error.message);
            return null;
        }
    }

    /**
     * Imprime um resumo completo do cluster
     * @param {string} clusterIdentifier - Identificador do cluster
     */
    async printClusterSummary(clusterIdentifier) {
        console.log(`\n${'='.repeat(60)}`);
        console.log(`RESUMO DO CLUSTER: ${clusterIdentifier}`);
        console.log(`${'='.repeat(60)}`);
        
        // Detalhes básicos
        const details = await this.getClusterDetails(clusterIdentifier);
        if (details) {
            console.log('\n📋 INFORMAÇÕES BÁSICAS:');
            Object.entries(details.basicInfo).forEach(([key, value]) => {
                console.log(`  ${key.replace(/([A-Z])/g, ' $1').toLowerCase()}: ${value}`);
            });
            
            console.log('\n🔗 CONECTIVIDADE:');
            Object.entries(details.connectivity).forEach(([key, value]) => {
                console.log(`  ${key.replace(/([A-Z])/g, ' $1').toLowerCase()}: ${value}`);
            });
            
            console.log('\n⚙️ CONFIGURAÇÃO:');
            Object.entries(details.configuration).forEach(([key, value]) => {
                console.log(`  ${key.replace(/([A-Z])/g, ' $1').toLowerCase()}: ${value}`);
            });
        }
        
        // Instâncias
        console.log('\n🖥️ INSTÂNCIAS:');
        const instances = await this.listInstances(clusterIdentifier);
        instances.forEach(instance => {
            console.log(`  • ${instance.identifier} (${instance.instanceClass}) - ${instance.status}`);
        });
        
        // Métricas recentes
        console.log('\n📊 MÉTRICAS (última hora):');
        const metrics = await this.getClusterMetrics(clusterIdentifier, 1);
        Object.entries(metrics).forEach(([metricName, metricData]) => {
            if (metricData) {
                const avg = metricData.latestAverage.toFixed(2);
                const max = metricData.latestMaximum.toFixed(2);
                console.log(`  • ${metricName}: Avg=${avg}, Max=${max}`);
            }
        });
        
        // String de conexão
        console.log('\n🔗 STRING DE CONEXÃO:');
        const connStr = await this.generateConnectionString(clusterIdentifier);
        if (connStr) {
            console.log(`  ${connStr}`);
        }
        
        console.log(`\n${'='.repeat(60)}`);
    }
}

/**
 * Função principal com exemplos de uso
 */
async function main() {
    console.log('🚀 Exemplos AWS SDK Node.js para DocumentDB - Módulo 1');
    console.log('='.repeat(50));
    
    try {
        // Inicializar manager
        const docdbManager = new DocumentDBManager('us-east-1');
        
        // Exemplo 1: Listar todos os clusters
        console.log('\n1️⃣ Listando clusters disponíveis:');
        const clusters = await docdbManager.listClusters();
        clusters.forEach(cluster => {
            console.log(`  • ${cluster.identifier} - ${cluster.status}`);
        });
        
        // Exemplo 2: Se houver clusters, mostrar detalhes do primeiro
        if (clusters.length > 0) {
            const firstCluster = clusters[0].identifier;
            console.log(`\n2️⃣ Detalhes do cluster: ${firstCluster}`);
            await docdbManager.printClusterSummary(firstCluster);
        }
        
        // Exemplo 3: Listar parameter groups
        console.log('\n3️⃣ Parameter groups disponíveis:');
        const parameterGroups = await docdbManager.listParameterGroups();
        parameterGroups.forEach(pg => {
            console.log(`  • ${pg.name} (${pg.family})`);
        });
        
        // Exemplo 4: Listar snapshots
        console.log('\n4️⃣ Snapshots disponíveis:');
        const snapshots = await docdbManager.listSnapshots();
        snapshots.slice(0, 5).forEach(snapshot => { // Mostrar apenas os 5 primeiros
            console.log(`  • ${snapshot.identifier} - ${snapshot.status}`);
        });
        
        console.log('\n✅ Exemplos executados com sucesso!');
        
    } catch (error) {
        console.error('❌ Erro durante execução:', error.message);
    }
}

// ============================================================================
// EXEMPLOS ADICIONAIS PARA ESTUDO
// ============================================================================

/**
 * Exemplo de tratamento de erros específicos
 */
async function exampleErrorHandling() {
    const docdbClient = new DocDBClient({ region: 'us-east-1' });
    
    try {
        // Tentar acessar cluster inexistente
        const command = new DescribeDBClustersCommand({
            DBClusterIdentifier: 'cluster-inexistente'
        });
        
        await docdbClient.send(command);
        
    } catch (error) {
        if (error.name === 'DBClusterNotFoundFault') {
            console.log('Cluster não encontrado');
        } else if (error.name === 'UnauthorizedOperation') {
            console.log('Acesso negado - verifique permissões IAM');
        } else {
            console.log(`Erro: ${error.name} - ${error.message}`);
        }
    }
}

/**
 * Exemplo de uso com async/await e Promise.all
 */
async function exampleParallelOperations() {
    const docdbManager = new DocumentDBManager();
    
    try {
        // Executar múltiplas operações em paralelo
        const [clusters, parameterGroups, snapshots] = await Promise.all([
            docdbManager.listClusters(),
            docdbManager.listParameterGroups(),
            docdbManager.listSnapshots()
        ]);
        
        console.log('Operações paralelas concluídas:');
        console.log(`- ${clusters.length} clusters`);
        console.log(`- ${parameterGroups.length} parameter groups`);
        console.log(`- ${snapshots.length} snapshots`);
        
    } catch (error) {
        console.error('Erro em operações paralelas:', error.message);
    }
}

/**
 * Exemplo de configuração avançada do cliente
 */
function exampleAdvancedClientConfig() {
    // Configuração com retry personalizado
    const docdbClient = new DocDBClient({
        region: 'us-east-1',
        maxAttempts: 3,
        retryMode: 'adaptive',
        requestHandler: {
            requestTimeout: 30000, // 30 segundos
            httpsAgent: {
                maxSockets: 25
            }
        }
    });
    
    console.log('Cliente configurado com retry e timeout personalizados');
    return docdbClient;
}

/**
 * Exemplo de monitoramento contínuo
 */
async function exampleContinuousMonitoring(clusterIdentifier, intervalMinutes = 5) {
    const docdbManager = new DocumentDBManager();
    
    console.log(`🔄 Iniciando monitoramento contínuo do cluster: ${clusterIdentifier}`);
    console.log(`📊 Intervalo: ${intervalMinutes} minutos`);
    
    const monitor = setInterval(async () => {
        try {
            const metrics = await docdbManager.getClusterMetrics(clusterIdentifier, 1);
            
            console.log(`\n⏰ ${new Date().toISOString()}`);
            console.log('📊 Métricas atuais:');
            
            Object.entries(metrics).forEach(([name, data]) => {
                if (data && name === 'CPUUtilization') {
                    console.log(`  CPU: ${data.latestAverage.toFixed(1)}%`);
                } else if (data && name === 'DatabaseConnections') {
                    console.log(`  Conexões: ${Math.round(data.latestAverage)}`);
                }
            });
            
        } catch (error) {
            console.error('❌ Erro no monitoramento:', error.message);
        }
    }, intervalMinutes * 60 * 1000);
    
    // Parar monitoramento após 30 minutos (exemplo)
    setTimeout(() => {
        clearInterval(monitor);
        console.log('🛑 Monitoramento interrompido');
    }, 30 * 60 * 1000);
}

// ============================================================================
// CONFIGURAÇÕES E CONSTANTES
// ============================================================================

// Configurações padrão
const DEFAULT_REGION = 'us-east-1';
const DEFAULT_ENGINE_VERSION = '5.0.0';
const DEFAULT_INSTANCE_CLASS = 'db.t3.medium';

// Métricas importantes do DocumentDB
const IMPORTANT_METRICS = [
    'CPUUtilization',
    'DatabaseConnections',
    'ReadLatency',
    'WriteLatency',
    'ReadThroughput',
    'WriteThroughput',
    'NetworkReceiveThroughput',
    'NetworkTransmitThroughput',
    'FreeableMemory',
    'SwapUsage'
];

// Parâmetros importantes do DocumentDB
const IMPORTANT_PARAMETERS = [
    'tls',
    'audit_logs',
    'ttl_monitor',
    'profiler',
    'profiler_threshold_ms'
];

// Exportar para uso em outros módulos
module.exports = {
    DocumentDBManager,
    exampleErrorHandling,
    exampleParallelOperations,
    exampleAdvancedClientConfig,
    exampleContinuousMonitoring,
    DEFAULT_REGION,
    IMPORTANT_METRICS,
    IMPORTANT_PARAMETERS
};

// Executar exemplos se chamado diretamente
if (require.main === module) {
    main().catch(console.error);
}

console.log('📚 Arquivo de exemplos AWS SDK Node.js carregado com sucesso!');
console.log('💡 Execute main() para ver exemplos em ação');
console.log('📖 Explore as funções individuais para aprender mais');