# Exercício 2: Integração com VPC, Subnets e Security Groups

Neste exercício, vamos configurar e otimizar as camadas de rede para proteger o acesso ao cluster DocumentDB, implementando controles de segurança que garantem que apenas fontes autorizadas possam se conectar.

## 📋 Objetivos

- Analisar a configuração atual de rede do cluster DocumentDB
- Entender e configurar Security Groups para controle de acesso
- Implementar regras de firewall restritivas
- Criar Security Groups para aplicações cliente
- Testar conectividade e isolamento de rede

## 🚀 Pré-requisitos

- Cluster DocumentDB `<seu-id>-lab-cluster-console` ativo (do Módulo 2)
- AWS CLI configurado
- Acesso ao console AWS
- Conhecimento básico de VPC e Security Groups

## 🏗️ Fundamentos: Redes Privadas vs Públicas na AWS

### Conceitos Essenciais

**Por que o DocumentDB não tem IP público?**

O Amazon DocumentDB foi projetado para ser um serviço **exclusivamente privado** por questões de segurança. Isso significa:

#### 🔒 **Subnets Privadas (DocumentDB)**
- **Sem acesso direto à Internet**
- **Sem IP público** atribuído
- **Comunicação apenas dentro da VPC**
- **Maior segurança** - não exposto publicamente
- **Acesso via**: Bastion Host, VPN, Direct Connect, ou recursos na mesma VPC

#### 🌐 **Subnets Públicas (Aplicações Web)**
- **Acesso direto à Internet** via Internet Gateway
- **IP público** pode ser atribuído
- **Ideal para**: Web servers, Load Balancers, Bastion Hosts
- **Maior exposição** - requer cuidados extras de segurança

### Arquitetura Típica de Segurança

```
                           INTERNET
                              ↓
                     [Internet Gateway]
                              ↓
    ┌──────────────────────────────────────────────────────────────┐
    │                    PUBLIC SUBNETS                            │
    │  AZ-1a              AZ-1b              AZ-1c                 │
    │ ┌─────────┐       ┌─────────┐       ┌─────────┐             │
    │ │Web Srv  │       │Bastion  │       │.        │             │
    │ │(HTTP)   │       │(SSH)    │       │         │             │
    │ └─────────┘       └─────────┘       └─────────┘             │
    └──────┬─────────────────┬─────────────────┬───────────────────┘
           │                 │                 │
     [Load Balancer]   [Security Groups]       |
           │                 │                 │
    ┌──────┴─────────────────┴─────────────────┴───────────────────┐
    │                  PRIVATE SUBNETS (APP)                      │
    │  AZ-1a              AZ-1b              AZ-1c                 │
    │ ┌─────────┐       ┌─────────┐       ┌─────────┐             │
    │ │App Srv  │       │App Srv  │       │Admin    │             │
    │ │Node.js  │       │Node.js  │       │Tools    │             │
    │ └─────────┘       └─────────┘       └─────────┘             │
    └──────┬─────────────────┬─────────────────┬───────────────────┘
           │                 │                 │
    [Restrictive Security Groups - Port 27017 Only]
           │                 │                 │
    ┌──────┴─────────────────┴─────────────────┴───────────────────┐
    │              PRIVATE SUBNETS (DATABASE)                     │
    │  AZ-1a              AZ-1b              AZ-1c                 │
    │ ┌─────────┐       ┌─────────┐       ┌─────────┐             │
    │ │DocumentDB│      │DocumentDB│      │DocumentDB│            │
    │ │ Primary │       │Replica 1│       │Replica 2│             │
    │ │ Writer  │◄──────┤ Reader  │◄──────┤ Reader  │             │
    │ └─────────┘       └─────────┘       └─────────┘             │
    │     (NO PUBLIC IP IN ANY AZ)                                │
    └─────────────────────────────────────────────────────────────┘

```
🔒 Princípios de Segurança e Alta Disponibilidade:
- DocumentDB NUNCA tem IP público
- Acesso apenas via Security Groups específicos  
- Múltiplas camadas de isolamento
- Bastion Host para acesso administrativo seguro
- **Multi-AZ**: Cada nó DocumentDB em AZ diferente
- **Failover automático**: Se AZ-1a falhar, AZ-1b assume
- **Redundância geográfica**: Proteção contra falhas de datacenter

