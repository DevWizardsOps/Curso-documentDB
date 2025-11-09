# Exercício 2: Console AWS - Navegação e Interface

## 🎯 Objetivos

- Navegar pela interface do DocumentDB no Console AWS
- Compreender as opções e configurações disponíveis
- Familiarizar-se com a terminologia e estrutura
- Explorar sem criar recursos (apenas visualização)

## ⏱️ Duração Estimada
90 minutos

---

## 🖥️ Parte 1: Acessando o Console DocumentDB

### Passo 1: Login no Console AWS

1. **Acesse o Console AWS:**
   - Vá para https://console.aws.amazon.com
   - Faça login com suas credenciais
   - Selecione uma região (ex: us-east-1)

2. **Navegar para DocumentDB:**
   - No menu de serviços, procure por "DocumentDB"
   - Ou use a barra de busca: "DocumentDB"
   - Clique em "Amazon DocumentDB"

### Passo 2: Interface Principal

Ao acessar o DocumentDB, você verá a interface principal com as seguintes seções:

```
┌─────────────────────────────────────────────────────────────┐
│                    Amazon DocumentDB                        │
├─────────────────────────────────────────────────────────────┤
│  Dashboard  │  Clusters  │  Instances  │  Snapshots  │...  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  📊 Getting Started                                         │
│  ├── Create your first cluster                             │
│  ├── View documentation                                     │
│  └── Explore sample applications                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 Parte 2: Explorando as Seções do Console

### Dashboard
- **Visão geral:** Resumo dos recursos na região
- **Links rápidos:** Acesso a documentação e tutoriais
- **Status:** Informações sobre quotas e limites

### Clusters
- **Lista de clusters:** Todos os clusters na região
- **Status:** Available, Creating, Deleting, etc.
- **Detalhes:** Endpoint, engine version, backup settings

### Instances
- **Instâncias individuais:** Cada instância do cluster
- **Roles:** Primary (writer) vs Read Replica
- **Métricas:** CPU, conexões, latência

### Snapshots
- **Automated:** Backups automáticos do sistema
- **Manual:** Snapshots criados pelo usuário
- **Cross-region:** Backups em outras regiões

### Parameter Groups
- **Default groups:** Configurações padrão do DocumentDB
- **Custom groups:** Configurações personalizadas
- **Parameters:** Configurações específicas do engine

### Subnet Groups
- **Network configuration:** Configuração de rede
- **VPC integration:** Integração com Virtual Private Cloud
- **Availability Zones:** Distribuição geográfica

---

## 🔍 Parte 3: Explorando Opções de Criação (Sem Criar)

### Passo 1: Botão "Create Cluster"

Clique em "Create cluster" para ver as opções (mas não prossiga com a criação):

#### Engine Options
- **Engine:** DocumentDB (compatível com MongoDB 3.6 e 4.0)
- **Version:** Versões disponíveis do engine

#### Cluster Configuration
- **Cluster identifier:** Nome único do cluster
- **Master username:** Usuário administrador
- **Master password:** Senha do administrador

#### Instance Configuration
- **Instance class:** Tipos de instância disponíveis
  - `db.t3.medium` (2 vCPU, 4 GB RAM)
  - `db.r5.large` (2 vCPU, 16 GB RAM)
  - `db.r5.xlarge` (4 vCPU, 32 GB RAM)
- **Number of instances:** Quantas instâncias criar

#### Network & Security
- **VPC:** Virtual Private Cloud
- **Subnet group:** Grupo de subnets
- **Security groups:** Regras de firewall
- **Port:** Porta de conexão (padrão: 27017)

#### Backup
- **Backup retention:** Período de retenção (1-35 dias)
- **Backup window:** Janela de backup automático
- **Copy tags to snapshots:** Copiar tags para backups

#### Encryption
- **Encryption at rest:** Criptografia de dados
- **KMS key:** Chave de criptografia

#### Monitoring
- **CloudWatch logs:** Exportar logs para CloudWatch
- **Performance Insights:** Análise de performance

---

## 📊 Parte 4: Compreendendo Métricas e Monitoramento

### CloudWatch Integration
Explore as métricas disponíveis (mesmo sem cluster criado):

#### Métricas de Performance
- **CPUUtilization:** Uso de CPU das instâncias
- **DatabaseConnections:** Número de conexões ativas
- **ReadLatency / WriteLatency:** Latência de operações
- **NetworkThroughput:** Throughput de rede

#### Métricas de Storage
- **VolumeBytesUsed:** Espaço de armazenamento usado
- **VolumeReadIOPs / VolumeWriteIOPs:** Operações de I/O

#### Métricas de Backup
- **BackupRetentionPeriodStorageUsed:** Espaço usado por backups

### Events and Notifications
- **Event categories:** Tipos de eventos do sistema
- **Event subscriptions:** Notificações via SNS
- **Event history:** Histórico de eventos

---

## 🔧 Parte 5: Configurações Avançadas

### Parameter Groups
Explore os parameter groups disponíveis:

#### Default Parameter Group
- **Family:** docdb3.6 ou docdb4.0
- **Parameters:** Configurações padrão do engine
- **Read-only:** Não pode ser modificado

#### Custom Parameter Groups
- **Modifiable parameters:** Parâmetros que podem ser alterados
- **Apply method:** Immediate vs Pending-reboot
- **Common parameters:**
  - `audit_logs`: enabled/disabled
  - `profiler`: enabled/disabled
  - `profiler_threshold_ms`: Threshold para profiling

### Subnet Groups
Compreenda a configuração de rede:

#### VPC Requirements
- **Private subnets:** DocumentDB deve estar em subnets privadas
- **Multiple AZs:** Pelo menos 2 Availability Zones
- **CIDR blocks:** Blocos de IP adequados

#### Security Groups
- **Inbound rules:** Regras de entrada (porta 27017)
- **Outbound rules:** Regras de saída
- **Source/Destination:** IPs ou security groups permitidos

---

## 📖 Parte 6: Documentação e Recursos

### Getting Started
- **Quick start guides:** Guias de início rápido
- **Best practices:** Melhores práticas
- **Tutorials:** Tutoriais passo-a-passo

### API Reference
- **AWS CLI commands:** Comandos de linha de comando
- **SDK documentation:** Documentação dos SDKs
- **REST API:** Referência da API REST

### Pricing Information
- **Instance pricing:** Preços por tipo de instância
- **Storage pricing:** Preços de armazenamento
- **Backup pricing:** Preços de backup
- **Data transfer:** Custos de transferência de dados

---

## ✅ Checklist de Conclusão

### Navegação Completada:

- ✅ Acessou o console DocumentDB
- ✅ Explorou todas as seções principais
- ✅ Compreendeu opções de criação de cluster
- ✅ Analisou configurações de rede e segurança
- ✅ Explorou métricas e monitoramento
- ✅ Compreendeu parameter groups e subnet groups

---

## 📝 Resumo do Console AWS

### Vantagens da Interface:
- **Intuitiva:** Fácil navegação para iniciantes
- **Visual:** Gráficos e métricas integradas
- **Guiada:** Wizards para configuração
- **Integrada:** Acesso direto a outros serviços AWS

### Limitações:
- **Automação:** Não adequado para automação
- **Velocidade:** Mais lento que CLI/API para operações repetitivas
- **Versionamento:** Não há controle de versão das configurações

### Quando Usar o Console:
- **Aprendizado:** Explorar recursos e opções
- **Configuração inicial:** Setup de recursos novos
- **Troubleshooting:** Investigar problemas visualmente
- **Monitoramento:** Visualizar métricas e logs

### Preparação para Próximos Módulos:
- **Módulo 2:** Criação real de clusters e configurações
- **CLI/SDKs:** Automação das operações vistas no console
- **Monitoramento:** Uso prático das métricas exploradas

---

[⬅️ Exercício 1](../exercicio1-introducao-conceitos/README.md) | [➡️ Exercício 3](../exercicio3-cli-sdks/README.md)