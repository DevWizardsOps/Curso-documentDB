# 🎓 Curso AWS DocumentDB

Curso completo de AWS DocumentDB com laboratórios práticos hands-on.

## 📚 Estrutura do Curso

### Módulos Disponíveis

| Módulo | Título | Duração | Exercícios | Descrição |
|--------|--------|---------|------------|-----------|
| **1** | [Visão Geral do DocumentDB](./modulo1-lab/) | 4h | 3 | Conceitos, Console AWS, CLI/SDKs |
| **2** | [Administração e Gerenciamento](./modulo2-lab/) | 6h | 5 | Provisionamento, Backup, Failover |
| **3** | [Segurança e Compliance](./modulo3-lab/) | 6h | 3 | Autenticação, VPC, Auditoria |
| **4** | [Performance e Tuning](./modulo4-lab/) | 3h | 2 | Métricas Avançadas, Planos de Execução |
| **5** | [Backup e Exportação de Dados](./modulo5-lab/) | 1.5h | 1 | Backup S3, Restore, Políticas de Retenção |

**Duração Total:** 20.5 horas de conteúdo prático

## 🚀 Para Instrutores

### Preparação do Ambiente AWS

Os scripts de preparação estão no diretório [`preparacao-curso/`](./preparacao-curso/):

```bash
cd preparacao-curso/

# 1. Deploy automático do ambiente
./deploy-curso.sh

# 2. Testar configuração
./test-ambiente.sh

# 3. Gerenciar recursos
./manage-curso.sh
```

**O que é criado automaticamente:**
- ✅ Instâncias EC2 (t3.micro) para cada aluno
- ✅ Usuários IAM com permissões específicas
- ✅ Chaves SSH geradas automaticamente
- ✅ AWS CLI pré-configurado
- ✅ Ferramentas instaladas: MongoDB Shell, Node.js, Python, Terraform
- ✅ Security Groups para DocumentDB
- ✅ Bucket S3 para laboratórios

**Documentação completa:** [`preparacao-curso/README-AMBIENTE.md`](./preparacao-curso/README-AMBIENTE.md)

## 👨‍🎓 Para Alunos

### Pré-requisitos

- Conhecimento básico de bancos de dados NoSQL
- Familiaridade com conceitos de cloud computing
- Acesso à instância EC2 fornecida pelo instrutor

### Como Conectar ao Ambiente

1. **Receba do instrutor:**
   - IP público da sua instância
   - Nome da chave SSH
   - Seu número de aluno

2. **Baixe a chave SSH** do console EC2 (o instrutor fornecerá acesso)

3. **Configure permissões:**
   ```bash
   chmod 400 nome-da-chave.pem
   ```

4. **Conecte via SSH diretamente ao seu usuário:**
   ```bash
   ssh -i nome-da-chave.pem alunoXX@SEU-IP-PUBLICO  # XX = seu número
   ```
   
   Alternativa (via ec2-user):
   ```bash
   ssh -i nome-da-chave.pem ec2-user@SEU-IP-PUBLICO
   sudo su - alunoXX
   ```

### Verificar Configuração

```bash
# Testar AWS CLI (deve mostrar suas credenciais)
aws sts get-caller-identity

# Verificar ferramentas instaladas
mongosh --version
node --version
python3 --version
terraform --version

# Verificar certificado DocumentDB
ls -la ~/global-bundle.pem
```

## 📋 Roteiro de Estudo

### Iniciante (Primeira vez com DocumentDB)
**Duração total: 16h**

1. **Módulo 1** - Conceitos fundamentais (4h)
   - Introdução ao DocumentDB
   - Console AWS
   - CLI e SDKs básicos

2. **Módulo 2** - Administração básica (6h)
   - Provisionamento via Console
   - Backup e snapshots
   - Monitoramento básico

3. **Módulo 3** - Segurança essencial (6h)
   - Autenticação nativa
   - VPC e Security Groups
   - Auditoria com CloudTrail

### Intermediário (Experiência com MongoDB)
**Duração total: 15.5h**

1. **Módulo 1** - Revisão rápida (2h)
   - Diferenças MongoDB vs DocumentDB
   - Console e CLI

2. **Módulo 2** - Administração completa (6h)
   - Provisionamento com Terraform
   - Failover e alta disponibilidade
   - Monitoramento avançado

3. **Módulo 4** - Performance e tuning (3h)
   - Métricas customizadas
   - Análise de planos de execução
   - Otimização de índices

4. **Módulo 5** - Backup e exportação (1.5h)
   - Backup para S3
   - Políticas de retenção
   - Restore e validação

