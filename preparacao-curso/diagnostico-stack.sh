#!/bin/bash

# Script para diagnosticar falhas em stacks CloudFormation
# Uso: ./diagnostico-stack.sh <nome-da-stack>

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Verificar parâmetro
if [ -z "$1" ]; then
    error "Uso: $0 <nome-da-stack>"
    exit 1
fi

STACK_NAME=$1

echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║           DIAGNÓSTICO DE STACK CLOUDFORMATION                ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

log "Analisando stack: $STACK_NAME"
echo ""

# 1. Verificar se a stack existe
log "1. Verificando existência da stack..."
if ! aws cloudformation describe-stacks --stack-name $STACK_NAME &> /dev/null; then
    error "Stack '$STACK_NAME' não encontrada"
    exit 1
fi
success "Stack encontrada"

# 2. Obter status da stack
log "2. Obtendo status da stack..."
STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].StackStatus' \
    --output text)

echo "Status atual: $STACK_STATUS"

if [[ $STACK_STATUS == *"FAILED"* ]] || [[ $STACK_STATUS == *"ROLLBACK"* ]]; then
    error "Stack em estado de falha: $STACK_STATUS"
else
    success "Stack em estado normal"
fi
echo ""

# 3. Obter razão da falha (se houver)
log "3. Verificando razão da falha..."
STACK_REASON=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].StackStatusReason' \
    --output text 2>/dev/null)

if [ "$STACK_REASON" != "None" ] && [ ! -z "$STACK_REASON" ]; then
    warning "Razão: $STACK_REASON"
else
    echo "Nenhuma razão específica reportada"
fi
echo ""

# 4. Listar eventos da stack (últimos 20)
log "4. Eventos recentes da stack (últimos 20)..."
echo ""
aws cloudformation describe-stack-events \
    --stack-name $STACK_NAME \
    --max-items 20 \
    --query 'StackEvents[*].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId,ResourceStatusReason]' \
    --output table

echo ""

# 5. Identificar recursos que falharam
log "5. Recursos que falharam..."
FAILED_RESOURCES=$(aws cloudformation describe-stack-events \
    --stack-name $STACK_NAME \
    --query "StackEvents[?contains(ResourceStatus, 'FAILED')].{Resource:LogicalResourceId,Type:ResourceType,Status:ResourceStatus,Reason:ResourceStatusReason}" \
    --output json)

if [ "$FAILED_RESOURCES" != "[]" ]; then
    echo "$FAILED_RESOURCES" | jq -r '.[] | "❌ \(.Resource) (\(.Type))\n   Status: \(.Status)\n   Razão: \(.Reason)\n"'
else
    success "Nenhum recurso com falha encontrado nos eventos recentes"
fi
echo ""

# 6. Verificar recursos criados
log "6. Recursos criados pela stack..."
aws cloudformation list-stack-resources \
    --stack-name $STACK_NAME \
    --query 'StackResourceSummaries[*].[LogicalResourceId,ResourceType,ResourceStatus]' \
    --output table

echo ""

# 7. Sugestões de correção baseadas em erros comuns
log "7. Análise de problemas comuns..."
echo ""

# Verificar erros de IAM
if echo "$FAILED_RESOURCES" | grep -q "IAM"; then
    warning "Problema com recursos IAM detectado"
    echo "Possíveis causas:"
    echo "  - Falta de permissão CAPABILITY_NAMED_IAM no deploy"
    echo "  - Nome de usuário ou grupo já existe"
    echo "  - Política IAM inválida"
    echo ""
    echo "Solução:"
    echo "  aws cloudformation create-stack --capabilities CAPABILITY_NAMED_IAM ..."
    echo ""
fi

# Verificar erros de EC2
if echo "$FAILED_RESOURCES" | grep -q "EC2"; then
    warning "Problema com recursos EC2 detectado"
    echo "Possíveis causas:"
    echo "  - AMI não disponível na região"
    echo "  - Subnet ou VPC inválidos"
    echo "  - Security Group com regras inválidas"
    echo "  - KeyPair não existe"
    echo ""
fi

# Verificar erros de DocumentDB
if echo "$FAILED_RESOURCES" | grep -q "DocDB\|RDS"; then
    warning "Problema com recursos DocumentDB detectado"
    echo "Possíveis causas:"
    echo "  - Subnet group inválido"
    echo "  - Security group não existe"
    echo "  - Senha não atende requisitos"
    echo "  - Cluster já existe com mesmo nome"
    echo ""
fi

# Verificar erros de S3
if echo "$FAILED_RESOURCES" | grep -q "S3"; then
    warning "Problema com recursos S3 detectado"
    echo "Possíveis causas:"
    echo "  - Nome do bucket já existe globalmente"
    echo "  - Região incorreta"
    echo "  - Permissões insuficientes"
    echo ""
fi

# Verificar erros de Secrets Manager
if echo "$FAILED_RESOURCES" | grep -q "Secret"; then
    warning "Problema com Secrets Manager detectado"
    echo "Possíveis causas:"
    echo "  - Secret já existe"
    echo "  - Secret foi deletado recentemente (período de recuperação)"
    echo ""
    echo "Solução:"
    echo "  aws secretsmanager delete-secret --secret-id <nome> --force-delete-without-recovery"
    echo ""
fi

# 8. Comandos úteis
echo ""
log "8. Comandos úteis para investigação..."
echo ""
echo "Ver todos os eventos:"
echo "  aws cloudformation describe-stack-events --stack-name $STACK_NAME"
echo ""
echo "Ver template da stack:"
echo "  aws cloudformation get-template --stack-name $STACK_NAME"
echo ""
echo "Deletar stack em ROLLBACK_COMPLETE:"
echo "  aws cloudformation delete-stack --stack-name $STACK_NAME"
echo ""
echo "Ver logs do CloudWatch (se houver):"
echo "  aws logs tail /aws/cloudformation/$STACK_NAME --follow"
echo ""

# 9. Recomendações finais
echo ""
log "9. Recomendações..."
echo ""

if [[ $STACK_STATUS == "ROLLBACK_COMPLETE" ]]; then
    warning "Stack em ROLLBACK_COMPLETE - precisa ser deletada antes de recriar"
    echo ""
    echo "Execute:"
    echo "  aws cloudformation delete-stack --stack-name $STACK_NAME"
    echo "  aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME"
    echo ""
elif [[ $STACK_STATUS == "CREATE_FAILED" ]]; then
    warning "Stack em CREATE_FAILED - CloudFormation fará rollback automaticamente"
    echo "Aguarde o rollback completar ou force a deleção"
    echo ""
fi

echo -e "${GREEN}✨ Diagnóstico completo!${NC}"
