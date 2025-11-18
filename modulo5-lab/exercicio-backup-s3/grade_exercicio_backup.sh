#!/bin/bash

# Grade script para Exercício: Backup de Dados para S3
# Módulo 5 - Backup e Exportação de Dados

set -e

ID="${ID:-seu-id}"
SCORE=0
MAX_SCORE=100

echo "=========================================="
echo "GRADE - Exercício: Backup de Dados para S3"
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

# Teste 1: Verificar se bucket S3 foi criado (20 pontos)
echo -n "Verificando: Bucket S3 para backups... "
BUCKET_EXISTS=$(aws s3 ls | grep "$ID-docdb-backups" | wc -l 2>/dev/null || echo "0")

if [ "$BUCKET_EXISTS" -gt 0 ]; then
    echo "✅ OK (+20 pontos)"
    SCORE=$((SCORE + 20))
    # Obter nome real do bucket
    BUCKET_NAME=$(aws s3 ls | grep "$ID-docdb-backups" | awk '{print $3}' | head -1)
else
    echo "❌ FALHOU (0 pontos)"
    BUCKET_NAME="$ID-docdb-backups-$(date +%Y%m%d)"
fi

# Teste 2: Verificar lifecycle policy no bucket (15 pontos)
if [ "$BUCKET_EXISTS" -gt 0 ]; then
    check_and_score "Lifecycle policy configurada no S3" 15 \
    "aws s3api get-bucket-lifecycle-configuration --bucket $BUCKET_NAME --query 'Rules[0].ID' --output text | grep -q 'BackupRetentionPolicy'"
fi

# Teste 3: Verificar se mongoexport está disponível (10 pontos)
check_and_score "MongoDB tools (mongoexport) disponível" 10 \
"command -v mongoexport"

# Teste 4: Verificar certificado SSL baixado (10 pontos)
check_and_score "Certificado SSL do DocumentDB baixado" 10 \
"test -f global-bundle.pem"

# Teste 5: Verificar se há backups completos no S3 (25 pontos)
if [ "$BUCKET_EXISTS" -gt 0 ]; then
    echo -n "Verificando: Backups completos no S3... "
    FULL_BACKUPS=$(aws s3 ls s3://$BUCKET_NAME/backups/full/ --recursive 2>/dev/null | wc -l || echo "0")
    
    if [ "$FULL_BACKUPS" -gt 0 ]; then
        echo "✅ OK (+25 pontos)"
        SCORE=$((SCORE + 25))
    else
        echo "❌ FALHOU (0 pontos)"
    fi
fi

# Teste 6: Verificar se há metadados de backup (10 pontos)
if [ "$BUCKET_EXISTS" -gt 0 ]; then
    echo -n "Verificando: Metadados de backup... "
    METADATA_FILES=$(aws s3 ls s3://$BUCKET_NAME/metadata/full/ --recursive 2>/dev/null | wc -l || echo "0")
    
    if [ "$METADATA_FILES" -gt 0 ]; then
        echo "✅ OK (+10 pontos)"
        SCORE=$((SCORE + 10))
    else
        echo "❌ FALHOU (0 pontos)"
    fi
fi

# Teste 7: Verificar se há backups incrementais (10 pontos)
if [ "$BUCKET_EXISTS" -gt 0 ]; then
    echo -n "Verificando: Backups incrementais... "
    INCREMENTAL_BACKUPS=$(aws s3 ls s3://$BUCKET_NAME/backups/incremental/ --recursive 2>/dev/null | wc -l || echo "0")
    
    if [ "$INCREMENTAL_BACKUPS" -gt 0 ]; then
        echo "✅ OK (+10 pontos)"
        SCORE=$((SCORE + 10))
    else
        echo "⚠️  Nenhum backup incremental encontrado"
    fi
fi

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
echo "- Bucket S3: Armazenamento com lifecycle policies"
echo "- Ferramentas: MongoDB tools para export/import"
echo "- Backups completos: Backup de todas as collections"
echo "- Backups incrementais: Backup apenas de dados novos"
echo "- Metadados: Informações sobre os backups realizados"

if [ $SCORE -lt 80 ]; then
    echo ""
    echo "Dicas para melhorar:"
    echo "1. Verifique se o bucket S3 foi criado corretamente"
    echo "2. Configure lifecycle policies para otimização de custos"
    echo "3. Execute pelo menos um backup completo"
    echo "4. Teste o procedimento de restore"
    echo "5. Crie backups incrementais para otimização"
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
    
    if [ "$FULL_BACKUPS" -gt 0 ]; then
        echo ""
        echo "Backups encontrados:"
        echo "- Backups completos: $FULL_BACKUPS arquivo(s)"
        echo "- Backups incrementais: $INCREMENTAL_BACKUPS arquivo(s)"
        echo "- Metadados: $METADATA_FILES arquivo(s)"
    fi
fi

echo ""
echo "💾 Benefícios do backup para S3:"
echo "- Backup de longo prazo com baixo custo"
echo "- Políticas de retenção automáticas"
echo "- Compressão para economia de espaço"
echo "- Restore flexível por collection"

echo ""
echo "💡 Próximos passos:"
echo "- Teste procedimentos de restore regularmente"
echo "- Configure automação via scripts ou Lambda"
echo "- Monitore custos de armazenamento no S3"
echo "- Documente procedimentos de disaster recovery"

exit 0