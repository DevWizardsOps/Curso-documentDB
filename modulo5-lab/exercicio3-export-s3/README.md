# Exercício 3: Exportação Automatizada para S3

## 🎯 Objetivos

- Configurar exportação automatizada de dados do DocumentDB para S3
- Implementar compressão e particionamento otimizado
- Integrar com AWS Glue para analytics
- Configurar monitoramento e notificações de exportação

## ⏱️ Duração Estimada
90 minutos

> ⚠️ **Atenção:** Lembre-se de usar seu prefixo de aluno (`<seu-id>`) em todos os nomes de recursos e comandos.

---

## 🗄️ Parte 1: Configuração do Bucket S3

### Passo 1: Criar Bucket S3 Otimizado

```bash
# Configurar variáveis
export ID="<seu-id>"
export CLUSTER_ID="$ID-lab-cluster-console"
export BUCKET_NAME="$ID-docdb-exports-$(date +%Y%m%d)"
export REGION="us-east-1"

# Criar bucket S3 com configurações otimizadas
aws s3 mb s3://$BUCKET_NAME --region $REGION

# Configurar versionamento
aws s3api put-bucket-versioning \
--bucket $BUCKET_NAME \
--versioning-configuration Status=Enabled

# Configurar lifecycle para otimização de custos
aws s3api put-bucket-lifecycle-configuration \
--bucket $BUCKET_NAME \
--lifecycle-configuration '{
  "Rules": [
    {
      "ID": "DocumentDBExportLifecycle",
      "Status": "Enabled",
      "Filter": {"Prefix": "exports/"},
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        },
        {
          "Days": 365,
          "StorageClass": "DEEP_ARCHIVE"
        }
      ]
    }
  ]
}'

echo "Bucket S3 criado: $BUCKET_NAME"
```

### Passo 2: Configurar Políticas de Acesso

```bash
# Criar role IAM para Lambda
aws iam create-role \
--role-name $ID-DocumentDBExportRole \
--assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

# Anexar políticas necessárias
aws iam attach-role-policy \
--role-name $ID-DocumentDBExportRole \
--policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Criar política customizada para DocumentDB e S3
aws iam create-policy \
--policy-name $ID-DocumentDBExportPolicy \
--policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::'$BUCKET_NAME'/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::'$BUCKET_NAME'"
    },
    {
      "Effect": "Allow",
      "Action": [
        "rds:DescribeDBClusters",
        "rds:DescribeDBInstances"
      ],
      "Resource": "*"
    }
  ]
}'

# Obter ARN da política criada
POLICY_ARN=$(aws iam list-policies \
--query "Policies[?PolicyName=='$ID-DocumentDBExportPolicy'].Arn" \
--output text)

# Anexar política ao role
aws iam attach-role-policy \
--role-name $ID-DocumentDBExportRole \
--policy-arn $POLICY_ARN
```

---

## 🔧 Parte 2: Função Lambda para Exportação

### Passo 1: Criar Função de Exportação

