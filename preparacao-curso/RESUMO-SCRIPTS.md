# 📋 Resumo dos Scripts do Ambiente AWS

## 🎯 Arquivos Criados

### 1. **setup-curso-documentdb-simple.yaml**
**CloudFormation Template Principal**
- Cria instâncias EC2 (t3.micro) para cada aluno
- Configura usuários IAM com permissões específicas
- Gera chaves SSH automaticamente
- Instala ferramentas necessárias (AWS CLI, MongoDB Shell, Node.js, Python, Terraform)
- Configura Security Groups para DocumentDB
- Cria bucket S3 para laboratórios

### 2. **deploy-curso.sh**
**Script de Deploy Interativo**
- Interface amigável para configuração
- Detecta VPC e subnet automaticamente
- Valida pré-requisitos (AWS CLI, credenciais)
- Deploy automático da stack CloudFormation
- Mostra informações das instâncias criadas

### 3. **manage-curso.sh**
**Gerenciador do Ambiente**
- Menu interativo para gerenciar recursos
- Listar stacks e informações detalhadas
- Conectar a instâncias dos alunos
- Parar/iniciar instâncias (economia de custos)
- Relatório de custos
- Deletar ambiente completo

### 4. **test-ambiente.sh**
**Validador do Ambiente**
- Testa se todos os recursos foram criados
- Verifica conectividade SSH
- Valida configurações de segurança
- Relatório de status completo

### 5. **README-AMBIENTE.md**
**Documentação Completa**
- Instruções detalhadas de uso
- Troubleshooting
- Gestão de custos
- Boas práticas de segurança

## 🚀 Como Usar

### Passo 1: Preparar Ambiente
```bash
# Verificar AWS CLI
aws --version
aws sts get-caller-identity

# Clonar repositório
git clone <repo>
cd Curso-documentDB
```

### Passo 2: Deploy
```bash
# Executar deploy
./deploy-curso.sh

# Seguir prompts interativos:
# - Número de alunos (1-10)
# - Prefixo dos alunos
# - Configurações de rede
# - Segurança SSH
```

### Passo 3: Validar
```bash
# Testar ambiente
./test-ambiente.sh

# Verificar se tudo está funcionando
```

### Passo 4: Gerenciar
```bash
# Usar gerenciador
./manage-curso.sh

# Opções disponíveis:
# 1. Listar stacks
# 2. Ver informações
# 3. Conectar a instâncias
# 4. Parar/iniciar instâncias
# 5. Relatório de custos
# 6. Deletar ambiente
```

## 📊 Recursos Criados por Aluno

### Instância EC2
- **Tipo**: t3.micro (Free Tier elegível)
- **OS**: Amazon Linux 2023
- **IP**: Público (para SSH)
- **Storage**: 8GB EBS (Free Tier)

### Usuário IAM
- **Nome**: `{stack-name}-{prefixo}{numero}`
- **Grupo**: Permissões específicas do curso
- **Access Key**: Gerada automaticamente
- **Permissões**: DocumentDB, CloudWatch, EC2 (limitado), S3

### Chave SSH
- **Nome**: `{stack-name}-{prefixo}{numero}-key`
- **Tipo**: RSA
- **Download**: Console EC2 > Key Pairs

### Ferramentas Instaladas
- ✅ AWS CLI v2 (pré-configurado)
- ✅ MongoDB Shell (mongosh)
- ✅ Node.js v18 + npm
- ✅ Python 3 + pip + boto3
- ✅ Terraform
- ✅ Git
- ✅ Certificado SSL DocumentDB

## 💰 Estimativa de Custos

### Por Aluno (mensal)
- **t3.micro**: $8.50 (Free Tier: $0)
- **EBS 8GB**: $0.80 (Free Tier: $0)
- **IP Público**: $3.65
- **Total**: ~$13/mês (Free Tier: ~$4/mês)

### Para 5 Alunos
- **Com Free Tier**: ~$20/mês
- **Sem Free Tier**: ~$65/mês

### Otimização
- Parar instâncias quando não usar: **-70% custos**
- Usar apenas durante aulas: **-80% custos**
- Deletar ao final do curso: **$0**

## 🛡️ Segurança Implementada

### Rede
- ✅ Security Groups restritivos
- ✅ SSH apenas de IPs permitidos
- ✅ DocumentDB isolado em VPC
- ✅ Sem acesso público ao DocumentDB

### IAM
- ✅ Princípio do menor privilégio
- ✅ Sem permissões administrativas
- ✅ Acesso limitado a recursos do curso
- ✅ Sem permissões IAM para alunos

### Instâncias
- ✅ Usuários separados por aluno
- ✅ Sudo configurado
- ✅ AWS CLI pré-configurado
- ✅ Certificados SSL instalados

## 🔧 Personalização

### Modificar Número de Alunos
Editar `setup-curso-documentdb-simple.yaml`:
```yaml
Parameters:
  NumeroAlunos:
    Type: Number
    Default: 5  # Alterar aqui
    MaxValue: 20  # Aumentar se necessário
```

### Adicionar Ferramentas
Editar seção `UserData` no template:
```bash
# Adicionar instalação de nova ferramenta
yum install -y nova-ferramenta
```

### Modificar Permissões IAM
Editar política no `CursoDocumentDBGroup`:
```yaml
- Effect: Allow
  Action:
    - 'novo-servico:*'
  Resource: '*'
```

## 📞 Troubleshooting Rápido

### Stack Creation Failed
```bash
aws cloudformation describe-stack-events --stack-name NOME-STACK
```

### Instância não inicia
```bash
aws ec2 describe-instances --instance-ids i-XXXXXXX
aws ec2 get-console-output --instance-id i-XXXXXXX
```

### SSH não conecta
```bash
# Verificar security group
aws ec2 describe-security-groups --group-ids sg-XXXXXXX

# Testar conectividade
telnet IP-PUBLICO 22
```

### AWS CLI não configurado
```bash
# Conectar e reconfigurar
ssh -i chave.pem ec2-user@IP
sudo su - aluno01
aws configure list
```

## ✅ Checklist de Deploy

- [ ] AWS CLI instalado e configurado
- [ ] Permissões IAM adequadas
- [ ] VPC com subnet pública disponível
- [ ] Executar `./deploy-curso.sh`
- [ ] Aguardar conclusão (10-15 min)
- [ ] Executar `./test-ambiente.sh`
- [ ] Baixar chaves SSH do console
- [ ] Testar conexão a uma instância
- [ ] Distribuir informações para alunos
- [ ] Iniciar curso!

## 🎓 Informações para Alunos

### Como Conectar
```bash
# 1. Receber do instrutor:
# - IP público da instância
# - Nome da chave SSH
# - Número do aluno

# 2. Baixar chave SSH do console EC2

# 3. Configurar permissões
chmod 400 nome-da-chave.pem

# 4. Conectar
ssh -i nome-da-chave.pem ec2-user@IP-PUBLICO

# 5. Mudar para usuário do curso
sudo su - alunoXX
```

### Verificar Configuração
```bash
# Testar AWS CLI
aws sts get-caller-identity

# Verificar ferramentas
mongosh --version
node --version
python3 --version
terraform --version

# Verificar certificado DocumentDB
ls -la ~/global-bundle.pem
```

---

**🎉 Ambiente pronto para o curso DocumentDB! 🎉**