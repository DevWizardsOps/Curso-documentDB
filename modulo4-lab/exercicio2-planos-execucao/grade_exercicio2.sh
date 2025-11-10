#!/bin/bash

# Grade script para Exercício 2 - Planos de Execução e Índices
# Módulo 4 - Performance e Tuning do DocumentDB

set -e

ID="${ID:-seu-id}"
SCORE=0
MAX_SCORE=100

# Obter endpoint do cluster
CLUSTER_ENDPOINT=$(aws docdb describe-db-clusters \
--db-cluster-identifier $ID-lab-cluster-console \
--query 'DBClusters[0].Endpoint' \
--output text 2>/dev/null || echo "$ID-lab-cluster-console.cluster-xxxxxxxxx.us-east-2.docdb.amazonaws.com")

echo "=========================================="
echo "GRADE - Exercício 2: Planos de Execução"
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



# Teste 1: Verificar se dados de teste foram criados (30 pontos)
check_and_score "Base de dados de teste criada" 30 \
"mongosh --host $CLUSTER_ENDPOINT:27017 --username \${DB_USERNAME:-docdbadmin} --password \${DB_PASSWORD:-Lab12345!} --ssl --sslCAFile global-bundle.pem --quiet --eval 'use performanceDB; print(db.products.countDocuments())' 2>/dev/null | grep -E '^[1-9][0-9]*$'"

# Teste 2: Verificar se há índices além do _id (25 pontos)
check_and_score "Índices customizados criados" 25 \
"mongosh --host $CLUSTER_ENDPOINT:27017 --username \${DB_USERNAME:-docdbadmin} --password \${DB_PASSWORD:-Lab12345!} --ssl --sslCAFile global-bundle.pem --quiet --eval 'use performanceDB; print(db.products.getIndexes().length)' 2>/dev/null | grep -E '^[2-9]|^[1-9][0-9]+$'"

# Teste 3: Verificar script de análise de explain (25 pontos)
check_and_score "Script explain-analyzer.js existe" 25 \
"test -f scripts/explain-analyzer.js"

# Teste 4: Verificar se package.json existe (20 pontos)
check_and_score "Package.json configurado" 20 \
"test -f package.json && grep -q mongodb package.json"

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
echo "- Dados de teste: Base para análise de performance"
echo "- Índices customizados: Otimização de queries"
echo "- Script de análise: Ferramenta para explain()"
echo "- Configuração: Package.json com dependências"

if [ $SCORE -lt 80 ]; then
    echo ""
    echo "Dicas para melhorar:"
    echo "1. Certifique-se de criar os dados de teste seguindo o README"
    echo "2. Crie índices seguindo os exemplos do exercício"
    echo "3. Verifique se o script explain-analyzer.js existe"
    echo "4. Execute npm install para configurar dependências"
fi

exit 0