⚠️ **IMPORTANTE - Multi-AZ DocumentDB:**
- **Cada nó** deve estar em **Availability Zone diferente**
- **Primary Writer**: AZ-1a (recebe todas as escritas)
- **Read Replicas**: AZ-1b e AZ-1c (distribuem leituras)
- **Failover**: Automático em caso de falha de AZ
- **Latência**: Mínima entre AZs na mesma região

⚠️ **IMPORTANTE - NAT Gateway:**
- NAT Gateway é **OPCIONAL** para App Servers
- Necessário apenas se App Server precisar acessar Internet
- App Server pode funcionar **100% isolado** (só DocumentDB)
- Para máxima segurança: remova rota para NAT Gateway

📋 Explicação das Camadas:

**Web Server (Camada de Apresentação):**
- Serve páginas HTML, CSS, JavaScript
- Interface que o usuário vê e interage
- Exemplos: Nginx, Apache, CloudFront
- Localização: Subnet Pública (precisa receber tráfego da Internet)

**App Server (Camada de Lógica de Negócio):**
- Processa requisições do frontend
- Executa validações e cálculos
- Conecta com o banco de dados
- Exemplos: Node.js, Java Spring, Python Django
- Localização: Subnet Privada (não precisa de acesso direto da Internet)

**DocumentDB (Camada de Dados):**
- Armazena e recupera dados
- Gerencia transações e consistência
- Backup e recuperação
- Localização: Subnet Privada (máxima segurança)

## 📝 Passos do Exercício

### 0. Configurar Identificador e Obter Informações do Cluster

```bash
# Obter informações do cluster
aws docdb describe-db-clusters \
  --db-cluster-identifier "$ID-lab-cluster-console" \
  --query 'DBClusters[].{
    Cluster: DBClusterIdentifier,
    SubnetGroup: DBSubnetGroup,
    SGs: join(`,`, VpcSecurityGroups[].VpcSecurityGroupId)
  }' \
  --output table

```

### 1. Identificar Tipos de Subnets na VPC

#### Entendendo a Topologia de Rede:

```bash
# Obter SubnetGroup do DocumentDB
SUBNET_GRP=$(aws docdb describe-db-clusters \
--db-cluster-identifier "$ID-lab-cluster-console" \
--query 'DBClusters[0].DBSubnetGroup' \
--output text)
echo "Subnet group: $SUBNET_GRP"

# Obter VPC do cluster DocumentDB
VPC_ID=$(aws docdb describe-db-subnet-groups \
--db-subnet-group-name "$SUBNET_GRP" \
--query 'DBSubnetGroups[0].VpcId' \
--output text)
echo "VPC do DocumentDB: $VPC_ID"

# Listar todas as subnets da VPC
echo "=== ANÁLISE DE SUBNETS ==="
aws ec2 describe-subnets \
--filters "Name=vpc-id,Values=$VPC_ID" \
--query 'Subnets[*].{SubnetId:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock,Public:MapPublicIpOnLaunch,RouteTable:Tags[?Key==`Name`].Value|[0]}' \
--output table

# Identificar subnets públicas vs privadas
echo "=== CLASSIFICAÇÃO DE SUBNETS ==="
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --output json \
| jq -r '["SubnetId","Classe","CIDR","AZ"],
         (.Subnets[] |
           [ .SubnetId,
             (if .MapPublicIpOnLaunch then "PÚBLICA" else "PRIVADA" end),
             .CidrBlock,
             .AvailabilityZone ]) | @tsv' \
| column -t

# Verificar distribuição Multi-AZ do DocumentDB
echo "=== DISTRIBUIÇÃO MULTI-AZ DO DOCUMENTDB ==="
aws docdb describe-db-clusters \
--db-cluster-identifier $ID-lab-cluster-console \
--query 'DBClusters[0].{ClusterIdentifier:DBClusterIdentifier,MultiAZ:MultiAZ,AvailabilityZones:AvailabilityZones}' \
--output table
```

