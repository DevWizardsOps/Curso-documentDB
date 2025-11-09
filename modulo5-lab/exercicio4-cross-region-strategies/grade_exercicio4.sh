#!/bin/bash

# Grade script para Exercício 4 - Estratégias Cross-Region
# Módulo 5 - Replicação, Backup e Alta Disponibilidade

set -e

ID="${ID:-seu-id}"
SCORE=0
MAX_SCORE=100
PRIMARY_REGION="us-east-1"
SECONDARY_REGION="us-west-2"

echo "=========================================="
echo "GRADE - Exercício 4: Estratégias Cross-Region"
echo "Aluno: $ID"
echo "=========================================="

# Função para verificar e pontuar
check_and_score() {
    local description="$1"
    local points="$2"
    local command="$3"
    
    echo -n "Verificando: $description... "
    
    if eval "$command" &>/dev/null; then
        echo "✅ OK (+$points pontos)"
        SCORE=$((SCORE + points))
    else
        echo "❌ FALHOU (0 pontos)"
    fi
}

# Teste 1: Verificar documentação de limitações (15 pontos)
check_and_score "Documentação de limitações do DocumentDB" 15 \
"test -f architectures/documentdb-limitations.md"

# Teste 2: Verificar design multi-região (15 pontos)
check_and_score "Documento de design multi-região" 15 \
"test -f architectures/multi-region-design.md"

# Teste 3: Verificar infraestrutura na região secundária (20 pontos)
echo -n "Verificando: Infraestrutura na região secundária... "
SECONDARY_VPC=$(aws ec2 describe-vpcs \
--region $SECONDARY_REGION \
--filters "Name=tag:Name,Values=$ID-docdb-vpc-secondary" \
--query 'Vpcs[0].VpcId' \
--output text 2>/dev/null || echo "None")

if [ "$SECONDARY_VPC" != "None" ] && [ "$SECONDARY_VPC" != "null" ]; then
    echo "✅ OK (+20 pontos)"
    SCORE=$((SCORE + 20))
else
    echo "❌ FALHOU (0 pontos)"
fi

# Teste 4: Verificar subnet group na região secundária (10 pontos)
check_and_score "DB Subnet Group na região secundária" 10 \
"aws docdb describe-db-subnet-groups --region $SECONDARY_REGION --db-subnet-group-name $ID-docdb-subnet-group-secondary --query 'DBSubnetGroups[0].DBSubnetGroupName' --output text | grep -q '$ID-docdb-subnet-group-secondary'"

# Teste 5: Verificar função Lambda de backup cross-region (15 pontos)
check_and_score "Função Lambda de backup cross-region" 15 \
"aws lambda get-function --region $PRIMARY_REGION --function-name $ID-CrossRegionBackup --query 'Configuration.FunctionName' --output text | grep -q '$ID-CrossRegionBackup'"

# Teste 6: Verificar agendamento de backup cross-region (10 pontos)
check_and_score "Agendamento de backup cross-region" 10 \
"aws events list-rules --region $PRIMARY_REGION --query 'Rules[?contains(Name, \`$ID-cross-region-backup\`)].Name' --output text | grep -q '$ID-cross-region-backup'"

# Teste 7: Verificar script de sincronização customizada (10 pontos)
check_and_score "Script de sincronização cross-region" 10 \
"test -f scripts/cross-region-sync.js"

# Teste 8: Verificar script de failover regional (5 pontos)
check_and_score "Script de failover regional" 5 \
"test -f scripts/region-failover.sh && test -x scripts/region-failover.sh"

echo ""

# Teste adicional: Verificar snapshots cross-region
echo -n "Verificando: Snapshots cross-region... "
CROSS_REGION_SNAPSHOTS=$(aws docdb describe-db-cluster-snapshots \
--region $SECONDARY_REGION \
--snapshot-type manual \
--query "DBClusterSnapshots[?contains(DBClusterSnapshotIdentifier, '$ID') && contains(DBClusterSnapshotIdentifier, 'cross-region')]" \
--output text 2>/dev/null | wc -l || echo "0")

if [ "$CROSS_REGION_SNAPSHOTS" -gt 0 ]; then
    echo "✅ OK (Bonus +5 pontos)"
    SCORE=$((SCORE + 5))
else
    echo "⚠️  Nenhum snapshot cross-region encontrado"
fi

# Teste adicional: Verificar análise de custos
echo -n "Verificando: Análise de custos cross-region... "
if test -f architectures/cost-optimization.md; then
    echo "✅ OK (Bonus +5 pontos)"
    SCORE=$((SCORE + 5))
