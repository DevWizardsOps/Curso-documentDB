#!/bin/bash

# Script para modificar instâncias do DocumentDB
# Uso: ./modify-instance.sh <instance-identifier> <new-instance-class> [apply-immediately]

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir uso
usage() {
    echo "Uso: $0 <instance-identifier> <new-instance-class> [apply-immediately]"
    echo ""
    echo "Parâmetros:"
    echo "  instance-identifier  : ID da instância a modificar"
    echo "  new-instance-class   : Nova classe da instância"
    echo "  apply-immediately    : yes/no (padrão: no)"
    echo ""
    echo "Exemplos:"
    echo "  $0 lab-cluster-console-1 db.r5.large no"
    echo "  $0 prod-cluster-1 db.r6g.xlarge yes"
    echo ""
    echo "Classes disponíveis:"
    echo "  • db.t3.medium  - 2 vCPU, 4 GB RAM"
    echo "  • db.r5.large   - 2 vCPU, 16 GB RAM"
    echo "  • db.r5.xlarge  - 4 vCPU, 32 GB RAM"
    echo "  • db.r5.2xlarge - 8 vCPU, 64 GB RAM"
    echo "  • db.r6g.large  - 2 vCPU, 16 GB RAM (Graviton)"
    exit 1
}

# Verificar argumentos
if [ $# -lt 2 ]; then
    usage
fi

INSTANCE_ID=$1
NEW_CLASS=$2
APPLY_IMMEDIATELY=${3:-no}

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    DocumentDB Instance Modification Tool              ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Verificar se a instância existe
echo "🔍 Verificando instância..."
if ! aws docdb describe-db-instances \
    --db-instance-identifier "$INSTANCE_ID" \
    --query 'DBInstances[0].DBInstanceIdentifier' \
    --output text &>/dev/null; then
    echo -e "${RED}❌ Erro: Instância '${INSTANCE_ID}' não encontrada${NC}"
    exit 1
fi

# Obter informações atuais
CURRENT_CLASS=$(aws docdb describe-db-instances \
    --db-instance-identifier "$INSTANCE_ID" \
    --query 'DBInstances[0].DBInstanceClass' \
    --output text)

CURRENT_STATUS=$(aws docdb describe-db-instances \
    --db-instance-identifier "$INSTANCE_ID" \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text)

CLUSTER_ID=$(aws docdb describe-db-instances \
    --db-instance-identifier "$INSTANCE_ID" \
    --query 'DBInstances[0].DBClusterIdentifier' \
    --output text)

IS_WRITER=$(aws docdb describe-db-cluster-members \
    --db-cluster-identifier "$CLUSTER_ID" \
    --query "DBClusterMembers[?DBInstanceIdentifier=='${INSTANCE_ID}'].IsClusterWriter" \
    --output text)

echo -e "${GREEN}✓ Instância encontrada${NC}"
echo ""

# Exibir informações
echo -e "${YELLOW}Informações Atuais:${NC}"
echo "  Instância:      $INSTANCE_ID"
echo "  Cluster:        $CLUSTER_ID"
echo "  Classe Atual:   $CURRENT_CLASS"
echo "  Nova Classe:    $NEW_CLASS"
echo "  Status:         $CURRENT_STATUS"
echo "  É Writer:       $IS_WRITER"
echo "  Aplicar Agora:  $([ "$APPLY_IMMEDIATELY" == "yes" ] && echo "Sim" || echo "Não (próxima janela)")"
echo ""

# Verificar se mudança é necessária
if [ "$CURRENT_CLASS" == "$NEW_CLASS" ]; then
    echo -e "${YELLOW}⚠️  Instância já está na classe $NEW_CLASS${NC}"
    exit 0
fi

# Verificar status
if [ "$CURRENT_STATUS" != "available" ]; then
    echo -e "${RED}❌ Erro: Instância não está disponível (status: $CURRENT_STATUS)${NC}"
    exit 1
fi

# Avisos
echo -e "${YELLOW}⚠️  IMPORTANTE:${NC}"
if [ "$APPLY_IMMEDIATELY" == "yes" ]; then
    echo "  • A modificação será aplicada IMEDIATAMENTE"
    echo "  • A instância será reiniciada"
    echo "  • Haverá DOWNTIME durante o reboot"
    if [ "$IS_WRITER" == "True" ]; then
        echo "  • ${RED}ATENÇÃO: Esta é a instância WRITER (primária)${NC}"
        echo "  • ${RED}Um failover ocorrerá automaticamente${NC}"
    fi
else
    echo "  • A modificação será aplicada na próxima janela de manutenção"
    echo "  • Menos disruptivo para operações"
fi
echo ""

# Confirmação
read -p "Deseja continuar? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Modificação cancelada${NC}"
    exit 0
fi

# Executar modificação
echo ""
echo "🚀 Modificando instância..."

if [ "$APPLY_IMMEDIATELY" == "yes" ]; then
    aws docdb modify-db-instance \
        --db-instance-identifier "$INSTANCE_ID" \
        --db-instance-class "$NEW_CLASS" \
        --apply-immediately
else
    aws docdb modify-db-instance \
        --db-instance-identifier "$INSTANCE_ID" \
        --db-instance-class "$NEW_CLASS" \
        --no-apply-immediately
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Modificação iniciada${NC}"
else
    echo -e "${RED}❌ Erro ao modificar instância${NC}"
    exit 1
fi

echo ""

if [ "$APPLY_IMMEDIATELY" == "yes" ]; then
    echo "⏳ Aguardando modificação completar..."
    echo ""
    
    # Monitorar progresso
    CHECK_COUNT=0
    MAX_CHECKS=120  # 20 minutos
    
    while [ $CHECK_COUNT -lt $MAX_CHECKS ]; do
        CHECK_COUNT=$((CHECK_COUNT + 1))
        
        STATUS=$(aws docdb describe-db-instances \
            --db-instance-identifier "$INSTANCE_ID" \
            --query 'DBInstances[0].DBInstanceStatus' \
            --output text 2>/dev/null)
        
        CLASS=$(aws docdb describe-db-instances \
            --db-instance-identifier "$INSTANCE_ID" \
            --query 'DBInstances[0].DBInstanceClass' \
            --output text 2>/dev/null)
        
        if [ "$STATUS" == "available" ] && [ "$CLASS" == "$NEW_CLASS" ]; then
            echo ""
            echo -e "${GREEN}✅ Modificação concluída!${NC}"
            break
        fi
        
        echo -ne "\r⏱️  Status: ${STATUS} | Classe: ${CLASS}  "
        sleep 10
    done
    
    if [ $CHECK_COUNT -ge $MAX_CHECKS ]; then
        echo ""
        echo -e "${RED}⚠️  Timeout aguardando modificação${NC}"
    fi
else
    echo -e "${YELLOW}ℹ️  Modificação agendada para próxima janela de manutenção${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📊 Resumo${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Instância:       $INSTANCE_ID"
echo "  Classe Anterior: $CURRENT_CLASS"
echo "  Nova Classe:     $NEW_CLASS"
echo ""

# Verificar janela de manutenção
MAINT_WINDOW=$(aws docdb describe-db-instances \
    --db-instance-identifier "$INSTANCE_ID" \
    --query 'DBInstances[0].PreferredMaintenanceWindow' \
    --output text)

if [ "$APPLY_IMMEDIATELY" != "yes" ]; then
    echo "  Janela de Manutenção: $MAINT_WINDOW"
    echo ""
fi

echo -e "${GREEN}✅ Operação concluída!${NC}"
