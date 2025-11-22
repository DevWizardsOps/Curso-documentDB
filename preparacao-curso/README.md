# Preparação do Ambiente - Curso DocumentDB

Este diretório contém scripts para preparar o ambiente AWS para o curso de DocumentDB.

## 🎯 O que é criado

Para cada aluno, o script cria:
- ✅ Instância EC2 (t3.micro) com Amazon Linux 2
- ✅ Usuário IAM com permissões para DocumentDB
- ✅ **Acesso ao Console AWS** (senha: `Extractta@2025`)
- ✅ Access Keys configuradas automaticamente na instância
- ✅ Ambiente pré-configurado (MongoDB Shell, Node.js, Python, Terraform)
- ✅ Security Groups para EC2 e DocumentDB

Recursos compartilhados:
- ✅ Security Group para DocumentDB
- ✅ Bucket S3 para laboratórios
- ✅ IAM Group com políticas do curso

## 📋 Pré-requisitos

1. **AWS CLI instalado e configurado**
   ```bash
   aws configure
   ```

2. **Permissões necessárias**:
   - Criar instâncias EC2
   - Criar usuários e grupos IAM
   - Criar Security Groups
   - Criar buckets S3
   - Criar/importar Key Pairs

3. **VPC com subnet pública** (pode usar a VPC padrão)

## 🚀 Como usar

Existem duas formas de criar o ambiente:

### Opção 1: Teste Rápido (2 alunos fixos) ⚡

**Ideal para**: Testes rápidos, validação do ambiente, POC

Use o template estático `setup-curso-documentdb-simple.yaml` que cria exatamente 2 alunos:

```bash
cd preparacao-curso

# Criar chave SSH
KEY_NAME="curso-documentdb-key"
ssh-keygen -t rsa -b 2048 -f "$KEY_NAME.pem" -N "" -C "Curso DocumentDB"
aws ec2 import-key-pair --key-name $KEY_NAME --public-key-material fileb://${KEY_NAME}.pem.pub
chmod 400 ${KEY_NAME}.pem
rm ${KEY_NAME}.pem.pub

# Deploy direto
aws cloudformation create-stack \
  --stack-name curso-documentdb \
  --template-body file://setup-curso-documentdb-simple.yaml \
  --parameters \
      ParameterKey=PrefixoAluno,ParameterValue=aluno \
      ParameterKey=VpcId,ParameterValue=vpc-xxxxx \
      ParameterKey=SubnetId,ParameterValue=subnet-xxxxx \
      ParameterKey=AllowedCIDR,ParameterValue=0.0.0.0/0 \
      ParameterKey=KeyPairName,ParameterValue=$KEY_NAME \
  --capabilities CAPABILITY_NAMED_IAM
```

**Vantagens**:
- ✅ Deploy rápido e simples
- ✅ Não precisa de scripts auxiliares
- ✅ Template fixo e fácil de revisar
- ✅ Ideal para testes e validação

**Limitações**:
- ⚠️ Sempre cria exatamente 2 alunos
- ⚠️ Para mais alunos, use a Opção 2

### Opção 2: Ambiente Completo (1-20 alunos) 🎓

**Ideal para**: Cursos reais, múltiplos alunos, produção

Use o script `deploy-curso.sh` que gera o template dinamicamente:

```bash
cd preparacao-curso
./deploy-curso.sh
```

O script perguntará:
- Número de alunos (1-20)
- Prefixo para nomes dos alunos (padrão: "aluno")
- Nome da stack CloudFormation (padrão: "curso-documentdb")
- CIDR permitido para SSH (recomendado: seu IP atual)

O script irá:
1. Gerar o template CloudFormation dinamicamente via `gerar-template.sh`
2. Criar/importar a chave SSH automaticamente
3. Criar a stack no CloudFormation
4. Aguardar a conclusão (pode levar 5-10 minutos)
5. Exibir as informações de acesso

**Vantagens**:
- ✅ Suporta de 1 a 20 alunos
- ✅ Totalmente automatizado
- ✅ Gerenciamento de chaves SSH integrado
- ✅ Validações e verificações automáticas

## 📊 Comparação das Opções

| Característica | Teste Rápido | Ambiente Completo |
|----------------|--------------|-------------------|
| Número de alunos | 2 (fixo) | 1-20 (configurável) |
| Complexidade | Baixa | Média |
| Automação | Manual | Automática |
| Tempo de setup | ~2 min | ~5 min |
| Uso recomendado | Testes/POC | Cursos reais |
| Template | Estático | Gerado dinamicamente |

## 🔑 Chave SSH

### Como funciona

O script cria uma chave SSH localmente e faz upload da chave pública para a AWS:

- **Arquivo criado**: `<nome-da-stack>-key.pem`
- **Localização**: Diretório atual
- **Uso**: Mesma chave para todas as instâncias

### ⚠️ IMPORTANTE

- A chave privada (.pem) fica apenas no seu computador
- Faça backup do arquivo .pem
- Distribua o arquivo .pem para os alunos
- Se perder o arquivo, não conseguirá mais acessar as instâncias via SSH

Veja mais detalhes em: [INSTRUCOES-SSH.md](./INSTRUCOES-SSH.md)

