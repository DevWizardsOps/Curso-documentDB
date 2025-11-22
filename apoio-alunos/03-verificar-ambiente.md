# ✅ Guia 3: Verificar Ambiente

## 📋 O que você vai fazer

Neste guia, você vai verificar que todas as ferramentas estão instaladas e funcionando corretamente.

## ⏱️ Tempo Estimado: 5 minutos

---

## 🔍 Passo 1: Verificar Identidade AWS

Primeiro, vamos confirmar que o AWS CLI está configurado:

```bash
aws sts get-caller-identity
```

**Saída esperada**:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "396739911713",
    "Arn": "arn:aws:iam::396739911713:user/curso-documentdb-aluno01"
}
```

✅ **Se você viu algo parecido, está correto!**

❌ **Se deu erro**, entre em contato com o instrutor.

---

## 🛠️ Passo 2: Verificar Ferramentas Instaladas

Execute cada comando abaixo e confirme que funciona:

### MongoDB Shell (mongosh)
```bash
mongosh --version
```

**Esperado**: `2.x.x` ou superior

### Node.js
```bash
node --version
```

**Esperado**: `v18.x.x` ou superior

### Python
```bash
python3 --version
```

**Esperado**: `Python 3.x.x`

### Terraform
```bash
terraform --version
```

**Esperado**: `Terraform v1.x.x`

### Git
```bash
git --version
```

**Esperado**: `git version 2.x.x`

✅ **Todas as ferramentas instaladas!**

---

## 📁 Passo 3: Verificar Estrutura de Diretórios

### Ver seu diretório home:
```bash
ls -la ~/
```

**Você deve ver**:
- `BEM-VINDO.txt` - Mensagem de boas-vindas
- `global-bundle.pem` - Certificado SSL do DocumentDB
- `documentdb-labs/` - Diretório para laboratórios

### Verificar certificado SSL:
```bash
ls -la ~/global-bundle.pem
```

**Esperado**: Arquivo existe e tem permissões de leitura

### Criar diretório de trabalho (se não existir):
```bash
mkdir -p ~/documentdb-labs
cd ~/documentdb-labs
pwd
```

**Esperado**: `/home/alunoXX/documentdb-labs`

---

## 🧪 Passo 4: Testar AWS CLI

### Listar regiões disponíveis:
```bash
aws ec2 describe-regions --query 'Regions[].RegionName' --output table
```

**Esperado**: Lista de regiões AWS

### Verificar sua região padrão:
```bash
aws configure get region
```

**Esperado**: `us-east-2` (ou a região do curso)

### Listar buckets S3 (se houver):
```bash
aws s3 ls
```

**Esperado**: Lista de buckets ou mensagem vazia (ambos OK)

✅ **AWS CLI funcionando!**

---

## 🐍 Passo 5: Testar Python e Boto3

### Verificar se boto3 está instalado:
```bash
python3 -c "import boto3; print(boto3.__version__)"
```

**Esperado**: Versão do boto3 (ex: `1.28.x`)

### Teste rápido de conexão:
```bash
python3 << 'EOF'
import boto3

# Criar cliente STS
sts = boto3.client('sts')

# Obter identidade
identity = sts.get_caller_identity()

print(f"✅ Conectado como: {identity['Arn']}")
print(f"✅ Account ID: {identity['Account']}")
EOF
```

**Esperado**: Suas informações de identidade

✅ **Python e Boto3 funcionando!**

---

## 📦 Passo 6: Testar Node.js

### Criar teste rápido:
```bash
node << 'EOF'
const os = require('os');
console.log('✅ Node.js funcionando!');
console.log(`✅ Versão: ${process.version}`);
console.log(`✅ Sistema: ${os.platform()}`);
EOF
```

**Esperado**: Mensagens de sucesso

✅ **Node.js funcionando!**

---

## 🔐 Passo 7: Verificar Certificado DocumentDB

### Ver conteúdo do certificado:
```bash
openssl x509 -in ~/global-bundle.pem -text -noout | head -20
```

**Esperado**: Informações do certificado SSL

### Verificar validade:
```bash
openssl x509 -in ~/global-bundle.pem -noout -dates
```

**Esperado**: Datas de validade do certificado

✅ **Certificado SSL OK!**

---

## 🎨 Passo 8: Testar Aliases Personalizados

Seu ambiente tem alguns aliases úteis:

### Listar arquivos detalhado:
```bash
ll
```

**Esperado**: Lista detalhada de arquivos (equivale a `ls -lah`)

### Ir para diretório de labs:
```bash
labs
pwd
```

**Esperado**: `/home/alunoXX/documentdb-labs`

### Ver identidade AWS:
```bash
awsid
```

**Esperado**: Suas informações IAM

✅ **Aliases funcionando!**

---

## 📊 Passo 9: Resumo do Ambiente

Execute este script para ver um resumo completo:

```bash
cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║           VERIFICAÇÃO DO AMBIENTE - RESUMO                   ║
╚══════════════════════════════════════════════════════════════╝

