# Módulo 4 - Performance e Tuning do DocumentDB

Laboratório prático para o Módulo 4 do curso de DocumentDB (6h), focado em otimização de performance, análise de planos de execução, estratégias para workloads e ajustes avançados de cluster.

## 📋 Objetivos do Laboratório

- Implementar monitoramento avançado de performance com métricas essenciais
- Analisar planos de execução e otimizar índices suportados
- Desenvolver estratégias específicas para workloads de leitura e escrita
- Configurar e otimizar conexões, pools e latência
- Realizar ajustes avançados de cluster e parâmetros suportados

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
├── exercicio2-planos-execucao/
│   ├── README.md
│   ├── queries/
│   │   ├── sample-queries.js
│   │   └── index-strategies.js
│   └── scripts/
│       ├── explain-analyzer.js
│       └── index-optimizer.sh
├── exercicio3-workload-optimization/
│   ├── README.md
│   ├── read-workloads/
│   │   ├── read-replicas-config.js
│   │   └── caching-strategies.js
│   ├── write-workloads/
│   │   ├── bulk-operations.js
│   │   └── write-optimization.js
│   └── scripts/
│       ├── workload-simulator.js
│       └── performance-test.sh
├── exercicio4-conexoes-latencia/
│   ├── README.md
│   ├── connection-pools/
│   │   ├── pool-config.js
│   │   └── connection-strategies.js
│   └── scripts/
│       ├── latency-test.js
│       └── connection-monitor.sh
└── exercicio5-tuning-cluster/
    ├── README.md
    ├── parameter-groups/
    │   ├── performance-parameters.json
    │   └── custom-parameter-group.tf
    └── scripts/
        ├── cluster-tuning.sh
        └── parameter-optimizer.js
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

### Exercício 3: Estratégias para Workloads de Leitura e Escrita
**Duração estimada:** 90 minutos

Otimize diferentes tipos de workloads:
- Configuração de read replicas para workloads de leitura
- Estratégias de caching e distribuição de carga
- Otimização de operações de escrita em lote
- Balanceamento entre consistência e performance

[📖 Ir para Exercício 3](./exercicio3-workload-optimization/README.md)

---

### Exercício 4: Otimização de Conexões, Pools e Latência
**Duração estimada:** 75 minutos

Configure conexões para máxima performance:
- Configuração otimizada de connection pools
- Estratégias de reutilização de conexões
- Monitoramento e redução de latência
- Troubleshooting de problemas de conectividade

[📖 Ir para Exercício 4](./exercicio4-conexoes-latencia/README.md)

---

### Exercício 5: Ajustes Avançados de Cluster e Parâmetros
**Duração estimada:** 90 minutos

Realize tuning avançado do cluster:
- Configuração de parameter groups customizados
- Ajustes de parâmetros para diferentes workloads
- Otimização de recursos de instância
- Monitoramento de impacto das mudanças

[📖 Ir para Exercício 5](./exercicio5-tuning-cluster/README.md)

---

## 🎯 Roteiro de Estudo Recomendado

1. **Dia 1 (2h):** Exercício 1 (métricas avançadas)
2. **Dia 2 (2h):** Exercício 2 (planos de execução e índices)
3. **Dia 3 (2h):** Exercício 3 (workload optimization)
4. **Dia 4 (2h):** Exercícios 4 e 5 (conexões e tuning)

## 🚀 Conceitos de Performance Aplicados

Este laboratório implementa os seguintes conceitos de otimização:

- **Monitoramento Proativo:** Identificação precoce de degradação
- **Indexação Estratégica:** Índices otimizados para queries específicas
- **Workload Separation:** Separação de cargas de leitura e escrita
- **Connection Optimization:** Uso eficiente de recursos de conexão
- **Parameter Tuning:** Ajustes específicos para casos de uso

## 💰 Atenção aos Custos

⚠️ **IMPORTANTE:** Este laboratório pode gerar custos adicionais:

- Read Replicas: ~$0.10-0.50 por hora (dependendo do tipo de instância)
- CloudWatch métricas customizadas: ~$0.30 por métrica por mês
- Instâncias maiores para testes: ~$0.20-2.00 por hora

**Custo estimado:** ~$10-20 USD para completar todo o laboratório

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
# Deletar read replicas
aws docdb delete-db-instance --db-instance-identifier <replica-id>

# Remover parameter groups customizados
aws docdb delete-db-cluster-parameter-group --db-cluster-parameter-group-name <custom-group>

# Deletar métricas customizadas e dashboards
aws cloudwatch delete-dashboards --dashboard-names <performance-dashboard>

# Parar simuladores de carga
pkill -f "workload-simulator"
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

2. **Alta latência de conexão**
   - Verifique configuração de connection pools
   - Analise localização geográfica das aplicações
   - Considere usar read replicas regionais

3. **CPU alta no cluster**
   - Analise queries mais custosas
   - Verifique se há operações de scan completo
   - Considere escalar verticalmente as instâncias

4. **Problemas de memória**
   - Monitore working set size
   - Ajuste parâmetros de cache
   - Considere otimizar estruturas de documentos

## 🎯 Objetivos de Performance

Ao final do laboratório, você deve conseguir:

- ✅ Identificar gargalos de performance em tempo real
- ✅ Otimizar queries usando análise de planos de execução
- ✅ Configurar workloads separados para leitura e escrita
- ✅ Implementar connection pooling eficiente
- ✅ Ajustar parâmetros de cluster para casos específicos
- ✅ Monitorar e medir melhorias de performance

## 📝 Notas de Performance

- Sempre teste mudanças em ambiente de desenvolvimento primeiro
- Monitore métricas antes e depois de otimizações
- Documente configurações que funcionam bem
- Implemente mudanças incrementalmente
- Use ferramentas de profiling para identificar gargalos

---

**Performance é uma jornada, não um destino! 🚀**