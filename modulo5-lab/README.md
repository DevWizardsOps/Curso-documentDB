# Módulo 5 - Backup e Exportação de Dados

Laboratório prático para o Módulo 5 do curso de DocumentDB (2h), focado em estratégias de backup de longo prazo, exportação automatizada para S3 e integração com ferramentas de analytics.

## 📋 Objetivos do Laboratório

- Configurar exportação automatizada de dados do DocumentDB para S3
- Implementar estratégias de backup de longo prazo e compliance
- Integrar dados exportados com AWS Glue e ferramentas de analytics
- Configurar monitoramento e alertas para processos de backup

## 🏗️ Estrutura do Laboratório

```
modulo5-lab/
├── README.md
└── exercicio-backup-s3/
    ├── README.md
    └── scripts/
        ├── backup-monitor.sh
        └── backup-audit.sh
```

## 🚀 Pré-requisitos

- Conta AWS ativa com permissões para múltiplas regiões
- AWS CLI configurado
- Cluster DocumentDB já provisionado (dos módulos anteriores)
- Terraform instalado (versão >= 1.0)
- Node.js instalado (versão >= 14)
- Python 3.8+ (para funções Lambda)
- Conhecimento dos módulos anteriores (especialmente Módulo 2)

## 📚 Exercício

### Exercício: Backup de Dados para S3
**Duração estimada:** 75 minutos

Implemente estratégias completas de backup do DocumentDB:
- Backup completo e incremental para S3
- Políticas de retenção e compliance
- Procedimentos de restore e validação
- Monitoramento e auditoria de backups

[📖 Ir para o Exercício](./exercicio-backup-s3/README.md)

---

## 🎯 Roteiro de Estudo Recomendado

**Sessão Única (1.5h):** Exercício de Backup para S3
- Configuração de ambiente e bucket S3
- Implementação de diferentes tipos de backup
- Testes de restore e validação de integridade

## 🏗️ Conceitos de Alta Disponibilidade Aplicados

Este laboratório implementa conceitos avançados de HA:

- **Multi-AZ Deployment:** Distribuição geográfica de réplicas
- **Cross-Region Backup:** Proteção contra falhas regionais
- **Automated Recovery:** Redução de RTO através de automação
- **Data Archival:** Estratégias de backup de longo prazo
- **Disaster Recovery:** Planos estruturados de recuperação

## 💰 Atenção aos Custos

⚠️ **IMPORTANTE:** Este laboratório pode gerar custos significativos:

- Read Replicas em múltiplas AZs: ~$0.20-1.00 por hora
- Transferência de dados cross-region: ~$0.02 por GB
- Armazenamento S3: ~$0.023 por GB/mês
- Funções Lambda: ~$0.20 por 1M execuções
- Snapshots cross-region: ~$0.095 por GB/mês

**Custo estimado:** ~$20-50 USD para completar todo o laboratório

## 📊 Métricas de Alta Disponibilidade

### RTO (Recovery Time Objective)
- **Failover Automático:** < 2 minutos
- **Recuperação Manual:** < 15 minutos
- **Disaster Recovery:** < 4 horas

### RPO (Recovery Point Objective)
- **Backup Contínuo:** < 5 minutos
- **Snapshots:** < 1 hora
- **Export S3:** < 24 horas

### Disponibilidade
- **Single-AZ:** 99.9% (8.76h downtime/ano)
- **Multi-AZ:** 99.95% (4.38h downtime/ano)
- **Multi-Region:** 99.99% (52.6min downtime/ano)

## 🧹 Limpeza de Recursos

Ao final do laboratório, remova recursos para evitar custos:

```bash
# Deletar read replicas em outras regiões
aws docdb delete-db-instance --db-instance-identifier <replica-id> --region us-west-2

# Remover snapshots cross-region
aws docdb delete-db-cluster-snapshot --db-cluster-snapshot-identifier <snapshot-id> --region us-west-2

# Deletar buckets S3 e objetos
aws s3 rm s3://<bucket-name> --recursive
aws s3 rb s3://<bucket-name>

# Remover funções Lambda
aws lambda delete-function --function-name <function-name>

# Limpar recursos Terraform
terraform destroy -auto-approve
```

## 📖 Recursos Adicionais

- [DocumentDB High Availability](https://docs.aws.amazon.com/documentdb/latest/developerguide/high-availability.html)
- [AWS Disaster Recovery Strategies](https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-options-in-the-cloud.html)
- [Cross-Region Backup Best Practices](https://docs.aws.amazon.com/documentdb/latest/developerguide/backup_restore-backup.html)
- [S3 Data Export Patterns](https://docs.aws.amazon.com/s3/latest/userguide/optimizing-performance.html)

## 🆘 Troubleshooting

### Problemas Comuns de Replicação

1. **Replication Lag Alto**
   - Verifique network latency entre AZs
   - Analise workload de escrita
   - Considere otimizar queries

2. **Falha na Exportação S3**
   - Verifique permissões IAM
   - Confirme configuração de VPC endpoints
   - Analise logs do Lambda

3. **Cross-Region Sync Issues**
   - Verifique conectividade entre regiões
   - Confirme configurações de security groups
   - Analise custos de transferência de dados

4. **RTO/RPO não atendidos**
   - Revise estratégia de backup
   - Otimize processo de failover
   - Considere arquitetura multi-região

## 🎯 Objetivos de Alta Disponibilidade

Ao final do laboratório, você deve conseguir:

- ✅ Configurar replicação otimizada em múltiplas AZs
- ✅ Implementar RTO < 2 minutos e RPO < 5 minutos
- ✅ Automatizar exportação de dados para S3
- ✅ Projetar arquiteturas multi-região resilientes
- ✅ Executar disaster recovery procedures
- ✅ Monitorar e otimizar métricas de disponibilidade

## 📝 Notas de Alta Disponibilidade

- DocumentDB não suporta replicação cross-region nativa
- Use snapshots cross-region para disaster recovery
- Implemente monitoramento proativo de health
- Teste procedures de recovery regularmente
- Documente runbooks de incident response

## 🔄 Diferenças do Módulo 2

Este módulo **complementa** o Módulo 2 com foco em:

- **Replicação Avançada** (vs. básica do Módulo 2)
- **Cross-Region Strategies** (não coberto anteriormente)
- **S3 Export Automation** (vs. snapshots manuais)
- **RTO/RPO Optimization** (vs. conceitos básicos)
- **Enterprise-grade HA** (vs. configuração inicial)

---

**Alta disponibilidade é uma jornada contínua! 🚀**