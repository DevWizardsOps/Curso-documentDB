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
║  Gerencie instâncias, usuários e recursos do curso           ║
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

# Função para forçar limpeza de recursos manualmente
force_cleanup_resources() {
    local stack_name=$1
    
    log "Iniciando limpeza forçada de recursos..."
    
    # Obter região
    REGION=$(aws configure get region)
    
    # 1. Deletar instâncias EC2
    log "Procurando instâncias EC2 da stack..."
    INSTANCE_IDS=$(aws ec2 describe-instances \
        --filters "Name=tag:aws:cloudformation:stack-name,Values=$stack_name" "Name=instance-state-name,Values=running,stopped,pending" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text)
    
    if [ ! -z "$INSTANCE_IDS" ]; then
        warning "Terminando instâncias EC2: $INSTANCE_IDS"
        aws ec2 terminate-instances --instance-ids $INSTANCE_IDS
        log "Aguardando terminação das instâncias..."
        aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS 2>/dev/null || true
        success "Instâncias EC2 terminadas"
    fi
    
    # 2. Deletar clusters DocumentDB
    log "Procurando clusters DocumentDB da stack..."
    DOCDB_CLUSTERS=$(aws docdb describe-db-clusters \
        --query "DBClusters[?contains(DBClusterIdentifier, '$stack_name')].DBClusterIdentifier" \
        --output text 2>/dev/null)
    
    if [ ! -z "$DOCDB_CLUSTERS" ]; then
        for cluster in $DOCDB_CLUSTERS; do
            warning "Deletando cluster DocumentDB: $cluster"
            
            # Deletar instâncias do cluster primeiro
            INSTANCES=$(aws docdb describe-db-clusters \
                --db-cluster-identifier $cluster \
                --query 'DBClusters[0].DBClusterMembers[].DBInstanceIdentifier' \
                --output text 2>/dev/null)
            
            for instance in $INSTANCES; do
                log "Deletando instância: $instance"
                aws docdb delete-db-instance \
                    --db-instance-identifier $instance \
                    --skip-final-snapshot 2>/dev/null || true
            done
            
            # Aguardar instâncias serem deletadas
            sleep 10
            
            # Deletar cluster
            aws docdb delete-db-cluster \
                --db-cluster-identifier $cluster \
                --skip-final-snapshot 2>/dev/null || true
        done
        success "Clusters DocumentDB deletados"
    fi
    
    # 3. Deletar Security Groups (exceto default)
    log "Procurando Security Groups da stack..."
    sleep 5  # Aguardar recursos serem liberados
    
    SG_IDS=$(aws ec2 describe-security-groups \
        --filters "Name=tag:aws:cloudformation:stack-name,Values=$stack_name" \
        --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
        --output text 2>/dev/null)
    
    if [ ! -z "$SG_IDS" ]; then
        for sg in $SG_IDS; do
            warning "Deletando Security Group: $sg"
            aws ec2 delete-security-group --group-id $sg 2>/dev/null || warning "Não foi possível deletar $sg (pode estar em uso)"
        done
    fi
    
    # 4. Deletar IAM Users e Access Keys
    log "Procurando usuários IAM da stack..."
    IAM_USERS=$(aws iam list-users \
        --query "Users[?contains(UserName, '$stack_name')].UserName" \
        --output text 2>/dev/null)
    
    if [ ! -z "$IAM_USERS" ]; then
        for user in $IAM_USERS; do
            warning "Deletando usuário IAM: $user"
            
            # Remover access keys
            ACCESS_KEYS=$(aws iam list-access-keys --user-name $user --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null)
            for key in $ACCESS_KEYS; do
                aws iam delete-access-key --user-name $user --access-key-id $key 2>/dev/null || true
            done
            
            # Remover login profile
            aws iam delete-login-profile --user-name $user 2>/dev/null || true
            
            # Remover de grupos
            GROUPS=$(aws iam list-groups-for-user --user-name $user --query 'Groups[].GroupName' --output text 2>/dev/null)
            for group in $GROUPS; do
                aws iam remove-user-from-group --user-name $user --group-name $group 2>/dev/null || true
            done
            
            # Deletar usuário
            aws iam delete-user --user-name $user 2>/dev/null || true
        done
        success "Usuários IAM deletados"
    fi
    
    success "Limpeza forçada concluída"
}

