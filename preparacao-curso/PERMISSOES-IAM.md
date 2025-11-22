# Permissões IAM - Usuários do Curso DocumentDB

Este documento descreve todas as permissões IAM concedidas aos alunos do curso.

## 📋 Resumo das Permissões

Os usuários IAM dos alunos têm permissões para executar todos os laboratórios do curso, seguindo o princípio do menor privilégio necessário.

## 🔐 Políticas IAM Detalhadas

### 1. DocumentDB - Acesso Completo
```yaml
Action: 'docdb:*'
Resource: '*'
```

**Justificativa**: Alunos precisam criar, modificar e deletar clusters DocumentDB durante os laboratórios.

**Módulos que usam**:
- Módulo 1: Exploração do console
- Módulo 2: Provisionamento, backup, failover
- Módulo 3: Configuração de segurança
- Módulo 4: Monitoramento de performance
- Módulo 5: Backup e restore

---

### 2. EC2 - Gerenciamento de Rede e Security Groups

```yaml
Actions:
  - ec2:DescribeVpcs
  - ec2:DescribeSubnets
  - ec2:DescribeSecurityGroups
  - ec2:DescribeAvailabilityZones
  - ec2:DescribeInstances
  - ec2:CreateSecurityGroup
  - ec2:AuthorizeSecurityGroupIngress
  - ec2:AuthorizeSecurityGroupEgress
  - ec2:RevokeSecurityGroupIngress
  - ec2:RevokeSecurityGroupEgress
  - ec2:DeleteSecurityGroup
  - ec2:CreateTags
  - ec2:ModifySecurityGroupRules
Resource: '*'
```

**Justificativa**: Alunos precisam criar e gerenciar Security Groups para controlar acesso ao DocumentDB.

**Módulos que usam**:
- Módulo 2, Exercício 1: Criar Security Groups para clusters
- Módulo 3, Exercício 2: Configurar isolamento de rede

**Limitações**:
- ❌ Não podem criar/modificar instâncias EC2
- ❌ Não podem criar/modificar VPCs ou Subnets
- ✅ Podem apenas gerenciar Security Groups

---

### 3. CloudWatch - Monitoramento e Métricas

```yaml
Actions:
  - cloudwatch:GetMetricStatistics
  - cloudwatch:ListMetrics
  - cloudwatch:GetMetricData
  - cloudwatch:DescribeAlarms
  - cloudwatch:PutMetricAlarm
  - cloudwatch:DeleteAlarms
  - cloudwatch:PutDashboard
  - cloudwatch:GetDashboard
  - cloudwatch:ListDashboards
  - cloudwatch:DeleteDashboards
Resource: '*'
```

**Justificativa**: Monitoramento de performance e criação de alarmes.

**Módulos que usam**:
- Módulo 2, Exercício 4: Criar dashboards e alarmes
- Módulo 4: Análise de performance

---

### 4. CloudWatch Logs - Visualização de Logs

```yaml
Actions:
  - logs:DescribeLogGroups
  - logs:DescribeLogStreams
  - logs:GetLogEvents
  - logs:FilterLogEvents
Resource: '*'
```

**Justificativa**: Análise de logs de auditoria e troubleshooting.

**Módulos que usam**:
- Módulo 3, Exercício 3: Auditoria com CloudTrail
- Módulo 4: Análise de performance

---

### 5. S3 - Armazenamento de Backups

```yaml
Actions:
  - s3:CreateBucket
  - s3:ListBucket
  - s3:GetObject
  - s3:PutObject
  - s3:DeleteObject
  - s3:GetBucketLocation
  - s3:PutBucketVersioning
  - s3:GetBucketVersioning
  - s3:PutLifecycleConfiguration
  - s3:GetLifecycleConfiguration
  - s3:PutBucketPolicy
  - s3:GetBucketPolicy
  - s3:ListAllMyBuckets

Resources:
  - arn:aws:s3:::${AWS::StackName}-*
  - arn:aws:s3:::${AWS::StackName}-*/*
  - arn:aws:s3:::*-docdb-backups-*
  - arn:aws:s3:::*-docdb-backups-*/*
  - arn:aws:s3:::*-lab-*
  - arn:aws:s3:::*-lab-*/*
```

**Justificativa**: Backup de dados do DocumentDB para S3 e gerenciamento de políticas de retenção.

**Módulos que usam**:
- Módulo 5: Backup completo e incremental para S3

**Limitações**:
- ✅ Podem criar buckets com padrões específicos
- ❌ Não podem acessar buckets de outros alunos ou da organização

---

### 6. EventBridge - Automação de Eventos

```yaml
Actions:
  - events:PutRule
  - events:DeleteRule
  - events:PutTargets
  - events:RemoveTargets
  - events:DescribeRule
  - events:ListRules
  - events:ListTargetsByRule
Resource: '*'
```

**Justificativa**: Criar regras para detectar eventos do DocumentDB (failover, backups, etc.).

**Módulos que usam**:
- Módulo 2, Exercício 4: Notificações de failover

---

### 7. Lambda - Funções de Automação

```yaml
Actions:
  - lambda:CreateFunction
  - lambda:DeleteFunction
  - lambda:InvokeFunction
  - lambda:UpdateFunctionCode
  - lambda:UpdateFunctionConfiguration
  - lambda:GetFunction
  - lambda:ListFunctions
Resource: arn:aws:lambda:*:${AWS::AccountId}:function:${AWS::StackName}-*
```

