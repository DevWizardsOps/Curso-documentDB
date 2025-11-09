#!/bin/bash

# Grade script para Exercício 3 - Exportação para S3
# Módulo 5 - Replicação, Backup e Alta Disponibilidade

set -e

ID="${ID:-seu-id}"
SCORE=0
MAX_SCORE=100
BUCKET_NAME="$ID-docdb-exports-$(date +%Y%m%d)"

echo "=========================================="
echo "GRADE - Exercício 3: Exportação para S3"
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

# Teste 1: Verificar se bucket S3 foi criado (15 pontos)
echo -n "Verificando: Bucket S3 para exportações... "
BUCKET_EXISTS=$(aws s3 ls | grep "$ID-docdb-exports" | wc -l 2>/dev/null || echo "0")

if [ "$BUCKET_EXISTS" -gt 0 ]; then
    echo "✅ OK (+15 pontos)"
    SCORE=$((SCORE + 15))
    # Obter nome real do bucket
    BUCKET_NAME=$(aws s3 ls | grep "$ID-docdb-exports" | awk '{print $3}' | head -1)
else
    echo "❌ FALHOU (0 pontos)"
fi

# Teste 2: Verificar lifecycle policy no bucket (10 pontos)
if [ "$BUCKET_EXISTS" -gt 0 ]; then
    check_and_score "Lifecycle policy configurada no S3" 10 \
    "aws s3api get-bucket-lifecycle-configuration --bucket $BUCKET_NAME --query 'Rules[0].ID' --output text | grep -q 'DocumentDB'"
fi

# Teste 3: Verificar função Lambda de exportação (20 pontos)
check_and_score "Função Lambda de exportação criada" 20 \
"aws lambda get-function --function-name $ID-DocumentDBExport --query 'Configuration.FunctionName' --output text | grep -q '$ID-DocumentDBExport'"

# Teste 4: Verificar role IAM para Lambda (15 pontos)
check_and_score "Role IAM para DocumentDB Export" 15 \
"aws iam get-role --role-name $ID-DocumentDBExportRole --query 'Role.RoleName' --output text | grep -q '$ID-DocumentDBExportRole'"

# Teste 5: Verificar regras EventBridge para agendamento (15 pontos)
check_and_score "Regras EventBridge para exportação automática" 15 \
"aws events list-rules --query 'Rules[?contains(Name, \`$ID\`) && contains(Name, \`export\`)].Name' --output text | grep -q 'export'"

# Teste 6: Verificar script de exportação manual (10 pontos)
check_and_score "Script de exportação manual" 10 \
"test -f scripts/export-to-s3.js"

# Teste 7: Verificar Glue Crawler (10 pontos)
check_and_score "Glue Crawler para descoberta de schema" 10 \
"aws glue get-crawler --name $ID-docdb-crawler --query 'Crawler.Name' --output text | grep -q '$ID-docdb-crawler'"

# Teste 8: Verificar database no Glue Catalog (5 pontos)
check_and_score "Database no Glue Catalog" 5 \
"aws glue get-database --name ${ID}_docdb_exports --query 'Database.Name' --output text | grep -q '${ID}_docdb_exports'"

echo ""

# Teste adicional: Verificar se há arquivos exportados no S3
if [ "$BUCKET_EXISTS" -gt 0 ]; then
    echo -n "Verificando: Arquivos exportados no S3... "
    EXPORT_FILES=$(aws s3 ls s3://$BUCKET_NAME/exports/ --recursive 2>/dev/null | wc -l || echo "0")
    
    if [ "$EXPORT_FILES" -gt 0 ]; then
        echo "✅ OK (Bonus +5 pontos)"
        SCORE=$((SCORE + 5))
    else
        echo "⚠️  Nenhum arquivo de exportação encontrado"
    fi
fi

# Teste adicional: Verificar manifestos
if [ "$BUCKET_EXISTS" -gt 0 ]; then
    echo -n "Verificando: Manifestos de exportação... "
    MANIFEST_FILES=$(aws s3 ls s3://$BUCKET_NAME/manifests/ --recursive 2>/dev/null | wc -l || echo "0")
    
    if [ "$MANIFEST_FILES" -gt 0 ]; then
        echo "✅ OK (Bonus +5 pontos)"
        SCORE=$((SCORE + 5))
    else
        echo "⚠️  Nenhum manifesto encontrado"
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
echo "- Bucket S3: Armazenamento otimizado com lifecycle"
echo "- Função Lambda: Exportação automatizada e comprimida"
echo "- Agendamento: EventBridge para execução periódica"
echo "- Integração Analytics: Glue Catalog para descoberta"
echo "- Monitoramento: Logs e notificações de exportação"

if [ $SCORE -lt 80 ]; then
    echo ""
    echo "Dicas para melhorar:"
    echo "1. Configure bucket S3 com lifecycle policies para otimização de custos"
    echo "2. Implemente função Lambda com compressão e particionamento"
    echo "3. Configure agendamento automático via EventBridge"
    echo "4. Integre com Glue Catalog para analytics"
    echo "5. Execute pelo menos uma exportação para validar funcionamento"
fi

# Mostrar informações do bucket se existir
if [ "$BUCKET_EXISTS" -gt 0 ]; then
    echo ""
    echo "Informações do bucket S3:"
    echo "Nome: $BUCKET_NAME"
    echo "Região: $(aws s3api get-bucket-location --bucket $BUCKET_NAME --query 'LocationConstraint' --output text 2>/dev/null || echo 'us-east-1')"
    
    echo ""
    echo "Estrutura do bucket:"
    aws s3 ls s3://$BUCKET_NAME/ 2>/dev/null | head -10 || echo "Bucket vazio ou sem permissão"
fi

# Mostrar informações da função Lambda se existir
if aws lambda get-function --function-name $ID-DocumentDBExport &>/dev/null; then
    echo ""
    echo "Informações da função Lambda:"
    aws lambda get-function --function-name $ID-DocumentDBExport \
    --query 'Configuration.{Runtime:Runtime,Timeout:Timeout,Memory:MemorySize,LastModified:LastModified}' \
    --output table 2>/dev/null || echo "Não foi possível obter informações da função"
fi

echo ""
echo "💾 Benefícios da exportação automatizada:"
echo "- Backup de longo prazo em S3 (custo reduzido)"
echo "- Integração com analytics (Athena, QuickSight)"
echo "- Compressão automática (economia de 70-90%)"
echo "- Particionamento por data (performance otimizada)"

echo ""
echo "💡 Próximos passos:"
echo "- Execute exportações manuais para testar funcionamento"
echo "- Configure notificações para monitorar exportações"
echo "- Integre com pipeline de analytics se necessário"

exit 0