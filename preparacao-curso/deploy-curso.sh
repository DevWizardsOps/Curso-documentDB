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
║  Este script criará instâncias EC2 e usuários IAM            ║
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

# Configurar senha do console
echo ""
echo -e "${YELLOW}Configuração de Senha do Console:${NC}"
read -p "Senha padrão para os alunos [Extractta@2026]: " CONSOLE_PASSWORD
CONSOLE_PASSWORD=${CONSOLE_PASSWORD:-Extractta@2026}

# Validar senha (mínimo 8 caracteres)
while [ ${#CONSOLE_PASSWORD} -lt 8 ]; do
    error "Senha deve ter no mínimo 8 caracteres"
    read -p "Senha padrão para os alunos [Extractta@2026]: " CONSOLE_PASSWORD
    CONSOLE_PASSWORD=${CONSOLE_PASSWORD:-Extractta@2026}
done

success "Senha configurada (será armazenada no Secrets Manager)"

# Configurar chave SSH
echo ""
echo -e "${YELLOW}Configuração da Chave SSH:${NC}"
KEY_NAME="${STACK_NAME}-key"
KEY_FILE="${KEY_NAME}.pem"

# Verificar se a chave já existe na AWS
if aws ec2 describe-key-pairs --key-names $KEY_NAME &> /dev/null; then
    warning "Chave SSH '$KEY_NAME' já existe na AWS"
    
    # Verificar se o arquivo local existe
    if [ -f "$KEY_FILE" ]; then
        success "Arquivo local da chave encontrado: $KEY_FILE"
        read -p "Usar chave existente? (Y/n): " USE_EXISTING
        if [[ $USE_EXISTING =~ ^[Nn]$ ]]; then
            error "Operação cancelada. Delete a chave na AWS primeiro ou use outro nome de stack."
            exit 1
        fi
    else
        error "Chave existe na AWS mas arquivo local não encontrado!"
        echo "Você tem duas opções:"
        echo "1. Se você tem o arquivo .pem, coloque-o neste diretório como: $KEY_FILE"
        echo "2. Delete a chave na AWS e execute o script novamente"
        echo ""
        echo "Para deletar: aws ec2 delete-key-pair --key-name $KEY_NAME"
        exit 1
    fi
else
    log "Criando nova chave SSH..."
    
    # Criar chave SSH localmente
    ssh-keygen -t rsa -b 2048 -f "$KEY_FILE" -N "" -C "Curso DocumentDB - $STACK_NAME" &> /dev/null
    
    if [ $? -eq 0 ]; then
        success "Chave SSH criada localmente: $KEY_FILE"
        
        # Fazer upload da chave pública para AWS
        log "Fazendo upload da chave pública para AWS..."
        aws ec2 import-key-pair \
            --key-name $KEY_NAME \
            --public-key-material fileb://${KEY_FILE}.pub
        
        if [ $? -eq 0 ]; then
            success "Chave SSH importada para AWS: $KEY_NAME"
            
            # Ajustar permissões
            chmod 400 $KEY_FILE
            success "Permissões ajustadas: chmod 400 $KEY_FILE"
            
            # Remover chave pública (não é mais necessária)
            rm -f ${KEY_FILE}.pub
            
            # Upload da chave privada para S3 (para distribuição aos alunos)
            log "Fazendo upload da chave privada para S3..."
            
            # Criar estrutura de diretório: ano/mes/dia
            S3_KEY_PATH="$(date +%Y)/$(date +%m)/$(date +%d)/${KEY_FILE}"
            S3_BUCKET="${STACK_NAME}-keys-${ACCOUNT_ID}"
            
            # Criar bucket se não existir
            if ! aws s3 ls "s3://${S3_BUCKET}" 2>&1 | grep -q 'NoSuchBucket'; then
                log "Bucket já existe: ${S3_BUCKET}"
            else
                log "Criando bucket S3: ${S3_BUCKET}"
                aws s3 mb "s3://${S3_BUCKET}" --region $REGION
                
                # Bloquear acesso público
                aws s3api put-public-access-block \
                    --bucket ${S3_BUCKET} \
                    --public-access-block-configuration \
                    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
            fi
            
            # Upload da chave
            aws s3 cp ${KEY_FILE} "s3://${S3_BUCKET}/${S3_KEY_PATH}" \
                --metadata "stack-name=${STACK_NAME},created-date=$(date -Iseconds)" \
                --region $REGION
            
            if [ $? -eq 0 ]; then
                success "Chave SSH enviada para S3: s3://${S3_BUCKET}/${S3_KEY_PATH}"
                
                # Gerar URL de console para download
                S3_CONSOLE_URL="https://s3.console.aws.amazon.com/s3/object/${S3_BUCKET}?region=${REGION}&prefix=${S3_KEY_PATH}"
                
                # Salvar informações para uso posterior
                echo "S3_BUCKET=${S3_BUCKET}" > .ssh-key-info
                echo "S3_KEY_PATH=${S3_KEY_PATH}" >> .ssh-key-info
                echo "S3_CONSOLE_URL=${S3_CONSOLE_URL}" >> .ssh-key-info
            else
                warning "Falha ao enviar chave para S3 (não crítico)"
            fi
        else
            error "Falha ao importar chave para AWS"
            exit 1
        fi
    else
        error "Falha ao criar chave SSH"
        exit 1
    fi
fi

# Criar/atualizar secret no Secrets Manager
echo ""
log "Configurando Secrets Manager..."
SECRET_NAME="${STACK_NAME}-console-password"

# Desabilitar exit on error temporariamente para verificação
set +e

# Verificar se o secret já existe
aws secretsmanager describe-secret --secret-id $SECRET_NAME &> /dev/null
SECRET_EXISTS=$?

if [ $SECRET_EXISTS -eq 0 ]; then
    # Secret existe, verificar se está deletado
    SECRET_STATUS=$(aws secretsmanager describe-secret --secret-id $SECRET_NAME --query 'DeletedDate' --output text 2>/dev/null)
    
    if [ "$SECRET_STATUS" == "None" ] || [ -z "$SECRET_STATUS" ]; then
        # Secret existe e está ativo
        log "Secret já existe, atualizando..."
        aws secretsmanager put-secret-value \
            --secret-id $SECRET_NAME \
            --secret-string "{\"password\":\"$CONSOLE_PASSWORD\"}"
        
        if [ $? -eq 0 ]; then
            success "Secret atualizado: $SECRET_NAME"
        else
            set -e
            error "Falha ao atualizar secret"
            exit 1
        fi
    else
        # Secret existe mas está marcado para deleção
        warning "Secret existe mas está marcado para deleção. Restaurando..."
        aws secretsmanager restore-secret --secret-id $SECRET_NAME
        
        if [ $? -eq 0 ]; then
            success "Secret restaurado: $SECRET_NAME"
            
            # Atualizar o valor
            aws secretsmanager put-secret-value \
                --secret-id $SECRET_NAME \
                --secret-string "{\"password\":\"$CONSOLE_PASSWORD\"}"
            
            if [ $? -eq 0 ]; then
                success "Secret atualizado: $SECRET_NAME"
            else
                set -e
                error "Falha ao atualizar secret restaurado"
                exit 1
            fi
        else
            set -e
            error "Falha ao restaurar secret"
            exit 1
        fi
    fi
else
    # Secret não existe, criar novo
    log "Criando novo secret..."
    aws secretsmanager create-secret \
        --name $SECRET_NAME \
        --description "Senha padrão do console para alunos do curso DocumentDB" \
        --secret-string "{\"password\":\"$CONSOLE_PASSWORD\"}" \
        --tags Key=Purpose,Value="Curso DocumentDB" Key=Stack,Value="$STACK_NAME"
    
    if [ $? -eq 0 ]; then
        success "Secret criado: $SECRET_NAME"
    else
        set -e
        error "Falha ao criar secret"
        exit 1
    fi
fi

# Reabilitar exit on error
set -e

# Obter ARN do secret
SECRET_ARN=$(aws secretsmanager describe-secret --secret-id $SECRET_NAME --query 'ARN' --output text)
success "Secret ARN: $SECRET_ARN"

# Confirmação final
echo ""
echo -e "${YELLOW}Resumo da Configuração:${NC}"
echo "Stack Name: $STACK_NAME"
echo "Número de Alunos: $NUM_ALUNOS"
echo "Prefixo: $PREFIXO_ALUNO"
echo "VPC: $VPC_ID"
echo "Subnet: $SUBNET_ID"
echo "SSH CIDR: $ALLOWED_CIDR"
echo "Chave SSH: $KEY_NAME (arquivo: $KEY_FILE)"
echo "Senha Console: ******** (armazenada em: $SECRET_NAME)"
echo "Ação: $ACTION"

echo ""
read -p "Confirma a criação do ambiente? (y/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    error "Operação cancelada"
    exit 1
fi

# Gerar template dinamicamente
log "Gerando template CloudFormation para $NUM_ALUNOS alunos..."
bash gerar-template.sh $NUM_ALUNOS

if [ $? -ne 0 ]; then
    error "Falha ao gerar template"
    exit 1
fi

success "Template gerado com sucesso"

# Criar bucket S3 para labs se não existir (antes do deploy)
LABS_BUCKET="${STACK_NAME}-labs-${ACCOUNT_ID}"
log "Verificando bucket S3 para scripts: $LABS_BUCKET"

if ! aws s3 ls "s3://${LABS_BUCKET}" 2>&1 | grep -q 'NoSuchBucket'; then
    log "Bucket já existe: ${LABS_BUCKET}"
else
    log "Criando bucket S3: ${LABS_BUCKET}"
    aws s3 mb "s3://${LABS_BUCKET}" --region $REGION
    
    # Configurar bloqueio de acesso público
    aws s3api put-public-access-block \
        --bucket ${LABS_BUCKET} \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    success "Bucket criado: ${LABS_BUCKET}"
fi

# Upload do script de setup para o S3
log "Fazendo upload do script de setup para o S3..."
if [ -f "setup-aluno.sh" ]; then
    aws s3 cp setup-aluno.sh "s3://${LABS_BUCKET}/scripts/setup-aluno.sh"
    if [ $? -eq 0 ]; then
        success "Script de setup enviado para S3"
    else
        error "Falha ao enviar script para S3"
        exit 1
    fi
else
    error "Arquivo setup-aluno.sh não encontrado!"
    exit 1
fi

# Deploy da stack
log "Iniciando deploy da stack CloudFormation..."

# Debug: verificar se todas as variáveis estão definidas
if [ -z "$KEY_NAME" ]; then
    error "KEY_NAME não está definido!"
    exit 1
fi

log "Parâmetros do CloudFormation:"
log "  NumeroAlunos: $NUM_ALUNOS"
log "  PrefixoAluno: $PREFIXO_ALUNO"
log "  VpcId: $VPC_ID"
log "  SubnetId: $SUBNET_ID"
log "  AllowedCIDR: $ALLOWED_CIDR"
log "  KeyPairName: $KEY_NAME"
log "  ConsolePasswordSecret: $SECRET_NAME"
log "  LabsBucketName: $LABS_BUCKET"

aws cloudformation $ACTION \
    --stack-name "$STACK_NAME" \
    --template-body file://setup-curso-documentdb-dynamic.yaml \
    --parameters \
        ParameterKey=NumeroAlunos,ParameterValue="$NUM_ALUNOS" \
        ParameterKey=PrefixoAluno,ParameterValue="$PREFIXO_ALUNO" \
        ParameterKey=VpcId,ParameterValue="$VPC_ID" \
        ParameterKey=SubnetId,ParameterValue="$SUBNET_ID" \
        ParameterKey=AllowedCIDR,ParameterValue="$ALLOWED_CIDR" \
        ParameterKey=KeyPairName,ParameterValue="$KEY_NAME" \
        ParameterKey=ConsolePasswordSecret,ParameterValue="$SECRET_NAME" \
        ParameterKey=LabsBucketName,ParameterValue="$LABS_BUCKET" \
    --capabilities CAPABILITY_NAMED_IAM \
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
        echo ""
        echo -e "${GREEN}🌐 ACESSO AO CONSOLE AWS:${NC}"
        echo "  URL: https://${ACCOUNT_ID}.signin.aws.amazon.com/console"
        echo "  Usuários: ${STACK_NAME}-${PREFIXO_ALUNO}01, ${STACK_NAME}-${PREFIXO_ALUNO}02"
        echo "  Senha padrão: Extractta@2026"
        echo ""
        # Mostrar informações do S3 se disponível
        if [ -f ".ssh-key-info" ]; then
            source .ssh-key-info
            echo -e "${GREEN}🔑 CHAVE SSH:${NC}"
            echo "  📁 Arquivo Local: $(pwd)/$KEY_FILE"
            echo "  ⚠️  IMPORTANTE: Guarde este arquivo em local seguro!"
            echo ""
            echo -e "${GREEN}☁️  CHAVE NO S3 (Para Distribuição aos Alunos):${NC}"
            echo "  📦 Bucket: ${S3_BUCKET}"
            echo "  📂 Caminho: ${S3_KEY_PATH}"
            echo ""
            echo -e "${BLUE}🔗 Link para Download (Console AWS):${NC}"
            echo "  ${S3_CONSOLE_URL}"
            echo ""
            echo -e "${YELLOW}📖 Manual Completo de Download:${NC}"
            echo "  https://github.com/DevWizardsOps/Curso-documentDB/blob/main/apoio-alunos/01-download-chave-ssh.md"
            echo ""
            echo -e "${YELLOW}📋 Instruções Rápidas para os Alunos:${NC}"
            echo "  1. Acesse o link do S3 acima (precisa estar logado no Console AWS)"
            echo "  2. Clique em 'Download' ou 'Baixar'"
            echo "  3. Salve como: ${KEY_FILE}"
            echo "  4. Execute: chmod 400 ${KEY_FILE}"
            echo ""
            echo -e "${YELLOW}📋 Ou via AWS CLI:${NC}"
            echo "  aws s3 cp s3://${S3_BUCKET}/${S3_KEY_PATH} ${KEY_FILE}"
            echo "  chmod 400 ${KEY_FILE}"
            echo ""
        else
            echo -e "${GREEN}🔑 CHAVE SSH:${NC}"
            echo "  📁 Arquivo Local: $(pwd)/$KEY_FILE"
            echo "  ⚠️  IMPORTANTE: Guarde este arquivo em local seguro!"
            echo ""
            echo -e "${YELLOW}📖 Manual de Download:${NC}"
            echo "  https://github.com/DevWizardsOps/Curso-documentDB/blob/main/apoio-alunos/01-download-chave-ssh.md"
            echo ""
        fi
        
        echo -e "${GREEN}🔌 CONEXÃO SSH (Recomendado):${NC}"
        echo "  ssh -i $KEY_FILE ${PREFIXO_ALUNO}XX@IP-PUBLICO"
        echo ""
        echo -e "${GREEN}🔌 CONEXÃO SSH (Alternativa via ec2-user):${NC}"
        echo "  ssh -i $KEY_FILE ec2-user@IP-PUBLICO"
        echo "  sudo su - ${PREFIXO_ALUNO}XX"
        echo ""
        echo -e "${YELLOW}💡 Dicas:${NC}"
        echo "  • Compartilhe o link do S3 com os alunos"
        echo "  • Ou distribua o arquivo $KEY_FILE diretamente"
        echo "  • Senha do console: Extractta@2026"
        echo "  • As credenciais AWS já estão configuradas nas instâncias"
        echo ""
        echo -e "${GREEN}✨ Ambiente pronto para o curso! ✨${NC}"
        
        # Gerar arquivo HTML com as informações (SEM A SENHA)
        log "Gerando relatório HTML..."
        
        HTML_FILE="curso-documentdb-info-$(date +%Y%m%d-%H%M%S).html"
        
        # Criar HTML completo localmente PRIMEIRO
        {
            cat << 'HTML_HEADER'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Curso DocumentDB - Informações de Acesso</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .header p {
            font-size: 1.2em;
            opacity: 0.9;
        }
        .content {
            padding: 40px;
        }
        .info-section {
            background: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 20px;
            margin-bottom: 20px;
            border-radius: 8px;
        }
        .info-section h2 {
            color: #667eea;
            margin-bottom: 15px;
            font-size: 1.5em;
        }
        .info-item {
            margin: 10px 0;
            padding: 10px;
            background: white;
            border-radius: 5px;
        }
        .info-item strong {
            color: #333;
            display: inline-block;
            min-width: 180px;
        }
        .warning-box {
            background: #fff3cd;
            border: 2px solid #ffc107;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
        }
        .warning-box h3 {
            color: #856404;
            margin-bottom: 10px;
        }
        .warning-box p {
            color: #856404;
            line-height: 1.6;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(450px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        .aluno-card {
            background: white;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            padding: 25px;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .aluno-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 25px rgba(0,0,0,0.1);
            border-color: #667eea;
        }
        .aluno-card h3 {
            color: #667eea;
            margin-bottom: 20px;
            font-size: 1.8em;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        .code-block {
            background: #2d2d2d;
            color: #f8f8f2;
            padding: 15px;
            border-radius: 5px;
            font-family: 'Courier New', monospace;
            margin: 10px 0;
            overflow-x: auto;
            font-size: 0.9em;
        }
        .badge {
            display: inline-block;
            padding: 5px 12px;
            background: #667eea;
            color: white;
            border-radius: 20px;
            font-size: 0.9em;
            margin-right: 10px;
            font-weight: bold;
        }
        .badge-warning {
            background: #ffc107;
            color: #333;
        }
        .footer {
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #666;
            border-top: 1px solid #e0e0e0;
        }
        @media print {
            body { background: white; padding: 0; }
            .container { box-shadow: none; }
            .aluno-card { page-break-inside: avoid; }
        }
        @media (max-width: 768px) {
            .grid { grid-template-columns: 1fr; }
            .info-item strong { display: block; margin-bottom: 5px; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎓 Curso DocumentDB</h1>
            <p>Informações de Acesso ao Ambiente AWS</p>
HTML_HEADER
            
            echo "            <p>Gerado em: $(date '+%d/%m/%Y às %H:%M:%S')</p>"
            echo "        </div>"
            echo "        <div class=\"content\">"
            
            # Aviso sobre senha
            echo "            <div class=\"warning-box\">"
            echo "                <h3>🔐 Informação Importante sobre Senhas</h3>"
            echo "                <p>A senha do console AWS está armazenada no <strong>AWS Secrets Manager</strong> e será fornecida pelo instrutor.</p>"
            echo "                <p>Por questões de segurança, a senha <strong>NÃO</strong> está incluída neste documento.</p>"
            echo "            </div>"
            
            # Informações gerais
            echo "            <div class=\"info-section\">"
            echo "                <h2>📋 Informações Gerais</h2>"
            echo "                <div class=\"info-item\"><strong>Stack Name:</strong> $STACK_NAME</div>"
            echo "                <div class=\"info-item\"><strong>Região AWS:</strong> $REGION</div>"
            echo "                <div class=\"info-item\"><strong>Account ID:</strong> $ACCOUNT_ID</div>"
            echo "                <div class=\"info-item\"><strong>Número de Alunos:</strong> $NUM_ALUNOS</div>"
            echo "            </div>"
            
            # Console AWS
            echo "            <div class=\"info-section\">"
            echo "                <h2>🌐 Acesso ao Console AWS</h2>"
            echo "                <div class=\"info-item\">"
            echo "                    <strong>URL de Login:</strong> "
            echo "                    <a href=\"https://${ACCOUNT_ID}.signin.aws.amazon.com/console\" target=\"_blank\">"
            echo "                        https://${ACCOUNT_ID}.signin.aws.amazon.com/console"
            echo "                    </a>"
            echo "                </div>"
            echo "                <div class=\"info-item\">"
            echo "                    <strong>Padrão de Usuário:</strong> ${STACK_NAME}-${PREFIXO_ALUNO}XX (onde XX = 01, 02, 03...)"
            echo "                </div>"
            echo "                <div class=\"info-item\">"
            echo "                    <strong>Senha:</strong> <span class=\"badge badge-warning\">Será fornecida pelo instrutor</span>"
            echo "                </div>"
            echo "            </div>"
            
            # Chave SSH
            if [ -f ".ssh-key-info" ]; then
                source .ssh-key-info
                echo "            <div class=\"info-section\">"
                echo "                <h2>🔑 Chave SSH</h2>"
                echo "                <div class=\"info-item\">"
                echo "                    <strong>Nome do Arquivo:</strong> $KEY_FILE"
                echo "                </div>"
                echo "                <div class=\"info-item\">"
                echo "                    <strong>Download via Console S3:</strong><br>"
                echo "                    <a href=\"https://s3.console.aws.amazon.com/s3/object/${S3_BUCKET}?region=${REGION}&prefix=${S3_KEY_PATH}\" target=\"_blank\">"
                echo "                        Clique aqui para baixar no Console AWS"
                echo "                    </a>"
                echo "                </div>"
                echo "                <div class=\"info-item\">"
                echo "                    <strong>Download via AWS CLI:</strong>"
                echo "                    <div class=\"code-block\">aws s3 cp s3://${S3_BUCKET}/${S3_KEY_PATH} ${KEY_FILE}<br>chmod 400 ${KEY_FILE}</div>"
                echo "                </div>"
                echo "            </div>"
            else
                echo "            <div class=\"info-section\">"
                echo "                <h2>🔑 Chave SSH</h2>"
                echo "                <div class=\"info-item\">"
                echo "                    <strong>Nome do Arquivo:</strong> $KEY_FILE"
                echo "                </div>"
                echo "                <div class=\"info-item\">"
                echo "                    <strong>Localização:</strong> Arquivo local - será distribuído pelo instrutor"
                echo "                </div>"
                echo "            </div>"
            fi
            
            # Alunos em grid
            echo "            <h2 style=\"color: #667eea; margin: 30px 0 20px 0; font-size: 2em;\">👨‍🎓 Informações dos Alunos</h2>"
            echo "            <div class=\"grid\">"
            
            # Gerar cards dos alunos
            for i in $(seq 1 $NUM_ALUNOS); do
                ALUNO_NUM=$(printf "%02d" $i)
                
                # Obter IP da instância
                INSTANCE_IP=$(aws cloudformation describe-stacks \
                    --stack-name $STACK_NAME \
                    --query "Stacks[0].Outputs[?OutputKey=='Aluno${ALUNO_NUM}IP'].OutputValue" \
                    --output text 2>/dev/null)
                
                if [ "$INSTANCE_IP" != "None" ] && [ ! -z "$INSTANCE_IP" ]; then
                    USUARIO_IAM="${STACK_NAME}-${PREFIXO_ALUNO}${ALUNO_NUM}"
                    USUARIO_LINUX="${PREFIXO_ALUNO}${ALUNO_NUM}"
                    
                    echo "                <div class=\"aluno-card\">"
                    echo "                    <h3>👤 Aluno ${i} - ${USUARIO_LINUX}</h3>"
                    echo "                    <div class=\"info-item\">"
                    echo "                        <span class=\"badge\">Console AWS</span><br>"
                    echo "                        <strong>Usuário IAM:</strong> $USUARIO_IAM"
                    echo "                    </div>"
                    echo "                    <div class=\"info-item\">"
                    echo "                        <span class=\"badge\">Instância EC2</span><br>"
                    echo "                        <strong>IP Público:</strong> <code>$INSTANCE_IP</code>"
                    echo "                    </div>"
                    echo "                    <div class=\"info-item\">"
                    echo "                        <span class=\"badge\">Usuário Linux:</span><br>"
                    echo "                        <strong>Username:</strong> $USUARIO_LINUX"
                    echo "                    </div>"
                    echo "                    <div class=\"info-item\">"
                    echo "                        <strong>Comando SSH:</strong>"
                    echo "                        <div class=\"code-block\">ssh -i $KEY_FILE ${USUARIO_LINUX}@${INSTANCE_IP}</div>"
                    echo "                    </div>"
                    echo "                    <div class=\"info-item\">"
                    echo "                        <strong>SSH Alternativo (via ec2-user):</strong>"
                    echo "                        <div class=\"code-block\">ssh -i $KEY_FILE ec2-user@${INSTANCE_IP}<br>sudo su - ${USUARIO_LINUX}</div>"
                    echo "                    </div>"
                    echo "                </div>"
                fi
            done
            
            echo "            </div>"
            
            # Instruções adicionais
            echo "            <div class=\"info-section\" style=\"margin-top: 30px;\">"
            echo "                <h2>📚 Instruções Importantes</h2>"
            echo "                <div class=\"info-item\">"
            echo "                    <strong>1. Primeiro Acesso:</strong> Faça login no console AWS com seu usuário e a senha fornecida pelo instrutor."
            echo "                </div>"
            echo "                <div class=\"info-item\">"
            echo "                    <strong>2. Chave SSH:</strong> Baixe a chave SSH e configure as permissões corretas (chmod 400)."
            echo "                </div>"
            echo "                <div class=\"info-item\">"
            echo "                    <strong>3. Conexão EC2:</strong> Use o comando SSH fornecido para conectar à sua instância."
            echo "                </div>"
            echo "                <div class=\"info-item\">"
            echo "                    <strong>4. Ambiente Configurado:</strong> Todas as ferramentas (AWS CLI, MongoDB Shell, Node.js, etc.) já estão instaladas."
            echo "                </div>"
            echo "            </div>"
            
            # Footer
            echo "        </div>"
            echo "        <div class=\"footer\">"
            echo "            <p><strong>📚 Curso DocumentDB - Extractta</strong></p>"
            echo "            <p>Para dúvidas ou problemas, entre em contato com o instrutor</p>"
            echo "            <p style=\"margin-top: 10px; font-size: 0.9em; color: #999;\">Documento gerado automaticamente - Não compartilhe com terceiros</p>"
            echo "        </div>"
            echo "    </div>"
            echo "</body>"
            echo "</html>"
            
        } > "$HTML_FILE"
        
        success "Relatório HTML gerado: $HTML_FILE"
        
        # Upload do HTML para S3 e configurar como website
        log "Fazendo upload do relatório para S3..."
        
        # Criar bucket para o relatório (se não existir)
        REPORT_BUCKET="${STACK_NAME}-reports-${ACCOUNT_ID}"
        
        if ! aws s3 ls "s3://${REPORT_BUCKET}" 2>&1 | grep -q 'NoSuchBucket'; then
            log "Bucket já existe: ${REPORT_BUCKET}"
        else
            log "Criando bucket S3 para relatórios: ${REPORT_BUCKET}"
            aws s3 mb "s3://${REPORT_BUCKET}" --region $REGION
        fi
        
        # Configurar bucket como website estático
        aws s3 website "s3://${REPORT_BUCKET}" \
            --index-document index.html \
            --error-document error.html
        
        # Configurar política de bucket para acesso público de leitura
        cat > /tmp/bucket-policy.json << POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${REPORT_BUCKET}/*"
        }
    ]
}
POLICY
        
        # Desbloquear acesso público
        aws s3api put-public-access-block \
            --bucket ${REPORT_BUCKET} \
            --public-access-block-configuration \
            "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"
        
        # Aplicar política de bucket
        aws s3api put-bucket-policy \
            --bucket ${REPORT_BUCKET} \
            --policy file:///tmp/bucket-policy.json
        
        rm -f /tmp/bucket-policy.json
        
        # Upload do arquivo HTML
        REPORT_KEY="relatorio-$(date +%Y%m%d-%H%M%S).html"
        aws s3 cp $HTML_FILE "s3://${REPORT_BUCKET}/${REPORT_KEY}" \
            --content-type "text/html; charset=utf-8" \
            --metadata "stack-name=${STACK_NAME},created-date=$(date -Iseconds)"
        
        # Também fazer upload como index.html (sempre a versão mais recente)
        aws s3 cp $HTML_FILE "s3://${REPORT_BUCKET}/index.html" \
            --content-type "text/html; charset=utf-8" \
            --metadata "stack-name=${STACK_NAME},created-date=$(date -Iseconds)"
        
        if [ $? -eq 0 ]; then
            # Gerar URL do website
            WEBSITE_URL="https://${REPORT_BUCKET}.s3-${REGION}.amazonaws.com"
            REPORT_URL="${WEBSITE_URL}/${REPORT_KEY}"
            
            success "Relatório publicado no S3!"
            
            echo ""
            echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
            echo -e "${GREEN}           ✅ DEPLOY CONCLUÍDO COM SUCESSO!                    ${NC}"
            echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
            echo ""
            echo -e "${BLUE}🌐 RELATÓRIO WEB (Sempre atualizado):${NC}"
            echo -e "${YELLOW}   $WEBSITE_URL${NC}"
            echo ""
            echo -e "${BLUE}📄 RELATÓRIO ESPECÍFICO (Esta execução):${NC}"
            echo -e "${YELLOW}   $REPORT_URL${NC}"
            echo ""
            echo -e "${BLUE}🔐 SENHA DO CONSOLE (Secrets Manager):${NC}"
            echo -e "${YELLOW}   https://console.aws.amazon.com/secretsmanager/home?region=${REGION}#!/secret?name=${SECRET_NAME}${NC}"
            echo ""
            if [ -f ".ssh-key-info" ]; then
                source .ssh-key-info
                echo -e "${BLUE}🔑 CHAVE SSH (S3):${NC}"
                echo -e "${YELLOW}   https://s3.console.aws.amazon.com/s3/object/${S3_BUCKET}?region=${REGION}&prefix=${S3_KEY_PATH}${NC}"
                echo ""
            fi
            echo -e "${BLUE}📁 ARQUIVO LOCAL:${NC}"
            echo "   $(pwd)/$HTML_FILE"
            echo ""
            echo -e "${GREEN}💡 Compartilhe o link do relatório com os alunos!${NC}"
            echo ""
            
            # Abrir o URL no navegador
            if command -v open &> /dev/null; then
                open $WEBSITE_URL
            elif command -v xdg-open &> /dev/null; then
                xdg-open $WEBSITE_URL
            fi
        else
            warning "Falha ao fazer upload para S3 (não crítico)"
            echo ""
            echo -e "${BLUE}📄 Arquivo local: $(pwd)/$HTML_FILE${NC}"
            
            # Abrir o arquivo local
            if command -v open &> /dev/null; then
                open $HTML_FILE
            elif command -v xdg-open &> /dev/null; then
                xdg-open $HTML_FILE
            fi
        fi
    else
        error "Falha no deployment da stack"
        exit 1
    fi
else
    error "Falha ao iniciar deployment da stack"
    exit 1
fi