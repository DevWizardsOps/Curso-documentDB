#!/bin/bash

# Script para criar usuários nativos no Amazon DocumentDB
# Este script cria múltiplos usuários com diferentes níveis de permissão

set -e  # Parar execução em caso de erro

# --- Configurações (EDITE ESTAS VARIÁVEIS) ---
# Substitua ID pelo mesmo usado no Módulo 2
ID="${ID:-seu-nome}"
CLUSTER_IDENTIFIER="$ID-lab-cluster-console"
MASTER_USER="${MASTER_USER:-docdbadmin}"
MASTER_PASSWORD="${MASTER_PASSWORD:-Lab12345!}"
DATABASE_NAME="labdb"
CERT_FILE="global-bundle.pem"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para imprimir mensagens coloridas
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se as variáveis foram configuradas
if [[ "$ID" == "seu-nome" ]]; then
    print_error "Por favor, configure ID no script ou como variável de ambiente"
    print_error "Exemplo: export ID=\"joao\" (use o mesmo ID do Módulo 2)"
    exit 1
fi

# Obter endpoint do cluster automaticamente
print_status "Obtendo endpoint do cluster $CLUSTER_IDENTIFIER..."
CLUSTER_ENDPOINT=$(aws docdb describe-db-clusters \
  --db-cluster-identifier $CLUSTER_IDENTIFIER \
  --query 'DBClusters[0].Endpoint' \
  --output text 2>/dev/null)

if [[ "$CLUSTER_ENDPOINT" == "None" ]] || [[ -z "$CLUSTER_ENDPOINT" ]]; then
    print_error "Cluster $CLUSTER_IDENTIFIER não encontrado"
    print_error "Verifique se o cluster foi criado no Módulo 2 com o ID correto"
    exit 1
fi

print_status "Cluster encontrado: $CLUSTER_ENDPOINT"

# Verificar se o certificado existe
if [[ ! -f "$CERT_FILE" ]]; then
    print_warning "Certificado $CERT_FILE não encontrado. Baixando..."
    wget -q https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
    if [[ $? -eq 0 ]]; then
        print_status "Certificado baixado com sucesso"
    else
        print_error "Falha ao baixar certificado"
        exit 1
    fi
fi

# Verificar se mongosh está disponível
if command -v mongosh &> /dev/null; then
    MONGO_CMD="mongosh"
    print_status "Usando mongosh (recomendado)"
elif command -v mongo &> /dev/null; then
    MONGO_CMD="mongo"
    print_warning "Usando mongo shell legado. Considere atualizar para mongosh"
else
    print_error "MongoDB shell não encontrado. Instale mongosh ou mongo"
    exit 1
fi

print_status "Conectando ao cluster $CLUSTER_ENDPOINT..."

# Testar conectividade
if ! timeout 10 bash -c "</dev/tcp/${CLUSTER_ENDPOINT}/27017"; then
    print_error "Não foi possível conectar ao cluster na porta 27017"
    print_error "Verifique: 1) Security Groups 2) VPC/Subnets 3) Endpoint correto"
    exit 1
fi

print_status "Conectividade OK. Criando usuários..."

# Script MongoDB para criar usuários e dados de teste
$MONGO_CMD --tls --host $CLUSTER_ENDPOINT:27017 \
           --tlsCAFile $CERT_FILE \
           --username $MASTER_USER \
           --password $MASTER_PASSWORD \
           --retryWrites=false \
           --quiet <<EOF

// Criar base de dados e dados de exemplo
use $DATABASE_NAME

// Inserir dados de exemplo se não existirem
if (db.produtos.countDocuments() === 0) {
    // Usar insertOne para evitar erro de retryWrites
    db.produtos.insertOne({ nome: "Notebook", preco: 2500, categoria: "eletrônicos", estoque: 10 });
    db.produtos.insertOne({ nome: "Mouse", preco: 50, categoria: "eletrônicos", estoque: 50 });
    db.produtos.insertOne({ nome: "Livro MongoDB", preco: 80, categoria: "educação", estoque: 20 });
    db.produtos.insertOne({ nome: "Teclado", preco: 150, categoria: "eletrônicos", estoque: 30 });
    print("✓ Dados de exemplo inseridos (4 produtos)");
} else {
    print("✓ Dados de exemplo já existem (" + db.produtos.countDocuments() + " produtos)");
}

// Função para criar usuário se não existir
function createUserIfNotExists(username, password, roles) {
    try {
        var existingUser = db.getUser(username);
        if (existingUser) {
            print("⚠ Usuário '" + username + "' já existe");
            return false;
        }
    } catch (e) {
        // Usuário não existe, continuar com criação
    }
    
    db.createUser({
        user: username,
        pwd: password,
        roles: roles
    });
    print("✓ Usuário '" + username + "' criado com sucesso");
    return true;
}

// Criar usuários com diferentes permissões
print("\n=== Criando usuários ===");

// 1. Usuário apenas leitura
createUserIfNotExists("leitor", "senha123", [
    { role: "read", db: "$DATABASE_NAME" }
]);

// 2. Usuário leitura e escrita
createUserIfNotExists("editor", "senha456", [
    { role: "readWrite", db: "$DATABASE_NAME" }
]);

// 3. Usuário administrador da aplicação
createUserIfNotExists("admin_app", "senha789", [
    { role: "readWrite", db: "$DATABASE_NAME" },
    { role: "dbAdmin", db: "$DATABASE_NAME" }
]);



// Criar base de teste adicional
use testdb
if (db.logs.countDocuments() === 0) {
    db.logs.insertOne({ 
        evento: "sistema_iniciado", 
        timestamp: new Date(),
        nivel: "info"
    });
    print("✓ Base de dados 'testdb' criada");
}

// Listar usuários criados
use $DATABASE_NAME
print("\n=== Usuários criados ===");
var users = db.getUsers();
users.forEach(function(user) {
    print("• " + user.user + " - Roles: " + JSON.stringify(user.roles));
});

print("\n=== Resumo ===");
print("Base de dados: $DATABASE_NAME");
print("Produtos cadastrados: " + db.produtos.countDocuments());
print("Usuários criados: " + users.length);

EOF

if [[ $? -eq 0 ]]; then
    print_status "Script executado com sucesso!"
    echo ""
    print_status "Cluster: $CLUSTER_IDENTIFIER"
    print_status "Endpoint: $CLUSTER_ENDPOINT"
    print_status "Usuários criados:"
    echo "  • leitor (senha123) - Apenas leitura"
    echo "  • editor (senha456) - Leitura e escrita"
    echo "  • admin_app (senha789) - Admin da aplicação"
    echo ""
    print_status "Para testar, use:"
    echo "  mongosh --tls --host $CLUSTER_ENDPOINT:27017 --tlsCAFile $CERT_FILE --username leitor --password senha123 --authenticationDatabase $DATABASE_NAME --retryWrites=false"
    echo ""
    print_status "Ou execute o script de teste:"
    echo "  export ID=\"$ID\""
    echo "  ./test_connection.sh"
else
    print_error "Falha na execução do script"
    exit 1
fi
