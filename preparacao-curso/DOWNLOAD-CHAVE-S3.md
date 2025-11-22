# 🔑 Como Baixar a Chave SSH do S3

## Para Alunos

Seu instrutor compartilhou um link para baixar a chave SSH necessária para acessar sua instância EC2.

### Opção 1: Via Console AWS (Mais Fácil) 🌐

1. **Acesse o link fornecido pelo instrutor**
   - O link será algo como: `https://s3.console.aws.amazon.com/s3/object/...`
   - Você precisa estar logado no Console AWS

2. **Faça login no Console AWS**
   - URL: `https://[ACCOUNT-ID].signin.aws.amazon.com/console`
   - Usuário: Fornecido pelo instrutor (ex: `curso-documentdb-aluno01`)
   - Senha: `Extractta@2026`

3. **Clique no link do S3**
   - Você será direcionado para a página do objeto no S3
   - Verá o arquivo `.pem` listado

4. **Baixe o arquivo**
   - Clique no botão **"Download"** ou **"Baixar"**
   - Salve o arquivo (mantenha o nome original)

5. **Configure as permissões** (Linux/Mac)
   ```bash
   chmod 400 nome-da-chave.pem
   ```
   
   Windows (PowerShell como Administrador):
   ```powershell
   icacls nome-da-chave.pem /inheritance:r
   icacls nome-da-chave.pem /grant:r "%username%:R"
   ```

### Opção 2: Via AWS CLI (Para Usuários Avançados) 💻

Se você já tem o AWS CLI configurado:

```bash
# Baixar a chave
aws s3 cp s3://BUCKET-NAME/YYYY/MM/DD/chave.pem ./chave.pem

# Configurar permissões
chmod 400 chave.pem
```

Substitua:
- `BUCKET-NAME`: Nome do bucket (fornecido pelo instrutor)
- `YYYY/MM/DD`: Data (fornecida pelo instrutor)
- `chave.pem`: Nome do arquivo (fornecido pelo instrutor)

## Testando a Chave

Após baixar e configurar as permissões:

```bash
# Conectar à sua instância
ssh -i chave.pem alunoXX@SEU-IP-PUBLICO
```

Se funcionar, você verá a mensagem de boas-vindas do curso!

## 🆘 Problemas Comuns

### "Permission denied (publickey)"

**Causa**: Permissões incorretas no arquivo .pem

**Solução**:
```bash
chmod 400 chave.pem
```

### "Access Denied" ao baixar do S3

**Causa**: Você não está logado ou não tem permissão

**Solução**:
1. Certifique-se de estar logado no Console AWS
2. Use o usuário IAM fornecido pelo instrutor
3. Verifique se está na região correta

### Arquivo não encontrado no S3

**Causa**: Link incorreto ou arquivo não foi enviado

**Solução**:
- Verifique o link com o instrutor
- Certifique-se de que o deploy foi concluído

### Windows: "WARNING: UNPROTECTED PRIVATE KEY FILE!"

**Causa**: Permissões muito abertas no Windows

**Solução**:
```powershell
# PowerShell como Administrador
icacls chave.pem /inheritance:r
icacls chave.pem /grant:r "%username%:R"
```

## 🔒 Segurança

### Boas Práticas:

- ✅ **Nunca compartilhe** sua chave privada com outros
- ✅ **Guarde em local seguro** (não deixe em Downloads)
- ✅ **Delete após o curso** se não for mais necessária
- ✅ **Não faça commit** da chave em repositórios Git

### Onde NÃO colocar a chave:

- ❌ Repositórios Git públicos
- ❌ Slack/Teams em canais públicos
- ❌ Email não criptografado
- ❌ Google Drive público
- ❌ Compartilhamento de tela durante apresentações

## 📞 Precisa de Ajuda?

Entre em contato com o instrutor se:
- Não conseguir acessar o link do S3
- Tiver problemas com permissões
- A chave não funcionar para conectar

---

**Boa sorte no curso! 🎓**
