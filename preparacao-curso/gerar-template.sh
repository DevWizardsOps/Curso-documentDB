#!/bin/bash

# Script para gerar template CloudFormation dinamicamente
# Uso: ./gerar-template.sh <numero-de-alunos>

NUM_ALUNOS=${1:-2}

if [ $NUM_ALUNOS -lt 1 ] || [ $NUM_ALUNOS -gt 20 ]; then
    echo "Erro: Número de alunos deve ser entre 1 e 20"
    exit 1
fi

cat > setup-curso-documentdb-dynamic.yaml << 'EOF_HEADER'
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Ambiente para Curso DocumentDB - Instancias EC2 + Usuarios IAM'

Parameters:
  NumeroAlunos:
    Type: Number
    Default: 2
    MinValue: 1
    MaxValue: 20
    Description: 'Numero de alunos (1-20)'
    
  PrefixoAluno:
    Type: String
    Default: 'aluno'
    Description: 'Prefixo para nomes dos alunos'
    
  VpcId:
    Type: AWS::EC2::VPC::Id
    Description: 'VPC onde criar as instancias'
    
  SubnetId:
    Type: AWS::EC2::Subnet::Id
    Description: 'Subnet publica para as instancias'
    
  AllowedCIDR:
    Type: String
    Default: '0.0.0.0/0'
    Description: 'CIDR permitido para SSH'
    
  KeyPairName:
    Type: String
    Description: 'Nome da chave SSH existente (a mesma sera usada para todas as instancias)'
    
  ConsolePasswordSecret:
    Type: String
    Description: 'Nome do secret no Secrets Manager contendo a senha do console'
    
  LabsBucketName:
    Type: String
    Description: 'Nome do bucket S3 para scripts e labs (ja deve existir)'

Mappings:
  RegionMap:
    us-east-1:
      AMI: ami-0c02fb55956c7d316
    us-east-2:
      AMI: ami-0807bd3aff0ae7273
    us-west-1:
      AMI: ami-0d9858aa3c6322f73
    us-west-2:
      AMI: ami-008fe2fc65df48dac
    eu-west-1:
      AMI: ami-01dd271720c1ba44f
    eu-central-1:
      AMI: ami-0f454ec961da9a046
    sa-east-1:
      AMI: ami-0c820c196a818d66a

Conditions:
EOF_HEADER

# Gerar conditions para cada aluno usando abordagem que funciona com limite de 10 do !Or
for i in $(seq 1 $NUM_ALUNOS); do
    ALUNO_NUM=$(printf "%02d" $i)
    
    if [ $i -eq 1 ]; then
        echo "  CreateAluno${ALUNO_NUM}: !Not [!Equals [!Ref NumeroAlunos, 0]]" >> setup-curso-documentdb-dynamic.yaml
    elif [ $i -le 10 ]; then
        # Para alunos 2-10: verificar se NumeroAlunos >= i (NumeroAlunos NÃO está em [0..i-1])
        PREV=$((i - 1))
        CONDITIONS=""
        for j in $(seq 0 $PREV); do
            if [ -z "$CONDITIONS" ]; then
                CONDITIONS="!Equals [!Ref NumeroAlunos, $j]"
            else
                CONDITIONS="$CONDITIONS, !Equals [!Ref NumeroAlunos, $j]"
            fi
        done
        echo "  CreateAluno${ALUNO_NUM}: !Not [!Or [$CONDITIONS]]" >> setup-curso-documentdb-dynamic.yaml
    else
        # Para alunos 11-20: usar !And com múltiplos !Not !Or para evitar limite de 10
        PREV=$((i - 1))
        
        # Primeira parte: [0..9]
        CONDITIONS1="!Equals [!Ref NumeroAlunos, 0], !Equals [!Ref NumeroAlunos, 1], !Equals [!Ref NumeroAlunos, 2], !Equals [!Ref NumeroAlunos, 3], !Equals [!Ref NumeroAlunos, 4], !Equals [!Ref NumeroAlunos, 5], !Equals [!Ref NumeroAlunos, 6], !Equals [!Ref NumeroAlunos, 7], !Equals [!Ref NumeroAlunos, 8], !Equals [!Ref NumeroAlunos, 9]"
        
        # Segunda parte: [10..PREV]
        CONDITIONS2=""
        COUNT2=0
        for j in $(seq 10 $PREV); do
            if [ -z "$CONDITIONS2" ]; then
                CONDITIONS2="!Equals [!Ref NumeroAlunos, $j]"
            else
                CONDITIONS2="$CONDITIONS2, !Equals [!Ref NumeroAlunos, $j]"
            fi
            COUNT2=$((COUNT2 + 1))
        done
        
        # Se temos apenas 1 elemento na segunda parte, não usar !Or
        if [ $COUNT2 -eq 1 ]; then
            echo "  CreateAluno${ALUNO_NUM}: !And [!Not [!Or [$CONDITIONS1]], !Not [$CONDITIONS2]]" >> setup-curso-documentdb-dynamic.yaml
        else
            echo "  CreateAluno${ALUNO_NUM}: !And [!Not [!Or [$CONDITIONS1]], !Not [!Or [$CONDITIONS2]]]" >> setup-curso-documentdb-dynamic.yaml
        fi
    fi
