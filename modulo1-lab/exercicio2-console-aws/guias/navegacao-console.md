# Guia de Navegação no Console AWS DocumentDB

## Acessando o Console DocumentDB

### 1. Login na AWS Console
1. Acesse [console.aws.amazon.com](https://console.aws.amazon.com)
2. Faça login com suas credenciais
3. Selecione a região desejada (ex: us-east-1)

### 2. Navegando para DocumentDB
- **Opção 1**: Digite "DocumentDB" na barra de busca
- **Opção 2**: Vá em Services → Database → Amazon DocumentDB
- **Opção 3**: Use o link direto: Services → All services → DocumentDB

## Interface Principal do DocumentDB

### Dashboard Principal
Ao acessar o DocumentDB, você verá:

```
┌─────────────────────────────────────────────────────┐
│ Amazon DocumentDB                                   │
├─────────────────────────────────────────────────────┤
│ [Clusters] [Instances] [Snapshots] [Parameter...]   │
├─────────────────────────────────────────────────────┤
│                                                     │
│ Getting Started                                     │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐    │
│ │Create Cluster│ │   Migrate   │ │   Monitor   │    │
│ └─────────────┘ └─────────────┘ └─────────────┘    │
│                                                     │
│ Resources                                           │
│ • Clusters: 0                                       │
│ • Instances: 0                                      │
│ • Snapshots: 0                                      │
└─────────────────────────────────────────────────────┘
```

### Menu de Navegação Lateral

#### Clusters
- **Clusters**: Lista todos os clusters DocumentDB
- **Create cluster**: Wizard para criar novo cluster

#### Instances  
- **Instances**: Lista todas as instâncias
- **Create instance**: Adicionar instância a cluster existente

#### Backups
- **Snapshots**: Snapshots manuais e automáticos
- **Automated backups**: Configurações de backup

#### Configuration
- **Parameter groups**: Grupos de parâmetros customizados
- **Subnet groups**: Grupos de subnets para VPC
- **Option groups**: Opções adicionais (limitado no DocumentDB)

#### Monitoring
- **Events**: Eventos do cluster e instâncias
- **Event subscriptions**: Notificações de eventos
- **Performance Insights**: Análise de performance (se habilitado)

## Navegação Detalhada por Seção

### 1. Seção Clusters

#### Visualização da Lista
```
Cluster identifier | Status | Engine | Instances | Created
lab-cluster       | Available | docdb | 3        | 2024-01-15
test-cluster      | Creating  | docdb | 1        | 2024-01-15
```

#### Ações Disponíveis
- **Create**: Criar novo cluster
- **Actions** (por cluster):
  - Modify
  - Delete
  - Create snapshot
  - Restore from snapshot
  - Add instance

#### Detalhes do Cluster
Clicando em um cluster, você vê:
- **Overview**: Informações gerais
- **Connectivity & security**: Endpoints e security groups
- **Monitoring**: Métricas do CloudWatch
- **Logs & events**: Logs e eventos
- **Configuration**: Parâmetros e configurações
- **Maintenance & backups**: Janelas de manutenção e backup

### 2. Seção Instances

#### Visualização da Lista
```
Instance identifier | Status | Class | AZ | Role
lab-cluster-1      | Available | db.t3.medium | us-east-1a | Writer
lab-cluster-2      | Available | db.t3.medium | us-east-1b | Reader
lab-cluster-3      | Available | db.t3.medium | us-east-1c | Reader
```

#### Informações por Instância
- **Status**: Available, Creating, Modifying, etc.
- **Instance class**: Tipo de instância (db.t3.medium, etc.)
- **Availability Zone**: AZ onde a instância está
- **Role**: Writer (primária) ou Reader (réplica)

### 3. Seção Snapshots

#### Tipos de Snapshots
- **Manual snapshots**: Criados manualmente
- **Automated backups**: Backups automáticos (retention period)

#### Informações dos Snapshots
```
Snapshot ID | Type | Status | Created | Size
manual-snap-1 | Manual | Available | 2024-01-15 | 10 GB
automated-1   | Automated | Available | 2024-01-15 | 10 GB
```

### 4. Seção Parameter Groups

#### Parameter Groups Padrão
- **default.docdb5.0**: Grupo padrão para DocumentDB 5.0
- **default.docdb4.0**: Grupo padrão para DocumentDB 4.0

#### Parâmetros Importantes
- **tls**: enabled/disabled
- **audit_logs**: enabled/disabled
- **ttl_monitor**: enabled/disabled
- **profiler**: 0 (off), 1 (slow ops), 2 (all ops)

### 5. Seção Subnet Groups

#### Informações dos Subnet Groups
```
Name | VPC ID | Status | Subnets
default | vpc-12345 | Complete | 3 subnets
custom-sg | vpc-67890 | Complete | 2 subnets
```

## Fluxo de Navegação Típico

### Para Criar um Cluster
1. **Clusters** → **Create cluster**
2. Configurar parâmetros básicos
3. Configurar rede (VPC, subnets, security groups)
4. Configurar backup e manutenção
5. Review e Create

### Para Monitorar um Cluster
1. **Clusters** → Selecionar cluster
2. **Monitoring** tab
3. Visualizar métricas:
   - CPU Utilization
   - Database Connections
   - Read/Write Latency
   - Read/Write Throughput

### Para Fazer Backup Manual
1. **Clusters** → Selecionar cluster
2. **Actions** → **Create snapshot**
3. Definir nome do snapshot
4. Confirmar criação

### Para Restaurar de Backup
1. **Snapshots** → Selecionar snapshot
2. **Actions** → **Restore snapshot**
3. Configurar novo cluster
4. Confirmar restauração

## Dicas de Navegação

### Filtros e Busca
- Use a barra de busca para filtrar recursos
- Filtros por status, engine version, etc.
- Ordenação por colunas (nome, data, status)

### Atalhos Úteis
- **Ctrl+F**: Buscar na página
- **F5**: Atualizar status
- **Breadcrumbs**: Navegação rápida entre seções

### Informações Contextuais
- **Tooltips**: Passe o mouse sobre ícones para ajuda
- **Help links**: Links para documentação
- **Status indicators**: Cores indicam status (verde=ok, amarelo=warning, vermelho=erro)

## Monitoramento Visual

### Gráficos Disponíveis
- **CPU Utilization**: Uso de CPU por instância
- **Database Connections**: Conexões ativas
- **Read/Write Latency**: Latência de operações
- **Network Throughput**: Tráfego de rede
- **Storage**: Uso de armazenamento

### Períodos de Visualização
- Última hora
- Últimas 6 horas
- Último dia
- Última semana
- Último mês
- Período customizado

## Próximos Passos

Após se familiarizar com a navegação:
1. Explore cada seção sem criar recursos
2. Observe as opções disponíveis em cada menu
3. Familiarize-se com a terminologia
4. Continue para o [Interface Overview](./interface-overview.md)