```python
# Criar função Lambda otimizada
cat > lambda/export-function.py << 'EOF'
import json
import boto3
import pymongo
import gzip
import io
import os
from datetime import datetime, timedelta
from bson import json_util

def lambda_handler(event, context):
    """
    Função Lambda para exportar dados do DocumentDB para S3
    """
    
    # Configurações
    cluster_endpoint = os.environ['CLUSTER_ENDPOINT']
    username = os.environ['DB_USERNAME']
    password = os.environ['DB_PASSWORD']
    bucket_name = os.environ['BUCKET_NAME']
    
    # Parâmetros do evento
    database_name = event.get('database', 'performanceDB')
    collection_name = event.get('collection', 'products')
    export_type = event.get('export_type', 'incremental')  # full, incremental, custom
    date_filter = event.get('date_filter')
    
    s3_client = boto3.client('s3')
    
    try:
        # Conectar ao DocumentDB
        connection_string = f"mongodb://{username}:{password}@{cluster_endpoint}:27017/{database_name}?ssl=true&retryWrites=false"
        client = pymongo.MongoClient(connection_string)
        
        db = client[database_name]
        collection = db[collection_name]
        
        # Determinar filtro baseado no tipo de exportação
        query_filter = {}
        
        if export_type == 'incremental':
            # Exportar apenas dados das últimas 24 horas
            yesterday = datetime.now() - timedelta(days=1)
            query_filter = {'createdAt': {'$gte': yesterday}}
        elif export_type == 'custom' and date_filter:
            # Usar filtro customizado
            query_filter = date_filter
        
        # Executar query com paginação
        batch_size = 1000
        total_exported = 0
        batch_number = 0
        
        cursor = collection.find(query_filter).batch_size(batch_size)
        
        for batch in batch_cursor(cursor, batch_size):
            if not batch:
                break
                
            batch_number += 1
            
            # Converter para JSON
            json_data = json_util.dumps(batch, indent=2)
            
            # Comprimir dados
            compressed_data = gzip.compress(json_data.encode('utf-8'))
            
            # Gerar chave S3 com particionamento
            timestamp = datetime.now()
            s3_key = f"exports/{database_name}/{collection_name}/year={timestamp.year}/month={timestamp.month:02d}/day={timestamp.day:02d}/batch_{batch_number}_{timestamp.strftime('%H%M%S')}.json.gz"
            
            # Upload para S3
            s3_client.put_object(
                Bucket=bucket_name,
                Key=s3_key,
                Body=compressed_data,
                ContentType='application/gzip',
                ContentEncoding='gzip',
                Metadata={
                    'export_type': export_type,
                    'batch_size': str(len(batch)),
                    'timestamp': timestamp.isoformat(),
                    'database': database_name,
                    'collection': collection_name
                }
            )
            
            total_exported += len(batch)
            
            print(f"Batch {batch_number} exportado: {len(batch)} documentos -> {s3_key}")
        
        # Criar manifesto do export
        manifest = {
            'export_id': f"{database_name}_{collection_name}_{timestamp.strftime('%Y%m%d_%H%M%S')}",
            'timestamp': timestamp.isoformat(),
            'database': database_name,
            'collection': collection_name,
            'export_type': export_type,
            'total_documents': total_exported,
            'total_batches': batch_number,
            'query_filter': query_filter,
            'compression': 'gzip',
            'format': 'json'
        }
        
        # Salvar manifesto
        manifest_key = f"manifests/{database_name}/{collection_name}/{timestamp.strftime('%Y/%m/%d')}/manifest_{timestamp.strftime('%H%M%S')}.json"
        
        s3_client.put_object(
            Bucket=bucket_name,
            Key=manifest_key,
            Body=json.dumps(manifest, indent=2),
            ContentType='application/json'
        )
        
        client.close()
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Export completed successfully',
                'export_id': manifest['export_id'],
                'total_documents': total_exported,
                'total_batches': batch_number,
                'manifest_location': f"s3://{bucket_name}/{manifest_key}"
            })
        }
        
    except Exception as e:
        print(f"Error during export: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }

def batch_cursor(cursor, batch_size):
    """
    Gerador para processar cursor em lotes
    """
    while True:
        batch = list(cursor.limit(batch_size))
        if not batch:
            break
        yield batch
        cursor = cursor.skip(len(batch))
EOF
```

### Passo 2: Criar Package de Deployment

```bash
# Criar diretório de deployment
mkdir -p lambda-package
cd lambda-package

# Instalar dependências
pip install pymongo -t .

# Copiar função
cp ../lambda/export-function.py .

# Criar ZIP package
zip -r ../export-function.zip .
cd ..

# Obter ARN do role
ROLE_ARN=$(aws iam get-role \
--role-name $ID-DocumentDBExportRole \
--query 'Role.Arn' \
--output text)

# Criar função Lambda
aws lambda create-function \
--function-name $ID-DocumentDBExport \
--runtime python3.9 \
--role $ROLE_ARN \
--handler export-function.lambda_handler \
--zip-file fileb://export-function.zip \
--timeout 900 \
--memory-size 1024 \
--environment Variables="{
  CLUSTER_ENDPOINT=$CLUSTER_ENDPOINT,
  DB_USERNAME=$DB_USERNAME,
  DB_PASSWORD=$DB_PASSWORD,
  BUCKET_NAME=$BUCKET_NAME
}"

echo "Função Lambda criada: $ID-DocumentDBExport"
```

---

## ⏰ Parte 3: Agendamento Automatizado

### Passo 1: Configurar EventBridge para Execução Periódica

