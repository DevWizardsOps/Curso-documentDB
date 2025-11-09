# Comandos Básicos AWS CLI para DocumentDB

## Pré-requisitos

### Instalação do AWS CLI
```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Windows
# Baixar e instalar o MSI do site oficial da AWS
```

### Configuração Inicial
```bash
# Configurar credenciais
aws configure

# Verificar configuração
aws sts get-caller-identity

# Definir região padrão (opcional)
export AWS_DEFAULT_REGION=us-east-1
```

## Comandos de Consulta (Sem Criar Recursos)

### 1. Listar Clusters Existentes

```bash
# Listar todos os clusters
aws docdb describe-db-clusters

# Listar clusters com output formatado
aws docdb describe-db-clusters --output table

# Listar apenas nomes dos clusters
aws docdb describe-db-clusters \
  --query 'DBClusters[].DBClusterIdentifier' \
  --output text

# Filtrar clusters por status
aws docdb describe-db-clusters \
  --query 'DBClusters[?Status==`available`]'
```

### 2. Obter Informações de Cluster Específico

```bash
# Detalhes de um cluster específico
aws docdb describe-db-clusters \
  --db-cluster-identifier my-cluster

# Obter apenas o endpoint
aws docdb describe-db-clusters \
  --db-cluster-identifier my-cluster \
  --query 'DBClusters[0].Endpoint' \
  --output text

# Obter informações de conectividade
aws docdb describe-db-clusters \
  --db-cluster-identifier my-cluster \
  --query 'DBClusters[0].{Endpoint:Endpoint,Port:Port,Status:Status}'
```

### 3. Listar Instâncias

```bash
# Listar todas as instâncias
aws docdb describe-db-instances

# Listar instâncias de um cluster específico
aws docdb describe-db-instances \
  --filters "Name=db-cluster-id,Values=my-cluster"

# Informações resumidas das instâncias
aws docdb describe-db-instances \
  --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus,DBInstanceClass,AvailabilityZone]' \
  --output table
```

### 4. Verificar Snapshots

```bash
# Listar todos os snapshots
aws docdb describe-db-cluster-snapshots

# Snapshots de um cluster específico
aws docdb describe-db-cluster-snapshots \
  --db-cluster-identifier my-cluster

# Apenas snapshots manuais
aws docdb describe-db-cluster-snapshots \
  --snapshot-type manual

# Snapshots automáticos
aws docdb describe-db-cluster-snapshots \
  --snapshot-type automated
```

### 5. Verificar Parameter Groups

```bash
# Listar parameter groups
aws docdb describe-db-cluster-parameter-groups

# Parâmetros de um group específico
aws docdb describe-db-cluster-parameters \
  --db-cluster-parameter-group-name default.docdb5.0

# Parâmetros modificáveis
aws docdb describe-db-cluster-parameters \
  --db-cluster-parameter-group-name default.docdb5.0 \
  --query 'Parameters[?IsModifiable==`true`]'
```

### 6. Verificar Subnet Groups

```bash
# Listar subnet groups
aws docdb describe-db-subnet-groups

# Detalhes de um subnet group específico
aws docdb describe-db-subnet-groups \
  --db-subnet-group-name default

# Subnets disponíveis
aws docdb describe-db-subnet-groups \
  --query 'DBSubnetGroups[].Subnets[].[SubnetIdentifier,AvailabilityZone.Name]' \
  --output table
```

### 7. Verificar Eventos

```bash
# Eventos recentes
aws docdb describe-events \
  --duration 1440  # últimas 24 horas

# Eventos de um cluster específico
aws docdb describe-events \
  --source-identifier my-cluster \
  --source-type db-cluster

# Eventos por categoria
aws docdb describe-events \
  --event-categories backup,failover,maintenance
```

## Comandos de Monitoramento

### 1. Métricas do CloudWatch

```bash
# Listar métricas disponíveis
aws cloudwatch list-metrics \
  --namespace AWS/DocDB

# Métrica específica de CPU
aws cloudwatch get-metric-statistics \
  --namespace AWS/DocDB \
  --metric-name CPUUtilization \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster \
  --start-time 2024-01-15T00:00:00Z \
  --end-time 2024-01-15T23:59:59Z \
  --period 3600 \
  --statistics Average

# Conexões de banco
aws cloudwatch get-metric-statistics \
  --namespace AWS/DocDB \
  --metric-name DatabaseConnections \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Average,Maximum
```

### 2. Logs do CloudWatch

```bash
# Listar log groups do DocumentDB
aws logs describe-log-groups \
  --log-group-name-prefix /aws/docdb

# Streams de log de um cluster
aws logs describe-log-streams \
  --log-group-name /aws/docdb/my-cluster/audit

# Últimas entradas de log
aws logs get-log-events \
  --log-group-name /aws/docdb/my-cluster/audit \
  --log-stream-name my-cluster-instance-1
```

## Comandos de Validação

### 1. Verificar Conectividade

