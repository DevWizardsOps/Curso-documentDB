#!/bin/bash

# Script para deploy do ambiente do Curso DocumentDB
# Autor: Kiro AI Assistant
# Versão: 1.0

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
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

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                    CURSO DOCUMENTDB                          ║
║              Setup de Ambiente AWS                           ║
║                                                              ║
║  Este script criará instâncias EC2 e usuários IAM           ║
║  para cada aluno do curso                                    ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Verificar se AWS CLI está instalado e configurado
log "Verificando pré-requisitos..."

if ! command -v aws &> /dev/null; then
    error "AWS CLI não está instalado. Instale primeiro: https://aws.amazon.com/cli/"
    exit 1
fi

# Verificar credenciais AWS
if ! aws sts get-caller-identity &> /dev/null; then
    error "Credenciais AWS não configuradas. Execute: aws configure"
    exit 1
fi

success "AWS CLI configurado corretamente"

# Obter informações da conta
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)
USER_ARN=$(aws sts get-caller-identity --query Arn --output text)

log "Conta AWS: $ACCOUNT_ID"
log "Região: $REGION"
log "Usuário: $USER_ARN"

# Parâmetros do curso
echo ""
echo -e "${YELLOW}Configuração do Curso:${NC}"

read -p "Número de alunos (1-20): " NUM_ALUNOS
if [[ ! $NUM_ALUNOS =~ ^[1-9]$|^1[0-9]$|^20$ ]]; then
    error "Número de alunos deve ser entre 1 e 20"
    exit 1
fi

read -p "Prefixo para nomes dos alunos [aluno]: " PREFIXO_ALUNO
PREFIXO_ALUNO=${PREFIXO_ALUNO:-aluno}

read -p "Nome da stack CloudFormation [curso-documentdb]: " STACK_NAME
STACK_NAME=${STACK_NAME:-curso-documentdb}

# Verificar se a stack já existe
if aws cloudformation describe-stacks --stack-name $STACK_NAME &> /dev/null; then
    warning "Stack '$STACK_NAME' já existe!"
    read -p "Deseja atualizar a stack existente? (y/N): " UPDATE_STACK
    if [[ $UPDATE_STACK =~ ^[Yy]$ ]]; then
        ACTION="update-stack"
    else
        error "Operação cancelada"
        exit 1
    fi
else
    ACTION="create-stack"
fi

# Obter VPC padrão
log "Obtendo VPC padrão..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
    error "VPC padrão não encontrada. Você precisa especificar uma VPC manualmente."
    read -p "Digite o ID da VPC: " VPC_ID
fi

# Obter subnet pública
log "Obtendo subnet pública..."
SUBNET_ID=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=true" \
    --query 'Subnets[0].SubnetId' --output text)

if [ "$SUBNET_ID" = "None" ] || [ -z "$SUBNET_ID" ]; then
    error "Subnet pública não encontrada na VPC $VPC_ID"
    read -p "Digite o ID da subnet pública: " SUBNET_ID
fi

success "VPC: $VPC_ID"
success "Subnet: $SUBNET_ID"

# Configurar CIDR permitido para SSH
echo ""
echo -e "${YELLOW}Configuração de Segurança:${NC}"
echo "Por segurança, recomendamos restringir o acesso SSH ao seu IP."

