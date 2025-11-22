# 📚 Índice da Documentação - Preparação do Curso

## 🚀 Para Começar

1. **[README.md](./README.md)** - **COMECE AQUI**
   - Guia completo de uso
   - Como fazer deploy do ambiente
   - Opções de configuração
   - Troubleshooting

## 👥 Para Distribuir aos Alunos

2. **[CREDENCIAIS-ALUNOS.md](./CREDENCIAIS-ALUNOS.md)**
   - Template com informações de acesso
   - Instruções de login (Console + SSH)
   - Comandos de verificação
   - Troubleshooting básico

3. **[INSTRUCOES-SSH.md](./INSTRUCOES-SSH.md)**
   - Como funcionam as chaves SSH
   - Como conectar às instâncias
   - Problemas comuns e soluções
   - Boas práticas de segurança

## 🔧 Referência Técnica

4. **[PERMISSOES-IAM.md](./PERMISSOES-IAM.md)**
   - Todas as permissões IAM detalhadas
   - Justificativa de cada permissão
   - Matriz de permissões por módulo
   - Troubleshooting de permissões

## 📋 Fluxo de Trabalho Recomendado

### Para Instrutores:

```
1. Ler README.md (este guia)
   ↓
2. Executar ./deploy-curso.sh
   ↓
3. Aguardar criação do ambiente (10-15 min)
   ↓
4. Editar CREDENCIAIS-ALUNOS.md com informações reais
   ↓
5. Distribuir CREDENCIAIS-ALUNOS.md para os alunos
   ↓
6. Compartilhar INSTRUCOES-SSH.md se necessário
   ↓
7. Iniciar o curso!
```

### Para Alunos:

```
1. Receber CREDENCIAIS-ALUNOS.md do instrutor
   ↓
2. Fazer login no Console AWS
   ↓
3. Conectar via SSH (seguir INSTRUCOES-SSH.md se necessário)
   ↓
4. Verificar ambiente
   ↓
5. Começar os laboratórios!
```

## 🆘 Precisa de Ajuda?

- **Problemas com deploy**: Ver seção "Solução de Problemas" no README.md
- **Problemas com SSH**: Ver INSTRUCOES-SSH.md
- **Problemas com permissões**: Ver PERMISSOES-IAM.md
- **Dúvidas gerais**: Consultar README.md primeiro

---

**💡 Dica**: Mantenha este INDEX.md aberto enquanto navega pela documentação!
