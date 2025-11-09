# 🚀 Ambiente AWS para Curso DocumentDB

Este repositório contém scripts para provisionar automaticamente um ambiente AWS completo para o curso de DocumentDB, incluindo instâncias EC2 e usuários IAM para cada aluno.

## 📋 Visão Geral

O ambiente criado inclui:
- **Instâncias EC2** (t3.micro - Free Tier) para cada aluno
- **Usuários IAM** com permissões específicas para o curso
- **Chaves SSH** geradas automaticamente
- **Security Groups** configurados para DocumentDB
- **AWS CLI** pré-configurado em cada instância
- **Ferramentas** necessárias: MongoDB Shell, Node.js, Python, Terraform

## 🛠️ Pré-requisitos

### 1. AWS CLI Instalado e Configurado
```bash
# Instalar AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configurar credenciais
aws configure
```

### 2. Permissões IAM Necessárias
O usuário que executar o script precisa das seguintes permissões:
- `CloudFormationFullAccess`
- `EC2FullAccess`
- `IAMFullAccess`
- `S3FullAccess`
- `LambdaFullAccess`

### 3. VPC com Subnet Pública
- VPC padrão (recomendado) ou VPC customizada
- Subnet pública com auto-assign de IP público

## 🚀 Deploy Rápido

### 1. Clone o Repositório
```bash
git clone <repository-url>
cd Curso-documentDB
```

### 2. Execute o Script de Deploy
```bash
./deploy-curso.sh
```

O script irá perguntar:
- Número de alunos (1-20)
- Prefixo para nomes dos alunos
- Nome da stack CloudFormation
- Configurações de rede e segurança

### 3. Aguarde a Criação
O processo leva aproximadamente 10-15 minutos para:
- Criar instâncias EC2
- Configurar usuários IAM
- Instalar ferramentas
- Configurar AWS CLI

## 📊 Gerenciamento do Ambiente

### Script de Gerenciamento
```bash
./manage-curso.sh
```

Funcionalidades disponíveis:
1. **Listar stacks** do curso
2. **Mostrar informações** detalhadas
3. **Conectar** a instâncias dos alunos
4. **Parar/Iniciar** instâncias (economia de custos)
5. **Relatório de custos**
6. **Deletar** ambiente completo

### Comandos Úteis

#### Listar Recursos Criados
```bash
# Listar instâncias
aws ec2 describe-instances --filters "Name=tag:Purpose,Values=Curso DocumentDB"

# Listar usuários IAM
aws iam list-users --query "Users[?contains(UserName, 'curso-documentdb')]"

# Listar chaves SSH
aws ec2 describe-key-pairs --query "KeyPairs[?contains(KeyName, 'curso-documentdb')]"
```

#### Conectar a uma Instância
```bash
# 1. Baixar chave SSH do console EC2
# 2. Configurar permissões
chmod 400 curso-documentdb-aluno01-key.pem

# 3. Conectar via SSH
ssh -i curso-documentdb-aluno01-key.pem ec2-user@IP-PUBLICO

# 4. Mudar para usuário do aluno
sudo su - aluno01
```

## 👥 Informações dos Alunos

### Estrutura de Usuários
Cada aluno recebe:
- **Instância EC2**: `t3.micro` com IP público
- **Usuário IAM**: `curso-documentdb-aluno01`
- **Usuário Linux**: `aluno01` (com sudo)
- **Chave SSH**: `curso-documentdb-aluno01-key`
- **AWS CLI**: Pré-configurado com credenciais

### Ferramentas Instaladas
- ✅ **AWS CLI** v2
- ✅ **MongoDB Shell** (mongosh)
- ✅ **Node.js** v18 + npm
- ✅ **Python** 3 + pip
- ✅ **Terraform**
- ✅ **Git**
- ✅ **Certificado SSL** do DocumentDB

### Permissões IAM
Os alunos têm acesso a:
- ✅ **DocumentDB**: Criação e gerenciamento completo
- ✅ **CloudWatch**: Métricas e logs
- ✅ **EC2**: Security groups e VPC (limitado)
- ✅ **S3**: Buckets do curso
- ✅ **Lambda**: Funções básicas
- ✅ **EventBridge**: Regras e targets
- ❌ **IAM**: Sem permissões (segurança)

## 💰 Gestão de Custos

### Custos Estimados (por aluno)
- **Instância t3.micro**: ~$8.50/mês (Free Tier: $0)
- **Volume EBS**: ~$1.00/mês (Free Tier: $0)
- **IP Público**: ~$3.65/mês
- **Total**: ~$13/mês por aluno (Free Tier: ~$4/mês)

### Otimização de Custos
```bash
# Parar instâncias quando não usar
aws ec2 stop-instances --instance-ids i-1234567890abcdef0

# Iniciar quando necessário
aws ec2 start-instances --instance-ids i-1234567890abcdef0

# Deletar ambiente ao final
aws cloudformation delete-stack --stack-name curso-documentdb
```

