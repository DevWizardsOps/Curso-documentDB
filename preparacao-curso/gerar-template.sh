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

# Gerar conditions para cada aluno
for i in $(seq 1 $NUM_ALUNOS); do
    ALUNO_NUM=$(printf "%02d" $i)
    
    if [ $i -eq 1 ]; then
        echo "  CreateAluno${ALUNO_NUM}: !Not [!Equals [!Ref NumeroAlunos, 0]]" >> setup-curso-documentdb-dynamic.yaml
    else
        PREV=$((i - 1))
        CONDITIONS="!Equals [!Ref NumeroAlunos, 0]"
        for j in $(seq 1 $PREV); do
            CONDITIONS="$CONDITIONS, !Equals [!Ref NumeroAlunos, $j]"
        done
        echo "  CreateAluno${ALUNO_NUM}: !Not [!Or [$CONDITIONS]]" >> setup-curso-documentdb-dynamic.yaml
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

  EC2InstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      Roles:
        - !Ref EC2Role

  # S3 Bucket para laboratorios
  LabsBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${AWS::StackName}-labs-${AWS::AccountId}'
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true

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
            yum update -y
            yum install -y aws-cli git
            
            # Instalar MongoDB Shell
            cat > /etc/yum.repos.d/mongodb-org-7.0.repo << 'EOFMONGO'
            [mongodb-org-7.0]
            name=MongoDB Repository
            baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/7.0/x86_64/
            gpgcheck=1
            enabled=1
            gpgkey=https://www.mongodb.org/static/pgp/server-7.0.asc
            EOFMONGO
            yum install -y mongodb-mongosh
            
            # Criar usuário do aluno
            useradd -m -s /bin/bash \${PrefixoAluno}${ALUNO_NUM}
            echo "\${PrefixoAluno}${ALUNO_NUM} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
            
            # Copiar chave SSH do ec2-user para o aluno (permite SSH direto)
            mkdir -p /home/\${PrefixoAluno}${ALUNO_NUM}/.ssh
            cp /home/ec2-user/.ssh/authorized_keys /home/\${PrefixoAluno}${ALUNO_NUM}/.ssh/authorized_keys
            chown -R \${PrefixoAluno}${ALUNO_NUM}:\${PrefixoAluno}${ALUNO_NUM} /home/\${PrefixoAluno}${ALUNO_NUM}/.ssh
            chmod 700 /home/\${PrefixoAluno}${ALUNO_NUM}/.ssh
            chmod 600 /home/\${PrefixoAluno}${ALUNO_NUM}/.ssh/authorized_keys
            
            # Instalar Node.js
            curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
            yum install -y npm wget nodejs python3 python3-pip yum-utils
            yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
            yum install -y terraform
            
            # Configurar AWS CLI
            sudo -u \${PrefixoAluno}${ALUNO_NUM} aws configure set aws_access_key_id \${AccessKey}
            sudo -u \${PrefixoAluno}${ALUNO_NUM} aws configure set aws_secret_access_key \${SecretKey}
            sudo -u \${PrefixoAluno}${ALUNO_NUM} aws configure set default.region \${AWS::Region}
            sudo -u \${PrefixoAluno}${ALUNO_NUM} aws configure set default.output json
            
            # Setup do ambiente
            cd /home/\${PrefixoAluno}${ALUNO_NUM}
            wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
            chown \${PrefixoAluno}${ALUNO_NUM}:\${PrefixoAluno}${ALUNO_NUM} global-bundle.pem
            sudo -u \${PrefixoAluno}${ALUNO_NUM} pip3 install --user boto3
            sudo -u \${PrefixoAluno}${ALUNO_NUM} \
              git clone https://github.com/DevWizardsOps/Curso-documentDB.git
            sudo -u \${PrefixoAluno}${ALUNO_NUM} \
              rm -fr /home/\${PrefixoAluno}${ALUNO_NUM}/Curso-documentDB/preparacao-curso
            timedatectl set-timezone America/Recife
            
            # Criar arquivo de boas-vindas (usando echo para evitar problemas com heredoc)
            echo "╔══════════════════════════════════════════════════════════════╗" > /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "║              BEM-VINDO AO CURSO DOCUMENTDB                   ║" >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "╚══════════════════════════════════════════════════════════════╝" >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "" >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "Olá \${PrefixoAluno}${ALUNO_NUM}!" >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "" >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "Seu ambiente está configurado e pronto para uso." >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "" >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "📋 INFORMAÇÕES DO AMBIENTE:" >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "  - Usuário Linux: \${PrefixoAluno}${ALUNO_NUM}" >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "  - Região AWS: \${AWS::Region}" >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "" >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "🔧 FERRAMENTAS INSTALADAS:" >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "  ✓ AWS CLI, MongoDB Shell, Node.js, Python, Terraform, Git" >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "" >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "🚀 PRIMEIROS PASSOS:" >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "  1. Teste: aws sts get-caller-identity" >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "  2. Acesse: cd ~/Curso-documentDB" >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "" >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            echo "Bom curso! 🎓" >> /home/\${PrefixoAluno}${ALUNO_NUM}/BEM-VINDO.txt
            
            # Adicionar customizações ao .bashrc
            sudo echo "" >> /home/\${PrefixoAluno}${ALUNO_NUM}/.bashrc
            sudo echo "# Aliases úteis" >> /home/\${PrefixoAluno}${ALUNO_NUM}/.bashrc
            sudo echo "alias ll='ls -lah'" >> /home/\${PrefixoAluno}${ALUNO_NUM}/.bashrc
            sudo echo "alias curso='cd ~/Curso-documentDB'" >> /home/\${PrefixoAluno}${ALUNO_NUM}/.bashrc
            sudo echo "alias awsid='aws sts get-caller-identity'" >> /home/\${PrefixoAluno}${ALUNO_NUM}/.bashrc
            sudo echo "" >> /home/\${PrefixoAluno}${ALUNO_NUM}/.bashrc
            sudo echo "# Mostrar boas-vindas no primeiro login" >> /home/\${PrefixoAluno}${ALUNO_NUM}/.bashrc
            sudo echo "if [ -f ~/BEM-VINDO.txt ] && [ ! -f ~/.welcome_shown ]; then" >> /home/\${PrefixoAluno}${ALUNO_NUM}/.bashrc
            sudo echo "    cat ~/BEM-VINDO.txt" >> /home/\${PrefixoAluno}${ALUNO_NUM}/.bashrc
            sudo echo "    touch ~/.welcome_shown" >> /home/\${PrefixoAluno}${ALUNO_NUM}/.bashrc
            sudo echo "fi" >> /home/\${PrefixoAluno}${ALUNO_NUM}/.bashrc
            sudo echo "" >> /home/\${PrefixoAluno}${ALUNO_NUM}/.bashrc
            sudo echo "export ID=\${PrefixoAluno}${ALUNO_NUM}" >> /home/\${PrefixoAluno}${ALUNO_NUM}/.bashrc
            sudo chown -R \${PrefixoAluno}${ALUNO_NUM}:\${PrefixoAluno}${ALUNO_NUM} /home/\${PrefixoAluno}${ALUNO_NUM}/
            
            echo "Setup completo em \$(date)" > /home/\${PrefixoAluno}${ALUNO_NUM}/setup-complete.txt
            sudo chown \${PrefixoAluno}${ALUNO_NUM}:\${PrefixoAluno}${ALUNO_NUM} /home/\${PrefixoAluno}${ALUNO_NUM}/setup-complete.txt
          - AccessKey: !Ref Aluno${ALUNO_NUM}AccessKey
            SecretKey: !GetAtt Aluno${ALUNO_NUM}AccessKey.SecretAccessKey
            PrefixoAluno: !Ref PrefixoAluno
      Tags:
        - Key: Name
          Value: !Sub '\${PrefixoAluno}${ALUNO_NUM}-instance'
        - Key: Purpose
          Value: 'Curso DocumentDB'
