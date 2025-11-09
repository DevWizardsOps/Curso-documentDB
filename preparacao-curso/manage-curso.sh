#!/bin/bash

# Script para gerenciar o ambiente do Curso DocumentDB
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
║                GERENCIADOR DO CURSO DOCUMENTDB               ║
║                                                              ║
║  Gerencie instâncias, usuários e recursos do curso          ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Verificar AWS CLI
if ! command -v aws &> /dev/null; then
    error "AWS CLI não está instalado"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    error "Credenciais AWS não configuradas"
    exit 1
fi

# Função para listar stacks do curso
list_stacks() {
    log "Buscando stacks do curso DocumentDB..."
    
    STACKS=$(aws cloudformation list-stacks \
        --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
        --query 'StackSummaries[?contains(StackName, `curso`) || contains(StackName, `documentdb`)].{Name:StackName,Status:StackStatus,Created:CreationTime}' \
        --output table)
    
    if [ $? -eq 0 ]; then
        echo "$STACKS"
    else
        error "Erro ao listar stacks"
    fi
}

# Função para mostrar informações de uma stack
show_stack_info() {
    local stack_name=$1
    
    if [ -z "$stack_name" ]; then
        error "Nome da stack não fornecido"
        return 1
    fi
    
    log "Obtendo informações da stack: $stack_name"
    
    # Verificar se a stack existe
    if ! aws cloudformation describe-stacks --stack-name $stack_name &> /dev/null; then
        error "Stack '$stack_name' não encontrada"
        return 1
    fi
    
    # Obter parâmetros da stack
    echo -e "\n${YELLOW}📋 Parâmetros da Stack:${NC}"
    aws cloudformation describe-stacks \
        --stack-name $stack_name \
        --query 'Stacks[0].Parameters[].{Parameter:ParameterKey,Value:ParameterValue}' \
        --output table
    
    # Obter outputs da stack
    echo -e "\n${YELLOW}📤 Outputs da Stack:${NC}"
    aws cloudformation describe-stacks \
        --stack-name $stack_name \
        --query 'Stacks[0].Outputs[].{Output:OutputKey,Value:OutputValue}' \
        --output table
    
    # Listar instâncias EC2 da stack
    echo -e "\n${YELLOW}🖥️  Instâncias EC2:${NC}"
    aws ec2 describe-instances \
        --filters "Name=tag:aws:cloudformation:stack-name,Values=$stack_name" "Name=instance-state-name,Values=running,stopped,pending" \
        --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
        --output table
    
    # Listar usuários IAM da stack
    echo -e "\n${YELLOW}👥 Usuários IAM:${NC}"
    aws iam list-users \
        --query "Users[?contains(UserName, '$stack_name')].{UserName:UserName,Created:CreateDate}" \
        --output table
    
    # Listar chaves SSH
    echo -e "\n${YELLOW}🔑 Chaves SSH:${NC}"
    aws ec2 describe-key-pairs \
        --query "KeyPairs[?contains(KeyName, '$stack_name')].{KeyName:KeyName,KeyType:KeyType,Created:CreateTime}" \
        --output table
}

# Função para conectar a uma instância
connect_instance() {
    local stack_name=$1
    local aluno_num=$2
    
    if [ -z "$stack_name" ] || [ -z "$aluno_num" ]; then
        error "Uso: connect_instance <stack-name> <numero-aluno>"
        return 1
    fi
    
    # Obter prefixo do aluno da stack
    PREFIXO=$(aws cloudformation describe-stacks \
        --stack-name $stack_name \
        --query 'Stacks[0].Parameters[?ParameterKey==`PrefixoAluno`].ParameterValue' \
        --output text)
    
    if [ "$PREFIXO" = "None" ] || [ -z "$PREFIXO" ]; then
        PREFIXO="aluno"
    fi
    
    # Formatar número do aluno
    ALUNO_FORMATTED=$(printf "%02d" $aluno_num)
    
    # Obter IP da instância
    INSTANCE_IP=$(aws cloudformation describe-stacks \
        --stack-name $stack_name \
        --query "Stacks[0].Outputs[?OutputKey=='${PREFIXO^}${ALUNO_FORMATTED}InstanceIP'].OutputValue" \
        --output text 2>/dev/null)
    
    if [ "$INSTANCE_IP" = "None" ] || [ -z "$INSTANCE_IP" ]; then
        error "IP da instância do ${PREFIXO}${ALUNO_FORMATTED} não encontrado"
        return 1
    fi
    
    KEY_NAME="${stack_name}-${PREFIXO}${ALUNO_FORMATTED}-key"
    
    echo -e "${GREEN}🔗 Conectando ao ${PREFIXO}${ALUNO_FORMATTED}:${NC}"
    echo "IP: $INSTANCE_IP"
    echo "Chave SSH: $KEY_NAME"
    echo ""
    echo -e "${YELLOW}Comandos para conexão:${NC}"
    echo "1. Baixe a chave do console EC2 se ainda não fez"
    echo "2. chmod 400 ${KEY_NAME}.pem"
    echo "3. ssh -i ${KEY_NAME}.pem ec2-user@${INSTANCE_IP}"
    echo "4. sudo su - ${PREFIXO}${ALUNO_FORMATTED}"
    echo ""
    
    read -p "Tentar conexão automática? (y/N): " AUTO_CONNECT
    if [[ $AUTO_CONNECT =~ ^[Yy]$ ]]; then
        if [ -f "${KEY_NAME}.pem" ]; then
            chmod 400 "${KEY_NAME}.pem"
            ssh -i "${KEY_NAME}.pem" ec2-user@${INSTANCE_IP}
        else
            error "Arquivo de chave ${KEY_NAME}.pem não encontrado no diretório atual"
        fi
    fi
}