# Obter IP público atual
CURRENT_IP=$(curl -s https://checkip.amazonaws.com)
if [ $? -eq 0 ] && [ ! -z "$CURRENT_IP" ]; then
    log "Seu IP público atual: $CURRENT_IP"
    read -p "Usar seu IP atual para SSH? (Y/n): " USE_CURRENT_IP
    if [[ ! $USE_CURRENT_IP =~ ^[Nn]$ ]]; then
        ALLOWED_CIDR="$CURRENT_IP/32"
    fi
fi

if [ -z "$ALLOWED_CIDR" ]; then
    read -p "Digite o CIDR permitido para SSH [0.0.0.0/0]: " ALLOWED_CIDR
    ALLOWED_CIDR=${ALLOWED_CIDR:-0.0.0.0/0}
fi

warning "CIDR permitido para SSH: $ALLOWED_CIDR"

# Confirmação final
echo ""
echo -e "${YELLOW}Resumo da Configuração:${NC}"
echo "Stack Name: $STACK_NAME"
echo "Número de Alunos: $NUM_ALUNOS"
echo "Prefixo: $PREFIXO_ALUNO"
echo "VPC: $VPC_ID"
echo "Subnet: $SUBNET_ID"
echo "SSH CIDR: $ALLOWED_CIDR"
echo "Ação: $ACTION"

echo ""
read -p "Confirma a criação do ambiente? (y/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    error "Operação cancelada"
    exit 1
fi

# Deploy da stack
log "Iniciando deploy da stack CloudFormation..."

aws cloudformation $ACTION \
    --stack-name $STACK_NAME \
    --template-body file://setup-curso-documentdb-simple.yaml \
    --parameters \
        ParameterKey=NumeroAlunos,ParameterValue=$NUM_ALUNOS \
        ParameterKey=PrefixoAluno,ParameterValue=$PREFIXO_ALUNO \
        ParameterKey=VpcId,ParameterValue=$VPC_ID \
        ParameterKey=SubnetId,ParameterValue=$SUBNET_ID \
        ParameterKey=AllowedCIDR,ParameterValue=$ALLOWED_CIDR \
    --capabilities CAPABILITY_IAM \
    --tags \
        Key=Purpose,Value="Curso DocumentDB" \
        Key=Environment,Value="Lab" \
        Key=CreatedBy,Value="$(whoami)"

if [ $? -eq 0 ]; then
    success "Stack deployment iniciado com sucesso!"
    
    log "Aguardando conclusão do deployment..."
    aws cloudformation wait stack-${ACTION%-stack}-complete --stack-name $STACK_NAME
    
    if [ $? -eq 0 ]; then
        success "Stack deployment concluído!"
        
        # Obter outputs da stack
        log "Obtendo informações das instâncias criadas..."
        
        echo ""
        echo -e "${GREEN}🎉 AMBIENTE CRIADO COM SUCESSO! 🎉${NC}"
        echo ""
        
        # Mostrar informações das instâncias
        for i in $(seq 1 $NUM_ALUNOS); do
            ALUNO_NUM=$(printf "%02d" $i)
            
            # Tentar obter IP da instância
            INSTANCE_IP=$(aws cloudformation describe-stacks \
                --stack-name $STACK_NAME \
                --query "Stacks[0].Outputs[?OutputKey=='${PREFIXO_ALUNO^}${ALUNO_NUM}InstanceIP'].OutputValue" \
                --output text 2>/dev/null)
            
            if [ "$INSTANCE_IP" != "None" ] && [ ! -z "$INSTANCE_IP" ]; then
                echo -e "${BLUE}👨‍🎓 ${PREFIXO_ALUNO}${ALUNO_NUM}:${NC}"
                echo "  IP Público: $INSTANCE_IP"
                echo "  Usuário SSH: ec2-user"
                echo "  Usuário do Curso: ${PREFIXO_ALUNO}${ALUNO_NUM}"
                echo "  Chave SSH: ${STACK_NAME}-${PREFIXO_ALUNO}${ALUNO_NUM}-key"
                echo ""
            fi
        done
        
        echo -e "${YELLOW}📋 Próximos Passos:${NC}"
        echo "1. Baixe as chaves SSH do console EC2 > Key Pairs"
        echo "2. Configure permissões: chmod 400 nome-da-chave.pem"
        echo "3. Conecte via SSH: ssh -i chave.pem ec2-user@IP-PUBLICO"
        echo "4. Mude para o usuário do aluno: sudo su - ${PREFIXO_ALUNO}XX"
        echo "5. As credenciais AWS já estão configuradas!"
        echo ""
        echo -e "${GREEN}✨ Ambiente pronto para o curso! ✨${NC}"
        
    else
        error "Falha no deployment da stack"
        exit 1
    fi
else
    error "Falha ao iniciar deployment da stack"
    exit 1
fi