**Justificativa**: Criar funções Lambda para automação básica.

**Módulos que usam**:
- Módulo 2, Exercício 4: Automação de respostas a eventos

**Limitações**:
- ✅ Apenas funções com prefixo da stack do curso
- ❌ Não podem criar roles IAM para Lambda (devem usar roles pré-criados)

---

### 8. SNS - Notificações e Alertas

```yaml
Actions:
  - sns:CreateTopic
  - sns:DeleteTopic
  - sns:Subscribe
  - sns:Unsubscribe
  - sns:ListTopics
  - sns:ListSubscriptions
  - sns:SetTopicAttributes
  - sns:GetTopicAttributes
  - sns:Publish
Resource: '*'
```

**Justificativa**: Criar tópicos SNS para receber notificações de alarmes e eventos.

**Módulos que usam**:
- Módulo 2, Exercício 4: Configurar notificações de alarmes

---

### 9. RDS - Comandos Alias do DocumentDB

```yaml
Actions:
  - rds:DescribeDBClusters
  - rds:DescribeDBInstances
  - rds:DescribeDBClusterSnapshots
  - rds:DescribeDBSnapshots
  - rds:ListTagsForResource
Resource: '*'
```

**Justificativa**: Alguns comandos AWS CLI usam o namespace `rds` para DocumentDB.

**Módulos que usam**:
- Todos os módulos (comandos CLI alternativos)

---

### 10. KMS - Visualização de Chaves

```yaml
Actions:
  - kms:Describe*
  - kms:List*
Resource: '*'
```

**Justificativa**: Visualizar chaves de criptografia usadas pelo DocumentDB.

**Módulos que usam**:
- Módulo 3: Segurança e compliance

**Limitações**:
- ✅ Apenas leitura
- ❌ Não podem criar ou modificar chaves

---

### 11. STS - Identificação do Usuário

```yaml
Action: sts:GetCallerIdentity
Resource: '*'
```

**Justificativa**: Verificar identidade e credenciais AWS.

**Módulos que usam**:
- Todos os módulos (verificação de configuração)

---

## 🚫 Permissões NÃO Concedidas

Por segurança e controle de custos, os alunos **NÃO** têm permissão para:

- ❌ Criar/modificar instâncias EC2
- ❌ Criar/modificar VPCs, Subnets, Internet Gateways
- ❌ Criar/modificar usuários ou roles IAM
- ❌ Acessar recursos de outros alunos
- ❌ Criar recursos fora dos padrões de nomenclatura permitidos
- ❌ Modificar configurações de billing
- ❌ Acessar serviços não relacionados ao curso

---

## 📊 Matriz de Permissões por Módulo

| Serviço | Módulo 1 | Módulo 2 | Módulo 3 | Módulo 4 | Módulo 5 |
|---------|----------|----------|----------|----------|----------|
| DocumentDB | ✅ | ✅ | ✅ | ✅ | ✅ |
| EC2 (SG) | ✅ | ✅ | ✅ | - | - |
| CloudWatch | - | ✅ | - | ✅ | - |
| CloudWatch Logs | - | - | ✅ | - | - |
| S3 | - | - | - | - | ✅ |
| EventBridge | - | ✅ | - | - | - |
| Lambda | - | ✅ | - | - | - |
| SNS | - | ✅ | - | - | - |
| RDS | ✅ | ✅ | ✅ | ✅ | ✅ |
| KMS | - | - | ✅ | - | - |
| STS | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## 🔒 Princípios de Segurança Aplicados

1. **Menor Privilégio**: Apenas permissões necessárias para os laboratórios
2. **Isolamento**: Alunos não podem acessar recursos de outros alunos
3. **Auditoria**: Todas as ações são registradas no CloudTrail
4. **Limitação de Escopo**: Recursos limitados por padrões de nomenclatura
5. **Sem Acesso Administrativo**: Nenhuma permissão de administração da conta

---

## 📝 Notas para Instrutores

### Adicionar Novas Permissões

Se um novo exercício requer permissões adicionais:

1. Edite `preparacao-curso/setup-curso-documentdb-simple.yaml`
2. Edite `preparacao-curso/gerar-template.sh`
3. Atualize este documento
4. Teste com um usuário de aluno antes de aplicar em produção

### Remover Permissões

Se uma permissão não é mais necessária:

1. Verifique todos os módulos para garantir que não é usada
2. Remova dos templates
3. Atualize este documento
4. Comunique aos alunos se já estiverem usando o ambiente

---

## 🆘 Troubleshooting de Permissões

### Erro: "Access Denied" ao criar Security Group

**Causa**: Aluno tentando criar SG sem as tags corretas ou em VPC não permitida

**Solução**: Verificar se está usando a VPC correta e seguindo padrões de nomenclatura

### Erro: "Access Denied" ao criar bucket S3

**Causa**: Nome do bucket não segue os padrões permitidos

**Solução**: Usar padrões: `<student-id>-docdb-backups-*` ou `<student-id>-lab-*`

### Erro: "Access Denied" ao criar tópico SNS

**Causa**: Permissão SNS pode não estar aplicada (versão antiga do template)

**Solução**: Atualizar a stack com o template mais recente

---

**Última atualização**: 2024-11-22
**Versão do template**: 2.0
