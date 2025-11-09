# Interface Overview - Console AWS DocumentDB

## Anatomia da Interface

### Header Global AWS
```
┌─────────────────────────────────────────────────────────────┐
│ AWS [🏠] Services [👤] Support [🔔] [Region: us-east-1 ▼]   │
└─────────────────────────────────────────────────────────────┘
```

### Breadcrumb Navigation
```
Services > Database > Amazon DocumentDB > Clusters
```

### Main Content Area
```
┌─────────────────────────────────────────────────────────────┐
│ Amazon DocumentDB (with MongoDB compatibility)             │
├─────────────────────────────────────────────────────────────┤
│ [Clusters] [Instances] [Snapshots] [Parameter groups] [...] │
├─────────────────────────────────────────────────────────────┤
│                    Content Area                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Elementos da Interface

### 1. Navigation Tabs

#### Primary Tabs
- **Clusters**: Gerenciamento de clusters
- **Instances**: Visualização de instâncias individuais
- **Snapshots**: Gerenciamento de backups
- **Parameter groups**: Configurações customizadas
- **Subnet groups**: Configurações de rede
- **Event subscriptions**: Notificações

#### Secondary Actions
- **Create cluster**: Botão principal de ação
- **Actions**: Menu dropdown para ações em lote
- **Refresh**: Atualizar dados da interface

### 2. Cluster List View

#### Table Headers
```
┌─────────────────┬──────────┬────────┬───────────┬─────────────┐
│ Cluster ID      │ Status   │ Engine │ Instances │ Created     │
├─────────────────┼──────────┼────────┼───────────┼─────────────┤
│ my-cluster      │Available │docdb   │ 3         │ 2024-01-15  │
│ test-cluster    │Creating  │docdb   │ 1         │ 2024-01-15  │
└─────────────────┴──────────┴────────┴───────────┴─────────────┘
```

#### Status Indicators
- 🟢 **Available**: Cluster operacional
- 🟡 **Creating**: Cluster sendo criado
- 🟡 **Modifying**: Cluster sendo modificado
- 🟡 **Backing-up**: Backup em andamento
- 🔴 **Failed**: Falha na operação
- 🔴 **Deleting**: Cluster sendo deletado

### 3. Cluster Detail View

#### Overview Tab
```
┌─────────────────────────────────────────────────────────────┐
│ Cluster: my-cluster                              [Actions ▼] │
├─────────────────────────────────────────────────────────────┤
│ [Overview] [Connectivity] [Monitoring] [Logs] [Config]      │
├─────────────────────────────────────────────────────────────┤
│ General Information                                         │
│ • Status: Available                                         │
│ • Engine: Amazon DocumentDB 5.0.0                          │
│ • Multi-AZ: Yes                                            │
│ • Created: January 15, 2024                                │
│                                                             │
│ Cluster Endpoints                                           │
│ • Writer: my-cluster.cluster-xyz.docdb.amazonaws.com       │
│ • Reader: my-cluster.cluster-ro-xyz.docdb.amazonaws.com    │
└─────────────────────────────────────────────────────────────┘
```

#### Connectivity & Security Tab
```
┌─────────────────────────────────────────────────────────────┐
│ Network & Security                                          │
│                                                             │
│ VPC: vpc-12345678 (default)                               │
│ Subnet group: default                                       │
│ Security groups: sg-87654321 (default)                     │
│ Port: 27017                                                │
│                                                             │
│ Encryption                                                  │
│ • Encryption at rest: Enabled                              │
│ • KMS key: Default (aws/rds)                              │
│ • Encryption in transit: TLS required                      │
└─────────────────────────────────────────────────────────────┘
```

### 4. Monitoring Interface

#### CloudWatch Metrics
```
┌─────────────────────────────────────────────────────────────┐
│ Performance Metrics                    [Time Range: 1h ▼]   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ CPU Utilization                                             │
│ ████████████████████████████████████████████████████████    │
│ 0%    25%    50%    75%    100%                            │
│                                                             │
│ Database Connections                                        │
│ ████████████████████████████████████████████████████████    │
│ 0     25     50     75     100                             │
│                                                             │
│ Read Latency (ms)                                          │
│ ████████████████████████████████████████████████████████    │
│ 0     5      10     15     20                              │
└─────────────────────────────────────────────────────────────┘
```

#### Available Metrics
- **CPU Utilization**: Percentual de uso de CPU
- **Database Connections**: Número de conexões ativas
- **Read/Write Latency**: Latência de operações em ms
- **Read/Write Throughput**: Operações por segundo
- **Network Receive/Transmit**: Tráfego de rede
- **Freeable Memory**: Memória disponível
- **Swap Usage**: Uso de swap

### 5. Instance Management

#### Instance List
```
┌─────────────────┬──────────┬──────────────┬────────────┬──────┐
│ Instance ID     │ Status   │ Class        │ AZ         │ Role │
├─────────────────┼──────────┼──────────────┼────────────┼──────┤
│ my-cluster-1    │Available │db.t3.medium  │us-east-1a  │Writer│
│ my-cluster-2    │Available │db.t3.medium  │us-east-1b  │Reader│
│ my-cluster-3    │Available │db.t3.medium  │us-east-1c  │Reader│
└─────────────────┴──────────┴──────────────┴────────────┴──────┘
```

#### Instance Actions
- **Modify**: Alterar classe de instância
- **Reboot**: Reiniciar instância
- **Delete**: Remover instância do cluster
- **Create read replica**: Adicionar réplica de leitura

### 6. Backup Management

#### Snapshot List
```
┌─────────────────┬──────────┬──────────┬─────────────┬────────┐
│ Snapshot ID     │ Type     │ Status   │ Created     │ Size   │
├─────────────────┼──────────┼──────────┼─────────────┼────────┤
│ manual-snap-1   │ Manual   │Available │ 2024-01-15  │ 10 GB  │
│ rds:my-cluster  │ Auto     │Available │ 2024-01-15  │ 10 GB  │
└─────────────────┴──────────┴──────────┴─────────────┴────────┘
```

#### Backup Configuration
```
┌─────────────────────────────────────────────────────────────┐
│ Automated Backup Settings                                   │
│                                                             │
│ Backup retention period: [7] days                          │
│ Backup window: [03:00-04:00] UTC                          │
│ Copy tags to snapshots: [✓] Enabled                       │
│                                                             │
│ Point-in-time Recovery                                      │
│ • Earliest restore time: 2024-01-08 03:00 UTC             │
│ • Latest restore time: 2024-01-15 14:30 UTC               │
└─────────────────────────────────────────────────────────────┘
```

## Elementos Interativos

### 1. Botões de Ação

#### Primary Actions (Azul)
- **Create cluster**: Ação principal
- **Create snapshot**: Criar backup manual
- **Restore**: Restaurar de backup

#### Secondary Actions (Branco)
- **Modify**: Alterar configurações
- **Reboot**: Reiniciar recursos
- **Delete**: Remover recursos

#### Danger Actions (Vermelho)
- **Delete cluster**: Ação destrutiva
- **Force failover**: Ação de emergência

### 2. Dropdowns e Seletores

#### Actions Menu
```
Actions ▼
├── Create snapshot
├── Modify cluster
├── Reboot cluster
├── Delete cluster
└── Add instance
```

#### Filter Options
```
Filter by status ▼
├── All statuses
├── Available
├── Creating
├── Modifying
└── Failed
```

### 3. Forms e Wizards

#### Create Cluster Wizard
```
Step 1: Configuration
┌─────────────────────────────────────────────────────────────┐
│ Cluster identifier: [my-cluster                          ] │
│ Engine version: [5.0.0                               ▼] │
│ Instance class: [db.t3.medium                        ▼] │
│ Number of instances: [3                              ] │
└─────────────────────────────────────────────────────────────┘

