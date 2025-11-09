# Módulo 1 - Visão Geral do AWS DocumentDB

Laboratório introdutório para o Módulo 1 do curso de DocumentDB (4h), focado em conceitos fundamentais, navegação no console e primeiros passos com CLI e SDKs.

## 📋 Objetivos do Laboratório

- Compreender o que é o DocumentDB e como se posiciona no mercado
- Explorar a arquitetura gerenciada e suas vantagens
- Identificar compatibilidades e limitações básicas em relação ao MongoDB
- Navegar no Console AWS DocumentDB
- Conhecer AWS CLI e SDKs para DocumentDB (sem criar recursos)

## 🏗️ Estrutura do Laboratório

```
modulo1-lab/
├── README.md
├── exercicio1-introducao-conceitos/
│   ├── README.md
│   └── documentos/
│       ├── o-que-e-documentdb.md
│       ├── comparativo-mongodb.md
│       └── casos-de-uso.md
├── exercicio2-console-aws/
│   ├── README.md
│   └── guias/
│       ├── navegacao-console.md
│       └── interface-overview.md
└── exercicio3-cli-sdks/
    ├── README.md
    ├── aws-cli/
    │   └── comandos-basicos.md
    ├── boto3/
    │   └── exemplos-basicos.py
    └── nodejs/
        └── exemplos-basicos.js
```

## 🚀 Pré-requisitos

- Conta AWS ativa (Free Tier suficiente para este módulo)
- AWS CLI instalado e configurado
- Node.js instalado (versão >= 14)
- Python 3.8+ instalado
- Conhecimento básico de bancos de dados NoSQL
- Familiaridade com conceitos de cloud computing

## 📚 Exercícios

### Exercício 1: Introdução e Conceitos Fundamentais
**Duração estimada:** 90 minutos

Compreenda os conceitos essenciais do DocumentDB:
- O que é o DocumentDB e como se posiciona
- Arquitetura gerenciada e suas vantagens
- Compatibilidade e limitações vs. MongoDB
- Casos de uso típicos e quando usar

[📖 Ir para Exercício 1](./exercicio1-introducao-conceitos/README.md)

---

### Exercício 2: Console AWS - Navegação e Interface
**Duração estimada:** 90 minutos

Explore a interface do DocumentDB no Console AWS:
- Navegação no console DocumentDB
- Visão geral da interface e opções disponíveis
- Compreensão das configurações (sem criar recursos)
- Familiarização com a terminologia

[📖 Ir para Exercício 2](./exercicio2-console-aws/README.md)

---

### Exercício 3: CLI e SDKs - Conhecendo as Ferramentas
**Duração estimada:** 90 minutos

Conheça as ferramentas de linha de comando e SDKs:
- AWS CLI: comandos de consulta (describe, list)
- Boto3 (Python): estrutura e exemplos teóricos
- AWS SDK Node.js: conceitos e padrões
- Comparação entre as ferramentas

[📖 Ir para Exercício 3](./exercicio3-cli-sdks/README.md)

---

## 🎯 Roteiro de Estudo Recomendado

1. **Sessão 1 (1.5h):** Exercício 1 - Conceitos fundamentais
2. **Sessão 2 (1.5h):** Exercício 2 - Console AWS
3. **Sessão 3 (1h):** Exercício 3 - CLI e SDKs

## 🧠 Conceitos Fundamentais Abordados

Este laboratório cobre os seguintes conceitos essenciais:

- **Arquitetura Serverless:** Separação de compute e storage
- **Compatibilidade MongoDB:** API 3.6 e 4.0 suportadas
- **Gerenciamento Automático:** Backup, patching, scaling
- **Integração AWS:** VPC, CloudWatch, EventBridge
- **Limitações Conhecidas:** Transações, sharding, algumas operações

## 💰 Custos do Laboratório

⚠️ **IMPORTANTE:** Este laboratório foi projetado para o AWS Free Tier:

- Instâncias db.t3.medium: Incluídas no Free Tier por 12 meses
- Armazenamento: Primeiros 30GB gratuitos
- Backup: Backup automático incluído
- Transferência de dados: Dentro dos limites gratuitos

**Custo estimado:** $0 USD (apenas navegação, sem criação de recursos)

## 📊 Comparativo DocumentDB vs MongoDB

### Vantagens do DocumentDB:
- ✅ **Gerenciamento Automático:** Backup, patching, scaling
- ✅ **Integração AWS:** Nativa com todos os serviços
- ✅ **Segurança:** Encryption at rest/transit por padrão
- ✅ **Performance:** Separação compute/storage otimizada
- ✅ **Disponibilidade:** Multi-AZ automático

### Limitações vs MongoDB:
- ❌ **Transações:** Suporte limitado
- ❌ **Sharding:** Não suportado nativamente
- ❌ **Algumas Operações:** GridFS, algumas aggregations
- ❌ **Versão:** Baseado em MongoDB 3.6/4.0
- ❌ **Flexibilidade:** Menos controle sobre configuração

## 🔧 Ferramentas Utilizadas

### Console AWS
- Interface gráfica intuitiva
- Monitoramento integrado
- Configuração visual
- Logs e métricas

### AWS CLI
- Automação de tarefas
- Scripts de deployment
- Operações em lote
- Integração CI/CD

### SDKs
- **Boto3 (Python):** Automação e scripts
- **AWS SDK (Node.js):** Aplicações web
- **MongoDB Drivers:** Compatibilidade de aplicações

## 🧹 Limpeza de Recursos

Ao final do laboratório, remova recursos para evitar custos:

```bash
# Deletar clusters de teste
aws docdb delete-db-cluster --db-cluster-identifier test-cluster --skip-final-snapshot

# Deletar instâncias
aws docdb delete-db-instance --db-instance-identifier test-instance --skip-final-snapshot

# Limpar security groups customizados
aws ec2 delete-security-group --group-id sg-xxxxxxxxx
```

## 📖 Recursos Adicionais

- [Documentação Oficial AWS DocumentDB](https://docs.aws.amazon.com/documentdb/)
- [Guia de Migração MongoDB para DocumentDB](https://docs.aws.amazon.com/documentdb/latest/developerguide/docdb-migration.html)
- [Best Practices DocumentDB](https://docs.aws.amazon.com/documentdb/latest/developerguide/best-practices.html)
- [Comparação MongoDB vs DocumentDB](https://docs.aws.amazon.com/documentdb/latest/developerguide/functional-differences.html)

## 🆘 Troubleshooting

### Problemas Comuns Iniciantes

1. **Erro de Conexão**
   - Verificar security groups
   - Confirmar VPC e subnets
   - Validar credenciais

2. **Compatibilidade de Código**
   - Verificar versão do driver MongoDB
   - Adaptar operações não suportadas
   - Usar connection string correta

3. **Performance Inesperada**
   - Verificar índices
   - Analisar queries
   - Considerar read replicas

## 🎯 Objetivos de Aprendizado

Ao final do laboratório, você deve conseguir:

- ✅ Explicar o posicionamento do DocumentDB no mercado
- ✅ Identificar casos de uso apropriados
- ✅ Navegar no console AWS com confiança
- ✅ Usar AWS CLI para operações básicas
- ✅ Implementar aplicações compatíveis
- ✅ Reconhecer limitações e workarounds

## 📝 Notas Importantes

- DocumentDB é compatível com MongoDB API 3.6 e 4.0
- Nem todas as features do MongoDB são suportadas
- Foco em casos de uso que se beneficiam da integração AWS
- Sempre considere limitações ao migrar aplicações existentes
- Use este módulo como base para módulos avançados

## 🔄 Preparação para Próximos Módulos

Este módulo prepara você para:

- **Módulo 2:** Administração e gerenciamento avançado
- **Módulo 3:** Segurança e compliance
- **Módulo 4:** Performance e tuning
- **Módulo 5:** Replicação e alta disponibilidade

---

**Bem-vindo ao mundo do AWS DocumentDB! 🚀**