```bash
# Criar regra para exportação diária
aws events put-rule \
--name $ID-daily-export \
--description "Exportação diária do DocumentDB para S3" \
--schedule-expression "cron(0 2 * * ? *)"  # Todo dia às 2:00 AM UTC

# Criar regra para exportação incremental (a cada 4 horas)
aws events put-rule \
--name $ID-incremental-export \
--description "Exportação incremental do DocumentDB" \
--schedule-expression "cron(0 */4 * * ? *)"  # A cada 4 horas

# Adicionar permissão para EventBridge invocar Lambda
aws lambda add-permission \
--function-name $ID-DocumentDBExport \
--statement-id allow-eventbridge-daily \
--action lambda:InvokeFunction \
--principal events.amazonaws.com \
--source-arn arn:aws:events:$REGION:$(aws sts get-caller-identity --query Account --output text):rule/$ID-daily-export

aws lambda add-permission \
--function-name $ID-DocumentDBExport \
--statement-id allow-eventbridge-incremental \
--action lambda:InvokeFunction \
--principal events.amazonaws.com \
--source-arn arn:aws:events:$REGION:$(aws sts get-caller-identity --query Account --output text):rule/$ID-incremental-export

# Configurar targets
aws events put-targets \
--rule $ID-daily-export \
--targets "Id"="1","Arn"="arn:aws:lambda:$REGION:$(aws sts get-caller-identity --query Account --output text):function:$ID-DocumentDBExport","Input"='{"export_type":"full","database":"performanceDB","collection":"products"}'

aws events put-targets \
--rule $ID-incremental-export \
--targets "Id"="1","Arn"="arn:aws:lambda:$REGION:$(aws sts get-caller-identity --query Account --output text):function:$ID-DocumentDBExport","Input"='{"export_type":"incremental","database":"performanceDB","collection":"products"}'
```

### Passo 2: Script de Exportação Manual

```bash
# Criar script para exportação sob demanda
cat > scripts/export-to-s3.js << 'EOF'
#!/usr/bin/env node

const AWS = require('aws-sdk');

const lambda = new AWS.Lambda();

class DocumentDBExporter {
  constructor(functionName) {
    this.functionName = functionName;
  }

  async exportCollection(database, collection, exportType = 'full', customFilter = null) {
    const payload = {
      database: database,
      collection: collection,
      export_type: exportType
    };

    if (customFilter) {
      payload.date_filter = customFilter;
      payload.export_type = 'custom';
    }

    console.log(`Iniciando exportação: ${database}.${collection} (${exportType})`);
    
    try {
      const result = await lambda.invoke({
        FunctionName: this.functionName,
        Payload: JSON.stringify(payload)
      }).promise();

      const response = JSON.parse(result.Payload);
      
      if (response.statusCode === 200) {
        const body = JSON.parse(response.body);
        console.log('✅ Exportação concluída com sucesso!');
        console.log(`   Export ID: ${body.export_id}`);
        console.log(`   Documentos: ${body.total_documents}`);
        console.log(`   Batches: ${body.total_batches}`);
        console.log(`   Manifesto: ${body.manifest_location}`);
        return body;
      } else {
        const error = JSON.parse(response.body);
        console.error('❌ Erro na exportação:', error.error);
        throw new Error(error.error);
      }
    } catch (error) {
      console.error('❌ Erro ao invocar função Lambda:', error);
      throw error;
    }
  }

  async exportMultipleCollections(database, collections, exportType = 'full') {
    const results = [];
    
    for (const collection of collections) {
      try {
        const result = await this.exportCollection(database, collection, exportType);
        results.push({ collection, success: true, result });
        
        // Aguardar 30 segundos entre exportações para evitar sobrecarga
        await new Promise(resolve => setTimeout(resolve, 30000));
      } catch (error) {
        results.push({ collection, success: false, error: error.message });
      }
    }
    
    return results;
  }
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);
  const functionName = process.env.ID + '-DocumentDBExport';
  
  if (args.length < 2) {
    console.log('Uso: node export-to-s3.js <database> <collection> [export_type]');
    console.log('Exemplo: node export-to-s3.js performanceDB products full');
    process.exit(1);
  }

  const [database, collection, exportType = 'full'] = args;
  
  const exporter = new DocumentDBExporter(functionName);
  
  try {
    await exporter.exportCollection(database, collection, exportType);
  } catch (error) {
    console.error('Falha na exportação:', error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = DocumentDBExporter;
EOF

chmod +x scripts/export-to-s3.js
```