#### Via AWS Console:

1. **Acessar VPC Dashboard:**
   - Navegue até **VPC** > **Subnets**
   - Filtre pela VPC do DocumentDB

2. **Identificar Tipos de Subnet:**
   - **Coluna "Auto-assign public IPv4"**: 
     - `Yes` = Subnet Pública
     - `No` = Subnet Privada
   - **Route Tables**: Verifique se há rota para Internet Gateway (0.0.0.0/0)

3. **Verificar Route Tables:**
   - Clique em cada subnet
   - Na aba **Route table**, observe:
     - **Subnet Pública**: Rota 0.0.0.0/0 → Internet Gateway (igw-xxx)
     - **Subnet Privada**: Rota 0.0.0.0/0 → NAT Gateway (nat-xxx) ou sem rota externa

### 2. Analisar Configuração Atual de Rede

#### Via AWS Console:

1. **Acessar DocumentDB:**
   - Navegue até **Amazon DocumentDB** no console AWS
   - Clique em **Clusters** no painel lateral
   - Selecione seu cluster `<seu-id>-lab-cluster-console`

2. **Verificar Configuração de Rede:**
   - Na aba **Connectivity & security**, observe:
     - **VPC**: VPC onde o cluster está localizado
     - **Subnet group**: Grupo de subnets utilizado
     - **VPC security groups**: Security groups associados
     - **Availability Zone**: Zonas de disponibilidade


### 3. Analisar Security Groups Atuais

#### Via AWS Console:

1. **Acessar EC2 Security Groups:**
   - Navegue até **EC2** > **Security Groups**
   - Localize o security group do DocumentDB (geralmente `<seu-id>-docdb-lab-sg`)

2. **Analisar Regras Atuais:**
   - Clique no security group
   - Examine as abas **Inbound rules** e **Outbound rules**
   - Identifique possíveis vulnerabilidades de segurança

#### Via AWS CLI:

```bash
# Obter security groups do cluster
DOCDB_SG=$(aws docdb describe-db-clusters \
  --db-cluster-identifier $ID-lab-cluster-console \
  --query 'DBClusters[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
  --output text)

echo "Security Group do DocumentDB: $DOCDB_SG"

# Analisar regras do security group
aws ec2 describe-security-groups \
  --group-ids $DOCDB_SG \
  --query 'SecurityGroups[0].{GroupId:GroupId,GroupName:GroupName,InboundRules:IpPermissions[*],OutboundRules:IpPermissionsEgress[*]}' \
  --output json
```

### 4. Criar Security Group para Aplicação Cliente

#### Via AWS Console:

1. **Criar Novo Security Group:**
   - Em **EC2** > **Security Groups**, clique **Create security group**
   - Configure:
     - **Security group name**: `<seu-id>-app-client-sg`
     - **Description**: `Security group para aplicações cliente DocumentDB`
     - **VPC**: Mesma VPC do cluster DocumentDB

2. **Configurar Regras de Saída:**
   - Na aba **Outbound rules**, adicione:
     - **Type**: Custom TCP
     - **Port range**: 27017
     - **Destination**: Security group do DocumentDB
     - **Description**: `Acesso ao DocumentDB`

#### Via AWS CLI:

```bash
# Obter SubnetGroup do DocumentDB Para obter o VPC_ID
SUBNET_GRP=$(aws docdb describe-db-clusters \
--db-cluster-identifier "$ID-lab-cluster-console" \
--query 'DBClusters[0].DBSubnetGroup' \
--output text)
echo "Subnet group: $SUBNET_GRP"

# Obter VPC do cluster DocumentDB
VPC_ID=$(aws docdb describe-db-subnet-groups \
--db-subnet-group-name "$SUBNET_GRP" \
--query 'DBSubnetGroups[0].VpcId' \
--output text)
echo "VPC do DocumentDB: $VPC_ID"

# Criar security group para aplicação cliente
APP_SG_ID=$(aws ec2 create-security-group \
--group-name "$ID-app-client-sg" \
--description "Security group para aplicacoes cliente DocumentDB" \
--vpc-id $VPC_ID \
--query 'GroupId' \
--output text)

# Removendo liberação padrão
aws ec2 revoke-security-group-egress \
  --group-id "$APP_SG_ID" \
  --protocol all \
  --port all \
  --cidr 0.0.0.0/0 || echo "Nenhuma regra padrão encontrada (já limpo)."

# Obter security groups do cluster
DOCDB_SG=$(aws docdb describe-db-clusters \
--db-cluster-identifier $ID-lab-cluster-console \
--query 'DBClusters[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
--output text)

# Adicionar regra de saída para DocumentDB
aws ec2 authorize-security-group-egress \
--group-id $APP_SG_ID \
--protocol tcp \
--port 27017 \
--source-group $DOCDB_SG

echo "Regra de saída adicionada: $APP_SG_ID -> $DOCDB_SG:27017"
```

### 5. Configurar Regras Restritivas no Security Group do DocumentDB

#### Via AWS Console:

1. **Modificar Security Group do DocumentDB:**
   - Selecione o security group `<seu-id>-docdb-lab-sg`
   - Na aba **Inbound rules**, clique **Edit inbound rules**

2. **Remover Regras Permissivas:**
   - Delete regras que permitem acesso de `0.0.0.0/0` (qualquer IP)
   - Delete regras muito amplas

3. **Adicionar Regra Restritiva:**
   - Clique **Add rule**
   - Configure:
     - **Type**: Custom TCP
     - **Port range**: 27017
     - **Source**: Security group da aplicação (`<seu-id>-app-client-sg`)
     - **Description**: `Acesso apenas de aplicações autorizadas`

#### Via AWS CLI:

```bash
# Listar regras atuais do DocumentDB
echo "Regras atuais do DocumentDB Security Group:"
aws ec2 describe-security-groups \
--group-ids $DOCDB_SG \
--query 'SecurityGroups[0].IpPermissions[*]' \
--output table

# Remover regras permissivas (se existirem)
# CUIDADO: Isso pode quebrar conexões existentes
echo "Removendo regras permissivas..."

# Verificar se existe regra 0.0.0.0/0
OPEN_RULE=$(aws ec2 describe-security-groups \
--group-ids $DOCDB_SG \
--query 'SecurityGroups[0].IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]' \
--output text)

if [ -n "$OPEN_RULE" ]; then
    echo "⚠️  ATENÇÃO: Regra permissiva encontrada (0.0.0.0/0)"
    echo "Removendo regra insegura..."
    
    aws ec2 revoke-security-group-ingress \
      --group-id $DOCDB_SG \
      --protocol tcp \
      --port 27017 \
      --cidr 0.0.0.0/0 2>/dev/null || echo "Regra não encontrada ou já removida"
fi

# Adicionar regra restritiva
aws ec2 authorize-security-group-ingress \
--group-id $DOCDB_SG \
--protocol tcp \
--port 27017 \
--source-group $APP_SG_ID

echo "✅ Regra restritiva adicionada: $APP_SG_ID -> $DOCDB_SG:27017"
```

#### Soluções para Acesso Externo:

**Opção 1: Bastion Host (Recomendado para testes)**
```bash
# Criar instância pública que pode acessar DocumentDB
echo "Criando Bastion Host para acesso ao DocumentDB..."
```

**Opção 2: VPN ou Direct Connect (Produção)**
- AWS Site-to-Site VPN
- AWS Client VPN  
- AWS Direct Connect

**Opção 3: AWS Cloud9 (Desenvolvimento)**
- IDE baseado na nuvem
- Automaticamente na mesma VPC
- Ideal para desenvolvimento e testes

### 6. Testar Conectividade e Isolamento