EOF_ALUNO
done

# Gerar Outputs
cat >> setup-curso-documentdb-dynamic.yaml << 'EOF_OUTPUTS'

Outputs:
  SecurityGroupDocumentDB:
    Description: 'Security Group ID para DocumentDB'
    Value: !Ref DocumentDBSecurityGroup
    Export:
      Name: !Sub '${AWS::StackName}-DocumentDB-SG'

  LabsBucketName:
    Description: 'Nome do bucket S3'
    Value: !Ref LabsBucket

EOF_OUTPUTS

# Gerar outputs para cada aluno
for i in $(seq 1 $NUM_ALUNOS); do
    ALUNO_NUM=$(printf "%02d" $i)
    
    cat >> setup-curso-documentdb-dynamic.yaml << EOF_OUTPUT
  Aluno${ALUNO_NUM}Info:
    Condition: CreateAluno${ALUNO_NUM}
    Description: 'Informacoes de acesso do Aluno ${ALUNO_NUM}'
    Value: !Sub |
      ===============================================================
      ALUNO ${ALUNO_NUM} - \${PrefixoAluno}${ALUNO_NUM}
      ===============================================================
      
      CONSOLE AWS:
        URL: https://\${AWS::AccountId}.signin.aws.amazon.com/console
        Usuario IAM: \${AWS::StackName}-\${PrefixoAluno}${ALUNO_NUM}
        Senha: Armazenada no Secrets Manager (\${ConsolePasswordSecret})
      
      INSTANCIA EC2:
        IP Publico: \${Aluno${ALUNO_NUM}Instance.PublicIp}
        Usuario Linux: \${PrefixoAluno}${ALUNO_NUM}
      
      ACESSO SSH:
        Chave: \${KeyPairName}.pem
        Comando: ssh -i \${KeyPairName}.pem \${PrefixoAluno}${ALUNO_NUM}@\${Aluno${ALUNO_NUM}Instance.PublicIp}
      
      AWS CLI ja configurado na instancia!