```bash
# Testar resolução DNS do endpoint
nslookup my-cluster.cluster-xyz.docdb.amazonaws.com

# Testar conectividade de rede (se em VPC)
telnet my-cluster.cluster-xyz.docdb.amazonaws.com 27017

# Verificar security groups
aws ec2 describe-security-groups \
  --group-ids sg-12345678 \
  --query 'SecurityGroups[].IpPermissions[]'
```

### 2. Verificar Configurações

```bash
# Status detalhado do cluster
aws docdb describe-db-clusters \
  --db-cluster-identifier my-cluster \
  --query 'DBClusters[0].{
    Status:Status,
    Engine:Engine,
    EngineVersion:EngineVersion,
    MultiAZ:MultiAZ,
    BackupRetentionPeriod:BackupRetentionPeriod,
    PreferredBackupWindow:PreferredBackupWindow,
    PreferredMaintenanceWindow:PreferredMaintenanceWindow
  }'

# Verificar encryption
aws docdb describe-db-clusters \
  --db-cluster-identifier my-cluster \
  --query 'DBClusters[0].{
    StorageEncrypted:StorageEncrypted,
    KmsKeyId:KmsKeyId
  }'
```

## Scripts Úteis

### 1. Script de Status Completo

```bash
#!/bin/bash
# status-cluster.sh

CLUSTER_ID=$1

if [ -z "$CLUSTER_ID" ]; then
    echo "Uso: $0 <cluster-identifier>"
    exit 1
fi

echo "=== Status do Cluster: $CLUSTER_ID ==="
aws docdb describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --query 'DBClusters[0].{
    Status:Status,
    Endpoint:Endpoint,
    ReaderEndpoint:ReaderEndpoint,
    Port:Port,
    Engine:Engine,
    EngineVersion:EngineVersion
  }' \
  --output table

echo -e "\n=== Instâncias ==="
aws docdb describe-db-instances \
  --filters "Name=db-cluster-id,Values=$CLUSTER_ID" \
  --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus,DBInstanceClass,AvailabilityZone]' \
  --output table

echo -e "\n=== Último Backup ==="
aws docdb describe-db-cluster-snapshots \
  --db-cluster-identifier $CLUSTER_ID \
  --snapshot-type automated \
  --max-items 1 \
  --query 'DBClusterSnapshots[0].{
    SnapshotId:DBClusterSnapshotIdentifier,
    Status:Status,
    SnapshotCreateTime:SnapshotCreateTime
  }' \
  --output table
```

### 2. Script de Monitoramento

```bash
#!/bin/bash
# monitor-cluster.sh

CLUSTER_ID=$1
HOURS=${2:-1}

if [ -z "$CLUSTER_ID" ]; then
    echo "Uso: $0 <cluster-identifier> [horas]"
    exit 1
fi

START_TIME=$(date -u -d "$HOURS hours ago" +%Y-%m-%dT%H:%M:%SZ)
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "=== Métricas do Cluster: $CLUSTER_ID (últimas $HOURS horas) ==="

echo "CPU Utilization:"
aws cloudwatch get-metric-statistics \
  --namespace AWS/DocDB \
  --metric-name CPUUtilization \
  --dimensions Name=DBClusterIdentifier,Value=$CLUSTER_ID \
  --start-time $START_TIME \
  --end-time $END_TIME \
  --period 3600 \
  --statistics Average,Maximum \
  --query 'Datapoints[].{Time:Timestamp,Avg:Average,Max:Maximum}' \
  --output table

echo -e "\nDatabase Connections:"
aws cloudwatch get-metric-statistics \
  --namespace AWS/DocDB \
  --metric-name DatabaseConnections \
  --dimensions Name=DBClusterIdentifier,Value=$CLUSTER_ID \
  --start-time $START_TIME \
  --end-time $END_TIME \
  --period 3600 \
  --statistics Average,Maximum \
  --query 'Datapoints[].{Time:Timestamp,Avg:Average,Max:Maximum}' \
  --output table
```

## Formatação de Output

### JSON (padrão)
```bash
aws docdb describe-db-clusters --output json
```

### Tabela
```bash
aws docdb describe-db-clusters --output table
```

### Texto
```bash
aws docdb describe-db-clusters --output text
```

### YAML
```bash
aws docdb describe-db-clusters --output yaml
```

### JQ para Processamento
```bash
# Instalar jq
brew install jq  # macOS
sudo apt-get install jq  # Ubuntu

# Usar com AWS CLI
aws docdb describe-db-clusters | jq '.DBClusters[].DBClusterIdentifier'

# Filtros complexos
aws docdb describe-db-clusters | \
  jq '.DBClusters[] | select(.Status=="available") | .DBClusterIdentifier'
```

## Próximos Passos

Após dominar os comandos básicos:
1. Pratique com diferentes filtros e queries
2. Crie scripts personalizados para seu ambiente
3. Explore integração com outras ferramentas AWS
4. Continue para [Boto3 Examples](../boto3/exemplos-basicos.py)