```bash
# Testar conectividade de rede
echo "Testando conectividade de rede..."

# Obter o Instance ID da sua instância EC2 automaticamente
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
echo "Instance ID detectado: $INSTANCE_ID"

# Obter endpoint do cluster
CLUSTER_ENDPOINT=$(aws docdb describe-db-clusters \
  --db-cluster-identifier $ID-lab-cluster-console \
  --query 'DBClusters[0].Endpoint' \
  --output text)

# Obter SG da instancia
DOCDB_SG=$(aws docdb describe-db-clusters \
--db-cluster-identifier "$ID-lab-cluster-console" \
--query 'DBClusters[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
--output text)

# Testar conectividade TCP (deve funcionar se estiver na mesma VPC)
timeout 5 bash -c "</dev/tcp/$CLUSTER_ENDPOINT/27017" && echo "✅ Conectividade TCP OK" || echo "❌ Conectividade TCP falhou"

# Após a remoção das liberações 0.0.0.0 é necessário liberar o acesso com menor privilégio

# Obter Security group criado para o APP
APP_SG_ID=$(aws ec2 describe-security-groups \
--filters "Name=group-name,Values=$ID-app-client-sg" "Name=vpc-id,Values=$VPC_ID" \
--query "SecurityGroups[0].GroupId" \
--output text)

# Adiciona o SG a instancia sem perder os SGs atuais já associados
aws ec2 modify-instance-attribute \
  --instance-id "$INSTANCE_ID" \
  --groups $(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[0].Instances[0].SecurityGroups[].GroupId" \
    --output text) $APP_SG_ID

# Verificar regras finais do DocumentDB
echo "Configuração final dos Security Groups:"
echo "DocumentDB SG ($DOCDB_SG):"
aws ec2 describe-security-groups \
  --group-ids $DOCDB_SG \
  --query 'SecurityGroups[0].IpPermissions[*].{Port:FromPort,Protocol:IpProtocol,Source:UserIdGroupPairs[0].GroupId}' \
  --output table

# Verificar regras finais do App
echo "Aplicação SG ($APP_SG_ID):"
aws ec2 describe-security-groups \
  --group-ids $APP_SG_ID \
  --query 'SecurityGroups[0].IpPermissionsEgress[*].{Port:FromPort,Protocol:IpProtocol,Destination:UserIdGroupPairs[0].GroupId}' \
  --output table

# Testar conectividade TCP (deve funcionar se estiver na mesma VPC)
timeout 5 bash -c "</dev/tcp/$CLUSTER_ENDPOINT/27017" && echo "✅ Conectividade TCP OK" || echo "❌ Conectividade TCP falhou"
```

## ✅ Validação do Exercício

### Validação Automatizada

Execute o script de validação para verificar automaticamente se o exercício foi concluído:

```bash
# A variável $ID já está configurada automaticamente
# Verifique com: echo $ID

# Executar validação
chmod +x /home/$ID/Curso-documentDB/modulo3-lab/exercicio2-integracao-rede/grade_exercicio2.sh

/home/$ID/Curso-documentDB/modulo3-lab/exercicio2-integracao-rede/grade_exercicio2.sh

# Ou passar o ID diretamente
/home/$ID/Curso-documentDB/modulo3-lab/exercicio2-integracao-rede/grade_exercicio2.sh $ID
```

O script irá verificar:
- ✅ Cluster DocumentDB disponível e configuração de rede
- ✅ Distribuição Multi-AZ adequada
- ✅ Subnets privadas configuradas corretamente
- ✅ Security Groups sem regras permissivas
- ✅ Security Group da aplicação criado
- ✅ Conectividade de rede funcionando
- ✅ Regras específicas para DocumentDB (porta 27017)

### Verificação via CLI