👤 Usuário: $(whoami)
🏠 Home: $HOME
🌍 Região AWS: $(aws configure get region)

🛠️  FERRAMENTAS INSTALADAS:
EOF

echo "  ✅ AWS CLI: $(aws --version 2>&1 | head -1)"
echo "  ✅ MongoDB Shell: $(mongosh --version 2>&1 | head -1)"
echo "  ✅ Node.js: $(node --version)"
echo "  ✅ Python: $(python3 --version)"
echo "  ✅ Terraform: $(terraform --version | head -1)"
echo "  ✅ Git: $(git --version)"

cat << 'EOF'

📁 ARQUIVOS IMPORTANTES:
EOF

[ -f ~/BEM-VINDO.txt ] && echo "  ✅ BEM-VINDO.txt" || echo "  ❌ BEM-VINDO.txt"
[ -f ~/global-bundle.pem ] && echo "  ✅ global-bundle.pem" || echo "  ❌ global-bundle.pem"
[ -d ~/documentdb-labs ] && echo "  ✅ documentdb-labs/" || echo "  ❌ documentdb-labs/"

echo ""
echo "🎉 Ambiente verificado e pronto para uso!"
```

---

## ✅ Checklist Final

Confirme que tudo está OK:

- [ ] AWS CLI configurado e funcionando
- [ ] MongoDB Shell instalado
- [ ] Node.js instalado
- [ ] Python e Boto3 instalados
- [ ] Terraform instalado
- [ ] Git instalado
- [ ] Certificado SSL do DocumentDB presente
- [ ] Diretório de labs criado
- [ ] Aliases personalizados funcionando

---

## 🆘 Problemas Comuns

### "aws: command not found"

**Solução**:
```bash
# Verificar se está no PATH
which aws

# Se não estiver, adicionar ao PATH
export PATH=$PATH:/usr/local/bin
```

### "mongosh: command not found"

**Solução**:
```bash
# Verificar instalação
which mongosh

# Se não estiver instalado, contate o instrutor
```

### "ModuleNotFoundError: No module named 'boto3'"

**Solução**:
```bash
# Instalar boto3
pip3 install --user boto3
```

### Certificado SSL não encontrado

**Solução**:
```bash
# Baixar novamente
cd ~
wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
```

---

## 💡 Comandos Úteis para o Curso

Salve estes comandos para usar durante o curso:

### Ver mensagem de boas-vindas:
```bash
cat ~/BEM-VINDO.txt
```

### Ir para diretório de labs:
```bash
cd ~/documentdb-labs
# ou simplesmente
labs
```

### Verificar identidade AWS:
```bash
aws sts get-caller-identity
# ou simplesmente
awsid
```

### Listar clusters DocumentDB:
```bash
aws docdb describe-db-clusters
```

### Ver região atual:
```bash
aws configure get region
```

---

## 🎓 Pronto para Começar!

Se todas as verificações passaram, você está pronto para começar os laboratórios!

### Próximos Passos:

1. ✅ Ambiente verificado
2. ➡️ Começar **Módulo 1** do curso
3. 🚀 Aproveitar o curso!

---

## 📚 Recursos Adicionais

### Documentação Útil:

- [AWS CLI Reference](https://docs.aws.amazon.com/cli/)
- [MongoDB Shell Docs](https://docs.mongodb.com/mongodb-shell/)
- [AWS DocumentDB Docs](https://docs.aws.amazon.com/documentdb/)

### Atalhos do Terminal:

- `Ctrl + C` - Cancelar comando atual
- `Ctrl + D` - Sair/Logout
- `Ctrl + L` - Limpar tela (ou digite `clear`)
- `Ctrl + R` - Buscar no histórico de comandos
- `↑` / `↓` - Navegar no histórico

---

## 🎉 Parabéns!

Você completou a configuração inicial do ambiente!

**Agora você está pronto para começar o Módulo 1 do Curso DocumentDB!** 🚀

---

**Dúvidas?** Entre em contato com o instrutor.

**Bom curso! 🎓**
