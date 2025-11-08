#!/bin/bash

# Script para testar failover do DocumentDB e medir RTO
# Uso: ./test-failover.sh <cluster-identifier>

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Função para exibir uso
usage() {
    echo "Uso: $0 <cluster-identifier>"
    echo ""
    echo "Exemplo:"
    echo "  $0 lab-cluster-console"
    exit 1
}

# Verificar argumentos
if [ $# -lt 1 ]; then
    usage
fi

CLUSTER_ID=$1
LOG_FILE="failover-test-$(date +%Y%m%d-%H%M%S).log"

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}       DocumentDB Failover Test & RTO Measurement      ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Cluster:${NC} $CLUSTER_ID"
echo -e "${YELLOW}Log File:${NC} $LOG_FILE"
echo ""

# Função para logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Verificar se o cluster existe
log "🔍 Verificando se o cluster existe..."
if ! aws docdb describe-db-clusters \
    --db-cluster-identifier "$CLUSTER_ID" \
    --query 'DBClusters[0].DBClusterIdentifier' \
    --output text &>/dev/null; then
    echo -e "${RED}❌ Erro: Cluster '${CLUSTER_ID}' não encontrado${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Cluster encontrado${NC}"
log "✓ Cluster encontrado"
echo ""

# Obter estado inicial
log "📊 Coletando estado inicial do cluster..."
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

