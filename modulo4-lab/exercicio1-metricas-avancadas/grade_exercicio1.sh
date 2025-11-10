#!/bin/bash

# Grade script para Exercício 1 - Métricas Avançadas
# Módulo 4 - Performance e Tuning do DocumentDB

set -e

ID="${ID:-seu-id}"
SCORE=0
MAX_SCORE=100

echo "=========================================="
echo "GRADE - Exercício 1: Métricas Avançadas"
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

# Teste 1: Verificar se métricas customizadas estão sendo enviadas (30 pontos)
check_and_score "Métricas customizadas no CloudWatch" 30 \
"aws cloudwatch list-metrics --namespace Custom/DocumentDB --query 'Metrics[?contains(MetricName, \`Query\`) || contains(MetricName, \`Index\`)].MetricName' --output text | grep -q 'QueryExecutionTime'"

# Teste 2: Verificar dashboard de performance (25 pontos)
check_and_score "Dashboard de performance criado" 25 \
"aws cloudwatch list-dashboards --query 'DashboardEntries[?contains(DashboardName, \`$ID-Performance\`)].DashboardName' --output text | grep -q '$ID'"

# Teste 3: Verificar se há dados nas métricas (25 pontos)
check_and_score "Dados de métricas disponíveis" 25 \
"aws cloudwatch get-metric-statistics --namespace Custom/DocumentDB --metric-name IndexHitRatio --dimensions Name=ClusterIdentifier,Value=$ID-lab-cluster-console --start-time \$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) --end-time \$(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Average --query 'Datapoints[0].Average' --output text | grep -v 'None'"

# Teste 4: Verificar script de coleta de métricas (10 pontos)
check_and_score "Script de coleta de métricas existe" 10 \
"test -f scripts/collect-metrics.js"

# Teste 5: Verificar se Node.js dependencies estão instaladas (10 pontos)
check_and_score "Dependencies Node.js instaladas" 10 \
"test -f package.json && npm list mongodb @aws-sdk/client-cloudwatch"

echo ""
echo "=========================================="
echo "RESULTADO FINAL"
echo "=========================================="
echo "Pontuação: $SCORE/$MAX_SCORE"

if [ $SCORE -ge 80 ]; then
    echo "Status: ✅ CONCLUÍDO ($SCORE/$MAX_SCORE)"
elif [ $SCORE -ge 60 ]; then
    echo "Status: ⚠️  PARCIALMENTE concluído ($SCORE/$MAX_SCORE)"
else
    echo "Status: ❌ INCOMPLETO ($SCORE/$MAX_SCORE)"
fi

echo ""
echo "Detalhes da avaliação:"
echo "- Métricas customizadas: Essencial para monitoramento avançado"
echo "- Dashboard especializado: Visualização focada em performance"
echo "- Dados de métricas: Verificação de envio bem-sucedido"
echo "- Estrutura de código: Scripts e dependências corretas"

if [ $SCORE -lt 80 ]; then
    echo ""
    echo "Dicas para melhorar:"
    echo "1. Verifique se as métricas estão sendo enviadas corretamente"
    echo "2. Confirme que o dashboard foi criado com todos os widgets"
    echo "3. Execute o script de coleta algumas vezes para gerar dados"
    echo "4. Aguarde alguns minutos para propagação das métricas"
fi

exit 0