---

## 📊 Parte 4: Integração com AWS Glue

### Passo 1: Configurar Glue Catalog

```bash
# Criar database no Glue Catalog
aws glue create-database \
--database-input '{
  "Name": "'$ID'_docdb_exports",
  "Description": "Database para dados exportados do DocumentDB"
}'

# Criar crawler para descobrir schema automaticamente
aws glue create-crawler \
--name $ID-docdb-crawler \
--role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/service-role/AWSGlueServiceRole \
--database-name ${ID}_docdb_exports \
--targets '{
  "S3Targets": [
    {
      "Path": "s3://'$BUCKET_NAME'/exports/"
    }
  ]
}' \
--schema-change-policy '{
  "UpdateBehavior": "UPDATE_IN_DATABASE",
  "DeleteBehavior": "LOG"
}'

echo "Glue Crawler criado: $ID-docdb-crawler"
```

### Passo 2: Executar Crawler e Criar Tabelas

```bash
# Executar crawler para descobrir dados
aws glue start-crawler --name $ID-docdb-crawler

# Aguardar conclusão do crawler
echo "Aguardando conclusão do crawler..."
while true; do
    STATUS=$(aws glue get-crawler --name $ID-docdb-crawler --query 'Crawler.State' --output text)
    if [ "$STATUS" = "READY" ]; then
        echo "Crawler concluído!"
        break
    fi
    echo "Status do crawler: $STATUS"
    sleep 30
done

# Listar tabelas criadas
aws glue get-tables \
--database-name ${ID}_docdb_exports \
--query 'TableList[*].{Name:Name,Location:StorageDescriptor.Location}' \
--output table
```

---

## 📈 Parte 5: Monitoramento e Notificações

### Passo 1: Configurar CloudWatch Logs e Métricas

```bash
# Criar grupo de logs para a função Lambda
aws logs create-log-group \
--log-group-name /aws/lambda/$ID-DocumentDBExport

# Criar métricas customizadas
aws cloudwatch put-metric-data \
--namespace Custom/DocumentDB/Export \
--metric-data \
MetricName=ExportSuccess,Value=1,Unit=Count,Dimensions=Name=FunctionName,Value=$ID-DocumentDBExport \
MetricName=DocumentsExported,Value=1000,Unit=Count,Dimensions=Name=Database,Value=performanceDB
```

### Passo 2: Função Lambda para Notificações

```python
# Criar função de notificação
cat > lambda/notification-handler.py << 'EOF'
import json
import boto3
from datetime import datetime

def lambda_handler(event, context):
    """
    Função para processar notificações de exportação
    """
    
    sns = boto3.client('sns')
    s3 = boto3.client('s3')
    
    # Processar evento S3
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        
        if 'manifests/' in key:
            # Processar manifesto de exportação
            try:
                # Baixar manifesto
                response = s3.get_object(Bucket=bucket, Key=key)
                manifest = json.loads(response['Body'].read())
                
                # Criar mensagem de notificação
                message = f"""
Exportação DocumentDB Concluída

Export ID: {manifest['export_id']}
Database: {manifest['database']}
Collection: {manifest['collection']}
Tipo: {manifest['export_type']}
Documentos: {manifest['total_documents']}
Batches: {manifest['total_batches']}
Timestamp: {manifest['timestamp']}

Localização: s3://{bucket}/{key}
                """
                
                # Enviar notificação
                topic_arn = f"arn:aws:sns:us-east-1:{context.invoked_function_arn.split(':')[4]}:docdb-export-notifications"
                
                sns.publish(
                    TopicArn=topic_arn,
                    Subject=f"DocumentDB Export Completed - {manifest['export_id']}",
                    Message=message
                )
                
                print(f"Notificação enviada para exportação: {manifest['export_id']}")
                
            except Exception as e:
                print(f"Erro ao processar manifesto {key}: {str(e)}")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Notifications processed successfully')
    }
EOF
```

### Passo 3: Configurar Trigger S3

