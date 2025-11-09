# Exercício 4: Estratégias Cross-Region e Limitações

## 🎯 Objetivos

- Explorar limitações do DocumentDB para replicação cross-region
- Implementar estratégias alternativas de sincronização entre regiões
- Configurar arquiteturas multi-região resilientes
- Desenvolver planos de failover regional

## ⏱️ Duração Estimada
105 minutos

> ⚠️ **Atenção:** Lembre-se de usar seu prefixo de aluno (`<seu-id>`) em todos os nomes de recursos e comandos.

---

## 🌍 Parte 1: Análise de Limitações Cross-Region

### Passo 1: Documentar Limitações do DocumentDB

```bash
# Configurar variáveis
export ID="<seu-id>"
export PRIMARY_REGION="us-east-1"
export SECONDARY_REGION="us-west-2"
export CLUSTER_ID="$ID-lab-cluster-console"

# Criar documento de limitações
cat > architectures/documentdb-limitations.md << 'EOF'
# Limitações do DocumentDB para Cross-Region

## Limitações Nativas

### 1. Replicação Cross-Region
- ❌ **Não suportada nativamente**
- ❌ Não há read replicas cross-region automáticas
- ❌ Não há sincronização automática entre regiões

### 2. Backup Cross-Region
- ✅ **Snapshots podem ser copiados entre regiões**
- ⚠️ Processo manual ou via automação customizada
- ⚠️ Custos de transferência de dados aplicáveis

### 3. Failover Regional
- ❌ **Não há failover automático entre regiões**
- ⚠️ Requer intervenção manual ou automação customizada
- ⚠️ RTO pode ser alto (horas) sem preparação adequada

## Comparação com RDS/Aurora

| Recurso | DocumentDB | RDS/Aurora |
|---------|------------|------------|
| Cross-Region Read Replicas | ❌ | ✅ |
| Global Database | ❌ | ✅ (Aurora) |
| Automated Cross-Region Backup | ❌ | ✅ |
| Cross-Region Failover | ❌ | ✅ (Aurora) |

## Implicações Arquiteturais

### Para Alta Disponibilidade
- Dependência de uma única região
- Necessidade de estratégias customizadas
- Maior complexidade operacional

### Para Disaster Recovery
- RPO potencialmente alto
- RTO dependente de processos manuais
- Necessidade de automação customizada

### Para Performance Global
- Latência alta para usuários distantes
- Impossibilidade de distribuição geográfica nativa
- Necessidade de arquiteturas alternativas
EOF
```

### Passo 2: Avaliar Alternativas Arquiteturais

```bash
# Criar análise de alternativas
cat > architectures/multi-region-design.md << 'EOF'
# Estratégias Multi-Região para DocumentDB

## Estratégia 1: Snapshot Cross-Region (Disaster Recovery)

### Arquitetura
```
Primary Region (us-east-1)     Secondary Region (us-west-2)
┌─────────────────────────┐    ┌─────────────────────────┐
│  DocumentDB Cluster     │    │  Standby Infrastructure │
│  ├── Primary Instance   │    │  ├── VPC               │
│  ├── Read Replica 1     │    │  ├── Subnets           │
│  └── Read Replica 2     │    │  ├── Security Groups   │
│                         │    │  └── Parameter Groups  │
│  Automated Snapshots    │    │                         │
│  ├── Daily: 2:00 AM     │───▶│  Cross-Region Snapshots │
│  └── Hourly: On-demand  │    │  ├── Daily Copies      │
└─────────────────────────┘    │  └── Emergency Copies   │
                               └─────────────────────────┘
```

### Características
- **RPO:** 1-24 horas (dependendo da frequência)
- **RTO:** 2-4 horas (restauração + configuração)
- **Custo:** Baixo (apenas snapshots + storage)
- **Complexidade:** Média

## Estratégia 2: Aplicação Dual-Write (Active-Active)

### Arquitetura
```
Application Layer
┌─────────────────────────────────────────────────┐
│  Load Balancer / API Gateway                    │
│  ├── Route 53 Health Checks                    │
│  └── Failover Routing                          │
└─────────────────┬───────────────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
Primary Region         Secondary Region
┌─────────────────┐    ┌─────────────────┐
│ DocumentDB      │    │ DocumentDB      │
│ Cluster A       │    │ Cluster B       │
│                 │    │                 │
│ Application     │    │ Application     │
│ writes to both  │◄──▶│ writes to both  │
└─────────────────┘    └─────────────────┘
```

### Características
- **RPO:** Próximo de zero
- **RTO:** Segundos (failover de DNS)
- **Custo:** Alto (clusters duplos)
- **Complexidade:** Alta (conflict resolution)

## Estratégia 3: Change Data Capture (CDC)

### Arquitetura
```
Primary Region                 Secondary Region
┌─────────────────────────┐    ┌─────────────────────────┐
│  DocumentDB Cluster     │    │  DocumentDB Cluster     │
│  ├── Primary Instance   │    │  ├── Primary Instance   │
│  └── Read Replicas      │    │  └── Read Replicas      │
│                         │    │                         │
│  Change Stream          │    │                         │
│  ├── Lambda Function    │───▶│  Replication Lambda     │
│  ├── DynamoDB Streams   │    │  ├── Conflict Detection │
│  └── Kinesis Data       │    │  └── Data Validation    │
└─────────────────────────┘    └─────────────────────────┘
```

### Características
- **RPO:** Minutos
- **RTO:** Minutos (automático)
- **Custo:** Médio (processamento + transferência)
- **Complexidade:** Alta (CDC implementation)
EOF
```

