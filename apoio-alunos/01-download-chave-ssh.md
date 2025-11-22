# 🔑 Guia 1: Baixar Chave SSH do S3

## 📋 O que você vai fazer

Neste guia, você vai baixar a chave SSH necessária para acessar sua instância EC2 do laboratório.

## ⏱️ Tempo Estimado: 5 minutos

---

## 📝 Informações Necessárias

Antes de começar, você deve ter recebido do instrutor:

- ✅ **Account ID**: Número da conta AWS (12 dígitos)
- ✅ **Usuário IAM**: Seu nome de usuário (ex: `curso-documentdb-aluno01`)
- ✅ **Senha**: Senha padrão do console
- ✅ **Link do S3**: Link direto para o arquivo da chave

## 🌐 Passo 1: Fazer Login no Console AWS

1. Abra seu navegador
2. Acesse a URL fornecida pelo instrutor:
   ```
   https://[ACCOUNT-ID].signin.aws.amazon.com/console
   ```
   
3. Preencha os campos:
   - **Account ID**: (já deve estar preenchido)
   - **IAM user name**: Seu usuário (ex: `curso-documentdb-aluno01`)
   - **Password**: `Extractta@2026`

4. Clique em **Sign in**

✅ **Você está logado!** Deve ver o dashboard da AWS.

---

## ☁️ Passo 2: Acessar o S3

### Opção A: Via Link Direto (Mais Fácil)

1. **Clique no link fornecido pelo instrutor**
   - O link será algo como:
   ```
   https://s3.console.aws.amazon.com/s3/object/curso-documentdb-keys-...
   ```

2. Você será direcionado diretamente para o arquivo

3. **Pule para o Passo 3**

### Opção B: Navegando Manualmente

1. No Console AWS, clique na barra de pesquisa no topo

2. Digite **S3** e clique em **S3** nos resultados

3. Você verá a lista de buckets

4. Procure pelo bucket: `curso-documentdb-keys-[números]`

5. Clique no nome do bucket

6. Navegue pela estrutura de pastas:
   - Clique na pasta do ano (ex: `2024`)
   - Clique na pasta do mês (ex: `11`)
   - Clique na pasta do dia (ex: `22`)

7. Você verá o arquivo `.pem`

---

## 💾 Passo 3: Baixar o Arquivo

1. **Selecione o arquivo** clicando na caixa de seleção ao lado do nome

2. Clique no botão **Download** (ou **Baixar**)
   - Fica no canto superior direito

3. **Salve o arquivo**
   - Mantenha o nome original (ex: `curso-documentdb-key.pem`)
   - Salve em um local que você lembre (ex: `Downloads`)

✅ **Download concluído!**

---

## 🔧 Passo 4: Configurar Permissões

### No Linux ou Mac:

1. Abra o Terminal

2. Navegue até onde salvou o arquivo:
   ```bash
   cd ~/Downloads
   ```

3. Configure as permissões:
   ```bash
   chmod 400 curso-documentdb-key.pem
   ```

4. Verifique:
   ```bash
   ls -la curso-documentdb-key.pem
   ```
   
   Deve mostrar: `-r--------`

### No Windows:

1. Abra o **PowerShell como Administrador**
   - Clique com botão direito no menu Iniciar
   - Selecione "Windows PowerShell (Admin)"

2. Navegue até onde salvou o arquivo:
   ```powershell
   cd C:\Users\SeuUsuario\Downloads
   ```

3. Configure as permissões:
   ```powershell
   icacls curso-documentdb-key.pem /inheritance:r
   icacls curso-documentdb-key.pem /grant:r "$env:USERNAME`:R"
   ```

4. Verifique:
   ```powershell
   icacls curso-documentdb-key.pem
   ```

✅ **Permissões configuradas!**

---

## ✅ Checklist de Conclusão

Antes de prosseguir, confirme:

- [ ] Fiz login no Console AWS
- [ ] Encontrei o bucket S3 correto
- [ ] Baixei o arquivo `.pem`
- [ ] Configurei as permissões (chmod 400 ou icacls)
- [ ] Sei onde o arquivo está salvo

---

## 🆘 Problemas Comuns

### "Access Denied" ao acessar o S3

**Causa**: Você não está logado ou não tem permissão

**Solução**:
1. Verifique se está logado com o usuário correto
2. Confirme o Account ID com o instrutor
3. Tente fazer logout e login novamente

### Não encontro o bucket

**Causa**: Pode estar na região errada

**Solução**:
1. No canto superior direito do Console, verifique a região
2. Mude para a região informada pelo instrutor (ex: `us-east-2`)
3. Use o link direto fornecido pelo instrutor

### "Permission denied" ao executar chmod

**Causa**: Você não tem permissão no diretório

**Solução**:
```bash
# Mova o arquivo para seu home
mv curso-documentdb-key.pem ~/
cd ~
chmod 400 curso-documentdb-key.pem
```

### Windows: "icacls não é reconhecido"

**Causa**: Comando não disponível ou PowerShell não é Admin

**Solução**:
1. Feche o PowerShell
2. Abra novamente como Administrador
3. Tente novamente

---

## 📍 Onde Guardar a Chave

**Recomendações**:

✅ **Bom**:
- `~/curso-documentdb/` (criar pasta específica)
- `~/.ssh/` (pasta padrão de chaves SSH)
- Desktop (temporariamente, para fácil acesso)

❌ **Evite**:
- Deixar em Downloads (pode ser deletado acidentalmente)
- Repositórios Git
- Pastas compartilhadas

**Sugestão**:
```bash
# Criar pasta específica
mkdir -p ~/curso-documentdb
mv ~/Downloads/curso-documentdb-key.pem ~/curso-documentdb/
cd ~/curso-documentdb
chmod 400 curso-documentdb-key.pem
```

---

## ➡️ Próximo Passo

Agora que você tem a chave SSH, vá para:

**[Guia 2: Conectar via SSH](./02-conectar-ssh.md)**

---

## 💡 Dica

Anote o caminho completo do arquivo para usar depois:

```bash
# Linux/Mac
pwd
# Mostra algo como: /home/seu-usuario/curso-documentdb

# Windows
cd
# Mostra algo como: C:\Users\SeuUsuario\curso-documentdb
```

**Caminho completo da chave**: `_______________________________`

(Preencha acima para referência futura)