```bash
# Criar tópico SNS para notificações
NOTIFICATION_TOPIC_ARN=$(aws sns create-topic \
--name $ID-docdb-export-notifications \
--query 'TopicArn' \
--output text)

# Adicionar subscriber
aws sns subscribe \
--topic-arn $NOTIFICATION_TOPIC_ARN \
--protocol email \
--notification-endpoint seu-email@example.com

# Configurar notificação S3 para manifestos
aws s3api put-bucket-notification-configuration \
--bucket $BUCKET_NAME \
--notification-configuration '{
  "LambdaConfigurations": [
    {
      "Id": "ManifestNotification",
      "LambdaFunctionArn": "arn:aws:lambda:'$REGION':$(aws sts get-caller-identity --query Account --output text):function:'$ID'-DocumentDBExport",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {
              "Name": "prefix",
              "Value": "manifests/"
            }
          ]
        }
      }
    }
  ]
}'
```

---

## 🧪 Parte 6: Testes e Validação

### Teste 1: Exportação Manual

```bash
# Testar exportação manual
node scripts/export-to-s3.js performanceDB products full

# Verificar arquivos no S3
aws s3 ls s3://$BUCKET_NAME/exports/ --recursive

# Verificar manifesto
aws s3 ls s3://$BUCKET_NAME/manifests/ --recursive
```

### Teste 2: Validação de Dados Exportados

```bash
# Baixar e verificar um arquivo exportado
LATEST_EXPORT=$(aws s3 ls s3://$BUCKET_NAME/exports/performanceDB/products/ --recursive | tail -1 | awk '{print $4}')

aws s3 cp s3://$BUCKET_NAME/$LATEST_EXPORT ./test-export.json.gz

# Descomprimir e verificar conteúdo
gunzip test-export.json.gz
head -20 test-export.json

echo "Validação de exportação concluída"
```

---

## ✅ Checklist de Conclusão

Execute o script de validação:

```bash
# Executa o grade para avaliar atividades
./grade_exercicio3.sh
```

### Itens Verificados:

- ✅ Bucket S3 configurado com lifecycle policies
- ✅ Função Lambda de exportação criada e funcionando
- ✅ Agendamento automático configurado
- ✅ Integração com Glue Catalog implementada
- ✅ Monitoramento e notificações ativos
- ✅ Testes de exportação executados com sucesso

---

## 🧹 Limpeza

```bash
# Deletar função Lambda
aws lambda delete-function --function-name $ID-DocumentDBExport

# Deletar regras EventBridge
aws events remove-targets --rule $ID-daily-export --ids 1
aws events remove-targets --rule $ID-incremental-export --ids 1
aws events delete-rule --name $ID-daily-export
aws events delete-rule --name $ID-incremental-export

# Deletar crawler Glue
aws glue delete-crawler --name $ID-docdb-crawler

# Deletar database Glue
aws glue delete-database --name ${ID}_docdb_exports

# Deletar bucket S3 (cuidado - remove todos os dados!)
aws s3 rm s3://$BUCKET_NAME --recursive
aws s3 rb s3://$BUCKET_NAME

# Deletar role e políticas IAM
aws iam detach-role-policy --role-name $ID-DocumentDBExportRole --policy-arn $POLICY_ARN
aws iam detach-role-policy --role-name $ID-DocumentDBExportRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-policy --policy-arn $POLICY_ARN
aws iam delete-role --role-name $ID-DocumentDBExportRole

# Deletar tópico SNS
aws sns delete-topic --topic-arn $NOTIFICATION_TOPIC_ARN
```

---

## 📊 Benefícios da Exportação Automatizada

### Vantagens Implementadas:

1. **Automação Completa:**
   - Exportações agendadas sem intervenção manual
   - Compressão automática (70-90% redução de tamanho)
   - Particionamento por data para performance

2. **Integração Analytics:**
   - Dados disponíveis no Glue Catalog
   - Queries via Athena possíveis
   - Pipeline de analytics automatizado

3. **Monitoramento Proativo:**
   - Notificações de sucesso/falha
   - Métricas de performance
   - Logs detalhados para troubleshooting

4. **Otimização de Custos:**
   - Lifecycle policies para S3
   - Compressão gzip
   - Exportação incremental

### Casos de Uso Atendidos:

- **Backup de Longo Prazo:** Arquivamento em S3 Glacier
- **Data Lake:** Integração com analytics stack
- **Compliance:** Retenção de dados auditáveis
- **Business Intelligence:** Dados estruturados para BI tools

---

[⬅️ Exercício 2](../exercicio2-rto-rpo-optimization/README.md) | [➡️ Exercício 4](../exercicio4-cross-region-strategies/README.md)