else
    echo "⚠️  Análise de custos não encontrada"
fi

echo ""
echo "=========================================="
echo "RESULTADO FINAL"
echo "=========================================="
echo "Pontuação: $SCORE/$MAX_SCORE"

if [ $SCORE -ge 80 ]; then
    echo "Status: ✅ APROVADO (Excelente!)"
elif [ $SCORE -ge 60 ]; then
    echo "Status: ⚠️  APROVADO (Bom trabalho)"
elif [ $SCORE -ge 40 ]; then
    echo "Status: ⚠️  PARCIAL (Precisa melhorar)"
else
    echo "Status: ❌ REPROVADO (Revisar exercício)"
fi

echo ""
echo "Detalhes da avaliação:"
echo "- Documentação: Limitações e estratégias bem documentadas"
echo "- Infraestrutura: Região secundária preparada para DR"
echo "- Automação: Backup cross-region automatizado"
echo "- Sincronização: Estratégias customizadas implementadas"
echo "- Failover: Planos e scripts de failover regional"

if [ $SCORE -lt 80 ]; then
    echo ""
    echo "Dicas para melhorar:"
    echo "1. Documente limitações do DocumentDB para cross-region"
    echo "2. Configure infraestrutura completa na região secundária"
    echo "3. Implemente automação de backup cross-region"
    echo "4. Desenvolva estratégias de sincronização customizada"
    echo "5. Crie e teste scripts de failover regional"
fi

# Mostrar recursos nas duas regiões
echo ""
echo "Recursos por região:"

echo ""
echo "Região Primária ($PRIMARY_REGION):"
aws docdb describe-db-clusters \
--region $PRIMARY_REGION \
--query "DBClusters[?contains(DBClusterIdentifier, '$ID')].{Cluster:DBClusterIdentifier,Status:Status,MultiAZ:MultiAZ}" \
--output table 2>/dev/null || echo "Nenhum cluster encontrado"

echo ""
echo "Região Secundária ($SECONDARY_REGION):"
if [ "$SECONDARY_VPC" != "None" ] && [ "$SECONDARY_VPC" != "null" ]; then
    echo "VPC: $SECONDARY_VPC"
    
    # Verificar subnets
    SECONDARY_SUBNETS=$(aws ec2 describe-subnets \
    --region $SECONDARY_REGION \
    --filters "Name=vpc-id,Values=$SECONDARY_VPC" \
    --query 'Subnets[].SubnetId' \
    --output text 2>/dev/null | wc -w || echo "0")
    echo "Subnets: $SECONDARY_SUBNETS"
    
    # Verificar clusters (se houver)
    aws docdb describe-db-clusters \
    --region $SECONDARY_REGION \
    --query "DBClusters[?contains(DBClusterIdentifier, '$ID')].{Cluster:DBClusterIdentifier,Status:Status}" \
    --output table 2>/dev/null || echo "Nenhum cluster na região secundária"
else
    echo "Infraestrutura não configurada"
fi

echo ""
echo "Snapshots Cross-Region:"
if [ "$CROSS_REGION_SNAPSHOTS" -gt 0 ]; then
    aws docdb describe-db-cluster-snapshots \
    --region $SECONDARY_REGION \
    --snapshot-type manual \
    --query "DBClusterSnapshots[?contains(DBClusterSnapshotIdentifier, '$ID-') && contains(DBClusterSnapshotIdentifier, 'cross-region')].{Snapshot:DBClusterSnapshotIdentifier,Created:SnapshotCreateTime,Status:Status}" \
    --output table 2>/dev/null | head -5
else
    echo "Nenhum snapshot cross-region encontrado"
fi

echo ""
echo "🌍 Estratégias Cross-Region Implementadas:"
echo "1. Snapshot Cross-Region: Disaster Recovery com RPO 1-24h"
echo "2. Infraestrutura Standby: Região secundária preparada"
echo "3. Automação: Backup e failover automatizados"
echo "4. Sincronização: CDC customizado para casos específicos"

echo ""
echo "⚠️  Limitações do DocumentDB:"
echo "- Sem replicação cross-region nativa"
echo "- Sem failover automático entre regiões"
echo "- Dependência de soluções customizadas"
echo "- Custos elevados para alta disponibilidade"

echo ""
echo "💡 Próximos passos:"
echo "- Teste scripts de failover regional"
echo "- Valide RTO/RPO em cenários reais"
echo "- Monitore custos de transferência cross-region"
echo "- Documente runbooks de disaster recovery"

exit 0