# Função para parar/iniciar instâncias
manage_instances() {
    local stack_name=$1
    local action=$2
    
    if [ -z "$stack_name" ] || [ -z "$action" ]; then
        error "Uso: manage_instances <stack-name> <start|stop>"
        return 1
    fi
    
    # Obter IDs das instâncias da stack
    INSTANCE_IDS=$(aws ec2 describe-instances \
        --filters "Name=tag:aws:cloudformation:stack-name,Values=$stack_name" "Name=instance-state-name,Values=running,stopped" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text)
    
    if [ -z "$INSTANCE_IDS" ]; then
        warning "Nenhuma instância encontrada para a stack $stack_name"
        return 1
    fi
    
    echo "Instâncias encontradas: $INSTANCE_IDS"
    
    case $action in
        "start")
            log "Iniciando instâncias..."
            aws ec2 start-instances --instance-ids $INSTANCE_IDS
            success "Comando de start enviado"
            ;;
        "stop")
            log "Parando instâncias..."
            aws ec2 stop-instances --instance-ids $INSTANCE_IDS
            success "Comando de stop enviado"
            ;;
        *)
            error "Ação inválida. Use 'start' ou 'stop'"
            return 1
            ;;
    esac
}

# Função para limpar recursos
cleanup_stack() {
    local stack_name=$1
    
    if [ -z "$stack_name" ]; then
        error "Nome da stack não fornecido"
        return 1
    fi
    
    warning "Esta ação irá DELETAR PERMANENTEMENTE todos os recursos da stack!"
    echo "Stack: $stack_name"
    echo ""
    read -p "Digite 'DELETE' para confirmar: " CONFIRM
    
    if [ "$CONFIRM" != "DELETE" ]; then
        error "Operação cancelada"
        return 1
    fi
    
    log "Deletando stack $stack_name..."
    aws cloudformation delete-stack --stack-name $stack_name
    
    if [ $? -eq 0 ]; then
        success "Comando de deleção enviado"
        log "Aguardando conclusão da deleção..."
        aws cloudformation wait stack-delete-complete --stack-name $stack_name
        success "Stack deletada com sucesso!"
    else
        error "Erro ao deletar stack"
    fi
}

# Função para gerar relatório de custos
cost_report() {
    local stack_name=$1
    
    if [ -z "$stack_name" ]; then
        error "Nome da stack não fornecido"
        return 1
    fi
    
    log "Gerando relatório de custos para $stack_name..."
    
    # Obter recursos da stack
    echo -e "\n${YELLOW}💰 Recursos que geram custos:${NC}"
    
    # Instâncias EC2
    echo -e "\n🖥️  Instâncias EC2:"
    aws ec2 describe-instances \
        --filters "Name=tag:aws:cloudformation:stack-name,Values=$stack_name" \
        --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,LaunchTime]' \
        --output table
    
    # Volumes EBS
    echo -e "\n💾 Volumes EBS:"
    aws ec2 describe-volumes \
        --filters "Name=tag:aws:cloudformation:stack-name,Values=$stack_name" \
        --query 'Volumes[].[VolumeId,VolumeType,Size,State]' \
        --output table
    
    # Snapshots
    echo -e "\n📸 Snapshots:"
    aws ec2 describe-snapshots \
        --owner-ids self \
        --filters "Name=tag:aws:cloudformation:stack-name,Values=$stack_name" \
        --query 'Snapshots[].[SnapshotId,VolumeSize,StartTime,State]' \
        --output table
    
    echo -e "\n${YELLOW}💡 Dicas para reduzir custos:${NC}"
    echo "• Pare instâncias quando não estiver usando"
    echo "• Delete snapshots desnecessários"
    echo "• Use instâncias t3.micro (Free Tier elegível)"
    echo "• Delete a stack ao final do curso"
}

# Menu principal
show_menu() {
    echo -e "\n${YELLOW}Escolha uma opção:${NC}"
    echo "1. Listar stacks do curso"
    echo "2. Mostrar informações de uma stack"
    echo "3. Conectar a uma instância"
    echo "4. Parar instâncias"
    echo "5. Iniciar instâncias"
    echo "6. Relatório de custos"
    echo "7. Deletar stack (CUIDADO!)"
    echo "8. Sair"
    echo ""
}

# Loop principal
while true; do
    show_menu
    read -p "Opção: " choice
    
    case $choice in
        1)
            list_stacks
            ;;
        2)
            read -p "Nome da stack: " stack_name
            show_stack_info "$stack_name"
            ;;
        3)
            read -p "Nome da stack: " stack_name
            read -p "Número do aluno: " aluno_num
            connect_instance "$stack_name" "$aluno_num"
            ;;
        4)
            read -p "Nome da stack: " stack_name
            manage_instances "$stack_name" "stop"
            ;;
        5)
            read -p "Nome da stack: " stack_name
            manage_instances "$stack_name" "start"
            ;;
        6)
            read -p "Nome da stack: " stack_name
            cost_report "$stack_name"
            ;;
        7)
            read -p "Nome da stack: " stack_name
            cleanup_stack "$stack_name"
            ;;
        8)
            success "Até logo!"
            exit 0
            ;;
        *)
            error "Opção inválida"
            ;;
    esac
    
    echo ""
    read -p "Pressione Enter para continuar..."
done