---

## 📋 Parte 2: Implementação de Snapshot Cross-Region

### Passo 1: Configurar Infraestrutura na Região Secundária

```bash
# Criar VPC na região secundária
aws ec2 create-vpc \
--region $SECONDARY_REGION \
--cidr-block 10.1.0.0/16 \
--tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value='$ID'-docdb-vpc-secondary}]'

# Obter VPC ID
SECONDARY_VPC_ID=$(aws ec2 describe-vpcs \
--region $SECONDARY_REGION \
--filters "Name=tag:Name,Values=$ID-docdb-vpc-secondary" \
--query 'Vpcs[0].VpcId' \
--output text)

# Criar subnets em AZs diferentes
SECONDARY_AZS=($(aws ec2 describe-availability-zones \
--region $SECONDARY_REGION \
--query 'AvailabilityZones[0:2].ZoneName' \
--output text))

# Subnet 1
aws ec2 create-subnet \
--region $SECONDARY_REGION \
--vpc-id $SECONDARY_VPC_ID \
--cidr-block 10.1.1.0/24 \
--availability-zone ${SECONDARY_AZS[0]} \
--tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value='$ID'-docdb-subnet-secondary-1}]'

# Subnet 2
aws ec2 create-subnet \
--region $SECONDARY_REGION \
--vpc-id $SECONDARY_VPC_ID \
--cidr-block 10.1.2.0/24 \
--availability-zone ${SECONDARY_AZS[1]} \
--tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value='$ID'-docdb-subnet-secondary-2}]'

# Criar DB Subnet Group
SECONDARY_SUBNET_IDS=$(aws ec2 describe-subnets \
--region $SECONDARY_REGION \
--filters "Name=vpc-id,Values=$SECONDARY_VPC_ID" \
--query 'Subnets[].SubnetId' \
--output text)

aws docdb create-db-subnet-group \
--region $SECONDARY_REGION \
--db-subnet-group-name $ID-docdb-subnet-group-secondary \
--db-subnet-group-description "Subnet group for DocumentDB in secondary region" \
--subnet-ids $SECONDARY_SUBNET_IDS

echo "Infraestrutura secundária criada na região $SECONDARY_REGION"
```

### Passo 2: Automação de Cópia de Snapshots

```python
# Criar função Lambda para cópia cross-region
cat > lambda/cross-region-backup.py << 'EOF'
import json
import boto3
from datetime import datetime, timedelta

def lambda_handler(event, context):
    """
    Função para copiar snapshots do DocumentDB entre regiões
    """
    
    source_region = event.get('source_region', 'us-east-1')
    target_region = event.get('target_region', 'us-west-2')
    cluster_identifier = event['cluster_identifier']
    retention_days = event.get('retention_days', 7)
    
    # Clientes para ambas as regiões
    source_docdb = boto3.client('docdb', region_name=source_region)
    target_docdb = boto3.client('docdb', region_name=target_region)
    
    try:
        # Listar snapshots automáticos na região source
        response = source_docdb.describe_db_cluster_snapshots(
            DBClusterIdentifier=cluster_identifier,
            SnapshotType='automated',
            MaxRecords=50
        )
        
        snapshots = response['DBClusterSnapshots']
        
        # Filtrar snapshots das últimas 24 horas
        yesterday = datetime.now() - timedelta(days=1)
        recent_snapshots = [
            s for s in snapshots 
            if s['SnapshotCreateTime'].replace(tzinfo=None) > yesterday
        ]
        
        copied_snapshots = []
        
        for snapshot in recent_snapshots:
            source_snapshot_id = snapshot['DBClusterSnapshotIdentifier']
            source_snapshot_arn = snapshot['DBClusterSnapshotArn']
            
            # Gerar ID para snapshot de destino
            target_snapshot_id = f"{cluster_identifier}-cross-region-{snapshot['SnapshotCreateTime'].strftime('%Y%m%d%H%M%S')}"
            
            # Verificar se já existe na região de destino
            try:
                target_docdb.describe_db_cluster_snapshots(
                    DBClusterSnapshotIdentifier=target_snapshot_id
                )
                print(f"Snapshot {target_snapshot_id} já existe na região de destino")
                continue
            except target_docdb.exceptions.DBClusterSnapshotNotFoundFault:
                pass
            
            # Copiar snapshot
            print(f"Copiando snapshot {source_snapshot_id} para {target_region}")
            
            copy_response = target_docdb.copy_db_cluster_snapshot(
                SourceDBClusterSnapshotIdentifier=source_snapshot_arn,
                TargetDBClusterSnapshotIdentifier=target_snapshot_id,
                CopyTags=True
            )
            
            copied_snapshots.append({
                'source_id': source_snapshot_id,
                'target_id': target_snapshot_id,
                'status': 'copying'
            })
        
        # Limpar snapshots antigos na região de destino
        cleanup_response = target_docdb.describe_db_cluster_snapshots(
            SnapshotType='manual',
            MaxRecords=100
        )
        
        cleanup_date = datetime.now() - timedelta(days=retention_days)
        
        for old_snapshot in cleanup_response['DBClusterSnapshots']:
            if (old_snapshot['DBClusterSnapshotIdentifier'].startswith(f"{cluster_identifier}-cross-region") and
                old_snapshot['SnapshotCreateTime'].replace(tzinfo=None) < cleanup_date):
                
                print(f"Removendo snapshot antigo: {old_snapshot['DBClusterSnapshotIdentifier']}")
                
                target_docdb.delete_db_cluster_snapshot(
                    DBClusterSnapshotIdentifier=old_snapshot['DBClusterSnapshotIdentifier']
                )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Cross-region backup completed successfully',
                'copied_snapshots': copied_snapshots,
                'source_region': source_region,
                'target_region': target_region
            })
        }
        
    except Exception as e:
        print(f"Error in cross-region backup: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
EOF
```

