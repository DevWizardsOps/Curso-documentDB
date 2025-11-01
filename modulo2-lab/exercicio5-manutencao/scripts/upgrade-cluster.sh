#!/bin/bash

# Script para upgrade automatizado do DocumentDB com validações
# Uso: ./upgrade-cluster.sh <cluster-identifier> <target-version>

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
    echo "Uso: $0 <cluster-identifier> <target-version>"
    echo ""
    echo "Exemplos:"
    echo "  $0 lab-cluster-console 5.0.1"
    echo "  $0 production-cluster 5.0.0"
    exit 1
}

# Verificar argumentos
if [ $# -lt 2 ]; then
    usage
fi

CLUSTER_ID=$1
TARGET_VERSION=$2
LOG_FILE="upgrade-${CLUSTER_ID}-$(date +%Y%m%d-%H%M%S).log"

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}     DocumentDB Cluster Upgrade Automation Tool        ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Cluster:${NC}        $CLUSTER_ID"
echo -e "${YELLOW}Target Version:${NC} $TARGET_VERSION"
echo -e "${YELLOW}Log File:${NC}       $LOG_FILE"
echo ""

# Função para logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "═══════════════════════════════════════════════════════"
log "Iniciando processo de upgrade"
log "Cluster: $CLUSTER_ID | Target: $TARGET_VERSION"
log "═══════════════════════════════════════════════════════"

# ====================================
# FASE 1: VALIDAÇÕES
# ====================================

echo -e "${MAGENTA}FASE 1: Validações Iniciais${NC}"
echo ""

# Verificar se o cluster existe
log "🔍 Verificando se o cluster existe..."
if ! aws docdb describe-db-clusters \
    --db-cluster-identifier "$CLUSTER_ID" \
    --query 'DBClusters[0].DBClusterIdentifier' \
    --output text &>/dev/null; then
    echo -e "${RED}❌ Erro: Cluster '${CLUSTER_ID}' não encontrado${NC}"
    log "❌ Erro: Cluster não encontrado"
    exit 1
fi

echo -e "${GREEN}✓ Cluster encontrado${NC}"
log "✓ Cluster encontrado"

# Obter versão atual
CURRENT_VERSION=$(aws docdb describe-db-clusters \
    --db-cluster-identifier "$CLUSTER_ID" \
    --query 'DBClusters[0].EngineVersion' \
    --output text)

echo ""
echo -e "${YELLOW}Versão Atual:${NC}  $CURRENT_VERSION"
echo -e "${YELLOW}Versão Target:${NC} $TARGET_VERSION"
echo ""

log "Versão atual: $CURRENT_VERSION"
log "Versão target: $TARGET_VERSION"

# Verificar se upgrade é necessário
if [ "$CURRENT_VERSION" == "$TARGET_VERSION" ]; then
    echo -e "${YELLOW}⚠️  Cluster já está na versão $TARGET_VERSION${NC}"
    log "⚠️  Upgrade não necessário - versão já é $TARGET_VERSION"
    exit 0
fi

# Verificar se versão target existe
log "🔍 Verificando se versão $TARGET_VERSION está disponível..."
AVAILABLE=$(aws docdb describe-db-engine-versions \
    --engine docdb \
    --engine-version "$TARGET_VERSION" \
    --query 'DBEngineVersions[0].EngineVersion' \
    --output text 2>/dev/null)

if [ "$AVAILABLE" != "$TARGET_VERSION" ]; then
    echo -e "${RED}❌ Erro: Versão $TARGET_VERSION não está disponível${NC}"
    log "❌ Erro: Versão target não disponível"
    
    echo ""
    echo "Versões disponíveis:"
    aws docdb describe-db-engine-versions \
        --engine docdb \
        --query 'DBEngineVersions[*].EngineVersion' \
        --output table
    
    exit 1
fi

echo -e "${GREEN}✓ Versão target disponível${NC}"
log "✓ Versão target disponível"

# Verificar status do cluster
CLUSTER_STATUS=$(aws docdb describe-db-clusters \
    --db-cluster-identifier "$CLUSTER_ID" \
    --query 'DBClusters[0].Status' \
    --output text)

if [ "$CLUSTER_STATUS" != "available" ]; then
    echo -e "${RED}❌ Erro: Cluster não está disponível (status: $CLUSTER_STATUS)${NC}"
    log "❌ Erro: Cluster status: $CLUSTER_STATUS"
    exit 1
