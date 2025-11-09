#!/bin/bash

# Grade script para Exercício 5 - Tuning de Cluster
# Módulo 4 - Performance e Tuning do DocumentDB

set -e

ID="${ID:-seu-id}"
SCORE=0
MAX_SCORE=100
CLUSTER_ID="$ID-lab-cluster-console"

echo "=========================================="
echo "GRADE - Exercício 5: Tuning de Cluster"
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

# Teste 1: Verificar parameter group de performance (20 pontos)
check_and_score "Parameter group de performance criado" 20 \
"aws docdb describe-db-cluster-parameter-groups --db-cluster-parameter-group-name $ID-performance-params --query 'DBClusterParameterGroups[0].DBClusterParameterGroupName' --output text | grep -q '$ID-performance-params'"

# Teste 2: Verificar parameter group de analytics (15 pontos)
check_and_score "Parameter group de analytics criado" 15 \
"aws docdb describe-db-cluster-parameter-groups --db-cluster-parameter-group-name $ID-analytics-params --query 'DBClusterParameterGroups[0].DBClusterParameterGroupName' --output text | grep -q '$ID-analytics-params'"

# Teste 3: Verificar se parameter group foi aplicado ao cluster (20 pontos)
check_and_score "Parameter group aplicado ao cluster" 20 \
"aws docdb describe-db-clusters --db-cluster-identifier $CLUSTER_ID --query 'DBClusters[0].DBClusterParameterGroup' --output text | grep -q '$ID.*params'"

# Teste 4: Verificar parâmetros customizados configurados (15 pontos)
echo -n "Verificando: Parâmetros customizados configurados... "
CUSTOM_PARAMS=$(aws docdb describe-db-cluster-parameters --db-cluster-parameter-group-name $ID-performance-params --query 'Parameters[?ParameterValue!=`null`]' --output text 2>/dev/null | wc -l)
if [ "$CUSTOM_PARAMS" -gt 0 ]; then
    echo "✅ OK (+15 pontos)"
    SCORE=$((SCORE + 15))
else
    echo "❌ FALHOU (0 pontos)"
fi

# Teste 5: Verificar script de monitoramento de impacto (10 pontos)
check_and_score "Script de monitoramento de impacto" 10 \
"test -f scripts/parameter-impact-monitor.sh || ls scripts/ | grep -q 'parameter.*monitor'"

# Teste 6: Verificar configurações para diferentes workloads (10 pontos)
check_and_score "Parameter groups para OLTP/OLAP" 10 \
"aws docdb describe-db-cluster-parameter-groups --query 'DBClusterParameterGroups[?contains(DBClusterParameterGroupName, \`$ID\`) && (contains(DBClusterParameterGroupName, \`oltp\`) || contains(DBClusterParameterGroupName, \`olap\`))]' --output text | grep -q '$ID'"

# Teste 7: Verificar métricas de performance no CloudWatch (10 pontos)
check_and_score "Métricas de tuning no CloudWatch" 10 \
"aws cloudwatch list-metrics --namespace Custom/DocumentDB/ParameterTuning --query 'Metrics[0].MetricName' --output text | grep -q '.*' || aws cloudwatch list-metrics --namespace Custom/DocumentDB --query 'Metrics[?contains(MetricName, \`Performance\`)].MetricName' --output text | grep -q '.*'"

echo ""

# Verificar status do cluster após mudanças
echo -n "Verificando: Status do cluster após tuning... "
CLUSTER_STATUS=$(aws docdb describe-db-clusters --db-cluster-identifier $CLUSTER_ID --query 'DBClusters[0].Status' --output text 2>/dev/null || echo "")
if [ "$CLUSTER_STATUS" = "available" ]; then
    echo "✅ OK (Bonus +5 pontos)"
    SCORE=$((SCORE + 5))
else
    echo "⚠️  Status: $CLUSTER_STATUS"
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
echo "- Parameter Groups: Configurações customizadas para diferentes cenários"
echo "- Aplicação no Cluster: Parâmetros ativos no ambiente"
echo "- Monitoramento: Acompanhamento do impacto das mudanças"
echo "- Workload Específico: Otimizações para OLTP/OLAP"
echo "- Métricas: Medição de melhorias de performance"

if [ $SCORE -lt 80 ]; then
    echo ""
    echo "Dicas para melhorar:"
    echo "1. Crie parameter groups específicos para cada tipo de workload"
    echo "2. Configure parâmetros apropriados (audit_logs, profiler, etc.)"
    echo "3. Aplique parameter groups ao cluster e reinicie instâncias"
    echo "4. Monitore impacto das mudanças na performance"
    echo "5. Execute testes comparativos antes/depois do tuning"
fi

# Mostrar parameter groups criados
echo ""
echo "Parameter Groups encontrados:"
aws docdb describe-db-cluster-parameter-groups \
--query "DBClusterParameterGroups[?contains(DBClusterParameterGroupName, '$ID')].{Name:DBClusterParameterGroupName,Family:DBParameterGroupFamily,Description:Description}" \
--output table 2>/dev/null || echo "Não foi possível listar parameter groups"

# Mostrar parâmetros customizados ativos
if aws docdb describe-db-cluster-parameter-groups --db-cluster-parameter-group-name $ID-performance-params &>/dev/null; then
    echo ""
    echo "Parâmetros customizados no group de performance:"
    aws docdb describe-db-cluster-parameters \
    --db-cluster-parameter-group-name $ID-performance-params \
    --query 'Parameters[?ParameterValue!=`null`].{Parameter:ParameterName,Value:ParameterValue,Method:ApplyMethod}' \
    --output table 2>/dev/null || echo "Não foi possível listar parâmetros customizados"
fi

# Lembrete sobre custos e limpeza
echo ""
echo "💰 Lembrete:"
echo "- Parameter groups não geram custos adicionais"
echo "- Lembre-se de reverter para parameter group padrão se necessário"
echo "- Delete parameter groups customizados após o exercício"

exit 0