#!/bin/bash

# Script de Validação - Exercício 1: Provisionamento
# Valida se todos os itens do checklist foram concluídos

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir cabeçalho
print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  VALIDAÇÃO - EXERCÍCIO 1: PROVISIONAMENTO     ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo
}

# Função para imprimir resultado
print_result() {
    local status=$1
    local message=$2
    
    if [ "$status" = "PASS" ]; then
        echo -e "✅ ${GREEN}PASS${NC} - $message"
    elif [ "$status" = "FAIL" ]; then
        echo -e "❌ ${RED}FAIL${NC} - $message"
    elif [ "$status" = "WARN" ]; then
        echo -e "⚠️  ${YELLOW}WARN${NC} - $message"
    else
        echo -e "ℹ️  ${BLUE}INFO${NC} - $message"
    fi
}

# Função para verificar se AWS CLI está configurado
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_result "FAIL" "AWS CLI não está instalado"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_result "FAIL" "AWS CLI não está configurado ou sem permissões"
        exit 1
    fi
    
    print_result "PASS" "AWS CLI configurado e funcionando"
}

# Função para obter o ID do aluno
get_student_id() {
    # Usar variável de ambiente $ID se estiver definida
    if [ -n "$ID" ]; then
        STUDENT_ID="$ID"
        echo -e "${BLUE}Usando ID do ambiente: ${STUDENT_ID}${NC}"
    elif [ -n "$1" ]; then
        STUDENT_ID="$1"
    else
        echo -e "${YELLOW}Por favor, informe seu ID de aluno:${NC}"
        read -p "ID do aluno: " STUDENT_ID
    fi
    
    if [ -z "$STUDENT_ID" ]; then
        print_result "FAIL" "ID do aluno é obrigatório"
        exit 1
    fi
    
    echo -e "${BLUE}Validando recursos para o aluno: ${STUDENT_ID}${NC}"
    echo
}

# Função para verificar recursos do Console
check_console_resources() {
    echo -e "${BLUE}1. Verificando recursos criados via Console...${NC}"
    
    local console_cluster="${STUDENT_ID}-lab-cluster-console"
    local security_group="${STUDENT_ID}-docdb-lab-sg"
    local subnet_group="${STUDENT_ID}-docdb-lab-subnet-group"
    
    # Verificar cluster do console
    if aws docdb describe-db-clusters --db-cluster-identifier "$console_cluster" &> /dev/null; then
        local cluster_status
        cluster_status=$(aws docdb describe-db-clusters \
            --db-cluster-identifier "$console_cluster" \
            --query 'DBClusters[0].Status' \
            --output text 2>/dev/null) || cluster_status="unknown"
        
        case "$cluster_status" in
            "available")
                print_result "PASS" "Cluster Console disponível: $console_cluster"
                ;;
            "creating"|"backing-up"|"modifying")
                print_result "WARN" "Cluster Console em processo: $cluster_status"
                ;;
            *)
                print_result "WARN" "Cluster Console em status: $cluster_status"
                ;;
        esac
    else
        print_result "FAIL" "Cluster Console não encontrado: $console_cluster"
    fi
    
    # Verificar Security Group
    if aws ec2 describe-security-groups --group-names "$security_group" &> /dev/null; then
        print_result "PASS" "Security Group encontrado: $security_group"
    else
        print_result "FAIL" "Security Group não encontrado: $security_group"
    fi
    
    # Verificar Subnet Group
    if aws docdb describe-db-subnet-groups --db-subnet-group-name "$subnet_group" &> /dev/null; then
        print_result "PASS" "Subnet Group encontrado: $subnet_group"
    else
        print_result "FAIL" "Subnet Group não encontrado: $subnet_group"
    fi
    
    echo
}

# Função para verificar recursos do Terraform
check_terraform_resources() {
    echo -e "${BLUE}2. Verificando recursos criados via Terraform...${NC}"
    
    local terraform_cluster="${STUDENT_ID}-lab-cluster-terraform"
    
    # Verificar cluster do Terraform
    if aws docdb describe-db-clusters --db-cluster-identifier "$terraform_cluster" &> /dev/null; then
        local cluster_status
        cluster_status=$(aws docdb describe-db-clusters \
            --db-cluster-identifier "$terraform_cluster" \
            --query 'DBClusters[0].Status' \
            --output text 2>/dev/null) || cluster_status="unknown"
        
        case "$cluster_status" in
            "available")
                print_result "PASS" "Cluster Terraform disponível: $terraform_cluster"
                ;;
            "creating"|"backing-up"|"modifying")
                print_result "WARN" "Cluster Terraform em processo: $cluster_status"
                ;;
            *)
                print_result "WARN" "Cluster Terraform em status: $cluster_status"
                ;;
        esac
    else
        print_result "FAIL" "Cluster Terraform não encontrado: $terraform_cluster"
    fi
    
    # Verificar arquivo de estado do Terraform
    local tfstate_paths=(
        "./terraform/terraform.tfstate"
        "$HOME/terraform/terraform.tfstate" 
        "../terraform/terraform.tfstate"
        "terraform/terraform.tfstate"
    )
    
    local tfstate_found=false
    for path in "${tfstate_paths[@]}"; do
        if [ -f "$path" ]; then
            print_result "PASS" "Arquivo de estado Terraform encontrado: $path"
            tfstate_found=true
            break
        fi
    done
    
    if [ "$tfstate_found" = false ]; then
        print_result "FAIL" "Arquivo terraform.tfstate não encontrado"
        print_result "INFO" "Locais verificados:"
        for path in "${tfstate_paths[@]}"; do
            print_result "INFO" "  - $path"
        done
        print_result "WARN" "Execute 'terraform apply' no diretório correto"
    fi
    
    echo
}


