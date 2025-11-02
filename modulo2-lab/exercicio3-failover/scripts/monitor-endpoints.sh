#!/bin/bash

# Script para monitorar endpoints do DocumentDB continuamente
# Usado para medir disponibilidade durante failover
# Uso: ./monitor-endpoints.sh <cluster-identifier> [interval-seconds]

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir uso
usage() {
    echo "Uso: $0 <cluster-identifier> [interval-seconds]"
    echo ""
    echo "Exemplos:"
    echo "  $0 lab-cluster-console"
    echo "  $0 lab-cluster-console 2"
    exit 1
}

# Verificar argumentos
if [ $# -lt 1 ]; then
    usage
fi

CLUSTER_ID=$1
INTERVAL=${2:-1}
LOG_FILE="endpoint-monitor-$(date +%Y%m%d-%H%M%S).log"

# Obter informações do cluster
CLUSTER_ENDPOINT=$(aws docdb describe-db-clusters \
    --db-cluster-identifier "$CLUSTER_ID" \
    --query 'DBClusters[0].Endpoint' \
    --output text)

READER_ENDPOINT=$(aws docdb describe-db-clusters \
    --db-cluster-identifier "$CLUSTER_ID" \
    --query 'DBClusters[0].ReaderEndpoint' \
    --output text)

PORT=$(aws docdb describe-db-clusters \
    --db-cluster-identifier "$CLUSTER_ID" \
    --query 'DBClusters[0].Port' \
    --output text)

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}      DocumentDB Endpoint Availability Monitor         ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Cluster:${NC}          $CLUSTER_ID"
echo -e "${YELLOW}Writer Endpoint:${NC}  $CLUSTER_ENDPOINT:$PORT"
echo -e "${YELLOW}Reader Endpoint:${NC}  $READER_ENDPOINT:$PORT"
echo -e "${YELLOW}Check Interval:${NC}   ${INTERVAL}s"
echo -e "${YELLOW}Log File:${NC}         $LOG_FILE"
echo ""
echo -e "${BLUE}Pressione Ctrl+C para parar o monitoramento${NC}"
echo ""

# Contadores
SUCCESS_COUNT=0
FAILURE_COUNT=0
DOWNTIME_START=0
TOTAL_DOWNTIME=0
LAST_STATUS="unknown"

# Função para testar conectividade
test_endpoint() {
    local endpoint=$1
    local port=$2
    
    # Usar timeout para testar conectividade TCP
    timeout 2 bash -c ">/dev/tcp/${endpoint}/${port}" 2>/dev/null
    return $?
}

# Função para logging
log_event() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)] $1" >> "$LOG_FILE"
}

# Trap para cleanup
cleanup() {
    echo ""
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📊 Estatísticas do Monitoramento${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    TOTAL_CHECKS=$((SUCCESS_COUNT + FAILURE_COUNT))
    if [ $TOTAL_CHECKS -gt 0 ]; then
        AVAILABILITY=$(awk "BEGIN {printf \"%.2f\", ($SUCCESS_COUNT / $TOTAL_CHECKS) * 100}")
        echo -e "  ✓ Checks Bem-sucedidos:  ${SUCCESS_COUNT}"
        echo -e "  ✗ Checks Falhados:       ${FAILURE_COUNT}"
        echo -e "  📊 Total de Checks:      ${TOTAL_CHECKS}"
        echo -e "  ⏱️  Downtime Total:       ${TOTAL_DOWNTIME}s"
        echo -e "  📈 Disponibilidade:      ${AVAILABILITY}%"
    fi
    
    echo ""
    echo -e "📄 Log completo: ${YELLOW}${LOG_FILE}${NC}"
    echo ""
    exit 0
}

trap cleanup SIGINT SIGTERM

# Header do log
log_event "═══════════════════════════════════════════════════════"
log_event "Iniciando monitoramento do cluster: $CLUSTER_ID"
log_event "Writer Endpoint: $CLUSTER_ENDPOINT:$PORT"
log_event "Reader Endpoint: $READER_ENDPOINT:$PORT"
log_event "═══════════════════════════════════════════════════════"

# Obter primária inicial
INITIAL_PRIMARY=$(aws docdb describe-db-clusters \
    --db-cluster-identifier "$CLUSTER_ID" \
    --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' \
    --output text)

log_event "Primária Inicial: $INITIAL_PRIMARY"

# Loop de monitoramento
while true; do
    TIMESTAMP=$(date +"%H:%M:%S")
    
    # Testar writer endpoint
    if test_endpoint "$CLUSTER_ENDPOINT" "$PORT"; then
        STATUS="${GREEN}UP${NC}"
        SYMBOL="✓"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        
        # Se estava down, calcular downtime
        if [ "$LAST_STATUS" == "down" ]; then
            DOWNTIME_END=$(date +%s)
            DOWNTIME_DURATION=$((DOWNTIME_END - DOWNTIME_START))
            TOTAL_DOWNTIME=$((TOTAL_DOWNTIME + DOWNTIME_DURATION))
            
            echo ""
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}✅ RECUPERADO após ${DOWNTIME_DURATION}s de downtime${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            
            log_event "✅ RECUPERADO - Downtime: ${DOWNTIME_DURATION}s"
        fi
        
        LAST_STATUS="up"
        
    else
        STATUS="${RED}DOWN${NC}"
        SYMBOL="✗"
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        
        # Se era up, marcar início do downtime
        if [ "$LAST_STATUS" != "down" ]; then
            DOWNTIME_START=$(date +%s)
            
            echo ""
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${RED}❌ ENDPOINT INDISPONÍVEL detectado em $(date)${NC}"
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            
            log_event "❌ DOWNTIME INICIADO"
        fi
        
        LAST_STATUS="down"
    fi
    
    # Obter primária atual
    CURRENT_PRIMARY=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$CLUSTER_ID" \
        --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' \
        --output text 2>/dev/null || echo "unknown")
    
    # Detectar mudança de primária
    if [ "$CURRENT_PRIMARY" != "$INITIAL_PRIMARY" ] && [ "$CURRENT_PRIMARY" != "unknown" ]; then
        PRIMARY_INDICATOR="${YELLOW}[FAILOVER: $INITIAL_PRIMARY → $CURRENT_PRIMARY]${NC}"
        log_event "🔄 FAILOVER DETECTADO: $INITIAL_PRIMARY → $CURRENT_PRIMARY"
        INITIAL_PRIMARY=$CURRENT_PRIMARY
    else
        PRIMARY_INDICATOR=""
    fi
    
    # Obter métricas do cluster
    CLUSTER_STATUS=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$CLUSTER_ID" \
        --query 'DBClusters[0].Status' \
        --output text 2>/dev/null || echo "unknown")
    
    # Exibir status
    echo -e "$TIMESTAMP | $SYMBOL | Writer: $STATUS | Primary: ${CURRENT_PRIMARY} | Cluster: ${CLUSTER_STATUS} ${PRIMARY_INDICATOR}"
    
    # Log do evento
    log_event "Writer: $([ "$LAST_STATUS" == "up" ] && echo "UP" || echo "DOWN") | Primary: $CURRENT_PRIMARY | Cluster: $CLUSTER_STATUS"
    
    sleep "$INTERVAL"
done