done

cat >> setup-curso-documentdb-dynamic.yaml << 'EOF_RESOURCES'

Resources:
  # Security Group para alunos
  AlunosSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: !Sub '${AWS::StackName}-alunos-sg'
      GroupDescription: 'Security Group para instancias dos alunos'
      VpcId: !Ref VpcId
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: !Ref AllowedCIDR
          Description: 'SSH access'
      SecurityGroupEgress:
        - IpProtocol: -1
          CidrIp: 0.0.0.0/0
      Tags:
        - Key: Name
          Value: !Sub '${AWS::StackName}-alunos-sg'

  # Security Group para DocumentDB
  DocumentDBSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: !Sub '${AWS::StackName}-documentdb-sg'
      GroupDescription: 'Security Group para DocumentDB'
      VpcId: !Ref VpcId
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 27017
          ToPort: 27017
          SourceSecurityGroupId: !Ref AlunosSecurityGroup
      Tags:
        - Key: Name
          Value: !Sub '${AWS::StackName}-documentdb-sg'

  # IAM Group para alunos
  CursoDocumentDBGroup:
    Type: AWS::IAM::Group
    Properties:
      GroupName: !Sub '${AWS::StackName}-students'
      Policies:
        - PolicyName: DocumentDBCoursePolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              # DocumentDB Elastic - Acesso completo (serviço elastic clusters)
              - Effect: Allow
                Action: 'docdb-elastic:*'
                Resource: '*'
              
              # RDS - Criação/modificação de instâncias COM restrição de classe (controle de custos)
              - Effect: Allow
                Action:
                  - 'rds:CreateDBInstance'
                  - 'rds:ModifyDBInstance'
                Resource: '*'
                Condition:
                  StringLike:
                    'rds:DatabaseClass':
                      - 'db.t3.medium'
                      - 'db.t3.large'
                      - 'db.t3.xlarge'
                      - 'db.r5.large'
                      - 'db.r5.xlarge'
              
              # RDS - Todas as outras operações SEM restrições
              - Effect: Allow
                Action: 'rds:*'
                Resource: '*'
              
              # EC2 - Consultas e gerenciamento (sem restrições de leitura)
              - Effect: Allow
                Action:
                  - 'ec2:*'
                Resource: '*'
              
              # EC2 - RunInstances com restrição de tipo de instância (família t3 até xlarge)
              - Effect: Allow
                Action: 'ec2:RunInstances'
                Resource: '*'
                Condition:
                  StringLike:
                    'ec2:InstanceType':
                      - 't3.nano'
                      - 't3.micro'
                      - 't3.small'
                      - 't3.medium'
                      - 't3.large'
                      - 't3.xlarge'
              
              # CloudWatch - Acesso completo (sem restrições para treinamento)
              - Effect: Allow
                Action: 'cloudwatch:*'
                Resource: '*'
              
              # CloudWatch Logs - Acesso completo (sem restrições para treinamento)
              - Effect: Allow
                Action: 'logs:*'
                Resource: '*'
              
              # S3 - Buckets do curso e backups dos alunos
              - Effect: Allow
                Action:
                  - 's3:CreateBucket'
                  - 's3:ListBucket'
                  - 's3:GetObject'
                  - 's3:PutObject'
                  - 's3:DeleteObject'
                  - 's3:GetBucketLocation'
                  - 's3:PutBucketVersioning'
                  - 's3:GetBucketVersioning'
                  - 's3:PutLifecycleConfiguration'
                  - 's3:GetLifecycleConfiguration'
                  - 's3:PutBucketPolicy'
                  - 's3:GetBucketPolicy'
                  - 's3:ListAllMyBuckets'
                Resource: 
                  - !Sub 'arn:aws:s3:::${AWS::StackName}-*'
                  - !Sub 'arn:aws:s3:::${AWS::StackName}-*/*'
                  - 'arn:aws:s3:::*-docdb-backups-*'
                  - 'arn:aws:s3:::*-docdb-backups-*/*'
                  - 'arn:aws:s3:::*-lab-*'
                  - 'arn:aws:s3:::*-lab-*/*'
              
              # EventBridge - Acesso completo (sem restrições para treinamento)
              - Effect: Allow
                Action: 'events:*'
                Resource: '*'
              
              # Lambda - Funcoes basicas para automacao
              - Effect: Allow
                Action:
                  - 'lambda:CreateFunction'
                  - 'lambda:DeleteFunction'
                  - 'lambda:InvokeFunction'
                  - 'lambda:UpdateFunctionCode'
                  - 'lambda:UpdateFunctionConfiguration'
                  - 'lambda:GetFunction'
                  - 'lambda:ListFunctions'
                Resource: !Sub 'arn:aws:lambda:*:${AWS::AccountId}:function:${AWS::StackName}-*'
              
              # SNS - Acesso completo (sem restrições para treinamento)
              - Effect: Allow
                Action: 'sns:*'
                Resource: '*'
              
              # CloudTrail - Auditoria e compliance (Modulo 3)
              - Effect: Allow
                Action:
                  - 'cloudtrail:*'
                Resource: '*'
              
              # KMS - Acesso completo (sem restrições para treinamento)
              - Effect: Allow
                Action: 'kms:*'
                Resource: '*'
              
              # STS - Identificacao do usuario
              - Effect: Allow
                Action: 'sts:GetCallerIdentity'
                Resource: '*'

  # IAM Role para instancias EC2
  EC2Role:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ec2.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
      Policies:
        - PolicyName: S3SetupScriptAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 's3:GetObject'
                  - 's3:ListBucket'
                Resource:
                  - !Sub 'arn:aws:s3:::${LabsBucketName}'
                  - !Sub 'arn:aws:s3:::${LabsBucketName}/*'

  EC2InstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      Roles:
        - !Ref EC2Role