## 📊 Arquitetura

```
┌─────────────────────────────────────────────────────────┐
│                    AWS Account                          │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  VPC                                             │  │
│  │                                                  │  │
│  │  ┌────────────┐  ┌────────────┐  ┌───────────┐ │  │
│  │  │ EC2 Aluno1 │  │ EC2 Aluno2 │  │    ...    │ │  │
│  │  │            │  │            │  │           │ │  │
│  │  │ - mongosh  │  │ - mongosh  │  │           │ │  │
│  │  │ - Node.js  │  │ - Node.js  │  │           │ │  │
│  │  │ - Python   │  │ - Python   │  │           │ │  │
│  │  │ - AWS CLI  │  │ - AWS CLI  │  │           │ │  │
│  │  └────────────┘  └────────────┘  └───────────┘ │  │
│  │         │               │              │        │  │
│  │         └───────────────┴──────────────┘        │  │
│  │                         │                       │  │
│  │                  ┌──────▼──────┐               │  │
│  │                  │ DocumentDB  │               │  │
│  │                  │   Cluster   │               │  │
│  │                  └─────────────┘               │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  IAM                                             │  │
│  │                                                  │  │
│  │  ┌─────────────────────────────────────────┐    │  │
│  │  │  Group: curso-documentdb-students       │    │  │
│  │  │  - DocumentDB Full Access               │    │  │
│  │  │  - EC2 Describe/SG Management           │    │  │
│  │  │  - CloudWatch Logs/Metrics              │    │  │
│  │  │  - S3 Access (curso buckets)            │    │  │
│  │  └─────────────────────────────────────────┘    │  │
│  │           │                                      │  │
│  │  ┌────────┴────────┬──────────┬─────────┐       │  │
│  │  │                 │          │         │       │  │
│  │  │  User: aluno01  │ aluno02  │   ...   │       │  │
│  │  │  (Access Keys)  │          │         │       │  │
│  │  └─────────────────┴──────────┴─────────┘       │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  S3: curso-documentdb-labs-<account-id>          │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## 📁 Arquivos

### Scripts principais
- `deploy-curso.sh` - Script automatizado para deploy completo (Opção 2)
- `gerar-template.sh` - Gera template CloudFormation dinamicamente para N alunos

### Templates CloudFormation
- `setup-curso-documentdb-simple.yaml` - Template estático para 2 alunos (Opção 1 - Teste Rápido)
- `setup-curso-documentdb-dynamic.yaml` - Template gerado dinamicamente (criado pelo gerar-template.sh)

### Documentação e utilitários
- `INSTRUCOES-SSH.md` - Instruções detalhadas sobre chaves SSH
- `CREDENCIAIS-ALUNOS.md` - Template de credenciais para distribuir aos alunos
- `conectar-aluno.sh` - Script auxiliar para conectar às instâncias
- `README.md` - Este arquivo

## 🔧 Solução de Problemas

### Erro: InsufficientCapabilitiesException

**Solução**: O script já usa `--capabilities CAPABILITY_NAMED_IAM`

### Erro: Parameters: [KeyPairName] must have values

**Causa**: A chave SSH não foi criada corretamente

**Solução**: 
1. Verifique se o arquivo .pem foi criado
2. Execute o script novamente
3. Se a chave já existe na AWS, certifique-se de ter o arquivo .pem local

### Stack falhou (ROLLBACK_COMPLETE)

**Solução**: Verifique os eventos da stack:
```bash
aws cloudformation describe-stack-events \
  --stack-name curso-documentdb \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]'
```

### Não consigo conectar via SSH

Veja: [INSTRUCOES-SSH.md](./INSTRUCOES-SSH.md)

## 🧹 Limpeza

Para deletar todo o ambiente após o curso:

```bash
# Deletar a stack (deleta EC2, IAM users, S3, etc.)
aws cloudformation delete-stack --stack-name curso-documentdb

# Aguardar conclusão
aws cloudformation wait stack-delete-complete --stack-name curso-documentdb

# Deletar a chave SSH da AWS
aws ec2 delete-key-pair --key-name curso-documentdb-key

# Deletar arquivo local da chave
rm curso-documentdb-key.pem

# Deletar template gerado
rm setup-curso-documentdb-dynamic.yaml
```

## 💰 Custos Estimados

Para 10 alunos durante 8 horas:

- **EC2** (10x t3.micro): ~$0.80
- **DocumentDB** (1x db.t3.medium): ~$1.60
- **S3**: < $0.01
- **Data Transfer**: < $0.10

**Total estimado**: ~$2.50 por dia de curso

## 📚 Próximos Passos

Após a criação do ambiente:

1. Distribua o arquivo .pem para os alunos
2. Forneça os IPs das instâncias (exibidos no final do script)
3. Instrua os alunos a conectarem via SSH
4. Os alunos podem começar os laboratórios imediatamente

## 🤝 Suporte

Para problemas ou dúvidas:
1. Verifique os logs do CloudFormation
2. Consulte [INSTRUCOES-SSH.md](./INSTRUCOES-SSH.md)
3. Revise os eventos da stack no console AWS