# Função para limpar recursos
cleanup_stack() {
    local stack_name=$1
    local force_mode=$2
    
    if [ -z "$stack_name" ]; then
        error "Nome da stack não fornecido"
        return 1
    fi
    
    warning "Esta ação irá DELETAR PERMANENTEMENTE todos os recursos da stack!"
    echo "Stack: $stack_name"
    echo ""
    
    # Obter informações da conta para construir o nome do bucket
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    S3_BUCKET="${stack_name}-keys-${ACCOUNT_ID}"
    
    # Verificar se o bucket S3 existe
    if aws s3 ls "s3://${S3_BUCKET}" &> /dev/null; then
        echo -e "\n${YELLOW}🗑️  Bucket S3 encontrado: ${S3_BUCKET}${NC}"
        read -p "Deletar também o bucket S3 com as chaves? (Y/n): " DELETE_S3
        
        if [[ ! $DELETE_S3 =~ ^[Nn]$ ]]; then
            log "Listando objetos no bucket..."
            OBJECTS=$(aws s3 ls "s3://${S3_BUCKET}" --recursive)
            
            if [ ! -z "$OBJECTS" ]; then
                echo -e "\n${YELLOW}Objetos no bucket:${NC}"
                echo "$OBJECTS"
                echo ""
            fi
            
            log "Removendo todos os objetos do bucket..."
            aws s3 rm "s3://${S3_BUCKET}" --recursive
            
            if [ $? -eq 0 ]; then
                success "Objetos removidos do bucket"
                
                log "Deletando bucket S3..."
                aws s3 rb "s3://${S3_BUCKET}"
                
                if [ $? -eq 0 ]; then
                    success "Bucket S3 deletado: ${S3_BUCKET}"
                else
                    warning "Erro ao deletar bucket S3 (pode não estar vazio)"
                fi
            else
                warning "Erro ao remover objetos do bucket"
            fi
        else
            warning "Bucket S3 será mantido"
        fi
    fi
    
    # Verificar se existe secret no Secrets Manager
    SECRET_NAME="${stack_name}-console-password"
    if aws secretsmanager describe-secret --secret-id $SECRET_NAME &> /dev/null 2>&1; then
        echo -e "\n${YELLOW}🔐 Secret encontrado: ${SECRET_NAME}${NC}"
        read -p "Deletar também o secret do Secrets Manager? (Y/n): " DELETE_SECRET
        
        if [[ ! $DELETE_SECRET =~ ^[Nn]$ ]]; then
            log "Deletando secret..."
            aws secretsmanager delete-secret --secret-id $SECRET_NAME --force-delete-without-recovery
            
            if [ $? -eq 0 ]; then
                success "Secret deletado: ${SECRET_NAME}"
            else
                warning "Erro ao deletar secret"
            fi
        else
            warning "Secret será mantido"
        fi
    fi
    
    # Modo force: limpar recursos manualmente primeiro
    if [ "$force_mode" = "force" ]; then
        echo -e "\n${YELLOW}⚡ MODO FORCE ATIVADO${NC}"
        echo "Recursos serão deletados manualmente antes da stack"
        echo ""
        read -p "Continuar com limpeza forçada? (y/N): " CONFIRM_FORCE
        
        if [[ $CONFIRM_FORCE =~ ^[Yy]$ ]]; then
            force_cleanup_resources "$stack_name"
        else
            error "Operação cancelada"
            return 1
        fi
    fi
    
    echo ""
    read -p "Digite 'DELETE' para confirmar a deleção da stack CloudFormation: " CONFIRM
    
    if [ "$CONFIRM" != "DELETE" ]; then
        error "Operação cancelada"
        return 1
    fi
    
    log "Deletando stack CloudFormation $stack_name..."
    aws cloudformation delete-stack --stack-name $stack_name
    
    if [ $? -eq 0 ]; then
        success "Comando de deleção enviado"
        log "Aguardando conclusão da deleção..."
        
        # Usar timeout para evitar espera infinita
        timeout 600 aws cloudformation wait stack-delete-complete --stack-name $stack_name 2>/dev/null
        WAIT_RESULT=$?
        
        if [ $WAIT_RESULT -eq 0 ]; then
            success "Stack deletada com sucesso!"
            
            # Limpar arquivo local de informações da chave SSH se existir
            if [ -f ".ssh-key-info" ]; then
                rm -f .ssh-key-info
                log "Arquivo .ssh-key-info removido"
            fi
            
            echo -e "\n${GREEN}✨ Limpeza completa realizada!${NC}"
        elif [ $WAIT_RESULT -eq 124 ]; then
            warning "Timeout aguardando deleção (10 minutos)"
            echo "Verifique o status da stack no console AWS"
        else
            error "Erro ao aguardar conclusão da deleção"
            echo ""
            echo -e "${YELLOW}💡 Dica: Se a stack falhou ao deletar, tente:${NC}"
            echo "1. Verificar o motivo no console CloudFormation"
            echo "2. Usar a opção 8 novamente e escolher modo FORCE"
            echo "3. Deletar recursos manualmente e tentar novamente"
            
            # Verificar status da stack
            STACK_STATUS=$(aws cloudformation describe-stacks --stack-name $stack_name --query 'Stacks[0].StackStatus' --output text 2>/dev/null)
            if [ "$STACK_STATUS" = "DELETE_FAILED" ]; then
                error "Stack em estado DELETE_FAILED"
                echo ""
                read -p "Tentar limpeza forçada agora? (y/N): " RETRY_FORCE
                if [[ $RETRY_FORCE =~ ^[Yy]$ ]]; then
                    cleanup_stack "$stack_name" "force"
                fi
            fi
        fi
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

# Função para listar buckets S3 do curso
list_s3_buckets() {
    log "Buscando buckets S3 do curso..."
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    echo -e "\n${YELLOW}📦 Buckets S3 relacionados ao curso:${NC}"
    
    # Listar todos os buckets
    ALL_BUCKETS=$(aws s3api list-buckets --query 'Buckets[].Name' --output text)
    
    for bucket in $ALL_BUCKETS; do
        if [[ $bucket == *"curso"* ]] || [[ $bucket == *"documentdb"* ]] || [[ $bucket == *"keys"* ]]; then
            echo -e "\n${BLUE}Bucket: ${bucket}${NC}"
            
            # Obter tamanho do bucket
            SIZE=$(aws s3 ls "s3://${bucket}" --recursive --summarize 2>/dev/null | grep "Total Size" | awk '{print $3}')
            OBJECTS=$(aws s3 ls "s3://${bucket}" --recursive --summarize 2>/dev/null | grep "Total Objects" | awk '{print $3}')
            
            if [ ! -z "$SIZE" ]; then
                SIZE_MB=$(echo "scale=2; $SIZE / 1024 / 1024" | bc)
                echo "  Tamanho: ${SIZE_MB} MB"
                echo "  Objetos: ${OBJECTS}"
            else
                echo "  Bucket vazio"
            fi
            
            # Listar objetos
            echo "  Objetos:"
            aws s3 ls "s3://${bucket}" --recursive --human-readable | head -10
            
            TOTAL=$(aws s3 ls "s3://${bucket}" --recursive | wc -l)
            if [ $TOTAL -gt 10 ]; then
                echo "  ... e mais $(($TOTAL - 10)) objetos"
            fi
        fi
    done
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
    echo "7. Listar buckets S3 do curso"
    echo "8. Deletar stack (CUIDADO!)"
    echo "9. Deletar stack com FORCE (recursos manuais primeiro)"
    echo "10. Sair"
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
            list_s3_buckets
            ;;
        8)
            read -p "Nome da stack: " stack_name
            cleanup_stack "$stack_name"
            ;;
        9)
            read -p "Nome da stack: " stack_name
            cleanup_stack "$stack_name" "force"
            ;;
        10)
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