EOF_RESOURCES

# Gerar recursos para cada aluno
for i in $(seq 1 $NUM_ALUNOS); do
    ALUNO_NUM=$(printf "%02d" $i)
    
    cat >> setup-curso-documentdb-dynamic.yaml << EOF_ALUNO

  # Recursos do Aluno ${ALUNO_NUM}
  Aluno${ALUNO_NUM}User:
    Condition: CreateAluno${ALUNO_NUM}
    Type: AWS::IAM::User
    Properties:
      UserName: !Sub '\${AWS::StackName}-\${PrefixoAluno}${ALUNO_NUM}'
      Groups:
        - !Ref CursoDocumentDBGroup
      LoginProfile:
        Password: !Sub '{{resolve:secretsmanager:\${ConsolePasswordSecret}:SecretString:password}}'
        PasswordResetRequired: false

  Aluno${ALUNO_NUM}AccessKey:
    Condition: CreateAluno${ALUNO_NUM}
    Type: AWS::IAM::AccessKey
    Properties:
      UserName: !Ref Aluno${ALUNO_NUM}User

  Aluno${ALUNO_NUM}Instance:
    Condition: CreateAluno${ALUNO_NUM}
    Type: AWS::EC2::Instance
    Properties:
      ImageId: !FindInMap [RegionMap, !Ref 'AWS::Region', AMI]
      InstanceType: t3.micro
      KeyName: !Ref KeyPairName
      SecurityGroupIds:
        - !Ref AlunosSecurityGroup
      SubnetId: !Ref SubnetId
      IamInstanceProfile: !Ref EC2InstanceProfile
      UserData:
        Fn::Base64: !Sub 
          - |
            #!/bin/bash
            # Aguardar IAM instance profile estar disponível (máximo 30s)
            for i in {1..30}; do
              if curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/ > /dev/null 2>&1; then
                break
              fi
              sleep 1
            done
            
            # Baixar e executar script de setup do S3
            aws s3 cp s3://\${BucketName}/scripts/setup-aluno.sh /tmp/setup-aluno.sh
            chmod +x /tmp/setup-aluno.sh
            /tmp/setup-aluno.sh "\${PrefixoAluno}${ALUNO_NUM}" "\${AWS::Region}" "\${AccessKey}" "\${SecretKey}" >> /var/log/setup-aluno.log 2>&1
          - AccessKey: !Ref Aluno${ALUNO_NUM}AccessKey
            SecretKey: !GetAtt Aluno${ALUNO_NUM}AccessKey.SecretAccessKey
            PrefixoAluno: !Ref PrefixoAluno
            BucketName: !Ref LabsBucketName
      Tags:
        - Key: Name
          Value: !Sub '\${PrefixoAluno}${ALUNO_NUM}-instance'
        - Key: Purpose
          Value: 'Curso DocumentDB'
