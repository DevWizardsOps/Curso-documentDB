#!/bin/bash

# Grade script para Exercício 4 - Conexões e Latência
# Módulo 4 - Performance e Tuning do DocumentDB

set -e

ID="${ID:-seu-id}"
SCORE=0
MAX_SCORE=100

echo "=========================================="
echo "GRADE - Exercício 4: Conexões e Latência"
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

# Teste 1: Verificar métricas de connection pool no CloudWatch (20 pontos)
check_and_score "Métricas de connection pool" 20 \
"aws cloudwatch list-metrics --namespace Custom/DocumentDB/ConnectionPool --query 'Metrics[?contains(MetricName, \`Connection\`)].MetricName' --output text | grep -q 'Connection'"

# Teste 2: Verificar script de monitoramento de conexões (20 pontos)
check_and_score "Script connection-monitor.sh existe" 20 \
"test -f scripts/connection-monitor.sh"

# Teste 3: Verificar script de teste de latência (15 pontos)
check_and_score "Script de teste de latência existe" 15 \
"test -f scripts/latency-test.js || ls scripts/ | grep -q 'latency'"

# Teste 4: Verificar configurações de pool (15 pontos)
check_and_score "Configurações de connection pool" 15 \
"test -f connection-pools/pool-config.js || ls connection-pools/ | grep -q 'pool'"

# Teste 5: Verificar script de diagnóstico (15 pontos)
check_and_score "Script de diagnóstico de conexão" 15 \
"grep -q 'ConnectionDiagnostics' scripts/*.js || test -f scripts/connection-diagnostics.js"

# Teste 6: Verificar se Node.js dependencies estão instaladas (10 pontos)
check_and_score "Dependencies Node.js para conexões" 10 \
"npm list mongodb 2>/dev/null | grep -q 'mongodb' || test -f package.json"

# Teste 7: Verificar permissões de execução nos scripts (5 pontos)
check_and_score "Scripts com permissão de execução" 5 \
"test -x scripts/connection-monitor.sh || ls -la scripts/connection-monitor.sh | grep -q 'rwx'"

echo ""

# Teste de conectividade básica (se possível)
if [ ! -z "$CLUSTER_ENDPOINT" ] && [ ! -z "$DB_USERNAME" ]; then
    echo -n "Testando conectividade básica... "
    if timeout 10 mongosh --host $CLUSTER_ENDPOINT:27017 --username $DB_USERNAME --password $DB_PASSWORD --ssl --sslCAFile global-bundle.pem --eval "db.adminCommand('ping')" &>/dev/null; then
        echo "✅ OK (Bonus +5 pontos)"
        SCORE=$((SCORE + 5))
    else
        echo "⚠️  Não foi possível testar conectividade"
    fi
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
echo "- Métricas de Pool: Monitoramento de eficiência de conexões"
echo "- Scripts de Monitoramento: Automação de coleta de dados"
echo "- Testes de Latência: Medição e otimização de performance"
echo "- Configurações Otimizadas: Pools adaptados para diferentes cenários"
echo "- Diagnósticos: Ferramentas para troubleshooting"

if [ $SCORE -lt 80 ]; then
    echo ""
    echo "Dicas para melhorar:"
    echo "1. Configure métricas customizadas para connection pools"
    echo "2. Implemente monitoramento contínuo de conexões"
    echo "3. Execute testes de latência em diferentes cenários"
    echo "4. Otimize configurações de pool para seu workload"
    echo "5. Implemente diagnósticos automáticos de conectividade"
fi

# Verificar se há processos de monitoramento rodando
echo ""
echo "Processos de monitoramento ativos:"
if pgrep -f "connection-monitor\|latency-test" >/dev/null; then
    echo "✅ Encontrados processos de monitoramento ativos"
    pgrep -f "connection-monitor\|latency-test" | while read pid; do
        echo "  - PID $pid: $(ps -p $pid -o comm= 2>/dev/null || echo 'processo')"
    done
else
    echo "⚠️  Nenhum processo de monitoramento ativo encontrado"
    echo "   Considere executar: ./scripts/connection-monitor.sh &"
fi

# Mostrar configurações recomendadas
echo ""
echo "📋 Configurações Recomendadas por Cenário:"
echo "- Web Apps: maxPoolSize=100, timeout=30s"
echo "- Batch Jobs: maxPoolSize=20, timeout=5min"  
echo "- Analytics: maxPoolSize=10, timeout=30min"
echo "- Real-time: maxPoolSize=150, timeout=15s"

exit 0