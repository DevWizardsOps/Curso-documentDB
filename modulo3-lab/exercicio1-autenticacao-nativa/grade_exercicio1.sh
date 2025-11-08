#!/bin/bash

# Script de Validação - Exercício 1: Autenticação Nativa
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
    echo -e "${BLUE}  VALIDAÇÃO - EXERCÍCIO 1: AUTENTICAÇÃO NATIVA ${NC}"
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

# Função para verificar se mongosh está instalado
check_mongosh() {
    if ! command -v mongosh &> /dev/null; then
        print_result "FAIL" "mongosh não está instalado"
        print_result "INFO" "Instale com: npm install -g mongosh"
        exit 1
    fi
    
    print_result "PASS" "mongosh instalado e disponível"
}

# Função para obter o ID do aluno
get_student_id() {
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Por favor, informe seu ID de aluno (mesmo usado no Módulo 2):${NC}"
        read -p "ID do aluno: " STUDENT_ID
    else
        STUDENT_ID=$1
    fi
    
    if [ -z "$STUDENT_ID" ]; then
        print_result "FAIL" "ID do aluno é obrigatório"
        exit 1
    fi
    
    echo -e "${BLUE}Validando recursos para o aluno: ${STUDENT_ID}${NC}"
    echo
}

# Função para verificar cluster do Módulo 2
check_cluster_exists() {
    echo -e "${BLUE}1. Verificando cluster do Módulo 2...${NC}"
    
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    
    if aws docdb describe-db-clusters --db-cluster-identifier "$cluster_id" &> /dev/null; then
        local cluster_status
        cluster_status=$(aws docdb describe-db-clusters \
            --db-cluster-identifier "$cluster_id" \
            --query 'DBClusters[0].Status' \
            --output text 2>/dev/null) || cluster_status="unknown"
        
        case "$cluster_status" in
            "available")
                print_result "PASS" "Cluster disponível: $cluster_id"
                CLUSTER_ENDPOINT=$(aws docdb describe-db-clusters \
                    --db-cluster-identifier "$cluster_id" \
                    --query 'DBClusters[0].Endpoint' \
                    --output text 2>/dev/null)
                print_result "INFO" "Endpoint: $CLUSTER_ENDPOINT"
                ;;
            "creating"|"backing-up"|"modifying")
                print_result "WARN" "Cluster em processo: $cluster_status"
                ;;
            *)
                print_result "FAIL" "Cluster em status inválido: $cluster_status"
                exit 1
                ;;
        esac
    else
        print_result "FAIL" "Cluster não encontrado: $cluster_id"
        print_result "INFO" "Execute primeiro o Módulo 2 - Exercício 1"
        exit 1
    fi
    
    echo
}

# Função para verificar certificado SSL
check_ssl_certificate() {
    echo -e "${BLUE}2. Verificando certificado SSL...${NC}"
    
    if [ -f "global-bundle.pem" ]; then
        print_result "PASS" "Certificado SSL encontrado"
        
        # Verificar se o certificado é válido
        if openssl x509 -in global-bundle.pem -text -noout &> /dev/null; then
            print_result "PASS" "Certificado SSL válido"
        else
            print_result "WARN" "Certificado SSL pode estar corrompido - fazendo novo download"
            rm -f global-bundle.pem
            download_certificate
        fi
    else
        print_result "INFO" "Certificado SSL não encontrado - fazendo download..."
        download_certificate
    fi
    
    echo
}

# Função auxiliar para fazer download do certificado
download_certificate() {
    local cert_url="https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem"
    
    # Tentar com wget primeiro
    if command -v wget &> /dev/null; then
        print_result "INFO" "Baixando certificado com wget..."
        if wget -q "$cert_url" -O global-bundle.pem; then
            print_result "PASS" "Certificado SSL baixado com sucesso (wget)"
            return 0
        else
            print_result "WARN" "Falha no download com wget, tentando curl..."
        fi
    fi
    
    # Tentar com curl se wget falhou ou não está disponível
    if command -v curl &> /dev/null; then
        print_result "INFO" "Baixando certificado com curl..."
        if curl -s "$cert_url" -o global-bundle.pem; then
            print_result "PASS" "Certificado SSL baixado com sucesso (curl)"
            return 0
        else
            print_result "WARN" "Falha no download com curl"
        fi
    fi
    
    # Se ambos falharam
    print_result "FAIL" "Falha ao baixar certificado SSL"
    print_result "INFO" "Baixe manualmente de: $cert_url"
    exit 1
}

# Função para testar conexão com usuário mestre
test_master_connection() {
    echo -e "${BLUE}3. Testando conexão com usuário mestre...${NC}"
    
    echo -e "${YELLOW}Digite a senha do usuário mestre (docdbadmin):${NC}"
    read -s -p "Senha: " master_password
    echo
    
    if [ -z "$master_password" ]; then
        print_result "WARN" "Senha não fornecida - pulando teste de conexão"
        return
    fi
    
    # Testar conexão básica
    if timeout 15 mongosh --tls --host "${CLUSTER_ENDPOINT}:27017" \
        --tlsCAFile global-bundle.pem \
        --username docdbadmin \
        --password "$master_password" \
        --retryWrites=false \
        --eval "db.runCommand({ping: 1})" &> /dev/null; then
        print_result "PASS" "Conexão com usuário mestre estabelecida"
        MASTER_PASSWORD="$master_password"
    else
        print_result "FAIL" "Falha na conexão com usuário mestre"
        print_result "INFO" "Verifique: 1) Senha correta 2) Security Groups 3) VPC/Subnets"
        return
    fi
    
    echo
}

