# Exercício 3: Auditoria com CloudTrail

Neste exercício, vamos habilitar e inspecionar os logs de auditoria para o DocumentDB, garantindo a rastreabilidade de eventos importantes que ocorrem no cluster.

## Passos

### 1. Habilitar a Auditoria de Eventos do DocumentDB
- **Objetivo:** Capturar eventos de gerenciamento e dados (DML) para fins de segurança e análise.
- **Ação:** Por padrão, o DocumentDB envia eventos de gerenciamento (como `CreateDBInstance`, `DeleteDbCluster`) para o CloudTrail. Para auditar eventos de dados (DML - `insert`, `update`, `delete`), você precisa habilitar a auditoria em um `DBClusterParameterGroup` customizado.

  ```bash
  # 1. Criar um novo DB Cluster Parameter Group (o padrão não pode ser modificado)
  aws docdb create-db-cluster-parameter-group \
    --db-cluster-parameter-group-name $ID-lab-audit-parameter-group \
    --db-parameter-group-family docdb5.0 \
    --description "Parameter group para habilitar auditoria no cluster $ID"

  # 2. Habilitar a auditoria no novo parameter group para capturar operações DML
  # Valores possíveis: enabled, disabled, ddl, dml, role, all
  # Para capturar operações DML (insert, update, delete), use 'all' ou 'dml'
  aws docdb modify-db-cluster-parameter-group \
    --db-cluster-parameter-group-name $ID-lab-audit-parameter-group \
    --parameters "ParameterName=audit_logs,ParameterValue=all,ApplyMethod=pending-reboot"

  # 3. Aplicar o novo parameter group ao cluster
  aws docdb modify-db-cluster \
    --db-cluster-identifier $ID-lab-cluster-console \
    --db-cluster-parameter-group-name $ID-lab-audit-parameter-group

  # 4. Reiniciar TODAS as instâncias do cluster para aplicar as mudanças
  aws docdb reboot-db-instance --db-instance-identifier $ID-lab-cluster-console
  aws docdb reboot-db-instance --db-instance-identifier $ID-lab-cluster-console2
  aws docdb reboot-db-instance --db-instance-identifier $ID-lab-cluster-console3
  ```

- **Importante:** Uma reinicialização do cluster é necessária para que a alteração seja aplicada. O processo pode levar alguns minutos.

### 2. Exportar Logs para o CloudWatch Logs
- **Objetivo:** Centralizar os logs de auditoria em um local onde possam ser facilmente pesquisados e monitorados.
- **Ação:** Após todas as instâncias do cluster terem reiniciado e os logs de auditoria estarem habilitados, configure a exportação para o CloudWatch Logs.
  ```bash
  # 1. Aguardar todas as instâncias ficarem disponíveis após o reboot
  aws docdb wait db-instance-available --db-instance-identifier $ID-lab-cluster-console
  aws docdb wait db-instance-available --db-instance-identifier $ID-lab-cluster-console2
  aws docdb wait db-instance-available --db-instance-identifier $ID-lab-cluster-console3

  # 2. Criar o log group no CloudWatch (necessário antes de habilitar a exportação)
  aws logs create-log-group \
    --log-group-name /aws/docdb/$ID-lab-cluster-console/audit

  # 3. Habilitar a exportação dos logs de auditoria para CloudWatch
  aws docdb modify-db-cluster \
    --db-cluster-identifier $ID-lab-cluster-console \
    --cloudwatch-logs-export-configuration '{"EnableLogTypes":["audit"]}'
  ```

### 3. Gerar Atividade no Banco para Produzir Logs
- **Objetivo:** Os logs de auditoria só aparecem quando há atividade no banco. Vamos gerar algumas operações para ver os logs.
- **Ação:** Conecte-se ao DocumentDB e execute algumas operações:
  ```bash
  # 1. Conectar ao DocumentDB usando mongosh
  export CLUSTER_ENDPOINT=$(aws docdb describe-db-clusters \
  --db-cluster-identifier $ID-lab-cluster-console \
  --query 'DBClusters[0].Endpoint' \
  --output text)

  mongosh --tls --host $CLUSTER_ENDPOINT:27017 \
  --tlsCAFile global-bundle.pem \
  --username docdbadmin \
  --password Lab12345! \
  --retryWrites false
  ```

  # 2. Dentro do mongosh, execute algumas operações que serão auditadas:
  ```bash
  use testdb
  db.users.insertOne({name: "João", email: "joao@example.com"})
  db.users.find({name: "João"})
  db.users.updateOne({name: "João"}, {$set: {email: "joao.silva@example.com"}})
  db.users.deleteOne({name: "João"})
  exit
  ```

### 4. Inspecionar os Logs no CloudWatch
- **Objetivo:** Visualizar e pesquisar os eventos de auditoria capturados após gerar atividade no banco.
- **Ação:**
  1. Navegue até o console do CloudWatch.
  2. Vá para **Log groups**.
  3. Encontre o log group chamado `/aws/docdb/$ID-lab-cluster-console/audit`.
  4. Selecione um log stream e inspecione os eventos. Você verá entradas detalhadas para:
     - Eventos de autenticação (login/logout)
     - Operações DML (insert, update, delete, find)
     - Operações DDL (createCollection, dropCollection)
  
- **Alternativa via CLI:** Você também pode visualizar os logs diretamente via CLI:
  ```bash
  # Aguardar alguns minutos para os logs aparecerem
  sleep 120

  # Listar os log streams disponíveis
  aws logs describe-log-streams \
    --log-group-name /aws/docdb/$ID-lab-cluster-console/audit

  # Visualizar os eventos de log mais recentes
  aws logs filter-log-events \
    --log-group-name /aws/docdb/$ID-lab-cluster-console/audit \
    --start-time $(date -d '10 minutes ago' +%s)000
  ```

- **Exemplos de logs de auditoria:** Com `audit_logs=all`, você verá diferentes tipos de eventos:

  **Log de Autenticação:**
  ```json
  {
    "atype": "authenticate",
    "ts": 1762630609230,
    "remote_ip": "172.31.31.150:36850",
    "user": "",
    "param": {
      "user": "docdbadmin",
      "mechanism": "SCRAM-SHA-1",
      "success": true,
      "message": "",
      "error": 0
    }
  }
  ```

  **Log de Operação DML (insert):**
  ```json
  {
    "atype": "insert",
    "ts": 1762630700000,
    "remote_ip": "172.31.31.150:36850",
    "user": "docdbadmin",
    "param": {
      "ns": "testdb.users",
      "o": {"name": "João", "email": "joao@example.com"}
    }
  }
  ```

  **Log de Operação DML (update):**
  ```json
  {
    "atype": "update",
    "ts": 1762630710000,
    "remote_ip": "172.31.31.150:36850",
    "user": "docdbadmin",
    "param": {
      "ns": "testdb.users",
      "o": {"$set": {"email": "joao.silva@example.com"}},
      "o2": {"name": "João"}
    }
  }
  ```

### 5. (Opcional) Criar um Trail no CloudTrail para Eventos de Dados
- **Objetivo:** Ter um registro de auditoria de longo prazo e mais detalhado para eventos de dados (operações de leitura e escrita).
- **Ação:** Use o script `scripts/create_data_event_trail.sh` para criar um Trail que capture eventos de dados para o seu cluster DocumentDB.