fi

echo -e "${GREEN}✓ Cluster disponível${NC}"
log "✓ Cluster disponível"
echo ""

# ====================================
# FASE 2: BACKUP
# ====================================

echo -e "${MAGENTA}FASE 2: Criar Snapshot de Segurança${NC}"
echo ""

SNAPSHOT_ID="pre-upgrade-${CLUSTER_ID}-$(date +%Y%m%d-%H%M%S)"

log "📸 Criando snapshot: $SNAPSHOT_ID"
echo -e "${YELLOW}Criando snapshot: $SNAPSHOT_ID${NC}"

aws docdb create-db-cluster-snapshot \
    --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
    --db-cluster-identifier "$CLUSTER_ID" \
    --tags \
        Key=Purpose,Value=PreUpgrade \
        Key=SourceVersion,Value=$CURRENT_VERSION \
        Key=TargetVersion,Value=$TARGET_VERSION \
        Key=CreatedBy,Value=upgrade-script

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Snapshot criado${NC}"
    log "✓ Snapshot criado: $SNAPSHOT_ID"
else
    echo -e "${RED}❌ Erro ao criar snapshot${NC}"
    log "❌ Erro ao criar snapshot"
    exit 1
fi

echo ""
echo "⏳ Aguardando snapshot completar..."

# Aguardar snapshot
MAX_WAIT=1800  # 30 minutos
WAITED=0
while true; do
    SNAP_STATUS=$(aws docdb describe-db-cluster-snapshots \
        --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
        --query 'DBClusterSnapshots[0].Status' \
        --output text 2>/dev/null)
    
    PROGRESS=$(aws docdb describe-db-cluster-snapshots \
        --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
        --query 'DBClusterSnapshots[0].PercentProgress' \
        --output text 2>/dev/null)
    
    if [ "$SNAP_STATUS" == "available" ]; then
        echo -e "\n${GREEN}✓ Snapshot disponível!${NC}"
        log "✓ Snapshot disponível"
        break
    elif [ "$SNAP_STATUS" == "failed" ]; then
        echo -e "\n${RED}❌ Snapshot falhou!${NC}"
        log "❌ Snapshot falhou"
        exit 1
    fi
    
    echo -ne "\r📊 Progresso: ${PROGRESS}% | Aguardado: ${WAITED}s  "
    sleep 10
    WAITED=$((WAITED + 10))
    
    if [ $WAITED -gt $MAX_WAIT ]; then
        echo -e "\n${RED}❌ Timeout aguardando snapshot${NC}"
        log "❌ Timeout aguardando snapshot"
        exit 1
    fi
done

echo ""

# ====================================
# FASE 3: CONFIRMAÇÃO
# ====================================

echo -e "${MAGENTA}FASE 3: Confirmação do Upgrade${NC}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}⚠️  ATENÇÃO: Você está prestes a fazer upgrade do cluster!${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Cluster:           $CLUSTER_ID"
echo "  Versão Atual:      $CURRENT_VERSION"
echo "  Versão Target:     $TARGET_VERSION"
echo "  Snapshot Backup:   $SNAPSHOT_ID"
echo ""
echo -e "${YELLOW}Este processo irá:${NC}"
echo "  • Reiniciar as instâncias do cluster"
echo "  • Causar indisponibilidade temporária (~15-30 min)"
echo "  • Aplicar mudanças irreversíveis"
echo ""
echo -e "${RED}IMPORTANTE:${NC} Certifique-se de:"
echo "  • Ter testado em staging"
echo "  • Ter janela de manutenção aprovada"
echo "  • Ter equipe de prontidão"
echo ""

read -p "Deseja continuar com o upgrade? (digite 'YES' para confirmar): " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo -e "${RED}Upgrade cancelado pelo usuário${NC}"
    log "Upgrade cancelado pelo usuário"
    exit 0
fi

echo ""
log "✓ Upgrade confirmado pelo usuário"

# ====================================
# FASE 4: EXECUTAR UPGRADE
# ====================================

echo -e "${MAGENTA}FASE 4: Executando Upgrade${NC}"
echo ""

START_TIME=$(date +%s)

log "🚀 Iniciando upgrade do cluster..."
echo -e "${YELLOW}Iniciando upgrade...${NC}"

