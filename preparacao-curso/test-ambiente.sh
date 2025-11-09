#!/bin/bash

# Script para testar o ambiente do curso DocumentDB
# Autor: Kiro AI Assistant

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                  TESTE DO AMBIENTE                           ║
║              Curso DocumentDB                                ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Verificar se stack existe
read -p "Nome da stack para testar: " STACK_NAME

if ! aws cloudformation describe-stacks --stack-name $STACK_NAME &> /dev/null; then
    error "Stack '$STACK_NAME' não encontrada"
    exit 1
fi

info "Testando stack: $STACK_NAME"

# Teste 1: Verificar status da stack
echo -e "\n${YELLOW}1. Status da Stack${NC}"
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query 'Stacks[0].StackStatus' --output text)
if [ "$STACK_STATUS" = "CREATE_COMPLETE" ] || [ "$STACK_STATUS" = "UPDATE_COMPLETE" ]; then
    success "Stack status: $STACK_STATUS"
else
    error "Stack status: $STACK_STATUS"
fi

# Teste 2: Verificar instâncias EC2
echo -e "\n${YELLOW}2. Instâncias EC2${NC}"
INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=tag:aws:cloudformation:stack-name,Values=$STACK_NAME" "Name=instance-state-name,Values=running,pending" \
    --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]' \
    --output text)

if [ -n "$INSTANCES" ]; then
    success "Instâncias encontradas:"
    echo "$INSTANCES" | while read instance_id state ip; do
        echo "  • $instance_id ($state) - IP: $ip"
    done
else
    error "Nenhuma instância encontrada"
fi

# Teste 3: Verificar usuários IAM
echo -e "\n${YELLOW}3. Usuários IAM${NC}"
USERS=$(aws iam list-users --query "Users[?contains(UserName, '$STACK_NAME')].UserName" --output text)
if [ -n "$USERS" ]; then
    success "Usuários IAM encontrados:"
    for user in $USERS; do
        echo "  • $user"
    done
else
    error "Nenhum usuário IAM encontrado"
fi

# Teste 4: Verificar chaves SSH
echo -e "\n${YELLOW}4. Chaves SSH${NC}"
KEYS=$(aws ec2 describe-key-pairs --query "KeyPairs[?contains(KeyName, '$STACK_NAME')].KeyName" --output text)
if [ -n "$KEYS" ]; then
    success "Chaves SSH encontradas:"
    for key in $KEYS; do
        echo "  • $key"
    done
else
    error "Nenhuma chave SSH encontrada"
fi

# Teste 5: Verificar Security Groups
echo -e "\n${YELLOW}5. Security Groups${NC}"
SG_ALUNOS=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$STACK_NAME-alunos-sg" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
SG_DOCDB=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$STACK_NAME-documentdb-sg" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)

if [ "$SG_ALUNOS" != "None" ] && [ -n "$SG_ALUNOS" ]; then
    success "Security Group Alunos: $SG_ALUNOS"
else
    error "Security Group Alunos não encontrado"
fi

if [ "$SG_DOCDB" != "None" ] && [ -n "$SG_DOCDB" ]; then
    success "Security Group DocumentDB: $SG_DOCDB"
else
    error "Security Group DocumentDB não encontrado"
fi

# Teste 6: Verificar bucket S3
echo -e "\n${YELLOW}6. Bucket S3${NC}"
BUCKET_NAME="$STACK_NAME-labs-$(aws sts get-caller-identity --query Account --output text)"
if aws s3 ls "s3://$BUCKET_NAME" &> /dev/null; then
    success "Bucket S3: $BUCKET_NAME"
else
    error "Bucket S3 não encontrado: $BUCKET_NAME"
fi

# Teste 7: Conectividade SSH (opcional)
echo -e "\n${YELLOW}7. Teste de Conectividade SSH${NC}"
read -p "Testar conectividade SSH? (y/N): " TEST_SSH

if [[ $TEST_SSH =~ ^[Yy]$ ]]; then
    # Obter primeira instância
    FIRST_INSTANCE=$(echo "$INSTANCES" | head -1 | awk '{print $3}')
    if [ -n "$FIRST_INSTANCE" ] && [ "$FIRST_INSTANCE" != "None" ]; then
        info "Testando conectividade para: $FIRST_INSTANCE"
        if timeout 5 bash -c "</dev/tcp/$FIRST_INSTANCE/22"; then
            success "Porta SSH (22) acessível"
        else
            error "Porta SSH (22) não acessível"
        fi
    else
        warning "IP público não disponível para teste"
    fi
fi

# Resumo final
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                        RESUMO DO TESTE                        ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# Contar recursos
INSTANCE_COUNT=$(echo "$INSTANCES" | wc -l)
USER_COUNT=$(echo "$USERS" | wc -w)
KEY_COUNT=$(echo "$KEYS" | wc -w)

echo "Stack: $STACK_NAME"
echo "Status: $STACK_STATUS"
echo "Instâncias EC2: $INSTANCE_COUNT"
echo "Usuários IAM: $USER_COUNT"
echo "Chaves SSH: $KEY_COUNT"

if [ "$STACK_STATUS" = "CREATE_COMPLETE" ] && [ $INSTANCE_COUNT -gt 0 ] && [ $USER_COUNT -gt 0 ]; then
    echo -e "\n${GREEN}🎉 AMBIENTE PRONTO PARA O CURSO! 🎉${NC}"
    
    echo -e "\n${YELLOW}Próximos passos:${NC}"
    echo "1. Baixe as chaves SSH do console EC2"
    echo "2. Distribua IPs e chaves para os alunos"
    echo "3. Teste conexão: ssh -i chave.pem ec2-user@IP"
    echo "4. Inicie o curso!"
else
    echo -e "\n${RED}⚠️  AMBIENTE COM PROBLEMAS${NC}"
    echo "Verifique os erros acima e corrija antes de iniciar o curso."
fi

echo ""