# 🔌 Guia 2: Conectar via SSH

## 📋 O que você vai fazer

Neste guia, você vai conectar à sua instância EC2 do laboratório usando SSH.

## ⏱️ Tempo Estimado: 5 minutos

---

## 📝 Informações Necessárias

Antes de começar, você deve ter:

- ✅ **Chave SSH baixada** (do Guia 1)
- ✅ **IP Público da instância**: Fornecido pelo instrutor
- ✅ **Seu número de aluno**: (ex: `01`, `02`, etc.)

## 🔍 Passo 1: Localizar Sua Chave SSH

1. Abra o Terminal (Linux/Mac) ou PowerShell (Windows)

2. Navegue até onde está a chave:
   ```bash
   cd ~/curso-documentdb
   # ou
   cd ~/Downloads
   ```

3. Verifique que o arquivo existe:
   ```bash
   ls -la curso-documentdb-key.pem
   ```

✅ **Chave encontrada!**

---

## 🌐 Passo 2: Obter Seu IP Público

Você deve ter recebido do instrutor algo como:

```
Aluno 01:
  IP Público: 18.191.123.45
  Usuário: aluno01
```

**Anote aqui**:
- Meu IP: `_______________________`
- Meu usuário: `aluno___`

---

## 🔌 Passo 3: Conectar via SSH

### Método Recomendado: Conexão Direta

```bash
ssh -i curso-documentdb-key.pem alunoXX@SEU-IP-PUBLICO
```

**Exemplo real**:
```bash
ssh -i curso-documentdb-key.pem aluno01@18.191.123.45
```

**Substitua**:
- `alunoXX` → Seu número de aluno (ex: `aluno01`)
- `SEU-IP-PUBLICO` → O IP fornecido pelo instrutor

### Método Alternativo: Via ec2-user

Se o método acima não funcionar:

```bash
ssh -i curso-documentdb-key.pem ec2-user@SEU-IP-PUBLICO
```

Depois de conectar:
```bash
sudo su - alunoXX
```

---

## ✅ Passo 4: Primeira Conexão

Na primeira vez que conectar, você verá:

```
The authenticity of host '18.191.123.45' can't be established.
ECDSA key fingerprint is SHA256:...
Are you sure you want to continue connecting (yes/no)?
```

**Digite**: `yes` e pressione Enter

Você verá:
```
Warning: Permanently added '18.191.123.45' (ECDSA) to the list of known hosts.
```

✅ **Isso é normal!**

---

## 🎉 Passo 5: Confirmar Conexão

Se tudo deu certo, você verá:

```
╔══════════════════════════════════════════════════════════════╗
║              BEM-VINDO AO CURSO DOCUMENTDB                   ║
╚══════════════════════════════════════════════════════════════╝

Olá aluno01!

Seu ambiente está configurado e pronto para uso.
...
```

E o prompt mudará para:
```
aluno01@documentdb-lab:~$
```

✅ **Você está conectado!**

---

## 🔧 Comandos Úteis

### Verificar onde você está:
```bash
whoami
# Deve mostrar: alunoXX
```

### Ver seu diretório home:
```bash
pwd
# Deve mostrar: /home/alunoXX
```

### Listar arquivos:
```bash
ls -la
```

### Ver mensagem de boas-vindas novamente:
```bash
cat ~/BEM-VINDO.txt
```

### Desconectar:
```bash
exit
# ou pressione Ctrl+D
```

---

## 🆘 Problemas Comuns

### "Permission denied (publickey)"

**Causa**: Permissões incorretas na chave

**Solução**:
```bash
chmod 400 curso-documentdb-key.pem
```

### "No such file or directory"

**Causa**: Caminho da chave incorreto

**Solução**:
```bash
# Use caminho completo
ssh -i ~/curso-documentdb/curso-documentdb-key.pem aluno01@IP
```

### "Connection timed out"

**Causa**: IP incorreto ou instância não está rodando

**Solução**:
1. Verifique o IP com o instrutor
2. Confirme que a instância está rodando
3. Verifique sua conexão com a internet

### "Connection refused"

**Causa**: Security Group não permite seu IP

**Solução**:
- Entre em contato com o instrutor
- Pode ser necessário atualizar o Security Group

### "Host key verification failed"

**Causa**: IP foi reutilizado ou mudou

**Solução**:
```bash
ssh-keygen -R SEU-IP-PUBLICO
# Depois tente conectar novamente
```

### Windows: "ssh não é reconhecido"

**Causa**: SSH não está instalado ou não está no PATH

**Solução**:
1. Use o PowerShell (não CMD)
2. Ou instale o OpenSSH:
   - Configurações → Apps → Recursos Opcionais
   - Adicionar → OpenSSH Client

---

## 💡 Dicas Importantes

### Criar um Alias (Opcional)

Para não digitar o comando completo toda vez:

**Linux/Mac** - Adicione ao `~/.bashrc` ou `~/.zshrc`:
```bash
alias lab='ssh -i ~/curso-documentdb/curso-documentdb-key.pem aluno01@18.191.123.45'
```

Depois:
```bash
source ~/.bashrc
lab  # Conecta automaticamente!
```

**Windows** - Crie um arquivo `conectar-lab.bat`:
```batch
@echo off
ssh -i C:\Users\SeuUsuario\curso-documentdb\curso-documentdb-key.pem aluno01@18.191.123.45
```

### Manter Conexão Ativa

Se a conexão cai por inatividade, adicione ao `~/.ssh/config`:

```bash
Host documentdb-lab
    HostName SEU-IP-PUBLICO
    User alunoXX
    IdentityFile ~/curso-documentdb/curso-documentdb-key.pem
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

Depois conecte com:
```bash
ssh documentdb-lab
```

### Copiar Arquivos (SCP)

**Do seu computador para o lab**:
```bash
scp -i curso-documentdb-key.pem arquivo.txt aluno01@IP:~/
```

**Do lab para seu computador**:
```bash
scp -i curso-documentdb-key.pem aluno01@IP:~/arquivo.txt ./
```

---

## ✅ Checklist de Conclusão

Antes de prosseguir, confirme:

- [ ] Consegui conectar via SSH
- [ ] Vi a mensagem de boas-vindas
- [ ] O prompt mostra meu usuário correto
- [ ] Consigo executar comandos básicos
- [ ] Sei como desconectar (exit)

---

## 📝 Anote Seu Comando de Conexão

Para referência futura, anote o comando completo:

```bash
ssh -i _________________ aluno___@_______________
```

---

## ➡️ Próximo Passo

Agora que você está conectado, vá para:

**[Guia 3: Verificar Ambiente](./03-verificar-ambiente.md)**

---

## 🎓 Pronto para os Laboratórios!

Após completar o Guia 3, você estará pronto para começar o **Módulo 1** do curso!
