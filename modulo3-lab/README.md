# Módulo 3 - Segurança e Compliance do DocumentDB

Laboratório prático para o Módulo 3 do curso de DocumentDB (6h), focado em autenticação, controle de acesso, integração de rede, auditoria e compliance de segurança.

## 📋 Objetivos do Laboratório

- Implementar autenticação nativa de banco de dados
- Configurar integração segura com VPC, subnets e security groups
- Estabelecer controle de acesso com TLS e roles de privilégios mínimos
- Habilitar auditoria completa com CloudTrail e CloudWatch Logs

## 🏗️ Estrutura do Laboratório

```
modulo3-lab/
├── README.md
├── exercicio1-autenticacao-nativa/
│   ├── README.md
│   └── scripts/
│       ├── create_user.sh
│       └── test_connection.sh
├── exercicio2-integracao-rede/
│   ├── README.md
│   └── json/
│       ├── inbound-rule.json
│       └── security-group.json
└── exercicio3-auditoria-cloudtrail/
    ├── README.md
    └── scripts/
        ├── enable-audit.sh
        └── create_data_event_trail.sh
```

## 🚀 Pré-requisitos

- Conta AWS ativa
- AWS CLI configurado
- Cluster DocumentDB já provisionado (do Módulo 2)
- MongoDB Shell (mongosh) instalado
- Acesso à console AWS
- Conhecimento básico de segurança AWS e MongoDB

## 📚 Exercícios

### Exercício 1: Autenticação Nativa de Banco de Dados
**Duração estimada:** 45 minutos

Aprenda a implementar autenticação segura:
- Criação de usuários nativos do DocumentDB
- Configuração de roles e permissões
- Teste de conexões autenticadas

[📖 Ir para Exercício 1](./exercicio1-autenticacao-nativa/README.md)

---

### Exercício 2: Integração com VPC, Subnets e Security Groups
**Duração estimada:** 60 minutos

Configure proteção de rede:
- Configuração de subnet groups privadas
- Criação e associação de security groups
- Regras de firewall para acesso controlado

[📖 Ir para Exercício 2](./exercicio2-integracao-rede/README.md)

---

### Exercício 3: Auditoria com CloudTrail e CloudWatch
**Duração estimada:** 60 minutos

Configure auditoria completa:
- Habilitação de logs de auditoria
- Exportação para CloudWatch Logs
- Criação de trails para eventos de dados

[📖 Ir para Exercício 3](./exercicio3-auditoria-cloudtrail/README.md)

---

## 🎯 Roteiro de Estudo Recomendado

1. **Dia 1 (2h):** Exercícios 1 e 2
2. **Dia 2 (2h):** Exercício 3

## 🔒 Princípios de Segurança Aplicados

Este laboratório implementa os seguintes princípios de segurança:

- **Defesa em Profundidade:** Múltiplas camadas de proteção
- **Princípio do Menor Privilégio:** Acesso mínimo necessário
- **Auditoria Contínua:** Rastreamento de todas as atividades
- **Criptografia em Trânsito:** TLS obrigatório para conexões

## 💰 Atenção aos Custos

⚠️ **IMPORTANTE:** Este laboratório utiliza recursos AWS que geram custos mínimos:

- CloudTrail: ~$2.00 por 100.000 eventos
- CloudWatch Logs: ~$0.50 por GB ingerido
- VPC Endpoints (se utilizados): ~$0.01 por hora

**Custo estimado:** ~$1-3 USD para completar todo o laboratório

## 🧹 Limpeza de Recursos

Ao final do laboratório, remova recursos desnecessários:

```bash
# Desabilitar logs de auditoria
aws docdb modify-db-cluster-parameter-group \
  --db-cluster-parameter-group-name <parameter-group-name> \
  --parameters "ParameterName=audit_logs,ParameterValue=disabled,ApplyMethod=pending-reboot"

# Remover exportação de logs
aws docdb modify-db-cluster \
  --db-cluster-identifier <cluster-id> \
  --cloudwatch-logs-export-configuration '{"DisableLogTypes":["audit"]}'

# Deletar trails do CloudTrail (se criados)
aws cloudtrail delete-trail --name <trail-name>
```

## 📖 Recursos Adicionais

- [Documentação de Segurança AWS DocumentDB](https://docs.aws.amazon.com/documentdb/latest/developerguide/security.html)
- [Guia de Melhores Práticas de Segurança](https://docs.aws.amazon.com/documentdb/latest/developerguide/security-best-practices.html)
- [AWS Well-Architected Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [MongoDB Security Checklist](https://docs.mongodb.com/manual/administration/security-checklist/)

## 🆘 Troubleshooting

### Problemas Comuns

1. **Erro de conexão após configurar TLS**
   - Verifique se o certificado CA está instalado
   - Confirme que a string de conexão inclui `ssl=true`

2. **Security Group bloqueando conexões**
   - Valide regras de entrada no security group
   - Verifique se a porta 27017 está liberada para a origem correta

3. **Logs de auditoria não aparecem**
   - Confirme que o parameter group foi modificado
   - Verifique se o cluster foi reiniciado após a alteração

4. **Usuário não consegue se conectar**
   - Confirme que o usuário foi criado no banco correto
   - Verifique se as roles foram atribuídas adequadamente

## 🔐 Checklist de Segurança

Ao final do laboratório, seu cluster deve ter:

- ✅ Usuários nativos configurados (não apenas usuário mestre)
- ✅ Security groups com regras restritivas
- ✅ TLS/SSL obrigatório para todas as conexões
- ✅ Logs de auditoria habilitados e exportados
- ✅ Roles com privilégios mínimos implementadas
- ✅ Cluster em subnets privadas
- ✅ CloudTrail configurado para eventos de dados

## 📝 Notas de Segurança

- Nunca use o usuário mestre para aplicações em produção
- Sempre force TLS em ambientes de produção
- Monitore logs de auditoria regularmente
- Implemente rotação de senhas periódica
- Use AWS Secrets Manager para gerenciar credenciais

---

**Segurança em primeiro lugar! 🔒**
