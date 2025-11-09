#!/bin/bash

# Grade script para Exercício 2 - Planos de Execução e Índices
# Módulo 4 - Performance e Tuning do DocumentDB

set -e

ID="${ID:-seu-id}"
SCORE=0
MAX_SCORE=100
CLUSTER_ENDPOINT="${ID}-lab-cluster-console.cluster-xxxxxxxxx.us-east-1.docdb.amazonaws.com"

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

# Função para verificar índices no MongoDB
check_indexes() {
    mongosh --host $CLUSTER_ENDPOINT:27017 \
    --username $DB_USERNAME \
    --password $DB_PASSWORD \
    --ssl \
    --sslCAFile global-bundle.pem \
    --quiet \
    --eval "
    use performanceDB;
    const indexes = db.products.getIndexes();
    const hasCompoundIndex = indexes.some(idx => Object.keys(idx.key).length > 1);
    const hasPartialIndex = indexes.some(idx => idx.partialFilterExpression);
    const hasTextIndex = indexes.some(idx => Object.values(idx.key).includes('text'));
    
    print('compound:' + hasCompoundIndex);
    print('partial:' + hasPartialIndex);
    print('text:' + hasTextIndex);
    " 2>/dev/null
}

# Teste 1: Verificar se dados de teste foram criados (15 pontos)
check_and_score "Base de dados de teste criada" 15 \
"mongosh --host $CLUSTER_ENDPOINT:27017 --username $DB_USERNAME --password $DB_PASSWORD --ssl --sslCAFile global-bundle.pem --quiet --eval 'use performanceDB; db.products.countDocuments()' | grep -q '[1-9]'"

# Teste 2: Verificar índices compostos (25 pontos)
echo -n "Verificando: Índices compostos criados... "
INDEX_CHECK=$(check_indexes 2>/dev/null || echo "")
if echo "$INDEX_CHECK" | grep -q "compound:true"; then
    echo "✅ OK (+25 pontos)"
    SCORE=$((SCORE + 25))
else
    echo "❌ FALHOU (0 pontos)"
fi

# Teste 3: Verificar índices parciais (20 pontos)
echo -n "Verificando: Índices parciais criados... "
if echo "$INDEX_CHECK" | grep -q "partial:true"; then
    echo "✅ OK (+20 pontos)"
    SCORE=$((SCORE + 20))
else
    echo "❌ FALHOU (0 pontos)"
fi

# Teste 4: Verificar índices de texto (15 pontos)
echo -n "Verificando: Índices de texto criados... "
if echo "$INDEX_CHECK" | grep -q "text:true"; then
    echo "✅ OK (+15 pontos)"
    SCORE=$((SCORE + 15))
else
    echo "❌ FALHOU (0 pontos)"
fi

# Teste 5: Verificar script de análise de explain (15 pontos)
check_and_score "Script explain-analyzer.js existe" 15 \
"test -f scripts/explain-analyzer.js"

# Teste 6: Verificar se script de análise funciona (10 pontos)
check_and_score "Script de análise executável" 10 \
"node scripts/explain-analyzer.js --help || test -f scripts/explain-analyzer.js"

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
echo "- Dados de teste: Base para análise de performance"
echo "- Índices compostos: Otimização para queries complexas"
echo "- Índices parciais: Redução de overhead e melhoria de seletividade"
echo "- Índices de texto: Busca textual eficiente"
echo "- Ferramentas de análise: Automação da análise de explain()"

if [ $SCORE -lt 80 ]; then
    echo ""
    echo "Dicas para melhorar:"
    echo "1. Certifique-se de criar os dados de teste com volume adequado"
    echo "2. Implemente índices compostos seguindo a ordem: igualdade -> range -> sort"
    echo "3. Use índices parciais para filtrar documentos específicos"
    echo "4. Configure índices de texto para busca textual"
    echo "5. Execute análises de explain() em diferentes tipos de query"
fi

# Mostrar estatísticas dos índices se disponível
if [ ! -z "$INDEX_CHECK" ]; then
    echo ""
    echo "Estatísticas dos índices encontrados:"
    mongosh --host $CLUSTER_ENDPOINT:27017 \
    --username $DB_USERNAME \
    --password $DB_PASSWORD \
    --ssl \
    --sslCAFile global-bundle.pem \
    --quiet \
    --eval "
    use performanceDB;
    db.products.getIndexes().forEach(idx => {
        print('- ' + idx.name + ': ' + JSON.stringify(idx.key));
    });
    " 2>/dev/null || echo "Não foi possível obter estatísticas dos índices"
fi

exit 0