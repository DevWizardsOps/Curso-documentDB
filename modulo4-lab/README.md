# Módulo 4 - Performance e Tuning do DocumentDB

Laboratório prático para o Módulo 4 do curso de DocumentDB (3h), focado em monitoramento avançado de performance e otimização de queries através de análise de planos de execução.

## 📋 Objetivos do Laboratório

- Implementar monitoramento avançado de performance com métricas customizadas
- Analisar planos de execução e otimizar índices suportados pelo DocumentDB
- Identificar gargalos de performance através de análise detalhada
- Aplicar estratégias de indexação para diferentes tipos de queries

## 🏗️ Estrutura do Laboratório

```
modulo4-lab/
├── README.md
├── exercicio1-metricas-avancadas/
│   ├── README.md
│   ├── cloudwatch/
│   │   ├── custom-metrics.json
│   │   └── performance-dashboard.json
│   └── scripts/
│       ├── collect-metrics.sh
│       └── analyze-performance.js
└── exercicio2-planos-execucao/
    ├── README.md
    ├── queries/
    │   ├── sample-queries.js
    │   └── index-strategies.js
    └── scripts/
        ├── explain-analyzer.js
        └── index-optimizer.sh
```

## 🚀 Pré-requisitos

- Conta AWS ativa
- AWS CLI configurado
- Cluster DocumentDB já provisionado (do Módulo 2)
- MongoDB Shell (mongosh) instalado
- Node.js instalado (versão >= 14)
- Terraform instalado (versão >= 1.0)
- Conhecimento dos módulos anteriores
- Ferramentas de monitoramento configuradas (Módulo 2)

## 📚 Exercícios

### Exercício 1: Métricas Avançadas e Monitoramento de Performance
**Duração estimada:** 75 minutos

Configure monitoramento avançado focado em performance:
- Métricas customizadas de performance
- Dashboard especializado em tuning
- Alertas proativos de degradação
- Análise de tendências de performance

[📖 Ir para Exercício 1](./exercicio1-metricas-avancadas/README.md)

---

### Exercício 2: Análise de Planos de Execução e Otimização de Índices
**Duração estimada:** 90 minutos

Domine a análise e otimização de queries:
- Uso do comando explain() para análise de planos
- Identificação de gargalos em queries
- Estratégias de indexação suportadas pelo DocumentDB
- Otimização de índices compostos e parciais

[📖 Ir para Exercício 2](./exercicio2-planos-execucao/README.md)

---

## 🎯 Roteiro de Estudo Recomendado

1. **Sessão 1 (1.5h):** Exercício 1 (métricas avançadas)
2. **Sessão 2 (1.5h):** Exercício 2 (planos de execução e índices)

## 🚀 Conceitos de Performance Aplicados

Este laboratório implementa os seguintes conceitos de otimização:

- **Monitoramento Proativo:** Identificação precoce de degradação através de métricas customizadas
- **Indexação Estratégica:** Índices otimizados para queries específicas do DocumentDB
- **Análise de Planos:** Uso do explain() para identificar gargalos de performance
- **Otimização de Queries:** Técnicas para melhorar eficiência de consultas

## 💰 Atenção aos Custos

⚠️ **IMPORTANTE:** Este laboratório pode gerar custos mínimos adicionais:

- CloudWatch métricas customizadas: ~$0.30 por métrica por mês
- Uso adicional do cluster existente para testes

**Custo estimado:** ~$2-5 USD para completar todo o laboratório

## 📊 Métricas de Performance Essenciais

### Métricas de Latência
- ReadLatency / WriteLatency
- DatabaseConnections
- ConnectionsCreated

### Métricas de Throughput
- ReadThroughput / WriteThroughput
- NetworkReceiveThroughput / NetworkTransmitThroughput
- VolumeReadIOPs / VolumeWriteIOPs

### Métricas de Recursos
- CPUUtilization
- FreeableMemory
- SwapUsage

### Métricas Customizadas
- Query execution time
- Index hit ratio
- Connection pool efficiency

## 🧹 Limpeza de Recursos

Ao final do laboratório, remova recursos para evitar custos:

```bash
# Deletar dashboards customizados
aws cloudwatch delete-dashboards --dashboard-names <performance-dashboard>

# Limpar dados de teste criados no DocumentDB
# (será feito dentro de cada exercício)
```

## 📖 Recursos Adicionais

- [DocumentDB Performance Best Practices](https://docs.aws.amazon.com/documentdb/latest/developerguide/performance-best-practices.html)
- [MongoDB Performance Tuning Guide](https://docs.mongodb.com/manual/administration/analyzing-mongodb-performance/)
- [AWS DocumentDB Monitoring](https://docs.aws.amazon.com/documentdb/latest/developerguide/monitoring.html)
- [Connection Pooling Best Practices](https://docs.mongodb.com/manual/administration/connection-pool-overview/)

## 🆘 Troubleshooting

### Problemas Comuns de Performance

1. **Queries lentas**
   - Verifique se há índices apropriados
   - Analise planos de execução com explain()
   - Considere otimização de queries

2. **CPU alta no cluster**
   - Analise queries mais custosas
   - Verifique se há operações de scan completo (COLLSCAN)
   - Otimize índices para queries frequentes

3. **Métricas não aparecem no CloudWatch**
   - Verifique permissões IAM
   - Confirme execução dos scripts de coleta
   - Aguarde tempo de propagação (2-5 minutos)

## 🎯 Objetivos de Performance

Ao final do laboratório, você deve conseguir:

- ✅ Implementar monitoramento customizado de performance
- ✅ Identificar gargalos através de métricas avançadas
- ✅ Analisar planos de execução com explain()
- ✅ Otimizar queries através de estratégias de indexação
- ✅ Criar dashboards especializados em performance
- ✅ Aplicar técnicas de tuning específicas do DocumentDB

## 📝 Notas de Performance

- Sempre teste mudanças em ambiente de desenvolvimento primeiro
- Monitore métricas antes e depois de otimizações
- Documente configurações que funcionam bem
- Implemente mudanças incrementalmente
- Use ferramentas de profiling para identificar gargalos

---

**Performance é uma jornada, não um destino! 🚀**