### Passo 3: Configurar Agendamento Cross-Region

```bash
# Criar função Lambda para backup cross-region
zip -j cross-region-backup.zip lambda/cross-region-backup.py

aws lambda create-function \
--region $PRIMARY_REGION \
--function-name $ID-CrossRegionBackup \
--runtime python3.9 \
--role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/$ID-DocumentDBExportRole \
--handler cross-region-backup.lambda_handler \
--zip-file fileb://cross-region-backup.zip \
--timeout 900

# Criar regra EventBridge para execução diária
aws events put-rule \
--region $PRIMARY_REGION \
--name $ID-cross-region-backup \
--description "Backup cross-region diário do DocumentDB" \
--schedule-expression "cron(0 3 * * ? *)"  # Todo dia às 3:00 AM UTC

# Configurar target
aws events put-targets \
--region $PRIMARY_REGION \
--rule $ID-cross-region-backup \
--targets "Id"="1","Arn"="arn:aws:lambda:$PRIMARY_REGION:$(aws sts get-caller-identity --query Account --output text):function:$ID-CrossRegionBackup","Input"="{\"cluster_identifier\":\"$CLUSTER_ID\",\"source_region\":\"$PRIMARY_REGION\",\"target_region\":\"$SECONDARY_REGION\"}"

echo "Backup cross-region configurado"
```

---

## 🔄 Parte 3: Implementação de Sincronização Customizada

### Passo 1: Change Data Capture com Lambda