Step 2: Settings
┌─────────────────────────────────────────────────────────────┐
│ Master username: [docdbadmin                         ] │
│ Master password: [••••••••••                        ] │
│ Confirm password: [••••••••••                        ] │
└─────────────────────────────────────────────────────────────┘
```

## Navegação por Teclado

### Atalhos Úteis
- **Tab**: Navegar entre elementos
- **Enter**: Confirmar ação
- **Esc**: Cancelar/fechar modal
- **Ctrl+F**: Buscar na página
- **F5**: Atualizar página

### Accessibility Features
- **Screen reader support**: Compatível com leitores de tela
- **High contrast**: Suporte a alto contraste
- **Keyboard navigation**: Navegação completa por teclado
- **Focus indicators**: Indicadores visuais de foco

## Responsividade

### Desktop (> 1200px)
- Layout completo com sidebar
- Tabelas com todas as colunas
- Gráficos em tamanho completo

### Tablet (768px - 1200px)
- Sidebar colapsável
- Algumas colunas ocultas
- Gráficos redimensionados

### Mobile (< 768px)
- Menu hambúrguer
- Tabelas em formato de cards
- Gráficos simplificados

## Customização da Interface

### Preferências do Usuário
- **Language**: Idioma da interface
- **Time zone**: Fuso horário para timestamps
- **Date format**: Formato de data preferido
- **Theme**: Claro/escuro (limitado)

### Configurações de Visualização
- **Items per page**: 10, 25, 50, 100
- **Column visibility**: Mostrar/ocultar colunas
- **Sort preferences**: Ordenação padrão
- **Refresh interval**: Auto-refresh de dados

## Próximos Passos

Após entender a interface:
1. Pratique navegação entre as seções
2. Explore os diferentes tipos de visualização
3. Familiarize-se com os atalhos de teclado
4. Continue para o [Exercício 3: CLI e SDKs](../../exercicio3-cli-sdks/README.md)