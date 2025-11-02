#!/bin/bash

# Cores para o output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para checagem
check() {
    local message=$1
    local command=$2

    echo -n "- ${message}... "
    if eval $command > /dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
        return 0
    else
        echo -e "${RED}FALHOU${NC}"
        return 1
    fi
}

# --- Início do Script ---

echo -e "${YELLOW}Iniciando script de validação para o Exercício 1...${NC}"

read -p "Por favor, insira seu ID de aluno (o prefixo usado nos recursos): " STUDENT_ID

if [ -z "$STUDENT_ID" ]; then
    echo -e "${RED}ID do aluno não pode ser vazio. Saindo.${NC}"
    exit 1
fi

echo ""
echo "--- Checando Recursos do Console ---" 

check "Cluster via Console '${STUDENT_ID}-lab-cluster-console' existe" "aws docdb describe-db-clusters --db-cluster-identifier ${STUDENT_ID}-lab-cluster-console"
check "Security Group '${STUDENT_ID}-docdb-lab-sg' existe" "aws ec2 describe-security-groups --group-names ${STUDENT_ID}-docdb-lab-sg"
check "Subnet Group '${STUDENT_ID}-docdb-lab-subnet-group' existe" "aws docdb describe-db-subnet-groups --db-subnet-group-name ${STUDENT_ID}-docdb-lab-subnet-group"

echo ""
echo "--- Checando Recursos do Terraform ---" 

check "Cluster via Terraform '${STUDENT_ID}-lab-cluster-terraform' existe" "aws docdb describe-db-clusters --db-cluster-identifier ${STUDENT_ID}-lab-cluster-terraform"

# Verifica o arquivo terraform.tfstate em diferentes locais possíveis
TFSTATE_PATHS=(
    "./terraform/terraform.tfstate"
    "$HOME/terraform/terraform.tfstate" 
    "../terraform/terraform.tfstate"
    "terraform/terraform.tfstate"
)

TFSTATE_FOUND=false
for path in "${TFSTATE_PATHS[@]}"; do
    if [ -f "$path" ]; then
        echo -e "- Arquivo de estado do Terraform encontrado em '$path'... ${GREEN}OK${NC}"
        TFSTATE_FOUND=true
        break
    fi
done

if [ "$TFSTATE_FOUND" = false ]; then
    echo -e "- Arquivo de estado do Terraform (terraform.tfstate) não encontrado... ${RED}FALHOU${NC}"
    echo "  Locais verificados:"
    for path in "${TFSTATE_PATHS[@]}"; do
        echo "    - $path"
    done
    echo "  (Você executou 'terraform apply' no diretório correto?)"
fi


echo ""
echo "--- Checando Conectividade ---"

# Função para testar conexão com DocumentDB
test_docdb_connection() {
    local cluster_name=$1
    local endpoint=$2
    local password=$3
    
    echo -n "- Testando conexão com cluster '$cluster_name'... "
    
    # Verifica se mongosh está instalado
    if ! command -v mongosh &> /dev/null; then
        echo -e "${RED}FALHOU${NC}"
        echo "  mongosh não está instalado. Instale com: npm install -g mongosh"
        return 1
    fi
    
    # Baixa o certificado se não existir
    if [ ! -f "global-bundle.pem" ]; then
        wget -q https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
    fi
    
    # Testa a conexão
    if timeout 10 mongosh --host ${endpoint}:27017 --username docdbadmin --password "$password" --tls --tlsCAFile global-bundle.pem --eval "db.runCommand({ping: 1})" &> /dev/null; then
        echo -e "${GREEN}OK${NC}"
        return 0
    else
        echo -e "${RED}FALHOU${NC}"
        echo "  Verifique se a senha está correta e se o cluster está disponível"
        return 1
    fi
}

# Obtém os endpoints dos clusters
CONSOLE_ENDPOINT=$(aws docdb describe-db-clusters --db-cluster-identifier ${STUDENT_ID}-lab-cluster-console --query 'DBClusters[0].Endpoint' --output text 2>/dev/null)
TERRAFORM_ENDPOINT=$(aws docdb describe-db-clusters --db-cluster-identifier ${STUDENT_ID}-lab-cluster-terraform --query 'DBClusters[0].Endpoint' --output text 2>/dev/null)

# Solicita a senha se pelo menos um cluster existir
if [ -n "$CONSOLE_ENDPOINT" ] || [ -n "$TERRAFORM_ENDPOINT" ]; then
    echo ""
    read -s -p "Digite a senha do DocumentDB (docdbadmin): " DB_PASSWORD
    echo ""
    echo ""
    
    if [ -z "$DB_PASSWORD" ]; then
        echo -e "${YELLOW}Senha não fornecida. Pulando testes de conectividade.${NC}"
    else
        # Testa conexão com cluster do console se existir
        if [ -n "$CONSOLE_ENDPOINT" ] && [ "$CONSOLE_ENDPOINT" != "None" ]; then
            test_docdb_connection "${STUDENT_ID}-lab-cluster-console" "$CONSOLE_ENDPOINT" "$DB_PASSWORD"
        fi
        
        # Testa conexão com cluster do terraform se existir
        if [ -n "$TERRAFORM_ENDPOINT" ] && [ "$TERRAFORM_ENDPOINT" != "None" ]; then
            test_docdb_connection "${STUDENT_ID}-lab-cluster-terraform" "$TERRAFORM_ENDPOINT" "$DB_PASSWORD"
        fi
    fi
else
    echo -e "${YELLOW}Nenhum cluster encontrado para testar conectividade.${NC}"
fi

echo ""
echo -e "${GREEN}Validação concluída!${NC}"