# Função para verificar base de dados e usuários criados
check_database_and_users() {
    echo -e "${BLUE}4. Verificando base de dados e usuários...${NC}"
    
    if [ -z "$MASTER_PASSWORD" ]; then
        print_result "WARN" "Senha do mestre não disponível - pulando verificação de usuários"
        return
    fi
    
    # Verificar se a base labdb existe e tem dados
    local db_check
    db_check=$(timeout 15 mongosh --tls --host "${CLUSTER_ENDPOINT}:27017" \
        --tlsCAFile global-bundle.pem \
        --username docdbadmin \
        --password "$MASTER_PASSWORD" \
        --retryWrites=false \
        --quiet \
        --eval "use labdb; db.produtos.countDocuments()" 2>/dev/null)
    
    if [[ "$db_check" =~ ^[0-9]+$ ]] && [ "$db_check" -gt 0 ]; then
        print_result "PASS" "Base de dados 'labdb' criada com $db_check produtos"
    else
        print_result "FAIL" "Base de dados 'labdb' não encontrada ou sem dados"
    fi
    
    # Verificar usuários criados
    local users_check
    users_check=$(timeout 15 mongosh --tls --host "${CLUSTER_ENDPOINT}:27017" \
        --tlsCAFile global-bundle.pem \
        --username docdbadmin \
        --password "$MASTER_PASSWORD" \
        --retryWrites=false \
        --quiet \
        --eval "use labdb; db.getUsers().length" 2>/dev/null)
    
    if [[ "$users_check" =~ ^[0-9]+$ ]] && [ "$users_check" -gt 0 ]; then
        print_result "PASS" "$users_check usuários nativos criados"
        
        # Verificar usuários específicos
        local expected_users=("leitor" "editor" "admin_app")
        for user in "${expected_users[@]}"; do
            local user_exists
            user_exists=$(timeout 10 mongosh --tls --host "${CLUSTER_ENDPOINT}:27017" \
                --tlsCAFile global-bundle.pem \
                --username docdbadmin \
                --password "$MASTER_PASSWORD" \
                --retryWrites=false \
                --quiet \
                --eval "use labdb; try { db.getUser('$user'); print('exists'); } catch(e) { print('not_found'); }" 2>/dev/null)
            
            if [[ "$user_exists" == *"exists"* ]]; then
                print_result "PASS" "Usuário '$user' encontrado"
            else
                print_result "FAIL" "Usuário '$user' não encontrado"
            fi
        done
    else
        print_result "FAIL" "Nenhum usuário nativo encontrado"
    fi
    
    echo
}

# Função para testar permissões dos usuários
test_user_permissions() {
    echo -e "${BLUE}5. Testando permissões dos usuários...${NC}"
    
    if [ -z "$MASTER_PASSWORD" ]; then
        print_result "WARN" "Senha do mestre não disponível - pulando testes de permissão"
        return
    fi
    
    # Testar usuário 'leitor' (apenas leitura)
    local read_test
    read_test=$(timeout 10 mongosh --tls --host "${CLUSTER_ENDPOINT}:27017" \
        --tlsCAFile global-bundle.pem \
        --username leitor \
        --password senha123 \
        --authenticationDatabase labdb \
        --retryWrites=false \
        --quiet \
        --eval "use labdb; db.produtos.countDocuments()" 2>/dev/null)
    
    if [[ "$read_test" =~ ^[0-9]+$ ]]; then
        print_result "PASS" "Usuário 'leitor' consegue ler dados"
        
        # Testar se não consegue escrever
        local write_test
        write_test=$(timeout 10 mongosh --tls --host "${CLUSTER_ENDPOINT}:27017" \
            --tlsCAFile global-bundle.pem \
            --username leitor \
            --password senha123 \
            --authenticationDatabase labdb \
            --retryWrites=false \
            --quiet \
            --eval "use labdb; try { db.produtos.insertOne({nome: 'teste', preco: 1}); print('write_ok'); } catch(e) { print('write_denied'); }" 2>/dev/null)
        
        if [[ "$write_test" == *"write_denied"* ]]; then
            print_result "PASS" "Usuário 'leitor' corretamente impedido de escrever"
        else
            print_result "FAIL" "Usuário 'leitor' conseguiu escrever (permissão incorreta)"
        fi
    else
        print_result "FAIL" "Usuário 'leitor' não consegue ler dados"
    fi
    
    # Testar usuário 'editor' (leitura e escrita)
    local editor_write_test
    editor_write_test=$(timeout 10 mongosh --tls --host "${CLUSTER_ENDPOINT}:27017" \
        --tlsCAFile global-bundle.pem \
        --username editor \
        --password senha456 \
        --authenticationDatabase labdb \
        --retryWrites=false \
        --quiet \
        --eval "use labdb; try { db.produtos.insertOne({nome: 'teste_editor', preco: 1}); db.produtos.deleteOne({nome: 'teste_editor'}); print('write_ok'); } catch(e) { print('write_denied'); }" 2>/dev/null)
    
    if [[ "$editor_write_test" == *"write_ok"* ]]; then
        print_result "PASS" "Usuário 'editor' consegue ler e escrever"
    else
        print_result "FAIL" "Usuário 'editor' não consegue escrever"
    fi
    
    echo
}

