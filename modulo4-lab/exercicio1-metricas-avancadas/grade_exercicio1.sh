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

# Teste 1: Verificar se métricas customizadas estão sendo enviadas (20 pontos)
check_and_score "Métricas customizadas no CloudWatch" 20 \
"aws cloudwatch list-metrics --namespace Custom/DocumentDB --query 'Metrics[?contains(MetricName, \`Query\`) || contains(MetricName, \`Index\`)].MetricName' --output text | grep -q 'QueryExecutionTime'"

# Teste 2: Verificar dashboard de performance (20 pontos)
check_and_score "Dashboard de performance criado" 20 \
"aws cloudwatch list-dashboards --query 'DashboardEntries[?contains(DashboardName, \`$ID-Performance\`)].DashboardName' --output text | grep -q '$ID'"

# Teste 3: Verificar alarmes de performance (20 pontos)
check_and_score "Alarmes de performance configurados" 20 \
"aws cloudwatch describe-alarms --alarm-names $ID-HighQueryExecutionTime --query 'MetricAlarms[0].AlarmName' --output text | grep -q '$ID-HighQueryExecutionTime'"

# Teste 4: Verificar tópico SNS para alertas (15 pontos)
check_and_score "Tópico SNS para alertas de performance" 15 \
"aws sns list-topics --query 'Topics[?contains(TopicArn, \`$ID-performance-alerts\`)].TopicArn' --output text | grep -q 'performance-alerts'"

# Teste 5: Verificar script de coleta de métricas (15 pontos)
check_and_score "Script de coleta de métricas existe" 15 \
"test -f scripts/collect-metrics.js"

# Teste 6: Verificar se Node.js dependencies estão instaladas (10 pontos)
check_and_score "Dependencies Node.js instaladas" 10 \
"test -f package.json && npm list mongodb aws-sdk"

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
echo "- Métricas customizadas: Essencial para monitoramento avançado"
echo "- Dashboard especializado: Visualização focada em performance"
echo "- Alertas proativos: Detecção precoce de problemas"
echo "- Automação: Scripts para coleta contínua"

if [ $SCORE -lt 80 ]; then
    echo ""
    echo "Dicas para melhorar:"
    echo "1. Verifique se as métricas estão sendo enviadas corretamente"
    echo "2. Confirme que o dashboard foi criado com todos os widgets"
    echo "3. Teste os alarmes com dados simulados"
    echo "4. Execute o script de coleta pelo menos uma vez"
fi

exit 0