### Free Tier
- **750 horas/mês** de t3.micro (suficiente para 1 instância 24/7)
- **30 GB** de armazenamento EBS
- **15 GB** de transferência de dados

## 🔧 Configuração Manual (Alternativa)

Se preferir configurar manualmente:

### 1. Criar Usuário IAM
```bash
# Criar usuário
aws iam create-user --user-name aluno01

# Adicionar ao grupo
aws iam add-user-to-group --user-name aluno01 --group-name DocumentDBStudents

# Criar access key
aws iam create-access-key --user-name aluno01
```

### 2. Criar Instância EC2
```bash
# Criar key pair
aws ec2 create-key-pair --key-name aluno01-key --query 'KeyMaterial' --output text > aluno01-key.pem

# Lançar instância
aws ec2 run-instances \
    --image-id ami-0c02fb55956c7d316 \
    --count 1 \
    --instance-type t3.micro \
    --key-name aluno01-key \
    --security-group-ids sg-12345678 \
    --subnet-id subnet-12345678
```

## 🛡️ Segurança

### Boas Práticas Implementadas
- ✅ **Princípio do menor privilégio** para IAM
- ✅ **Security Groups** restritivos
- ✅ **Encryption at rest** habilitada
- ✅ **TLS obrigatório** para DocumentDB
- ✅ **Chaves SSH** únicas por aluno
- ✅ **IP restrito** para SSH (configurável)

### Recomendações Adicionais
- 🔒 Use **IP específico** para SSH (não 0.0.0.0/0)
- 🔒 **Rotacione** access keys regularmente
- 🔒 **Delete** o ambiente após o curso
- 🔒 **Monitore** custos no AWS Cost Explorer

## 📚 Estrutura dos Laboratórios

### Módulos do Curso
1. **Módulo 1**: Introdução e Conceitos (4h)
2. **Módulo 2**: Administração e Gerenciamento (6h)
3. **Módulo 3**: Segurança e Compliance (6h)
4. **Módulo 4**: Performance e Tuning (6h)
5. **Módulo 5**: Replicação e Alta Disponibilidade (6h)

### Diretórios Criados
```
/home/aluno01/
├── documentdb-labs/          # Laboratórios do curso
├── nodejs-project/           # Projeto Node.js com SDKs
├── global-bundle.pem         # Certificado SSL DocumentDB
└── setup-complete.txt        # Confirmação de setup
```

## 🆘 Troubleshooting

### Problemas Comuns

#### 1. Stack Creation Failed
```bash
# Verificar eventos da stack
aws cloudformation describe-stack-events --stack-name curso-documentdb

# Verificar recursos
aws cloudformation list-stack-resources --stack-name curso-documentdb
```

#### 2. Não Consegue Conectar via SSH
```bash
# Verificar security group
aws ec2 describe-security-groups --group-ids sg-12345678

# Verificar se instância está rodando
aws ec2 describe-instances --instance-ids i-1234567890abcdef0
```

#### 3. AWS CLI Não Configurado
```bash
# Conectar à instância e reconfigurar
ssh -i key.pem ec2-user@IP
sudo su - aluno01
aws configure list
aws configure  # Reconfigurar se necessário
```

#### 4. Permissões IAM Insuficientes
```bash
# Verificar permissões do usuário
aws iam list-attached-user-policies --user-name curso-documentdb-aluno01
aws iam list-user-policies --user-name curso-documentdb-aluno01
```

### Logs e Monitoramento
```bash
# CloudFormation logs
aws logs describe-log-groups --log-group-name-prefix /aws/cloudformation

# EC2 instance logs
aws ec2 get-console-output --instance-id i-1234567890abcdef0

# SSM command history
aws ssm list-commands --filter key=Status,value=Success
```

## 📞 Suporte

### Recursos Úteis
- 📖 [Documentação AWS DocumentDB](https://docs.aws.amazon.com/documentdb/)
- 📖 [AWS CLI Reference](https://docs.aws.amazon.com/cli/)
- 📖 [CloudFormation User Guide](https://docs.aws.amazon.com/cloudformation/)

### Comandos de Diagnóstico
```bash
# Verificar conectividade AWS
aws sts get-caller-identity

# Verificar região
aws configure get region

# Listar recursos do curso
aws resourcegroupstaggingapi get-resources --tag-filters Key=Purpose,Values="Curso DocumentDB"
```

---

## 🎯 Próximos Passos

1. **Execute** o deploy do ambiente
2. **Distribua** as informações de acesso para os alunos
3. **Inicie** o curso com o Módulo 1
4. **Monitore** custos durante o curso
5. **Delete** o ambiente ao final

**Bom curso! 🚀**