```bash
# Script de verificação rápida
echo "=== VERIFICAÇÃO DE SEGURANÇA DE REDE ==="

# 1. Verificar se cluster existe
aws docdb describe-db-clusters --db-cluster-identifier $ID-lab-cluster-console --query 'DBClusters[0].Status' --output text

# 2. Verificar Security Groups
DOCDB_SG=$(aws docdb describe-db-clusters --db-cluster-identifier $ID-lab-cluster-console --query 'DBClusters[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)
echo "DocumentDB Security Group: $DOCDB_SG"

# 3. Verificar regras restritivas
OPEN_RULES=$(aws ec2 describe-security-groups --group-ids $DOCDB_SG --query 'SecurityGroups[0].IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]' --output text)
if [ -z "$OPEN_RULES" ]; then
    echo "✅ Nenhuma regra permissiva encontrada"
else
    echo "⚠️  Regras permissivas ainda existem"
fi

# 4. Verificar Security Group da aplicação
if aws ec2 describe-security-groups --group-names "$ID-app-client-sg" &>/dev/null; then
    echo "✅ Security Group da aplicação criado"
else
    echo "❌ Security Group da aplicação não encontrado"
fi
```

## 🚨 Troubleshooting

**Erro: Não consigo conectar ao DocumentDB**
```bash
# Verificar se está na mesma VPC
aws docdb describe-db-clusters --db-cluster-identifier $ID-lab-cluster-console --query 'DBClusters[0].VpcId'

# Verificar regras do security group
aws ec2 describe-security-groups --group-ids $DOCDB_SG --query 'SecurityGroups[0].IpPermissions'
```

**Erro: Security Group não permite conexão**
```bash
# Adicionar regra temporária para seu IP
MY_IP=$(curl -s ifconfig.me)
aws ec2 authorize-security-group-ingress \
  --group-id $DOCDB_SG \
  --protocol tcp \
  --port 27017 \
  --cidr $MY_IP/32
```

## 📚 Conceitos Aprendidos

### Segurança de Rede
- **Defense in Depth**: Múltiplas camadas de segurança de rede
- **Principle of Least Privilege**: Acesso mínimo necessário
- **Security Groups**: Firewall virtual stateful
- **VPC Isolation**: Isolamento de rede na nuvem
- **Network Segmentation**: Segmentação por função

### Topologia de Rede AWS
- **Subnets Públicas vs Privadas**: Diferenças e casos de uso
- **Internet Gateway**: Acesso à Internet para subnets públicas
- **NAT Gateway**: Acesso de saída para subnets privadas
- **Route Tables**: Controle de roteamento de tráfego
- **DocumentDB Private-Only**: Por que não tem IP público

### Padrões de Acesso Seguro
- **Bastion Host**: Proxy seguro para acesso administrativo
- **VPN**: Conexão segura site-to-site ou client-to-site
- **Direct Connect**: Conexão dedicada para enterprise
- **Security Group Chaining**: Comunicação entre camadas

### Melhores Práticas
1. **Nunca exponha bancos de dados publicamente**
2. **Use subnets privadas para dados sensíveis**
3. **Implemente múltiplas camadas de segurança**
4. **Monitore e audite acessos de rede**
5. **Use VPN ou bastion hosts para acesso administrativo**

## 🔍 Comparação: Cenários de Acesso

| Componente | Subnet Type | Acesso Internet | Segurança | Exemplo Real |
|------------|-------------|-----------------|-----------|--------------|
| **Web Server** | Pública | Direto (IGW) | Média | Site da loja, páginas HTML |
| **App Server** | Privada | Opcional (NAT)* | Alta | APIs de pagamento, validações |
| **DocumentDB** | Privada | Nenhum | Muito Alta | Dados de clientes, produtos |
| **Bastion Host** | Pública | Direto (IGW) | Alta** | Acesso para DBAs e DevOps |

*App Server: NAT Gateway apenas se precisar de APIs externas
**Bastion Host: Requer configuração de segurança rigorosa

*Bastion Host requer configuração de segurança rigorosa

## 🧹 Limpeza (Opcional)

```bash
# Remover instância EC2 de teste (se criada)
if [ -n "$INSTANCE_ID" ]; then
    aws ec2 terminate-instances --instance-ids $INSTANCE_ID
fi

# Remover Security Group da aplicação (se não for mais necessário)
# aws ec2 delete-security-group --group-id $APP_SG_ID
```

## ➡️ Próximo Exercício

No [Exercício 3](../exercicio3-controle-acesso/README.md), você aprenderá a implementar controles de acesso avançados com TLS obrigatório e roles granulares.