# 🔧 Preparação do Ambiente - APENAS INSTRUTORES

> ⚠️ **ATENÇÃO:** Este diretório contém scripts de preparação do ambiente AWS e deve ser usado APENAS por instrutores. Os alunos não precisam acessar estes arquivos.

## 📋 Arquivos Neste Diretório

### Scripts Principais
- **`deploy-curso.sh`** - Deploy automático do ambiente completo
- **`manage-curso.sh`** - Gerenciamento de recursos criados
- **`test-ambiente.sh`** - Validação do ambiente

### Templates CloudFormation
- **`setup-curso-documentdb-simple.yaml`** - Template principal otimizado

### Documentação
- **`README-AMBIENTE.md`** - Documentação completa do ambiente
- **`RESUMO-SCRIPTS.md`** - Guia rápido de uso

## 🚀 Quick Start para Instrutores

### 1. Pré-requisitos
```bash
# Verificar AWS CLI
aws --version
aws sts get-caller-identity

# Verificar permissões necessárias:
# - CloudFormationFullAccess
# - EC2FullAccess  
# - IAMFullAccess
# - S3FullAccess
```

### 2. Deploy do Ambiente
```bash
cd preparacao-curso/
./deploy-curso.sh
```

O script irá perguntar:
- Número de alunos (1-10)
- Prefixo para nomes (ex: "aluno")
- Configurações de rede
- Restrições de SSH

### 3. Validar Ambiente
```bash
./test-ambiente.sh
```

### 4. Gerenciar Durante o Curso
```bash
./manage-curso.sh
```

Opções disponíveis:
1. Listar stacks do curso
2. Mostrar informações detalhadas
3. Conectar a instâncias dos alunos
4. Parar/iniciar instâncias (economia)
5. Relatório de custos
6. Deletar ambiente completo

## 💰 Gestão de Custos

### Por Aluno (estimativa mensal)
- **t3.micro**: $8.50 (Free Tier: $0)
- **EBS 8GB**: $0.80 (Free Tier: $0)  
- **IP Público**: $3.65
- **Total**: ~$13/mês (Free Tier: ~$4/mês)

### Economia Durante o Curso
```bash
# Parar todas as instâncias (economia de ~70%)
./manage-curso.sh
# Escolher opção 4 (Parar instâncias)

# Iniciar quando necessário
./manage-curso.sh  
# Escolher opção 5 (Iniciar instâncias)
```

## 🎓 Informações para Distribuir aos Alunos

Após o deploy, forneça para cada aluno:

### Dados de Acesso
- **IP Público**: Obtido nos outputs da stack
- **Usuário SSH**: `ec2-user`
- **Usuário do Curso**: `alunoXX` (onde XX é o número)
- **Chave SSH**: Nome da chave para download no console EC2

### Instruções de Conexão
```bash
# 1. Baixar chave SSH do console EC2
# 2. Configurar permissões
chmod 400 nome-da-chave.pem

# 3. Conectar via SSH  
ssh -i nome-da-chave.pem ec2-user@IP-PUBLICO

# 4. Mudar para usuário do curso
sudo su - alunoXX
```

### Verificação do Ambiente
```bash
# AWS CLI deve estar configurado
aws sts get-caller-identity

# Ferramentas disponíveis
mongosh --version
node --version  
python3 --version
terraform --version

# Certificado DocumentDB
ls -la ~/global-bundle.pem
```

## 🛡️ Segurança Implementada

### Permissões IAM dos Alunos
✅ **Permitido:**
- DocumentDB: Acesso completo
- CloudWatch: Métricas e logs
- EC2: Consultas e Security Groups (limitado)
- S3: Buckets do curso apenas
- EventBridge: Regras básicas
- Lambda: Funções básicas

❌ **Negado:**
- CloudFormation (não precisam)
- IAM: Criação de usuários/roles
- EC2: Criação de instâncias
- Serviços não relacionados ao curso

### Isolamento de Rede
- Security Groups restritivos
- DocumentDB apenas em VPC privada
- SSH apenas de IPs permitidos
- Usuários separados por aluno

## 🔧 Personalização

### Modificar Número de Alunos
Editar `setup-curso-documentdb-simple.yaml`:
```yaml
Parameters:
  NumeroAlunos:
    Default: 5  # Alterar aqui
    MaxValue: 10  # Aumentar se necessário
```

### Adicionar Ferramentas
Editar seção `UserData`:
```bash
# Adicionar nova ferramenta
yum install -y nova-ferramenta
```

### Modificar Permissões
Editar política IAM no template:
```yaml
- Effect: Allow
  Action:
    - 'novo-servico:*'
  Resource: '*'
```

## 🆘 Troubleshooting

### Stack Creation Failed
```bash
aws cloudformation describe-stack-events --stack-name NOME-STACK
```

### Aluno Não Consegue Conectar
```bash
# Verificar instância
aws ec2 describe-instances --instance-ids i-XXXXXXX

# Verificar security group  
aws ec2 describe-security-groups --group-ids sg-XXXXXXX

# Testar conectividade
telnet IP-PUBLICO 22
```

### AWS CLI Não Configurado
```bash
# Conectar à instância e verificar
ssh -i chave.pem ec2-user@IP
sudo su - alunoXX
aws configure list

# Reconfigurar se necessário
aws configure
```

## 📞 Suporte

### Logs Úteis
```bash
# CloudFormation events
aws cloudformation describe-stack-events --stack-name STACK-NAME

# EC2 console output
aws ec2 get-console-output --instance-id i-XXXXXXX

# Instance user data logs
ssh -i key.pem ec2-user@IP
sudo tail -f /var/log/cloud-init-output.log
```

### Comandos de Diagnóstico
```bash
# Listar recursos do curso
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Purpose,Values="Curso DocumentDB"

# Verificar custos
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

---

## ⚠️ IMPORTANTE

- **Sempre teste** o ambiente antes do curso
- **Monitore custos** durante o curso  
- **Delete recursos** ao final para evitar cobranças
- **Mantenha backups** das configurações importantes
- **Documente** qualquer customização feita

**Este ambiente foi projetado para ser seguro, econômico e fácil de usar. Boa sorte com o curso! 🎓**