aws docdb modify-db-cluster \
    --db-cluster-identifier "$CLUSTER_ID" \
    --engine-version "$TARGET_VERSION" \
    --allow-major-version-upgrade \
    --apply-immediately \
    2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo -e "${GREEN}✓ Comando de upgrade executado${NC}"
    log "✓ Comando de upgrade executado"
else
    echo -e "${RED}❌ Erro ao executar upgrade${NC}"
    log "❌ Erro ao executar upgrade"
    exit 1
fi

echo ""
echo "⏳ Monitorando progresso do upgrade..."
echo ""

# Monitorar progresso
CHECK_COUNT=0
MAX_CHECKS=180  # 30 minutos (10s interval)

while [ $CHECK_COUNT -lt $MAX_CHECKS ]; do
    CHECK_COUNT=$((CHECK_COUNT + 1))
    
    CURRENT_STATUS=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$CLUSTER_ID" \
        --query 'DBClusters[0].Status' \
        --output text 2>/dev/null)
    
    CURRENT_VER=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$CLUSTER_ID" \
        --query 'DBClusters[0].EngineVersion' \
        --output text 2>/dev/null)
    
    ELAPSED=$(($(date +%s) - START_TIME))
    
    if [ "$CURRENT_STATUS" == "available" ] && [ "$CURRENT_VER" == "$TARGET_VERSION" ]; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✅ Upgrade Concluído com Sucesso!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        log "✅ Upgrade concluído em ${DURATION}s"
        break
    fi
    
    echo -ne "\r⏱️  Status: ${CURRENT_STATUS} | Versão: ${CURRENT_VER} | Tempo: ${ELAPSED}s  "
    sleep 10
done

if [ $CHECK_COUNT -ge $MAX_CHECKS ]; then
    echo ""
    echo -e "${RED}❌ Timeout: Upgrade não completou em 30 minutos${NC}"
    log "❌ Timeout após 30 minutos"
    exit 1
fi

# ====================================
# FASE 5: VALIDAÇÃO PÓS-UPGRADE
# ====================================

echo -e "${MAGENTA}FASE 5: Validação Pós-Upgrade${NC}"
echo ""

# Verificar versão final
FINAL_VERSION=$(aws docdb describe-db-clusters \
    --db-cluster-identifier "$CLUSTER_ID" \
    --query 'DBClusters[0].EngineVersion' \
    --output text)

if [ "$FINAL_VERSION" == "$TARGET_VERSION" ]; then
    echo -e "${GREEN}✓ Versão correta: $FINAL_VERSION${NC}"
    log "✓ Versão verificada: $FINAL_VERSION"
else
    echo -e "${RED}✗ Versão incorreta: $FINAL_VERSION (esperado: $TARGET_VERSION)${NC}"
    log "✗ Versão incorreta após upgrade"
fi

# Verificar instâncias
echo ""
echo "📊 Status das Instâncias:"
aws docdb describe-db-instances \
    --filters "Name=db-cluster-id,Values=$CLUSTER_ID" \
    --query 'DBInstances[*].[DBInstanceIdentifier, DBInstanceStatus, EngineVersion]' \
    --output table

# ====================================
# RESUMO FINAL
# ====================================

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📊 Resumo do Upgrade${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Cluster:               $CLUSTER_ID"
echo "  Versão Anterior:       $CURRENT_VERSION"
echo "  Versão Atual:          $FINAL_VERSION"
echo "  Snapshot Backup:       $SNAPSHOT_ID"
echo "  Duração:               ${DURATION}s (~$((DURATION / 60)) minutos)"
echo "  Log Completo:          $LOG_FILE"
echo ""

log "═══════════════════════════════════════════════════════"
log "UPGRADE CONCLUÍDO"
log "  Versão: $CURRENT_VERSION -> $FINAL_VERSION"
log "  Duração: ${DURATION}s"
log "  Snapshot: $SNAPSHOT_ID"
log "═══════════════════════════════════════════════════════"

echo -e "${YELLOW}🔔 Próximos Passos:${NC}"
echo ""
echo "  1. Monitorar métricas CloudWatch por 24-48h"
echo "  2. Executar testes de smoke nas aplicações"
echo "  3. Verificar logs de erro"
echo "  4. Notificar stakeholders"
echo "  5. Documentar upgrade realizado"
echo ""

if [ "$FINAL_VERSION" == "$TARGET_VERSION" ]; then
    echo -e "${GREEN}✅ Upgrade completado com sucesso!${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Upgrade completou mas versão não confere${NC}"
    exit 1
fi
