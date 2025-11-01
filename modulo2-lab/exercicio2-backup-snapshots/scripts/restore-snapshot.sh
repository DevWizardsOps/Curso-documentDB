#!/bin/bash

# Script para restaurar snapshot do DocumentDB
# Uso: ./restore-snapshot.sh <snapshot-id> <novo-cluster-id> [instance-class] [instance-count]

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir uso
usage() {
    echo "Uso: $0 <snapshot-id> <novo-cluster-id> [instance-class] [instance-count]"
    echo ""
    echo "Parâmetros:"
    echo "  snapshot-id      : ID do snapshot a ser restaurado"
    echo "  novo-cluster-id  : ID do novo cluster a ser criado"
    echo "  instance-class   : Classe da instância (padrão: db.t3.medium)"
    echo "  instance-count   : Número de instâncias (padrão: 1)"
    echo ""
    echo "Exemplos:"
    echo "  $0 lab-snapshot-001 lab-cluster-restored"
    echo "  $0 lab-snapshot-001 lab-cluster-dev db.t3.medium 2"
    exit 1
}

# Verificar argumentos
if [ $# -lt 2 ]; then
    usage
fi

SNAPSHOT_ID=$1
NEW_CLUSTER_ID=$2
INSTANCE_CLASS=${3:-db.t3.medium}
INSTANCE_COUNT=${4:-1}

echo -e "${YELLOW}🔄 Restaurando snapshot do DocumentDB${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "📸 Snapshot ID:      ${SNAPSHOT_ID}"
echo -e "🆕 Novo Cluster ID:  ${NEW_CLUSTER_ID}"
echo -e "💻 Instance Class:   ${INSTANCE_CLASS}"
echo -e "🔢 Instance Count:   ${INSTANCE_COUNT}"
echo ""

# Verificar se o snapshot existe
echo "🔍 Verificando se o snapshot existe..."
if ! aws docdb describe-db-cluster-snapshots \
    --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
    --query 'DBClusterSnapshots[0].DBClusterSnapshotIdentifier' \
    --output text &>/dev/null; then
    echo -e "${RED}❌ Erro: Snapshot '${SNAPSHOT_ID}' não encontrado${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Snapshot encontrado${NC}"

# Verificar se o cluster já existe
echo "🔍 Verificando se o cluster já existe..."
if aws docdb describe-db-clusters \
    --db-cluster-identifier "$NEW_CLUSTER_ID" \
    --query 'DBClusters[0].DBClusterIdentifier' \
    --output text &>/dev/null; then
    echo -e "${RED}❌ Erro: Cluster '${NEW_CLUSTER_ID}' já existe${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Nome do cluster está disponível${NC}"
echo ""

# Obter informações do snapshot
echo "📋 Informações do Snapshot:"
SNAPSHOT_INFO=$(aws docdb describe-db-cluster-snapshots \
    --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
    --query 'DBClusterSnapshots[0].[Engine, EngineVersion, VpcId]' \
    --output text)

ENGINE=$(echo $SNAPSHOT_INFO | awk '{print $1}')
ENGINE_VERSION=$(echo $SNAPSHOT_INFO | awk '{print $2}')
VPC_ID=$(echo $SNAPSHOT_INFO | awk '{print $3}')

echo "  Engine: ${ENGINE}"
echo "  Version: ${ENGINE_VERSION}"
echo "  VPC: ${VPC_ID}"
echo ""

# Obter subnet group e security group
echo "🔍 Buscando subnet group e security group..."
SUBNET_GROUP=$(aws docdb describe-db-subnet-groups \
    --query "DBSubnetGroups[?VpcId=='${VPC_ID}'] | [0].DBSubnetGroupName" \
    --output text)

if [ "$SUBNET_GROUP" == "None" ] || [ -z "$SUBNET_GROUP" ]; then
    echo -e "${RED}❌ Erro: Nenhum subnet group encontrado para a VPC${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Subnet Group: ${SUBNET_GROUP}${NC}"

# Buscar security group (assumindo nome padrão do lab)
SECURITY_GROUP=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=*docdb*" "Name=vpc-id,Values=${VPC_ID}" \
    --query 'SecurityGroups[0].GroupId' \
    --output text)

if [ "$SECURITY_GROUP" == "None" ] || [ -z "$SECURITY_GROUP" ]; then
    echo -e "${YELLOW}⚠️  Aviso: Security group padrão será usado${NC}"
    SECURITY_GROUP=""
else
    echo -e "${GREEN}✓ Security Group: ${SECURITY_GROUP}${NC}"
fi

echo ""

# Restaurar o cluster
echo "🚀 Restaurando cluster do snapshot..."
RESTORE_CMD="aws docdb restore-db-cluster-from-snapshot \
    --db-cluster-identifier $NEW_CLUSTER_ID \
    --snapshot-identifier $SNAPSHOT_ID \
    --engine $ENGINE \
    --db-subnet-group-name $SUBNET_GROUP"

if [ -n "$SECURITY_GROUP" ]; then
    RESTORE_CMD="$RESTORE_CMD --vpc-security-group-ids $SECURITY_GROUP"
fi

RESTORE_CMD="$RESTORE_CMD --tags Key=RestoredFrom,Value=$SNAPSHOT_ID Key=RestoredAt,Value=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

eval $RESTORE_CMD

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Cluster restaurado com sucesso!${NC}"
    echo ""
else
    echo -e "${RED}❌ Erro ao restaurar cluster${NC}"
    exit 1
fi

# Aguardar cluster estar disponível
echo "⏳ Aguardando cluster estar disponível..."
aws docdb wait db-cluster-available --db-cluster-identifier "$NEW_CLUSTER_ID"
echo -e "${GREEN}✓ Cluster disponível${NC}"
echo ""

# Criar instâncias
echo "🖥️  Criando ${INSTANCE_COUNT} instância(s)..."
for i in $(seq 1 $INSTANCE_COUNT); do
    INSTANCE_ID="${NEW_CLUSTER_ID}-${i}"
    echo "  Criando instância: ${INSTANCE_ID}"
    
    aws docdb create-db-instance \
        --db-instance-identifier "$INSTANCE_ID" \
        --db-instance-class "$INSTANCE_CLASS" \
        --db-cluster-identifier "$NEW_CLUSTER_ID" \
        --engine "$ENGINE" \
        --tags Key=Instance,Value=$i > /dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ Instância ${i} criada${NC}"
    else
        echo -e "  ${RED}✗ Erro ao criar instância ${i}${NC}"
    fi
done

echo ""
echo "⏳ Aguardando instâncias ficarem disponíveis..."
echo "  (Isso pode levar ~10-15 minutos)"
echo ""

# Aguardar todas as instâncias
for i in $(seq 1 $INSTANCE_COUNT); do
    INSTANCE_ID="${NEW_CLUSTER_ID}-${i}"
    echo "  Aguardando: ${INSTANCE_ID}..."
    aws docdb wait db-instance-available --db-instance-identifier "$INSTANCE_ID"
    echo -e "  ${GREEN}✓ ${INSTANCE_ID} disponível${NC}"
done

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Restauração concluída com sucesso!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Exibir informações do cluster restaurado
echo "📋 Informações do Cluster Restaurado:"
ENDPOINT=$(aws docdb describe-db-clusters \
    --db-cluster-identifier "$NEW_CLUSTER_ID" \
    --query 'DBClusters[0].Endpoint' \
    --output text)

READER_ENDPOINT=$(aws docdb describe-db-clusters \
    --db-cluster-identifier "$NEW_CLUSTER_ID" \
    --query 'DBClusters[0].ReaderEndpoint' \
    --output text)

PORT=$(aws docdb describe-db-clusters \
    --db-cluster-identifier "$NEW_CLUSTER_ID" \
    --query 'DBClusters[0].Port' \
    --output text)

echo ""
echo "  Cluster ID:        ${NEW_CLUSTER_ID}"
echo "  Endpoint:          ${ENDPOINT}"
echo "  Reader Endpoint:   ${READER_ENDPOINT}"
echo "  Port:              ${PORT}"
echo "  Instâncias:        ${INSTANCE_COUNT}"
echo ""

echo "🔗 String de Conexão:"
echo "  mongosh --host ${ENDPOINT}:${PORT} \\"
echo "    --username <seu-usuario> \\"
echo "    --password <sua-senha> \\"
echo "    --tls \\"
echo "    --tlsCAFile global-bundle.pem"
echo ""

echo -e "${BLUE}💡 Dica: Não esqueça de deletar este cluster quando não precisar mais dele!${NC}"
echo "  aws docdb delete-db-cluster --db-cluster-identifier ${NEW_CLUSTER_ID} --skip-final-snapshot"
