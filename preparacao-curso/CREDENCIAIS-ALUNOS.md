# Credenciais de Acesso - Curso DocumentDB

## 🌐 Acesso ao Console AWS

### URL de Login
```
https://[ACCOUNT-ID].signin.aws.amazon.com/console
```

### Credenciais Padrão

| Aluno | Nome de Usuário IAM | Senha Padrão |
|-------|---------------------|--------------|
| Aluno 01 | `[stack-name]-aluno01` | `Extractta@2026` |
| Aluno 02 | `[stack-name]-aluno02` | `Extractta@2026` |

**⚠️ IMPORTANTE:**
- A senha é a mesma para todos os alunos: **`Extractta@2026`**
- **NÃO** é necessário trocar a senha no primeiro login
- Mantenha a senha em local seguro durante o curso
- Todos os alunos usam a mesma senha para facilitar o treinamento

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
- Não é necessário trocar a senha

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

### Esqueci a senha do console
- A senha padrão é: `Extractta@2026`
- Esta senha não muda durante o curso
- Se ainda assim não conseguir acessar, entre em contato com o instrutor

## 📞 Suporte

Para problemas técnicos:
1. Verifique este documento primeiro
2. Consulte o arquivo `~/BEM-VINDO.txt` na sua instância
3. Entre em contato com o instrutor

---

**Bom curso! 🎓**