# Função para verificar scripts automatizados
check_scripts() {
    echo -e "${BLUE}6. Verificando scripts automatizados...${NC}"
    
    # Verificar se os scripts existem
    if [ -f "scripts/create_user.sh" ]; then
        print_result "PASS" "Script create_user.sh encontrado"
        
        # Verificar se é executável
        if [ -x "scripts/create_user.sh" ]; then
            print_result "PASS" "Script create_user.sh é executável"
        else
            print_result "WARN" "Script create_user.sh não é executável (chmod +x necessário)"
        fi
    else
        print_result "FAIL" "Script create_user.sh não encontrado"
    fi
    
    if [ -f "scripts/test_connection.sh" ]; then
        print_result "PASS" "Script test_connection.sh encontrado"
        
        # Verificar se é executável
        if [ -x "scripts/test_connection.sh" ]; then
            print_result "PASS" "Script test_connection.sh é executável"
        else
            print_result "WARN" "Script test_connection.sh não é executável (chmod +x necessário)"
        fi
    else
        print_result "FAIL" "Script test_connection.sh não encontrado"
    fi
    
    echo
}

# Função para gerar relatório final
generate_report() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}                RELATÓRIO FINAL                ${NC}"
    echo -e "${BLUE}================================================${NC}"
    
    local total_checks=7
    local passed_checks=0
    
    # Revalidar itens principais
    if aws docdb describe-db-clusters --db-cluster-identifier "${STUDENT_ID}-lab-cluster-console" &> /dev/null; then
        ((passed_checks++))
    fi
    
    if [ -f "global-bundle.pem" ]; then
        ((passed_checks++))
    fi
    
    if [ -n "$MASTER_PASSWORD" ]; then
        ((passed_checks++))
        
        # Verificar base de dados
        local db_check
        db_check=$(timeout 10 mongosh --tls --host "${CLUSTER_ENDPOINT}:27017" \
            --tlsCAFile global-bundle.pem \
            --username docdbadmin \
            --password "$MASTER_PASSWORD" \
            --retryWrites=false \
            --quiet \
            --eval "use labdb; db.produtos.countDocuments()" 2>/dev/null)
        
        if [[ "$db_check" =~ ^[0-9]+$ ]] && [ "$db_check" -gt 0 ]; then
            ((passed_checks++))
        fi
        
        # Verificar usuários
        local users=("leitor" "editor" "admin_app")
        for user in "${users[@]}"; do
            local user_exists
            user_exists=$(timeout 10 mongosh --tls --host "${CLUSTER_ENDPOINT}:27017" \
                --tlsCAFile global-bundle.pem \
                --username docdbadmin \
                --password "$MASTER_PASSWORD" \
                --retryWrites=false \
                --quiet \
                --eval "use labdb; try { db.getUser('$user'); print('exists'); } catch(e) { print('not_found'); }" 2>/dev/null)
            
            if [[ "$user_exists" == *"exists"* ]]; then
                ((passed_checks++))
            fi
        done
    fi
    
    echo "Checklist do Exercício 1:"
    echo "✅ Cluster do Módulo 2 disponível: $([ $passed_checks -ge 1 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Certificado SSL configurado: $([ $passed_checks -ge 2 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Conexão com usuário mestre: $([ $passed_checks -ge 3 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Base de dados 'labdb' criada: $([ $passed_checks -ge 4 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Usuário 'leitor' criado: $([ $passed_checks -ge 5 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Usuário 'editor' criado: $([ $passed_checks -ge 6 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Usuário 'admin_app' criado: $([ $passed_checks -ge 7 ] && echo "SIM" || echo "NÃO")"
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
    echo -e "${BLUE}Próximo passo: ${NC}Exercício 2 - Integração com VPC e Security Groups"
    echo -e "${BLUE}Comandos úteis:${NC}"
    echo "  export ID=\"$STUDENT_ID\""
    echo "  ./scripts/create_user.sh"
    echo "  ./scripts/test_connection.sh"
}

# Função principal
main() {
    print_header
    
    # Verificar pré-requisitos
    check_aws_cli
    check_mongosh
    
    # Obter ID do aluno
    get_student_id "$1"
    
    # Executar validações
    check_cluster_exists
    check_ssl_certificate
    test_master_connection
    check_database_and_users
    test_user_permissions
    check_scripts
    
    # Gerar relatório final
    generate_report
}

# Executar script
main "$@"