# Função para testar conectividade
check_connectivity() {
    echo -e "${BLUE}3. Verificando conectividade...${NC}"
    
    # Verificar se mongosh está instalado
    if ! command -v mongosh &> /dev/null; then
        print_result "WARN" "mongosh não está instalado"
        print_result "INFO" "Instale com: npm install -g mongosh"
        echo
        return
    fi
    
    # Baixar certificado se necessário
    if [ ! -f "global-bundle.pem" ]; then
        print_result "INFO" "Baixando certificado SSL..."
        if wget -q https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem; then
            print_result "PASS" "Certificado SSL baixado"
        else
            print_result "WARN" "Falha ao baixar certificado SSL"
        fi
    else
        print_result "PASS" "Certificado SSL encontrado"
    fi
    
    # Obter endpoints dos clusters
    local console_endpoint
    local terraform_endpoint
    
    console_endpoint=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "${STUDENT_ID}-lab-cluster-console" \
        --query 'DBClusters[0].Endpoint' \
        --output text 2>/dev/null) || console_endpoint=""
    
    terraform_endpoint=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "${STUDENT_ID}-lab-cluster-terraform" \
        --query 'DBClusters[0].Endpoint' \
        --output text 2>/dev/null) || terraform_endpoint=""
    
    # Testar conectividade se clusters existirem
    if [ -n "$console_endpoint" ] && [ "$console_endpoint" != "None" ] || \
       [ -n "$terraform_endpoint" ] && [ "$terraform_endpoint" != "None" ]; then
        
        # Usar senha padrão ou solicitar
        local db_password="Lab12345!"
        
        echo -e "${YELLOW}Testando conectividade com senha padrão (Lab12345!)${NC}"
        echo -e "${YELLOW}Se a senha for diferente, pressione Enter e digite a senha correta:${NC}"
        read -s -p "Senha (Enter para usar padrão): " custom_password
        echo
        
        if [ -n "$custom_password" ]; then
            db_password="$custom_password"
            echo -e "${BLUE}Usando senha customizada${NC}"
        else
            echo -e "${BLUE}Usando senha padrão${NC}"
        fi
        
        if [ -n "$db_password" ]; then
            # Testar cluster Console
            if [ -n "$console_endpoint" ] && [ "$console_endpoint" != "None" ]; then
                if timeout 10 mongosh --host "${console_endpoint}:27017" \
                    --username docdbadmin --password "$db_password" \
                    --tls --tlsCAFile global-bundle.pem \
                    --eval "db.runCommand({ping: 1})" &> /dev/null; then
                    print_result "PASS" "Conectividade Console OK: $console_endpoint"
                else
                    print_result "FAIL" "Falha na conectividade Console: $console_endpoint"
                fi
            fi
            
            # Testar cluster Terraform
            if [ -n "$terraform_endpoint" ] && [ "$terraform_endpoint" != "None" ]; then
                if timeout 10 mongosh --host "${terraform_endpoint}:27017" \
                    --username docdbadmin --password "$db_password" \
                    --tls --tlsCAFile global-bundle.pem \
                    --eval "db.runCommand({ping: 1})" &> /dev/null; then
                    print_result "PASS" "Conectividade Terraform OK: $terraform_endpoint"
                else
                    print_result "FAIL" "Falha na conectividade Terraform: $terraform_endpoint"
                fi
            fi
        fi
    else
        print_result "WARN" "Nenhum cluster disponível para testar conectividade"
    fi
    
    echo
}

# Função para gerar relatório final
generate_report() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}                RELATÓRIO FINAL                ${NC}"
    echo -e "${BLUE}================================================${NC}"
    
    local total_checks=4
    local passed_checks=0
    
    # Revalidar itens principais
    if aws docdb describe-db-clusters --db-cluster-identifier "${STUDENT_ID}-lab-cluster-console" &> /dev/null; then
        ((passed_checks++))
    fi
    
    if aws ec2 describe-security-groups --group-names "${STUDENT_ID}-docdb-lab-sg" &> /dev/null; then
        ((passed_checks++))
    fi
    
    if aws docdb describe-db-subnet-groups --db-subnet-group-name "${STUDENT_ID}-docdb-lab-subnet-group" &> /dev/null; then
        ((passed_checks++))
    fi
    
    if aws docdb describe-db-clusters --db-cluster-identifier "${STUDENT_ID}-lab-cluster-terraform" &> /dev/null; then
        ((passed_checks++))
    fi
    
    echo "Checklist do Exercício 1:"
    echo "✅ Cluster Console criado: $([ $passed_checks -ge 1 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Security Group criado: $([ $passed_checks -ge 2 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Subnet Group criado: $([ $passed_checks -ge 3 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Cluster Terraform criado: $([ $passed_checks -ge 4 ] && echo "SIM" || echo "NÃO")"
    echo
    
    local percentage=$((passed_checks * 100 / total_checks))
    
    if [ $percentage -eq 100 ]; then
        print_result "PASS" "Exercício 1 CONCLUÍDO com sucesso! ($passed_checks/$total_checks)"
    elif [ $percentage -ge 75 ]; then
        print_result "WARN" "Exercício 1 PARCIALMENTE concluído ($passed_checks/$total_checks)"
    else
        print_result "FAIL" "Exercício 1 INCOMPLETO ($passed_checks/$total_checks)"
    fi
    
    echo
    echo -e "${BLUE}Próximo passo: ${NC}Exercício 2 - Backup e Snapshots"
}

# Função principal
main() {
    print_header
    
    # Verificar pré-requisitos
    check_aws_cli
    
    # Obter ID do aluno
    get_student_id "$1"
    
    # Executar validações
    check_console_resources
    check_terraform_resources
    check_connectivity
    
    # Gerar relatório final
    generate_report
}

# Executar script
main "$@"
