#!/bin/bash

# Grade script para Exercício 1 - Replicação Avançada
# Módulo 5 - Replicação, Backup e Alta Disponibilidade

set -e

ID="${ID:-seu-id}"
SCORE=0
MAX_SCORE=100
CLUSTER_ID="$ID-lab-cluster-console"

echo "=========================================="
echo "GRADE - Exercício 1: Replicação Avançada"
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

# Teste 1: Verificar se read replicas foram criadas em múltiplas AZs (25 pontos)
echo -n "Verificando: Read replicas em múltiplas AZs... "
REPLICA_COUNT=$(aws docdb describe-db-instances \
--query "DBInstances[?DBClusterIdentifier=='$CLUSTER_ID' && IsClusterWriter==\`false\`]" \
--output text | wc -l 2>/dev/null || echo "0")

if [ "$REPLICA_COUNT" -ge 2 ]; then
    echo "✅ OK (+25 pontos)"
    SCORE=$((SCORE + 25))
else
    echo "❌ FALHOU (0 pontos) - Encontradas $REPLICA_COUNT replicas"
fi

# Teste 2: Verificar distribuição por AZ (20 pontos)
echo -n "Verificando: Distribuição por AZ... "
AZ_COUNT=$(aws docdb describe-db-instances \
--query "DBInstances[?DBClusterIdentifier=='$CLUSTER_ID'].AvailabilityZone" \
--output text | tr '\t' '\n' | sort -u | wc -l 2>/dev/null || echo "0")

if [ "$AZ_COUNT" -ge 2 ]; then
    echo "✅ OK (+20 pontos)"
    SCORE=$((SCORE + 20))
else
    echo "❌ FALHOU (0 pontos) - Instâncias em $AZ_COUNT AZ(s)"
fi

# Teste 3: Verificar promotion tiers configurados (15 pontos)
check_and_score "Promotion tiers configurados" 15 \
"aws docdb describe-db-instances --query 'DBInstances[?DBClusterIdentifier==\`$CLUSTER_ID\`].PromotionTier' --output text | grep -q '[0-9]'"

# Teste 4: Verificar métricas de replicação no CloudWatch (15 pontos)
check_and_score "Métricas de replicação customizadas" 15 \
"aws cloudwatch list-metrics --namespace Custom/DocumentDB/Replication --query 'Metrics[?contains(MetricName, \`Replication\`)].MetricName' --output text | grep -q 'Replication'"

# Teste 5: Verificar script de teste de lag (10 pontos)
check_and_score "Script de teste de replication lag" 10 \
"test -f scripts/test-replication-lag.js"

# Teste 6: Verificar dashboard de replicação (10 pontos)
check_and_score "Dashboard de monitoramento de replicação" 10 \
"aws cloudwatch list-dashboards --query 'DashboardEntries[?contains(DashboardName, \`$ID-Replication\`)].DashboardName' --output text | grep -q '$ID'"

# Teste 7: Verificar alarmes de replicação (5 pontos)
check_and_score "Alarmes de replicação configurados" 5 \
"aws cloudwatch describe-alarms --query 'MetricAlarms[?contains(AlarmName, \`$ID\`) && contains(AlarmName, \`Replication\`)].AlarmName' --output text | grep -q 'Replication'"

echo ""

# Teste adicional: Verificar se cluster está Multi-AZ
echo -n "Verificando: Cluster Multi-AZ habilitado... "
MULTI_AZ=$(aws docdb describe-db-clusters \
--db-cluster-identifier $CLUSTER_ID \
--query 'DBClusters[0].MultiAZ' \
--output text 2>/dev/null || echo "false")

if [ "$MULTI_AZ" = "true" ]; then
    echo "✅ OK (Bonus +5 pontos)"
    SCORE=$((SCORE + 5))
else
    echo "⚠️  Multi-AZ não habilitado"
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
echo "- Read Replicas Multi-AZ: Distribuição geográfica para HA"
echo "- Promotion Tiers: Failover determinístico e otimizado"
echo "- Monitoramento: Métricas e alertas de replicação"
echo "- Automação: Scripts para teste e validação"

if [ $SCORE -lt 80 ]; then
    echo ""
    echo "Dicas para melhorar:"
    echo "1. Crie pelo menos 2 read replicas em AZs diferentes"
    echo "2. Configure promotion tiers (0=primary, 1=first failover, etc.)"
    echo "3. Implemente monitoramento de replication lag"
    echo "4. Execute testes de failover para validar configuração"
    echo "5. Configure alertas proativos para problemas de replicação"
fi

# Mostrar configuração atual do cluster
if aws docdb describe-db-clusters --db-cluster-identifier $CLUSTER_ID &>/dev/null; then
    echo ""
    echo "Configuração atual do cluster:"
    aws docdb describe-db-instances \
    --query "DBInstances[?DBClusterIdentifier=='$CLUSTER_ID'].{Instance:DBInstanceIdentifier,AZ:AvailabilityZone,Writer:IsClusterWriter,Tier:PromotionTier}" \
    --output table 2>/dev/null || echo "Não foi possível obter configuração do cluster"
fi

echo ""
echo "💡 Próximos passos:"
echo "- Execute testes de failover para validar RTO"
echo "- Monitore replication lag sob diferentes cargas"
echo "- Considere implementar automação de recovery"

exit 0