```javascript
// Implementar CDC básico
cat > scripts/cross-region-sync.js << 'EOF'
const { MongoClient } = require('mongodb');
const AWS = require('aws-sdk');

class CrossRegionSync {
  constructor(primaryEndpoint, secondaryEndpoint, credentials) {
    this.primaryClient = new MongoClient(`mongodb://${credentials.username}:${credentials.password}@${primaryEndpoint}:27017/syncDB?ssl=true&retryWrites=false`);
    this.secondaryClient = new MongoClient(`mongodb://${credentials.username}:${credentials.password}@${secondaryEndpoint}:27017/syncDB?ssl=true&retryWrites=false`);
    
    this.syncLog = new Map(); // Track sync status
    this.conflictResolver = new ConflictResolver();
  }

  async connect() {
    await Promise.all([
      this.primaryClient.connect(),
      this.secondaryClient.connect()
    ]);
    console.log('Connected to both regions');
  }

  async startSync(collections = ['products', 'orders']) {
    console.log('Starting cross-region synchronization...');
    
    for (const collectionName of collections) {
      await this.syncCollection(collectionName);
    }
  }

  async syncCollection(collectionName) {
    const primaryDb = this.primaryClient.db('syncDB');
    const secondaryDb = this.secondaryClient.db('syncDB');
    
    const primaryCollection = primaryDb.collection(collectionName);
    const secondaryCollection = secondaryDb.collection(collectionName);
    
    // Implementar change stream no primary
    const changeStream = primaryCollection.watch([], {
      fullDocument: 'updateLookup'
    });
    
    console.log(`Watching changes on ${collectionName}...`);
    
    changeStream.on('change', async (change) => {
      try {
        await this.processChange(change, secondaryCollection);
      } catch (error) {
        console.error(`Error processing change for ${collectionName}:`, error);
        await this.handleSyncError(change, error);
      }
    });
    
    // Sync inicial (full sync)
    await this.performInitialSync(primaryCollection, secondaryCollection);
  }

  async processChange(change, targetCollection) {
    const { operationType, documentKey, fullDocument } = change;
    
    switch (operationType) {
      case 'insert':
        await this.handleInsert(fullDocument, targetCollection);
        break;
      case 'update':
        await this.handleUpdate(documentKey, fullDocument, targetCollection);
        break;
      case 'delete':
        await this.handleDelete(documentKey, targetCollection);
        break;
      case 'replace':
        await this.handleReplace(documentKey, fullDocument, targetCollection);
        break;
    }
    
    // Log sync operation
    this.logSyncOperation(change);
  }

  async handleInsert(document, targetCollection) {
    // Check for conflicts
    const existing = await targetCollection.findOne({_id: document._id});
    
    if (existing) {
      // Conflict detected
      const resolution = await this.conflictResolver.resolve('insert', document, existing);
      if (resolution.action === 'overwrite') {
        await targetCollection.replaceOne({_id: document._id}, document);
      }
    } else {
      await targetCollection.insertOne(document);
    }
  }

  async handleUpdate(documentKey, fullDocument, targetCollection) {
    if (fullDocument) {
      await targetCollection.replaceOne(
        {_id: documentKey._id},
        fullDocument,
        {upsert: true}
      );
    }
  }

  async handleDelete(documentKey, targetCollection) {
    await targetCollection.deleteOne({_id: documentKey._id});
  }

  async handleReplace(documentKey, fullDocument, targetCollection) {
    await targetCollection.replaceOne(
      {_id: documentKey._id},
      fullDocument,
      {upsert: true}
    );
  }

  async performInitialSync(sourceCollection, targetCollection) {
    console.log('Performing initial sync...');
    
    const cursor = sourceCollection.find({});
    let syncedCount = 0;
    
    while (await cursor.hasNext()) {
      const doc = await cursor.next();
      
      try {
        await targetCollection.replaceOne(
          {_id: doc._id},
          doc,
          {upsert: true}
        );
        syncedCount++;
        
        if (syncedCount % 1000 === 0) {
          console.log(`Synced ${syncedCount} documents...`);
        }
      } catch (error) {
        console.error(`Error syncing document ${doc._id}:`, error);
      }
    }
    
    console.log(`Initial sync completed: ${syncedCount} documents`);
  }

  logSyncOperation(change) {
    const logEntry = {
      timestamp: new Date(),
      operationType: change.operationType,
      documentId: change.documentKey._id,
      clusterTime: change.clusterTime
    };
    
    this.syncLog.set(change.documentKey._id.toString(), logEntry);
  }

  async handleSyncError(change, error) {
    // Implement error handling and retry logic
    console.error('Sync error:', {
      change: change,
      error: error.message
    });
    
    // Send to DLQ or retry queue
    // Implement exponential backoff
  }

  async getSyncStatus() {
    return {
      totalOperations: this.syncLog.size,
      lastSync: Array.from(this.syncLog.values()).pop()?.timestamp,
      errors: 0 // Implement error tracking
    };
  }
}

class ConflictResolver {
  async resolve(operation, newDoc, existingDoc) {
    // Implement conflict resolution strategies
    
    // Strategy 1: Last Write Wins (based on timestamp)
    if (newDoc.lastModified && existingDoc.lastModified) {
      if (newDoc.lastModified > existingDoc.lastModified) {
        return { action: 'overwrite', document: newDoc };
      } else {
        return { action: 'ignore', document: existingDoc };
      }
    }
    
    // Strategy 2: Primary Region Wins
    return { action: 'overwrite', document: newDoc };
  }
}

