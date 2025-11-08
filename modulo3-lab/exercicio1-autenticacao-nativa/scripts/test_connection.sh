#!/bin/bash

# Script para testar conexões com diferentes usuários do DocumentDB
# Este script valida que as permissões estão funcionando corretamente

set -e

# --- Configurações ---
ID="${ID:-seu-nome}"
CLUSTER_IDENTIFIER="$ID-lab-cluster-console"
DATABASE_NAME="labdb"
CERT_FILE="global-bundle.pem"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_failure() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Verificar pré-requisitos
if [[ "$ID" == "seu-nome" ]]; then
    echo -e "${RED}ERRO:${NC} Configure ID no script ou como variável de ambiente"
    echo -e "${YELLOW}Exemplo:${NC} export ID=\"joao\""
    exit 1
fi

# Obter endpoint do cluster
print_info "Obtendo endpoint do cluster $CLUSTER_IDENTIFIER..."
CLUSTER_ENDPOINT=$(aws docdb describe-db-clusters \
  --db-cluster-identifier $CLUSTER_IDENTIFIER \
  --query 'DBClusters[0].Endpoint' \
  --output text 2>/dev/null)

if [[ "$CLUSTER_ENDPOINT" == "None" ]] || [[ -z "$CLUSTER_ENDPOINT" ]]; then
    echo -e "${RED}ERRO:${NC} Cluster $CLUSTER_IDENTIFIER não encontrado"
    exit 1
fi

if [[ ! -f "$CERT_FILE" ]]; then
    echo -e "${RED}ERRO:${NC} Certificado $CERT_FILE não encontrado"
    exit 1
fi

# Verificar mongosh
if command -v mongosh &> /dev/null; then
    MONGO_CMD="mongosh --quiet"
else
    echo -e "${RED}ERRO:${NC} mongosh não encontrado. Instale o MongoDB Shell"
    exit 1
fi

# Função para testar conexão e operações
test_user() {
    local username=$1
    local password=$2
    local expected_read=$3
    local expected_write=$4
    local description=$5
    
    print_header "Testando usuário: $username ($description)"
    
    # Testar conexão
    local connection_result
    connection_result=$($MONGO_CMD --tls --host $CLUSTER_ENDPOINT:27017 \
                       --tlsCAFile $CERT_FILE \
                       --username $username \
                       --password $password \
                       --authenticationDatabase $DATABASE_NAME \
                       --retryWrites=false \
                       --eval "db.runCommand({ping: 1})" 2>&1)
    
    if echo "$connection_result" | grep -q '"ok" : 1'; then
        print_success "Conexão estabelecida"
    else
        print_failure "Falha na conexão"
        echo "$connection_result"
        return 1
    fi
    
    # Testar leitura
    print_info "Testando operação de leitura..."
    local read_result
    read_result=$($MONGO_CMD --tls --host $CLUSTER_ENDPOINT:27017 \
                  --tlsCAFile $CERT_FILE \
                  --username $username \
                  --password $password \
                  --authenticationDatabase $DATABASE_NAME \
                  --retryWrites=false \
                  --eval "use $DATABASE_NAME; db.produtos.countDocuments()" 2>&1)
    
    if echo "$read_result" | grep -q -E '^[0-9]+$'; then
        if [[ "$expected_read" == "true" ]]; then
            print_success "Leitura permitida (encontrados $(echo "$read_result" | tail -1) documentos)"
        else
            print_failure "Leitura deveria ser negada mas foi permitida"
        fi
    else
        if [[ "$expected_read" == "false" ]]; then
            print_success "Leitura negada conforme esperado"
        else
            print_failure "Leitura deveria ser permitida mas foi negada"
            echo "$read_result"
        fi
    fi
    
    # Testar escrita
    print_info "Testando operação de escrita..."
    local write_result
    local test_doc="{nome: 'Teste_$username', preco: 1, categoria: 'teste', timestamp: new Date()}"
    write_result=$($MONGO_CMD --tls --host $CLUSTER_ENDPOINT:27017 \
                   --tlsCAFile $CERT_FILE \
                   --username $username \
                   --password $password \
                   --authenticationDatabase $DATABASE_NAME \
                   --retryWrites=false \
                   --eval "use $DATABASE_NAME; db.produtos.insertOne($test_doc)" 2>&1)
    
    if echo "$write_result" | grep -q '"acknowledged" : true'; then
        if [[ "$expected_write" == "true" ]]; then
            print_success "Escrita permitida"
            # Limpar documento de teste
            $MONGO_CMD --tls --host $CLUSTER_ENDPOINT:27017 \
                       --tlsCAFile $CERT_FILE \
                       --username $username \
                       --password $password \
                       --authenticationDatabase $DATABASE_NAME \
                       --retryWrites=false \
                       --eval "use $DATABASE_NAME; db.produtos.deleteOne({nome: 'Teste_$username'})" &>/dev/null
        else
            print_failure "Escrita deveria ser negada mas foi permitida"
        fi
    else
        if [[ "$expected_write" == "false" ]]; then
            print_success "Escrita negada conforme esperado"
        else
            print_failure "Escrita deveria ser permitida mas foi negada"
            echo "$write_result"
        fi
    fi
    
    echo ""
}

# Executar testes
print_header "Iniciando testes de autenticação e autorização"
print_info "Cluster ID: $CLUSTER_IDENTIFIER"
print_info "Endpoint: $CLUSTER_ENDPOINT"
print_info "Database: $DATABASE_NAME"

# Testar cada usuário
test_user "leitor" "senha123" "true" "false" "Usuário apenas leitura"
test_user "editor" "senha456" "true" "true" "Usuário leitura e escrita"
test_user "admin_app" "senha789" "true" "true" "Usuário administrador"
test_user "relatorios" "senha101" "true" "false" "Usuário para relatórios"

print_header "Teste adicional: Acesso a base não autorizada"

# Testar acesso a base não autorizada
print_info "Testando acesso do usuário 'leitor' à base 'testdb'..."
unauthorized_result=$($MONGO_CMD --tls --host $CLUSTER_ENDPOINT:27017 \
                      --tlsCAFile $CERT_FILE \
                      --username leitor \
                      --password senha123 \
                      --authenticationDatabase $DATABASE_NAME \
                      --retryWrites=false \
                      --eval "use testdb; db.logs.countDocuments()" 2>&1)

if echo "$unauthorized_result" | grep -q "not authorized"; then
    print_success "Acesso negado à base não autorizada (comportamento correto)"
else
    print_failure "Usuário conseguiu acessar base não autorizada"
    echo "$unauthorized_result"
fi

print_header "Resumo dos testes"
print_info "Todos os testes de autenticação e autorização foram executados"
print_info "Verifique os resultados acima para confirmar que as permissões estão corretas"

echo -e "\n${GREEN}Testes concluídos!${NC}"