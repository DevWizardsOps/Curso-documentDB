# Módulo 2 - Administração e Gerenciamento do DocumentDB

Laboratório prático para o Módulo 2 do curso de DocumentDB (6h), focado em provisionamento, políticas de backup, failover, monitoramento e operações de manutenção.

## 📋 Objetivos do Laboratório

- Provisionar clusters DocumentDB via Console e Terraform
- Configurar políticas de backup e snapshots automáticos
- Implementar e testar failover
- Configurar monitoramento com CloudWatch e EventBridge
- Realizar operações de manutenção e atualizações

## 🏗️ Estrutura do Laboratório

```
modulo2-lab/
├── README.md
├── exercicio1-provisionamento/
│   ├── README.md
│   ├── console/
│   │   └── instrucoes.md
│   └── terraform/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── exercicio2-backup-snapshots/
│   ├── README.md
│   ├── scripts/
│   │   ├── backup-manual.sh
│   │   └── restore-snapshot.sh
│   └── politicas/
│       └── backup-policy.json
├── exercicio3-failover/
│   ├── README.md
│   ├── scripts/
│   │   ├── test-failover.sh
│   │   └── monitor-endpoints.sh
│   └── exemplos/
│       └── connection-failover.js
├── exercicio4-monitoramento/
│   ├── README.md
│   ├── cloudwatch/
│   │   ├── dashboard.json
│   │   └── alarms.tf
│   └── eventbridge/
│       ├── rules.json
│       └── targets.tf
└── exercicio5-manutencao/
    ├── README.md
    ├── scripts/
    │   ├── upgrade-cluster.sh
    │   └── modify-instance.sh
    └── checklists/
        └── manutencao.md
```

## 🚀 Pré-requisitos

- Conta AWS ativa
- AWS CLI configurado
- Terraform instalado (versão >= 1.0)
- Node.js instalado (para scripts de teste)
- Acesso à console AWS
- Conhecimento básico de MongoDB/DocumentDB

## 📚 Exercícios

### Exercício 1: Provisionamento de Clusters
**Duração estimada:** 60 minutos

Aprenda a provisionar clusters DocumentDB usando:
- AWS Console (interface gráfica)
- Terraform (infraestrutura como código)

[📖 Ir para Exercício 1](./exercicio1-provisionamento/README.md)

---

### Exercício 2: Backup e Snapshots Automáticos
**Duração estimada:** 45 minutos

Configure e gerencie:
- Políticas de backup automático
- Snapshots manuais
- Restauração de backups

[📖 Ir para Exercício 2](./exercicio2-backup-snapshots/README.md)

---

### Exercício 3: Gerenciamento de Failover
**Duração estimada:** 60 minutos

Implemente e teste:
- Failover automático
- Failover manual
- Monitoramento de endpoints

[📖 Ir para Exercício 3](./exercicio3-failover/README.md)

---

### Exercício 4: Monitoramento com CloudWatch e EventBridge
**Duração estimada:** 75 minutos

Configure:
- Dashboards no CloudWatch
- Alarmes personalizados
- Regras do EventBridge para eventos do cluster

[📖 Ir para Exercício 4](./exercicio4-monitoramento/README.md)

---

### Exercício 5: Operações de Manutenção e Atualizações
**Duração estimada:** 60 minutos

Execute:
- Upgrade de versão do cluster
- Modificação de instâncias
- Aplicação de patches

[📖 Ir para Exercício 5](./exercicio5-manutencao/README.md)

---

## 🎯 Roteiro de Estudo Recomendado

1. **Dia 1 (2h):** Exercícios 1 e 2
2. **Dia 2 (2h):** Exercícios 3 e 4
3. **Dia 3 (2h):** Exercício 5 e revisão

## 💰 Atenção aos Custos

⚠️ **IMPORTANTE:** Este laboratório utiliza recursos AWS que geram custos. Para minimizar gastos:

- Delete recursos após concluir cada exercício
- Use instâncias `db.t3.medium` ou menores
- Remova snapshots desnecessários
- Execute `terraform destroy` ao finalizar

**Custo estimado:** ~$5-10 USD para completar todo o laboratório (dependendo do tempo de execução)

## 🧹 Limpeza de Recursos

Ao final de cada exercício, execute:

```bash
# Via Terraform
cd exercicio-X/terraform
terraform destroy -auto-approve

# Via AWS CLI
aws docdb delete-db-cluster --db-cluster-identifier lab-cluster --skip-final-snapshot
```

## 📖 Recursos Adicionais

- [Documentação AWS DocumentDB](https://docs.aws.amazon.com/documentdb/)
- [Guia de Melhores Práticas](https://docs.aws.amazon.com/documentdb/latest/developerguide/best-practices.html)
- [Terraform AWS Provider - DocumentDB](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/docdb_cluster)

## 🆘 Troubleshooting

### Problemas Comuns

1. **Cluster não provisiona**
   - Verifique subnet groups e security groups
   - Confirme quotas da conta AWS

2. **Erro de conexão**
   - Valide regras de security group
   - Verifique se está na mesma VPC

3. **Terraform fails**
   - Execute `terraform init` primeiro
   - Verifique credenciais AWS

## 📝 Notas

- Todos os scripts assumem região `us-east-1` (pode ser alterado)
- Senhas padrão devem ser alteradas em produção
- Use AWS Secrets Manager para credenciais em ambientes reais

---

**Bom laboratório! 🚀**
