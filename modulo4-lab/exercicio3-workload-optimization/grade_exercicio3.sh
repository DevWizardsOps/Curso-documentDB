#!/bin/bash

# Grade script para Exercício 3 - Workload Optimization
# Módulo 4 - Performance e Tuning do DocumentDB

set -e

ID="${ID:-seu-id}"
SCORE=0
MAX_SCORE=100

echo "=========================================="
echo "GRADE - Exercício 3: Workload Optimization"
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

# Teste 1: Verificar se read replica foi criada (25 pontos)
check_and_score "Read replica criada" 25 \
"aws docdb describe-db-instances --db-instance-identifier $ID-read-replica-1 --query 'DBInstances[0].DBInstanceIdentifier' --output text | grep -q '$ID-read-replica-1'"

# Teste 2: Verificar se read replica está disponível (15 pontos)
check_and_score "Read replica disponível" 15 \
"aws docdb describe-db-instances --db-instance-identifier $ID-read-replica-1 --query 'DBInstances[0].DBInstanceStatus' --output text | grep -q 'available'"

# Teste 3: Verificar script de simulação de workload (20 pontos)
check_and_score "Script workload-simulator.js existe" 20 \
"test -f scripts/workload-simulator.js"

# Teste 4: Verificar se script de workload é executável (15 pontos)
check_and_score "Script de workload executável" 15 \
"node scripts/workload-simulator.js --help 2>/dev/null || test -x scripts/workload-simulator.js || test -f scripts/workload-simulator.js"

# Teste 5: Verificar configurações de connection pool (10 pontos)
check_and_score "Arquivos de configuração de pool existem" 10 \
"test -f connection-pools/pool-config.js || ls connection-pools/ | grep -q 'pool'"

# Teste 6: Verificar estratégias de caching (15 pontos)
check_and_score "Estratégias de caching implementadas" 15 \
"test -f read-workloads/caching-strategies.js || ls read-workloads/ | grep -q 'caching'"

echo ""

# Teste adicional: Verificar se read replica está no mesmo cluster
echo -n "Verificando: Read replica no cluster correto... "
REPLICA_CLUSTER=$(aws docdb describe-db-instances --db-instance-identifier $ID-read-replica-1 --query 'DBInstances[0].DBClusterIdentifier' --output text 2>/dev/null || echo "")
if [ "$REPLICA_CLUSTER" = "$ID-lab-cluster-console" ]; then
    echo "✅ OK (Bonus +5 pontos)"
    SCORE=$((SCORE + 5))
else
    echo "⚠️  Não verificado"
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
echo "- Read Replica: Separação de workloads de leitura/escrita"
echo "- Simulação de Workload: Testes de diferentes cenários de carga"
echo "- Connection Pooling: Otimização de recursos de conexão"
echo "- Estratégias de Cache: Melhoria de performance de leitura"

if [ $SCORE -lt 80 ]; then
    echo ""
    echo "Dicas para melhorar:"
    echo "1. Certifique-se de que a read replica foi criada e está disponível"
    echo "2. Implemente diferentes estratégias de connection pooling"
    echo "3. Configure caching para queries frequentes"
    echo "4. Execute simulações de workload para validar otimizações"
    echo "5. Monitore métricas de performance durante os testes"
fi

# Mostrar informações da read replica se disponível
if aws docdb describe-db-instances --db-instance-identifier $ID-read-replica-1 &>/dev/null; then
    echo ""
    echo "Informações da Read Replica:"
    aws docdb describe-db-instances --db-instance-identifier $ID-read-replica-1 \
    --query 'DBInstances[0].{Status:DBInstanceStatus,Class:DBInstanceClass,AZ:AvailabilityZone,Endpoint:Endpoint.Address}' \
    --output table 2>/dev/null || echo "Não foi possível obter informações da read replica"
fi

# Verificar custos estimados
echo ""
echo "💰 Lembrete de Custos:"
echo "- Read replica db.t3.medium: ~$0.10-0.50/hora"
echo "- Lembre-se de deletar recursos após o exercício"
echo "- Use: aws docdb delete-db-instance --db-instance-identifier $ID-read-replica-1 --skip-final-snapshot"

exit 0