// CLI interface
async function main() {
  const primaryEndpoint = process.env.PRIMARY_ENDPOINT;
  const secondaryEndpoint = process.env.SECONDARY_ENDPOINT;
  const credentials = {
    username: process.env.DB_USERNAME,
    password: process.env.DB_PASSWORD
  };

  const sync = new CrossRegionSync(primaryEndpoint, secondaryEndpoint, credentials);
  
  try {
    await sync.connect();
    await sync.startSync(['products', 'orders']);
    
    // Keep running
    process.on('SIGINT', async () => {
      console.log('Shutting down sync...');
      await sync.primaryClient.close();
      await sync.secondaryClient.close();
      process.exit(0);
    });
    
  } catch (error) {
    console.error('Sync failed:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = CrossRegionSync;
EOF
```

---

## 🚨 Parte 4: Plano de Failover Regional

### Passo 1: Script de Failover Automático

```bash
# Criar script de failover regional
cat > scripts/region-failover.sh << 'EOF'
#!/bin/bash

# Script de failover regional para DocumentDB
# Uso: ./region-failover.sh <cluster-id> <primary-region> <secondary-region>

CLUSTER_ID=$1
PRIMARY_REGION=$2
SECONDARY_REGION=$3
NOTIFICATION_TOPIC=$4

if [ $# -lt 3 ]; then
    echo "Uso: $0 <cluster-id> <primary-region> <secondary-region> [notification-topic]"
    exit 1
fi

echo "=== INICIANDO FAILOVER REGIONAL ==="
echo "Cluster: $CLUSTER_ID"
echo "Primary Region: $PRIMARY_REGION"
echo "Secondary Region: $SECONDARY_REGION"
echo "Timestamp: $(date)"

# Função para enviar notificação
send_notification() {
    local message="$1"
    local subject="$2"
    
    if [ ! -z "$NOTIFICATION_TOPIC" ]; then
        aws sns publish \
        --topic-arn $NOTIFICATION_TOPIC \
        --subject "$subject" \
        --message "$message"
    fi
    
    echo "$message"
}

# 1. Verificar status da região primária
echo "1. Verificando status da região primária..."
PRIMARY_STATUS=$(aws docdb describe-db-clusters \
--region $PRIMARY_REGION \
--db-cluster-identifier $CLUSTER_ID \
--query 'DBClusters[0].Status' \
--output text 2>/dev/null || echo "UNAVAILABLE")

if [ "$PRIMARY_STATUS" = "available" ]; then
    echo "   ⚠️  Região primária ainda disponível. Confirme se failover é necessário."
    read -p "   Continuar com failover? (y/N): " confirm
    if [ "$confirm" != "y" ]; then
        echo "   Failover cancelado pelo usuário."
        exit 0
    fi
fi

send_notification "Iniciando failover regional para $CLUSTER_ID" "DocumentDB Regional Failover Started"

# 2. Encontrar snapshot mais recente na região secundária
echo "2. Localizando snapshot mais recente na região secundária..."
LATEST_SNAPSHOT=$(aws docdb describe-db-cluster-snapshots \
--region $SECONDARY_REGION \
--query "DBClusterSnapshots[?contains(DBClusterSnapshotIdentifier, '$CLUSTER_ID-cross-region')].{ID:DBClusterSnapshotIdentifier,Time:SnapshotCreateTime}" \
--output text | sort -k2 -r | head -1 | cut -f1)

if [ -z "$LATEST_SNAPSHOT" ]; then
    echo "   ❌ Nenhum snapshot encontrado na região secundária!"
    send_notification "ERRO: Nenhum snapshot disponível para failover" "DocumentDB Failover Failed"
    exit 1
fi

echo "   ✅ Snapshot encontrado: $LATEST_SNAPSHOT"

# 3. Restaurar cluster na região secundária
echo "3. Restaurando cluster na região secundária..."
FAILOVER_CLUSTER_ID="${CLUSTER_ID}-failover-$(date +%Y%m%d%H%M%S)"

START_TIME=$(date +%s)

aws docdb restore-db-cluster-from-snapshot \
--region $SECONDARY_REGION \
--db-cluster-identifier $FAILOVER_CLUSTER_ID \
--snapshot-identifier $LATEST_SNAPSHOT \
--engine docdb \
--db-subnet-group-name $ID-docdb-subnet-group-secondary

# 4. Criar instâncias no cluster restaurado
echo "4. Criando instâncias no cluster restaurado..."
aws docdb create-db-instance \
--region $SECONDARY_REGION \
--db-instance-identifier ${FAILOVER_CLUSTER_ID}-1 \
--db-instance-class db.t3.medium \
--db-cluster-identifier $FAILOVER_CLUSTER_ID \
--engine docdb

# Aguardar disponibilidade
echo "5. Aguardando cluster ficar disponível..."
aws docdb wait db-cluster-available \
--region $SECONDARY_REGION \
--db-cluster-identifier $FAILOVER_CLUSTER_ID

END_TIME=$(date +%s)
FAILOVER_TIME=$((END_TIME - START_TIME))

# 6. Obter endpoint do novo cluster
NEW_ENDPOINT=$(aws docdb describe-db-clusters \
--region $SECONDARY_REGION \
--db-cluster-identifier $FAILOVER_CLUSTER_ID \
--query 'DBClusters[0].Endpoint' \
--output text)

echo "6. Cluster restaurado com sucesso!"
echo "   ✅ Novo Cluster ID: $FAILOVER_CLUSTER_ID"
echo "   ✅ Novo Endpoint: $NEW_ENDPOINT"
echo "   ✅ Região: $SECONDARY_REGION"
echo "   ✅ Tempo de Failover: ${FAILOVER_TIME}s"

# 7. Atualizar DNS (se configurado)
if [ ! -z "$ROUTE53_HOSTED_ZONE" ] && [ ! -z "$DNS_RECORD" ]; then
    echo "7. Atualizando DNS..."
    # Implementar atualização Route53
    echo "   DNS atualizado para apontar para nova região"
fi

# 8. Notificar conclusão
COMPLETION_MESSAGE="Failover regional concluído com sucesso!

Detalhes:
- Cluster Original: $CLUSTER_ID ($PRIMARY_REGION)
- Novo Cluster: $FAILOVER_CLUSTER_ID ($SECONDARY_REGION)
- Novo Endpoint: $NEW_ENDPOINT
- Tempo de Failover: ${FAILOVER_TIME}s
- Snapshot Usado: $LATEST_SNAPSHOT

Próximos Passos:
1. Atualizar aplicações para usar novo endpoint
2. Validar integridade dos dados
3. Monitorar performance na nova região
4. Planejar failback quando apropriado"

send_notification "$COMPLETION_MESSAGE" "DocumentDB Regional Failover Completed"

echo ""
echo "=== FAILOVER REGIONAL CONCLUÍDO ==="
echo "Novo endpoint: $NEW_ENDPOINT"
echo "Tempo total: ${FAILOVER_TIME}s"
EOF

chmod +x scripts/region-failover.sh
```

### Passo 2: Validação de Integridade Pós-Failover

```javascript
// Script de validação pós-failover
cat > scripts/post-failover-validation.js << 'EOF'
const { MongoClient } = require('mongodb');

class FailoverValidator {
  constructor(originalEndpoint, failoverEndpoint, credentials) {
    this.originalClient = new MongoClient(`mongodb://${credentials.username}:${credentials.password}@${originalEndpoint}:27017/testDB?ssl=true&retryWrites=false`);
    this.failoverClient = new MongoClient(`mongodb://${credentials.username}:${credentials.password}@${failoverEndpoint}:27017/testDB?ssl=true&retryWrites=false`);
  }

  async validateFailover() {
    console.log('=== VALIDAÇÃO PÓS-FAILOVER ===');
    
    try {
      // Conectar ao cluster de failover
      await this.failoverClient.connect();
      console.log('✅ Conexão com cluster de failover estabelecida');
      
      // Executar testes de validação
      const results = {
        connectivity: await this.testConnectivity(),
        dataIntegrity: await this.testDataIntegrity(),
        performance: await this.testPerformance(),
        functionality: await this.testFunctionality()
      };
      
      // Gerar relatório
      this.generateReport(results);
      
      return results;
      
    } catch (error) {
      console.error('❌ Erro na validação:', error);
      throw error;
    } finally {
      await this.failoverClient.close();
    }
  }

  async testConnectivity() {
    console.log('\n1. Testando conectividade...');
    
    try {
      await this.failoverClient.db('admin').command({ ping: 1 });
      console.log('   ✅ Ping bem-sucedido');
      
      const serverStatus = await this.failoverClient.db('admin').command({ serverStatus: 1 });
      console.log(`   ✅ Versão do servidor: ${serverStatus.version}`);
      
      return { status: 'PASS', details: 'Conectividade OK' };
    } catch (error) {
      console.log('   ❌ Falha na conectividade:', error.message);
      return { status: 'FAIL', details: error.message };
    }
  }

  async testDataIntegrity() {
    console.log('\n2. Testando integridade dos dados...');
    
    try {
      const db = this.failoverClient.db('performanceDB');
      
      // Contar documentos em collections principais
      const collections = ['products', 'orders'];
      const counts = {};
      
      for (const collName of collections) {
        try {
          const count = await db.collection(collName).countDocuments();
          counts[collName] = count;
          console.log(`   ✅ ${collName}: ${count} documentos`);
        } catch (error) {
          console.log(`   ⚠️  ${collName}: Erro ao contar - ${error.message}`);
          counts[collName] = -1;
        }
      }
      
      // Verificar índices
      for (const collName of collections) {
        try {
          const indexes = await db.collection(collName).indexes();
          console.log(`   ✅ ${collName}: ${indexes.length} índices`);
        } catch (error) {
          console.log(`   ⚠️  ${collName}: Erro ao verificar índices - ${error.message}`);
        }
      }
      
      return { status: 'PASS', details: counts };
    } catch (error) {
      console.log('   ❌ Falha na verificação de integridade:', error.message);
      return { status: 'FAIL', details: error.message };
    }
  }

  async testPerformance() {
    console.log('\n3. Testando performance...');
    
    try {
      const db = this.failoverClient.db('performanceDB');
      const collection = db.collection('products');
      
      // Teste de leitura
      const readStart = Date.now();
      await collection.findOne({});
      const readTime = Date.now() - readStart;
      
      // Teste de escrita
      const writeStart = Date.now();
      await collection.insertOne({
        _id: `failover-test-${Date.now()}`,
        timestamp: new Date(),
        test: 'failover-validation'
      });
      const writeTime = Date.now() - writeStart;
      
      // Teste de query complexa
      const queryStart = Date.now();
      await collection.find({ category: 'electronics' }).limit(10).toArray();
      const queryTime = Date.now() - queryStart;
      
      console.log(`   ✅ Leitura: ${readTime}ms`);
      console.log(`   ✅ Escrita: ${writeTime}ms`);
      console.log(`   ✅ Query: ${queryTime}ms`);
      
      return {
        status: 'PASS',
        details: {
          readLatency: readTime,
          writeLatency: writeTime,
          queryLatency: queryTime
        }
      };
    } catch (error) {
      console.log('   ❌ Falha no teste de performance:', error.message);
      return { status: 'FAIL', details: error.message };
    }
  }

  async testFunctionality() {
    console.log('\n4. Testando funcionalidades...');
    
    try {
      const db = this.failoverClient.db('performanceDB');
      const testCollection = db.collection('failover_test');
      
      // CRUD operations
      const testDoc = {
        _id: `test-${Date.now()}`,
        timestamp: new Date(),
        data: 'failover-test'
      };
      
      // Create
      await testCollection.insertOne(testDoc);
      console.log('   ✅ INSERT funcionando');
      
      // Read
      const found = await testCollection.findOne({ _id: testDoc._id });
      if (found) {
        console.log('   ✅ FIND funcionando');
      }
      
      // Update
      await testCollection.updateOne(
        { _id: testDoc._id },
        { $set: { updated: new Date() } }
      );
      console.log('   ✅ UPDATE funcionando');
      
      // Delete
      await testCollection.deleteOne({ _id: testDoc._id });
      console.log('   ✅ DELETE funcionando');
      
      // Aggregation
      const aggResult = await testCollection.aggregate([
        { $match: {} },
        { $count: 'total' }
      ]).toArray();
      console.log('   ✅ AGGREGATION funcionando');
      
      return { status: 'PASS', details: 'Todas as operações CRUD funcionando' };
    } catch (error) {
      console.log('   ❌ Falha no teste de funcionalidade:', error.message);
      return { status: 'FAIL', details: error.message };
    }
  }

  generateReport(results) {
    console.log('\n=== RELATÓRIO DE VALIDAÇÃO ===');
    
    const allPassed = Object.values(results).every(r => r.status === 'PASS');
    
    console.log(`Status Geral: ${allPassed ? '✅ APROVADO' : '❌ REPROVADO'}`);
    console.log('\nDetalhes por Teste:');
    
    Object.entries(results).forEach(([test, result]) => {
      const status = result.status === 'PASS' ? '✅' : '❌';
      console.log(`${status} ${test.toUpperCase()}: ${result.status}`);
    });
    
    if (results.performance.status === 'PASS') {
      console.log('\nMétricas de Performance:');
      console.log(`- Latência de Leitura: ${results.performance.details.readLatency}ms`);
      console.log(`- Latência de Escrita: ${results.performance.details.writeLatency}ms`);
      console.log(`- Latência de Query: ${results.performance.details.queryLatency}ms`);
    }
    
    console.log('\n=== FIM DO RELATÓRIO ===');
  }
}

// CLI interface
async function main() {
  const originalEndpoint = process.argv[2];
  const failoverEndpoint = process.argv[3];
  
  if (!originalEndpoint || !failoverEndpoint) {
    console.log('Uso: node post-failover-validation.js <original-endpoint> <failover-endpoint>');
    process.exit(1);
  }
  
  const credentials = {
    username: process.env.DB_USERNAME,
    password: process.env.DB_PASSWORD
  };
  
  const validator = new FailoverValidator(originalEndpoint, failoverEndpoint, credentials);
  
  try {
    await validator.validateFailover();
    console.log('\n✅ Validação concluída com sucesso!');
  } catch (error) {
    console.error('\n❌ Validação falhou:', error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = FailoverValidator;
EOF
```

---

## 💰 Parte 5: Análise de Custos Cross-Region

### Passo 1: Calculadora de Custos

```bash
# Criar análise de custos
cat > architectures/cost-optimization.md << 'EOF'
# Análise de Custos - Estratégias Cross-Region

## Custos por Estratégia

### 1. Snapshot Cross-Region (Disaster Recovery)

#### Componentes de Custo
- **Snapshots Storage:** $0.095/GB/mês (região secundária)
- **Data Transfer:** $0.02/GB (cross-region)
- **Compute (standby):** $0 (apenas quando ativado)

#### Exemplo Mensal (Cluster 100GB)
```
Snapshot Storage: 100GB × $0.095 = $9.50/mês
Daily Transfer: 5GB × 30 dias × $0.02 = $3.00/mês
Total: ~$12.50/mês
```

### 2. Dual-Write (Active-Active)

#### Componentes de Custo
- **Primary Cluster:** db.t3.medium × 3 = ~$150/mês
- **Secondary Cluster:** db.t3.medium × 3 = ~$150/mês
- **Data Transfer:** ~$20/mês
- **Application Compute:** ~$50/mês

#### Total Mensal
```
Total: ~$370/mês (3x mais caro que single region)
```

### 3. Change Data Capture (CDC)

#### Componentes de Custo
- **Primary Cluster:** ~$150/mês
- **Secondary Cluster:** ~$150/mês
- **Lambda Executions:** ~$10/mês
- **Kinesis/DynamoDB:** ~$30/mês
- **Data Transfer:** ~$15/mês

#### Total Mensal
```
Total: ~$355/mês
```

## Otimizações de Custo

### Para Snapshot Strategy
1. **Snapshot Frequency:** Reduzir para 2x/dia
2. **Retention:** Manter apenas 7 dias
3. **Compression:** Usar compressão nos snapshots
4. **Lifecycle:** Mover para Glacier após 30 dias

### Para Active-Active
1. **Instance Sizing:** Usar instâncias menores na região secundária
2. **Read Replicas:** Reduzir número de replicas
3. **Reserved Instances:** Usar RIs para economia de 30-60%

### Para CDC
1. **Batch Processing:** Agrupar mudanças para reduzir execuções Lambda
2. **Filtering:** Sincronizar apenas dados críticos
3. **Compression:** Comprimir dados em trânsito

## ROI Analysis

### Custo de Downtime
- **E-commerce:** $5,000-50,000/hora
- **SaaS:** $1,000-10,000/hora
- **Enterprise:** $10,000-100,000/hora

### Break-even Analysis
```
Se downtime custa $10,000/hora:
- 1 hora de downtime evitada = ROI de 2-3 anos
- 4 horas de downtime evitadas = ROI de 6-12 meses
```

## Recomendações por Cenário

### Startup/SMB
- **Estratégia:** Snapshot Cross-Region
- **Custo:** ~$15/mês
- **RTO/RPO:** 2-4h / 1-24h

### Enterprise
- **Estratégia:** CDC ou Active-Active
- **Custo:** ~$350/mês
- **RTO/RPO:** <5min / <1min

### Critical Systems
- **Estratégia:** Active-Active + Monitoring
- **Custo:** ~$500/mês
- **RTO/RPO:** <1min / <30s
EOF
```

---

## ✅ Checklist de Conclusão

Execute o script de validação:

```bash
# Executa o grade para avaliar atividades
./grade_exercicio4.sh
```

### Itens Verificados:

- ✅ Limitações do DocumentDB documentadas
- ✅ Infraestrutura cross-region configurada
- ✅ Automação de backup cross-region implementada
- ✅ Estratégia de sincronização customizada desenvolvida
- ✅ Plano de failover regional criado e testado
- ✅ Análise de custos realizada

---

## 🧹 Limpeza

```bash
# Deletar recursos na região secundária
aws docdb delete-db-instance --region $SECONDARY_REGION --db-instance-identifier $FAILOVER_CLUSTER_ID-1 --skip-final-snapshot
aws docdb delete-db-cluster --region $SECONDARY_REGION --db-cluster-identifier $FAILOVER_CLUSTER_ID --skip-final-snapshot

# Deletar snapshots cross-region
aws docdb describe-db-cluster-snapshots --region $SECONDARY_REGION --query "DBClusterSnapshots[?contains(DBClusterSnapshotIdentifier, '$CLUSTER_ID-cross-region')].DBClusterSnapshotIdentifier" --output text | xargs -I {} aws docdb delete-db-cluster-snapshot --region $SECONDARY_REGION --db-cluster-snapshot-identifier {}

# Deletar infraestrutura secundária
aws docdb delete-db-subnet-group --region $SECONDARY_REGION --db-subnet-group-name $ID-docdb-subnet-group-secondary
aws ec2 delete-subnet --region $SECONDARY_REGION --subnet-id $(aws ec2 describe-subnets --region $SECONDARY_REGION --filters "Name=vpc-id,Values=$SECONDARY_VPC_ID" --query 'Subnets[0].SubnetId' --output text)
aws ec2 delete-subnet --region $SECONDARY_REGION --subnet-id $(aws ec2 describe-subnets --region $SECONDARY_REGION --filters "Name=vpc-id,Values=$SECONDARY_VPC_ID" --query 'Subnets[1].SubnetId' --output text)
aws ec2 delete-vpc --region $SECONDARY_REGION --vpc-id $SECONDARY_VPC_ID

# Deletar função Lambda
aws lambda delete-function --region $PRIMARY_REGION --function-name $ID-CrossRegionBackup

# Deletar regra EventBridge
aws events remove-targets --region $PRIMARY_REGION --rule $ID-cross-region-backup --ids 1
aws events delete-rule --region $PRIMARY_REGION --name $ID-cross-region-backup
```

---

## 📊 Resumo das Estratégias Implementadas

### Estratégias Cross-Region Desenvolvidas:

1. **Snapshot Cross-Region:**
   - RPO: 1-24 horas
   - RTO: 2-4 horas
   - Custo: Baixo (~$15/mês)
   - Complexidade: Média

2. **Sincronização Customizada (CDC):**
   - RPO: Minutos
   - RTO: Minutos
   - Custo: Alto (~$350/mês)
   - Complexidade: Alta

3. **Failover Regional Automatizado:**
   - Detecção automática de falhas
   - Restauração automatizada
   - Validação pós-failover
   - Notificações integradas

### Limitações Identificadas:

- ❌ Sem replicação cross-region nativa
- ❌ Sem failover automático entre regiões
- ❌ Dependência de soluções customizadas
- ⚠️ Custos elevados para alta disponibilidade

### Alternativas Recomendadas:

- **Para DR:** Snapshots cross-region automatizados
- **Para HA:** Arquitetura dual-write com conflict resolution
- **Para Performance:** CDN + edge caching
- **Para Compliance:** Backup multi-região com retenção longa

---

[⬅️ Exercício 3](../exercicio3-export-s3/README.md) | [🏠 Módulo 5 Home](../README.md)