5. **Módulo 3** - Segurança (3h - opcional)
   - Aprofundamento em compliance

### Avançado (Arquitetos/DevOps)
**Duração total: 15h**

1. **Módulo 2** - Provisionamento com Terraform (3h)
   - Infraestrutura como código
   - Automação completa
   - Ambientes reproduzíveis

2. **Módulo 3** - Segurança e compliance (6h)
   - Autenticação avançada
   - Auditoria completa
   - Compliance e governança

3. **Módulo 4** - Performance avançada (3h)
   - Análise profunda de métricas
   - Otimização de queries complexas
   - Troubleshooting de performance

4. **Módulo 5** - Backup e disaster recovery (1.5h)
   - Estratégias de backup
   - Automação de backups
   - Testes de restore

5. **Módulo 2** - Monitoramento e automação (1.5h - revisão)
   - EventBridge e automação
   - Dashboards customizados

## 🛠️ Ferramentas Utilizadas

### Console AWS
- Interface gráfica para gerenciamento
- Monitoramento integrado
- Configuração visual

### AWS CLI
- Automação de tarefas
- Scripts de deployment
- Operações em lote

### SDKs
- **Boto3 (Python)** - Automação e scripts
- **AWS SDK (Node.js)** - Aplicações web
- **MongoDB Drivers** - Compatibilidade

### Terraform
- Infraestrutura como código
- Ambientes reproduzíveis
- Versionamento de infraestrutura

## 💰 Custos do Laboratório

### Estimativa por Aluno
- **Com Free Tier:** ~$4/mês
- **Sem Free Tier:** ~$13/mês

### Otimização de Custos
- ✅ Usar instâncias t3.micro (Free Tier)
- ✅ Parar instâncias quando não usar
- ✅ Deletar recursos ao final do curso
- ✅ Monitorar custos no AWS Cost Explorer

## 🔒 Segurança

### Implementado no Ambiente
- ✅ **Princípio do menor privilégio** para IAM
- ✅ **Security Groups** restritivos
- ✅ **Encryption at rest** habilitada por padrão
- ✅ **TLS obrigatório** para DocumentDB
- ✅ **Chaves SSH** únicas por aluno
- ✅ **Usuários separados** por aluno

### Boas Práticas Ensinadas
- 🔐 Configuração de autenticação nativa
- 🔐 Integração segura com VPC
- 🔐 Auditoria com CloudTrail
- 🔐 Monitoramento de segurança
- 🔐 Backup e recovery seguros

## 📖 Recursos Adicionais

### Documentação Oficial
- [AWS DocumentDB User Guide](https://docs.aws.amazon.com/documentdb/)
- [MongoDB Compatibility](https://docs.aws.amazon.com/documentdb/latest/developerguide/functional-differences.html)
- [Best Practices](https://docs.aws.amazon.com/documentdb/latest/developerguide/best-practices.html)

### Ferramentas Úteis
- [MongoDB Compass](https://www.mongodb.com/products/compass) (GUI)
- [Studio 3T](https://studio3t.com/) (IDE avançado)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/latest/reference/docdb/)

## 🆘 Suporte

### Durante o Curso
- Instrutor disponível para dúvidas
- Ambiente de laboratório compartilhado
- Troubleshooting em tempo real

### Problemas Comuns
- **Conexão SSH:** Verificar IP e chave
- **AWS CLI:** Reconfigurar credenciais
- **DocumentDB:** Validar security groups
- **Permissões:** Verificar políticas IAM

### Comandos de Diagnóstico
```bash
# Verificar conectividade AWS
aws sts get-caller-identity

# Testar conexão DocumentDB
mongosh --host ENDPOINT:27017 --tls --tlsCAFile global-bundle.pem

# Verificar logs
tail -f /var/log/cloud-init-output.log
```

## 🎯 Objetivos de Aprendizado

Ao final do curso, você será capaz de:

- ✅ **Provisionar** clusters DocumentDB via Console e Terraform
- ✅ **Configurar** segurança, backup e monitoramento
- ✅ **Otimizar** performance e troubleshooting
- ✅ **Implementar** alta disponibilidade e disaster recovery
- ✅ **Migrar** aplicações MongoDB para DocumentDB
- ✅ **Integrar** com outros serviços AWS
- ✅ **Automatizar** operações com scripts e APIs

## 📞 Contato

Para dúvidas sobre o curso ou ambiente:
- 📧 Email do instrutor
- 💬 Chat do curso
- 📋 Issues no repositório

---

**Bem-vindo ao curso AWS DocumentDB! 🚀**

*Transforme-se em um especialista em bancos de dados gerenciados na AWS.*