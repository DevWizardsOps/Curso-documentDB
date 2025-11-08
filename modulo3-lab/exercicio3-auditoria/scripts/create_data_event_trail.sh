#!/bin/bash

# Este script cria um novo Trail no AWS CloudTrail para capturar eventos de dados (leitura e escrita)
# em todos os clusters DocumentDB da conta. 

# --- Variáveis (substitua pelos seus valores) ---
TRAIL_NAME="docdb-data-events-trail"
S3_BUCKET_NAME="seu-bucket-para-logs-cloudtrail-$(aws sts get-caller-identity --query Account --output text)"

# --- Lógica do Script ---

# 1. Criar o bucket S3 se ele não existir
echo "Verificando/Criando bucket S3: $S3_BUCKET_NAME..."
aws s3api create-bucket --bucket $S3_BUCKET_NAME --region us-east-1 > /dev/null 2>&1

# Adiciona a política necessária para o CloudTrail escrever no bucket
POLICY_JSON=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {"Service": "cloudtrail.amazonaws.com"},
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::$S3_BUCKET_NAME"
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {"Service": "cloudtrail.amazonaws.com"},
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::$S3_BUCKET_NAME/AWSLogs/$(aws sts get-caller-identity --query Account --output text)/*",
            "Condition": {"StringEquals": {"s3:x-amz-acl": "bucket-owner-full-control"}}
        }
    ]
}
EOF
)
aws s3api put-bucket-policy --bucket $S3_BUCKET_NAME --policy "$POLICY_JSON"

# 2. Criar o Trail no CloudTrail
echo "Criando Trail: $TRAIL_NAME..."
aws cloudtrail create-trail --name $TRAIL_NAME --s3-bucket-name $S3_BUCKET_NAME --is-multi-region-trail

# 3. Configurar o seletor de eventos para capturar eventos de dados do DocumentDB
echo "Configurando seletores de eventos de dados..."
aws cloudtrail put-event-selectors --trail-name $TRAIL_NAME --advanced-event-selectors \
'[
  {
    "Name": "Log DocumentDB read/write operations",
    "FieldSelectors": [
      { "Field": "eventCategory", "Equals": ["Data"] },
      { "Field": "resources.type", "Equals": ["AWS::RDS::DBCluster"] }
    ]
  }
]'

# 4. Iniciar o logging no Trail
echo "Iniciando logging para o Trail..."
aws cloudtrail start-logging --name $TRAIL_NAME

echo "
Trail '$TRAIL_NAME' criado e configurado com sucesso! 
Eventos de dados do DocumentDB serão entregues no bucket S3 '$S3_BUCKET_NAME'.
"
