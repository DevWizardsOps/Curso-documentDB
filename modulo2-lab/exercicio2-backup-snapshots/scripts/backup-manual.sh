#!/bin/bash

# Script para criar snapshot manual do DocumentDB
# Uso: ./backup-manual.sh <cluster-identifier> [snapshot-suffix]

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para exibir uso
usage() {
    echo "Uso: $0 <cluster-identifier> [snapshot-suffix]"
    echo ""
    echo "Exemplos:"
    echo "  $0 lab-cluster-console"
    echo "  $0 lab-cluster-console pre-migration"
    exit 1
}

# Verificar argumentos
if [ $# -lt 1 ]; then
    usage
fi

CLUSTER_ID=$1
SUFFIX=${2:-$(date +%Y%m%d-%H%M%S)}
SNAPSHOT_ID="${CLUSTER_ID}-snapshot-${SUFFIX}"

echo -e "${YELLOW}📸 Criando snapshot do cluster: ${CLUSTER_ID}${NC}"
echo -e "${YELLOW}🏷️  Snapshot ID: ${SNAPSHOT_ID}${NC}"
echo ""

# Verificar se o cluster existe
echo "🔍 Verificando se o cluster existe..."
if ! aws docdb describe-db-clusters \
    --db-cluster-identifier "$CLUSTER_ID" \
    --query 'DBClusters[0].DBClusterIdentifier' \
    --output text &>/dev/null; then
    echo -e "${RED}❌ Erro: Cluster '${CLUSTER_ID}' não encontrado${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Cluster encontrado${NC}"
echo ""

STUDENT_ID=$(echo $CLUSTER_ID | cut -d'-' -f1)

# Criar snapshot
echo "🚀 Criando snapshot..."
aws docdb create-db-cluster-snapshot \
    --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
    --db-cluster-identifier "$CLUSTER_ID" \
    --tags \
        Key=CreatedBy,Value=backup-script \
        Key=CreatedAt,Value=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
        Key=Purpose,Value=manual-backup \
        Key=Student,Value=$STUDENT_ID

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Snapshot criado com sucesso!${NC}"
    echo ""
else
    echo -e "${RED}❌ Erro ao criar snapshot${NC}"
    exit 1
fi

# Monitorar progresso
echo "⏳ Monitorando progresso do snapshot..."
echo ""

while true; do
    STATUS=$(aws docdb describe-db-cluster-snapshots \
        --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
        --query 'DBClusterSnapshots[0].Status' \
        --output text 2>/dev/null)
    
    PROGRESS=$(aws docdb describe-db-cluster-snapshots \
        --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
        --query 'DBClusterSnapshots[0].PercentProgress' \
        --output text 2>/dev/null)
    
    if [ "$STATUS" == "available" ]; then
        echo -e "\n${GREEN}✅ Snapshot concluído!${NC}"
        break
    elif [ "$STATUS" == "failed" ]; then
        echo -e "\n${RED}❌ Snapshot falhou!${NC}"
        exit 1
    else
        echo -ne "\r📊 Status: ${STATUS} | Progresso: ${PROGRESS}%  "
        sleep 10
    fi
done

# Exibir informações do snapshot
echo ""
echo "📋 Informações do Snapshot:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

aws docdb describe-db-cluster-snapshots \
    --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
    --query 'DBClusterSnapshots[0].[
        DBClusterSnapshotIdentifier,
        Status,
        SnapshotCreateTime,
        AllocatedStorage,
        Engine,
        EngineVersion
    ]' \
    --output table

echo ""
echo -e "${GREEN}✅ Backup concluído com sucesso!${NC}"
echo ""
echo "Para restaurar este snapshot, use:"
echo "  ./restore-snapshot.sh ${SNAPSHOT_ID} <novo-cluster-id>"
