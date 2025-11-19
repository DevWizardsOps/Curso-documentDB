# Módulo 5 - Backup e Exportação de Dados

Laboratório prático para o Módulo 5 do curso de DocumentDB (1.5h), focado em estratégias básicas de backup para S3 usando ferramentas nativas do MongoDB.

## 📋 Objetivos do Laboratório

- Implementar backup completo e incremental do DocumentDB para S3
- Configurar políticas de retenção no S3 para compliance básico
- Testar procedimentos de restore e validação de integridade
- Estabelecer rotinas manuais de backup operacional

## 🏗️ Estrutura do Laboratório

```
modulo5-lab/
├── README.md
└── exercicio-backup-s3/
    ├── README.md
    └── grade_exercicio_backup.sh
```

## 🚀 Pré-requisitos

- Conta AWS ativa com permissões para S3 e DocumentDB
- AWS CLI configurado
- Cluster DocumentDB já provisionado (dos módulos anteriores)
- MongoDB Database Tools instalados (mongoexport/mongoimport)
- Conhecimento básico de comandos MongoDB

## 📚 Exercício

### Exercício: Backup de Dados para S3
**Duração estimada:** 75 minutos

Implemente estratégias básicas de backup do DocumentDB:
- Backup completo usando mongoexport
- Backup incremental com filtros de data
- Políticas de retenção no S3
- Procedimentos de restore usando mongoimport
- Validação de integridade dos dados restaurados

[📖 Ir para o Exercício](./exercicio-backup-s3/README.md)

---

## 🎯 Roteiro de Estudo Recomendado

**Sessão Única (1.5h):** Exercício de Backup para S3
- Configuração de ambiente e bucket S3
- Implementação de backup completo e incremental
- Testes de restore e validação de integridade
- Configuração de políticas de retenção

## 🏗️ Conceitos de Backup Aplicados

Este laboratório implementa conceitos básicos de backup:

- **Backup Completo:** Export completo de collections usando mongoexport
- **Backup Incremental:** Export de dados modificados recentemente
- **Armazenamento S3:** Uso de lifecycle policies para otimização de custos
- **Restore Manual:** Procedimentos de restore usando mongoimport
- **Validação de Integridade:** Verificação de consistência dos dados

## 💰 Atenção aos Custos

⚠️ **IMPORTANTE:** Este laboratório gera custos mínimos:

- Armazenamento S3: ~$0.023 por GB/mês (dados de teste são pequenos)
- Requests S3: ~$0.0004 por 1.000 requests
- Transferência de dados: Mínima para dados de teste

**Custo estimado:** ~$1-3 USD para completar todo o laboratório

## 📊 Métricas de Backup

### Tipos de Backup Implementados
- **Backup Completo:** Export de todas as collections
- **Backup Incremental:** Export de dados modificados nas últimas 24h
- **Compressão:** Arquivos tar.gz para otimização de espaço

### Políticas de Retenção S3
- **Standard:** Primeiros 30 dias
- **Standard-IA:** 30-90 dias
- **Glacier:** 90 dias - 7 anos
- **Deep Archive:** 7+ anos
- **Expiração:** 8 anos (2920 dias)

## 🧹 Limpeza de Recursos

Ao final do laboratório, remova recursos para evitar custos:

```bash
# Deletar bucket S3 e objetos (se desejar)
aws s3 rm s3://<seu-id>-docdb-backups-<data> --recursive
aws s3 rb s3://<seu-id>-docdb-backups-<data>

# Limpar arquivos temporários locais
rm -rf ~/docdb-backup/*
rm -rf ~/restore/*

# Remover database de teste (opcional)
# mongosh --host <cluster-endpoint> --username docdbadmin --password Lab12345! --tls --tlsCAFile global-bundle.pem
# use backupTestDB
# db.dropDatabase()
```

## 📖 Recursos Adicionais

- [DocumentDB Backup and Restore](https://docs.aws.amazon.com/documentdb/latest/developerguide/backup_restore.html)
- [MongoDB Database Tools](https://docs.mongodb.com/database-tools/)
- [S3 Lifecycle Management](https://docs.aws.amazon.com/s3/latest/userguide/object-lifecycle-mgmt.html)
- [mongoexport Documentation](https://docs.mongodb.com/database-tools/mongoexport/)
- [mongoimport Documentation](https://docs.mongodb.com/database-tools/mongoimport/)

## 🆘 Troubleshooting

### Problemas Comuns de Backup

1. **Erro de Conexão SSL**
   - Verifique se o certificado global-bundle.pem foi baixado
   - Confirme que está usando --tls e --tlsCAFile

2. **Falha no mongoexport/mongoimport**
   - Verifique se MongoDB Database Tools estão instalados
   - Confirme credenciais e endpoint do cluster
   - Teste conectividade com mongosh primeiro

3. **Erro de Permissões S3**
   - Verifique permissões IAM para S3
   - Confirme que o bucket foi criado na região correta
   - Teste com aws s3 ls

4. **Backup Incremental Vazio**
   - Verifique se há dados novos no período especificado
   - Confirme formato da query de data
   - Ajuste o filtro de tempo conforme necessário

## 🎯 Objetivos de Backup

Ao final do laboratório, você deve conseguir:

- ✅ Executar backup completo de collections do DocumentDB
- ✅ Implementar backup incremental com filtros de data
- ✅ Configurar políticas de retenção no S3
- ✅ Restaurar dados usando mongoimport
- ✅ Validar integridade dos dados restaurados
- ✅ Estabelecer rotinas operacionais de backup

## 📝 Notas de Backup

- Use mongoexport/mongoimport para backups manuais
- Snapshots automáticos do DocumentDB são complementares
- Teste procedimentos de restore regularmente
- Configure lifecycle policies no S3 para otimizar custos
- Documente procedimentos de backup e restore

## 🔄 Diferenças do Módulo 2

Este módulo **complementa** o Módulo 2 com foco em:

- **Backup Manual** (vs. snapshots automáticos do Módulo 2)
- **Export para S3** (vs. snapshots internos)
- **Backup Incremental** (não coberto anteriormente)
- **Restore Seletivo** (vs. restore completo de snapshots)
- **Políticas de Retenção** (vs. configuração básica)

---

**Backup é proteção essencial para seus dados! 💾**