INITIAL_PRIMARY=$(aws docdb describe-db-clusters \
    --db-cluster-identifier "$CLUSTER_ID" \
    --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' \
    --output text)

TOTAL_INSTANCES=$(aws docdb describe-db-clusters \
    --db-cluster-identifier "$CLUSTER_ID" \
    --query 'length(DBClusters[0].DBClusterMembers)' \
    --output text)

CLUSTER_ENDPOINT=$(aws docdb describe-db-clusters \
    --db-cluster-identifier "$CLUSTER_ID" \
    --query 'DBClusters[0].Endpoint' \
    --output text)

echo ""
echo -e "${YELLOW}Estado Inicial:${NC}"
echo -e "  ├─ Instância Primária: ${GREEN}${INITIAL_PRIMARY}${NC}"
echo -e "  ├─ Total de Instâncias: ${TOTAL_INSTANCES}"
echo -e "  └─ Cluster Endpoint: ${CLUSTER_ENDPOINT}"
echo ""

log "Estado inicial: Primary=$INITIAL_PRIMARY, Instances=$TOTAL_INSTANCES"

# Listar todas as instâncias
echo -e "${YELLOW}Topologia do Cluster:${NC}"
aws docdb describe-db-clusters \
    --db-cluster-identifier "$CLUSTER_ID" \
    --query 'DBClusters[0].DBClusterMembers[*].[DBInstanceIdentifier, IsClusterWriter, PromotionTier]' \
    --output table

echo ""

# Confirmar antes de prosseguir
echo -e "${YELLOW}⚠️  Aviso: Este teste irá executar um failover no cluster!${NC}"
read -p "Deseja continuar? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Teste cancelado pelo usuário${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}🚀 Iniciando Failover...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Registrar tempo de início
START_TIME=$(date +%s)
log "⏱️  Tempo de início: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Executar failover
log "🔄 Executando comando de failover..."
aws docdb failover-db-cluster \
    --db-cluster-identifier "$CLUSTER_ID" 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo -e "${GREEN}✓ Comando de failover executado${NC}"
    log "✓ Comando de failover aceito"
else
    echo -e "${RED}❌ Erro ao executar failover${NC}"
    log "❌ Erro ao executar failover"
    exit 1
fi

echo ""
echo -e "⏳ Aguardando failover completar..."
echo ""

# Monitorar o progresso
DETECTED_CHANGE=false
FAILOVER_COMPLETE=false
CHECK_COUNT=0
MAX_CHECKS=60  # 5 minutos máximo

while [ $CHECK_COUNT -lt $MAX_CHECKS ]; do
    CHECK_COUNT=$((CHECK_COUNT + 1))
    
    # Obter status atual
    CURRENT_STATUS=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$CLUSTER_ID" \
        --query 'DBClusters[0].Status' \
        --output text 2>/dev/null)
    
    CURRENT_PRIMARY=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$CLUSTER_ID" \
        --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' \
        --output text 2>/dev/null)
    
    # Detectar quando a primária muda
    if [ "$CURRENT_PRIMARY" != "$INITIAL_PRIMARY" ] && [ "$DETECTED_CHANGE" = false ]; then
        CHANGE_TIME=$(date +%s)
        CHANGE_DURATION=$((CHANGE_TIME - START_TIME))
        echo ""
        echo -e "${YELLOW}🔄 Detectada mudança de primária após ${CHANGE_DURATION}s${NC}"
        log "🔄 Mudança detectada após ${CHANGE_DURATION}s: $INITIAL_PRIMARY -> $CURRENT_PRIMARY"
        DETECTED_CHANGE=true
    fi
    
    # Verificar se completou
    if [ "$CURRENT_STATUS" == "available" ] && [ "$DETECTED_CHANGE" = true ]; then
        COMPLETE_TIME=$(date +%s)
        TOTAL_DURATION=$((COMPLETE_TIME - START_TIME))
        echo -e "${GREEN}✅ Failover completado após ${TOTAL_DURATION}s${NC}"
        log "✅ Failover completo após ${TOTAL_DURATION}s"
        FAILOVER_COMPLETE=true
        break
    fi
    
    # Exibir progresso
    echo -ne "\r⏱️  Tempo decorrido: ${CHECK_COUNT}s | Status: ${CURRENT_STATUS} | Primary: ${CURRENT_PRIMARY}     "
    sleep 1
done

echo ""
echo ""

if [ "$FAILOVER_COMPLETE" = false ]; then
    echo -e "${RED}❌ Timeout: Failover não completou em ${MAX_CHECKS}s${NC}"
    log "❌ Timeout após ${MAX_CHECKS}s"
    exit 1
fi

# Coletar estado final
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📊 Resultados do Teste de Failover${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

FINAL_PRIMARY=$(aws docdb describe-db-clusters \
    --db-cluster-identifier "$CLUSTER_ID" \
    --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' \
    --output text)

FINAL_STATUS=$(aws docdb describe-db-clusters \
    --db-cluster-identifier "$CLUSTER_ID" \
    --query 'DBClusters[0].Status' \
    --output text)

# Calcular métricas
RTO=$TOTAL_DURATION
DETECTION_TIME=${CHANGE_DURATION:-$TOTAL_DURATION}

echo -e "${YELLOW}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "${YELLOW}│  Métricas de Recuperação (RTO)                     │${NC}"
echo -e "${YELLOW}└─────────────────────────────────────────────────────┘${NC}"
echo ""
echo -e "  📍 Primária Inicial:     ${INITIAL_PRIMARY}"
echo -e "  📍 Primária Final:       ${GREEN}${FINAL_PRIMARY}${NC}"
echo -e "  🔄 Tempo de Detecção:    ${GREEN}${DETECTION_TIME}s${NC} (mudança de primária)"
echo -e "  ⏱️  RTO Total:            ${GREEN}${RTO}s${NC} (cluster disponível)"
echo -e "  📊 Status Final:         ${FINAL_STATUS}"
echo -e "  🌐 Endpoint:             ${CLUSTER_ENDPOINT} (inalterado)"
echo ""

# Log das métricas
log "═══════════════════════════════════════════════════════"
log "MÉTRICAS FINAIS:"
log "  Primária Inicial: $INITIAL_PRIMARY"
log "  Primária Final: $FINAL_PRIMARY"
log "  Tempo de Detecção (mudança): ${DETECTION_TIME}s"
log "  RTO Total (disponível): ${RTO}s"
log "  Status: $FINAL_STATUS"
log "═══════════════════════════════════════════════════════"

# Análise de performance
echo -e "${YELLOW}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "${YELLOW}│  Análise de Performance                             │${NC}"
echo -e "${YELLOW}└─────────────────────────────────────────────────────┘${NC}"
echo ""

echo -e "  📝 ${BLUE}Explicação dos Tempos:${NC}"
echo -e "     • Tempo de Detecção: quando a nova primária assume"
echo -e "     • RTO Total: quando o cluster fica completamente disponível"
echo ""

if [ $RTO -lt 60 ]; then
    echo -e "  ${GREEN}✅ Excelente: RTO < 60s (Target: 30-120s)${NC}"
elif [ $RTO -lt 120 ]; then
    echo -e "  ${GREEN}✅ Bom: RTO dentro do esperado (30-120s)${NC}"
else
    echo -e "  ${YELLOW}⚠️  Atenção: RTO acima do esperado (>120s)${NC}"
fi

echo ""

# Listar topologia final
echo -e "${YELLOW}Topologia Final do Cluster:${NC}"
aws docdb describe-db-clusters \
    --db-cluster-identifier "$CLUSTER_ID" \
    --query 'DBClusters[0].DBClusterMembers[*].[DBInstanceIdentifier, IsClusterWriter, PromotionTier]' \
    --output table

echo ""

# Recomendações
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}💡 Recomendações${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  • Documente este RTO para seu playbook de DR"
echo -e "  • Configure suas aplicações para reconectar automaticamente"
echo -e "  • Use sempre o cluster endpoint, não endpoints de instâncias"
echo -e "  • Teste failover regularmente (ex: trimestralmente)"
echo -e "  • Configure alarmes CloudWatch para eventos de failover"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Teste de Failover Concluído com Sucesso!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "📄 Log completo salvo em: ${YELLOW}${LOG_FILE}${NC}"
echo ""
