# Credenciais de Acesso - Curso DocumentDB

## 🌐 Acesso ao Console AWS

### URL de Login
```
https://[ACCOUNT-ID].signin.aws.amazon.com/console
```

### Credenciais do Treinamento

| Aluno | Nome de Usuário IAM | Senha |
|-------|---------------------|-------|
| Aluno 01 | `[stack-name]-aluno01` | Ver abaixo |
| Aluno 02 | `[stack-name]-aluno02` | Ver abaixo |

### �O Como Obter a Senha

A senha está armazenada de forma segura no AWS Secrets Manager.

**Opção 1 - Via AWS CLI:**
```bash
aws secretsmanager get-secret-value \
  --secret-id [stack-name]-console-password \
  --query SecretString --output text | jq -r .password
```

**Opção 2 - Via Console AWS (com credenciais de administrador):**
1. Acesse o serviço Secrets Manager
2. Procure por `[stack-name]-console-password`
3. Clique em "Retrieve secret value"
4. A senha estará no campo `password`

**⚠️ IMPORTANTE:**
- Você será solicitado a trocar a senha no primeiro login
- Escolha uma senha forte com pelo menos 8 caracteres
- Não compartilhe sua nova senha com outros alunos

## 🔑 Acesso SSH às Instâncias EC2

### Pré-requisitos
1. Baixe o arquivo de chave SSH: `[stack-name]-key.pem`
2. Configure as permissões corretas:
   ```bash
   chmod 400 [stack-name]-key.pem
   ```

### Conectar à sua instância

**Aluno 01:**
```bash
ssh -i [stack-name]-key.pem ec2-user@[IP-ALUNO-01]
sudo su - aluno01
```

**Aluno 02:**
```bash
ssh -i [stack-name]-key.pem ec2-user@[IP-ALUNO-02]
sudo su - aluno02
```

## 🛠️ Verificar Configuração

Após conectar via SSH, execute:

```bash
# Verificar identidade AWS
aws sts get-caller-identity

# Verificar ferramentas instaladas
mongosh --version
node --version
python3 --version
terraform --version

# Ver arquivo de boas-vindas
cat ~/BEM-VINDO.txt
```

## 📋 Informações do Ambiente

### Ferramentas Pré-instaladas
- ✅ AWS CLI (configurado com suas credenciais)
- ✅ MongoDB Shell (mongosh)
- ✅ Node.js 18.x
- ✅ Python 3 + pip
- ✅ Terraform
- ✅ Git

### Diretórios Importantes
- **Laboratórios**: `~/documentdb-labs`
- **Certificado SSL**: `~/global-bundle.pem`

### Aliases Úteis
- `ll` - Lista detalhada de arquivos
- `labs` - Vai para o diretório de laboratórios
- `awsid` - Mostra sua identidade AWS

## 🔒 Permissões IAM

Seu usuário tem permissões para:
- ✅ **DocumentDB**: Acesso completo
- ✅ **EC2**: Consultas e gerenciamento de Security Groups
- ✅ **CloudWatch**: Métricas e logs
- ✅ **S3**: Acesso aos buckets do curso
- ✅ **EventBridge**: Automação básica
- ✅ **Lambda**: Funções básicas

## 🆘 Problemas Comuns

### Não consigo fazer login no console
- Verifique se está usando o nome de usuário completo: `[stack-name]-alunoXX`
- Certifique-se de estar na URL correta com o Account ID
- A senha padrão é: `Extractta@2026`
- Você será solicitado a trocar a senha no primeiro login

### Erro "Permission denied" no SSH
```bash
# Ajustar permissões da chave
chmod 400 [stack-name]-key.pem
```

### AWS CLI não funciona
```bash
# Reconfigurar (não deveria ser necessário)
aws configure list

# Se necessário, o instrutor pode fornecer novas credenciais
```

### Esqueci minha nova senha do console
- A senha padrão inicial é: `Extractta@2026`
- Se você já trocou a senha e esqueceu, entre em contato com o instrutor para reset

## 📞 Suporte

Para problemas técnicos:
1. Verifique este documento primeiro
2. Consulte o arquivo `~/BEM-VINDO.txt` na sua instância
3. Entre em contato com o instrutor

---

**Bom curso! 🎓**