EOF_ALUNO
done

# Gerar Outputs SIMPLIFICADOS
cat >> setup-curso-documentdb-dynamic.yaml << 'EOF_OUTPUTS'

Outputs:
  StackName:
    Description: 'Nome da Stack'
    Value: !Ref AWS::StackName
    
  Regiao:
    Description: 'Regiao AWS'
    Value: !Ref AWS::Region
    
  AccountId:
    Description: 'Account ID'
    Value: !Ref AWS::AccountId
    
  SecurityGroupDocumentDB:
    Description: 'Security Group ID para DocumentDB'
    Value: !Ref DocumentDBSecurityGroup
    Export:
      Name: !Sub '${AWS::StackName}-DocumentDB-SG'

  LabsBucketName:
    Description: 'Nome do bucket S3 para labs'
    Value: !Ref LabsBucketName
  
  ConsolePasswordSecret:
    Description: 'Nome do secret contendo a senha do console'
    Value: !Ref ConsolePasswordSecret
    Export:
      Name: !Sub '${AWS::StackName}-ConsolePassword-Secret'
      
  SecretsManagerURL:
    Description: 'Link para o Secrets Manager'
    Value: !Sub 'https://console.aws.amazon.com/secretsmanager/home?region=${AWS::Region}#!/secret?name=${ConsolePasswordSecret}'
    
  KeyPairName:
    Description: 'Nome da chave SSH'
    Value: !Ref KeyPairName

EOF_OUTPUTS

# Gerar outputs APENAS com IPs públicos para cada aluno
for i in $(seq 1 $NUM_ALUNOS); do
    ALUNO_NUM=$(printf "%02d" $i)
    
    cat >> setup-curso-documentdb-dynamic.yaml << EOF_OUTPUT
  Aluno${ALUNO_NUM}IP:
    Condition: CreateAluno${ALUNO_NUM}
    Description: 'IP publico do Aluno ${ALUNO_NUM}'
    Value: !GetAtt Aluno${ALUNO_NUM}Instance.PublicIp

EOF_OUTPUT
done

echo "Template gerado: setup-curso-documentdb-dynamic.yaml (para $NUM_ALUNOS alunos)"