EOF_OUTPUT
done

cat >> setup-curso-documentdb-dynamic.yaml << 'EOF_FOOTER'
  ConsolePasswordSecretName:
    Description: 'Nome do secret contendo a senha do console'
    Value: !Ref ConsolePasswordSecret
    Export:
      Name: !Sub '${AWS::StackName}-ConsolePassword-Secret'

  SecretsManagerURL:
    Description: 'Link direto para o Secrets Manager'
    Value: !Sub 'https://console.aws.amazon.com/secretsmanager/home?region=${AWS::Region}#!/secret?name=${ConsolePasswordSecret}'

  InstrucoesGerais:
    Description: 'Instrucoes gerais do curso'
    Value: !Sub |
      ===============================================================
      CURSO DOCUMENTDB - INSTRUCOES GERAIS
      ===============================================================
      
      SENHA DO CONSOLE:
        Link Direto: https://console.aws.amazon.com/secretsmanager/home?region=${AWS::Region}#!/secret?name=${ConsolePasswordSecret}
        
        Via CLI:
        aws secretsmanager get-secret-value \
          --secret-id ${ConsolePasswordSecret} \
          --query SecretString --output text | jq -r .password
      
      CHAVE SSH:
        Nome: ${KeyPairName}.pem
        Localizacao: Mesmo diretorio do script de deploy
      
      RECURSOS CRIADOS:
        - Security Group DocumentDB: ${DocumentDBSecurityGroup}
        - Bucket S3 Labs: ${LabsBucket}
        - Regiao: ${AWS::Region}
      
      DICA: Veja os outputs individuais de cada aluno acima!
      RELATORIO WEB: Verifique o link gerado pelo script de deploy
EOF_FOOTER

echo "Template gerado: setup-curso-documentdb-dynamic.yaml (para $NUM_ALUNOS alunos)"
