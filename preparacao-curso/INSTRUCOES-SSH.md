# Instruções de Acesso SSH - Curso DocumentDB

## 🔑 Sobre a Chave SSH

Quando você executa o script `deploy-curso.sh`, uma chave SSH é criada automaticamente:

- **Nome da chave**: `<nome-da-stack>-key`
- **Arquivo local**: `<nome-da-stack>-key.pem`
- **Localização**: No mesmo diretório onde você executou o script

### ⚠️ IMPORTANTE

**A chave privada (.pem) só existe localmente no seu computador!**

- A AWS armazena apenas a chave pública
- Se você perder o arquivo .pem, não conseguirá mais acessar as instâncias via SSH
- Faça backup do arquivo .pem em local seguro

## 📋 Como Conectar às Instâncias

### 1. Verificar permissões da chave

```bash
chmod 400 <nome-da-stack>-key.pem
```

### 2. Conectar via SSH

```bash
ssh -i <nome-da-stack>-key.pem ec2-user@<IP-PUBLICO>
```

Substitua:
- `<nome-da-stack>-key.pem` pelo nome real do arquivo
- `<IP-PUBLICO>` pelo IP da instância (fornecido no output do script)

### 3. Mudar para o usuário do aluno

Após conectar como `ec2-user`:

```bash
sudo su - aluno01
```

(Substitua `aluno01` pelo usuário correto)

## 👥 Distribuindo Acesso aos Alunos

### Opção 1: Compartilhar a mesma chave (mais simples)

1. Envie o arquivo `.pem` para cada aluno (via email seguro, Slack, etc.)
2. Forneça o IP da instância de cada aluno
3. Instrua os alunos a:
   - Salvar o arquivo .pem
   - Executar `chmod 400 arquivo.pem`
   - Conectar usando o comando SSH acima

### Opção 2: Criar chaves individuais (mais seguro)

Se preferir que cada aluno tenha sua própria chave:

1. Conecte-se à instância do aluno
2. Adicione a chave pública do aluno ao arquivo `~/.ssh/authorized_keys`

```bash
# Na instância do aluno
echo "ssh-rsa AAAAB3... chave-publica-do-aluno" >> /home/aluno01/.ssh/authorized_keys
```

## 🔒 Segurança

### Boas práticas:

- ✅ Mantenha o arquivo .pem com permissões 400
- ✅ Não compartilhe a chave em canais públicos
- ✅ Faça backup da chave em local seguro
- ✅ Delete a chave da AWS quando o curso terminar
- ✅ Destrua as instâncias EC2 após o curso

### Para deletar a chave após o curso:

```bash
# Deletar da AWS
aws ec2 delete-key-pair --key-name <nome-da-stack>-key

# Deletar arquivo local
rm <nome-da-stack>-key.pem
```

## 🆘 Problemas Comuns

### "Permission denied (publickey)"

**Causa**: Permissões incorretas no arquivo .pem

**Solução**:
```bash
chmod 400 arquivo.pem
```

### "No such file or directory"

**Causa**: Caminho incorreto para o arquivo .pem

**Solução**: Use o caminho completo:
```bash
ssh -i /caminho/completo/para/arquivo.pem ec2-user@IP
```

### "Connection refused"

**Causa**: Security Group não permite seu IP ou instância não está rodando

**Solução**:
1. Verifique se a instância está rodando no console EC2
2. Verifique se seu IP está no CIDR permitido do Security Group

### Perdi o arquivo .pem

**Solução**: Não há como recuperar. Você precisará:

1. Conectar via AWS Systems Manager Session Manager (se configurado)
2. Ou criar uma nova chave e adicioná-la manualmente à instância
3. Ou recriar as instâncias

## 📞 Suporte

Se tiver problemas:

1. Verifique os logs do CloudFormation no console AWS
2. Verifique o Security Group permite seu IP
3. Verifique se a instância está rodando
4. Teste a conectividade: `ping IP-PUBLICO`
