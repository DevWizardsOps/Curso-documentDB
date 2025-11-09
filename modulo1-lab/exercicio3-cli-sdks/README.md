# Exercício 3: CLI e SDKs - Conhecendo as Ferramentas

## 🎯 Objetivos

- Conhecer o AWS CLI para DocumentDB
- Compreender Boto3 (Python SDK) 
- Entender AWS SDK para Node.js
- Comparar as diferentes ferramentas disponíveis

## ⏱️ Duração Estimada
90 minutos

---

## 🖥️ Parte 1: AWS CLI - Linha de Comando

### Passo 1: Verificação do AWS CLI

```bash
# Verificar se AWS CLI está instalado
aws --version

# Verificar configuração (sem mostrar credenciais)
aws configure list

# Testar conectividade básica
aws sts get-caller-identity
```

### Passo 2: Comandos de Consulta DocumentDB

Estes comandos apenas consultam informações, sem criar recursos:

```bash
# Listar clusters existentes na região
aws docdb describe-db-clusters

# Listar todas as instâncias
aws docdb describe-db-instances

# Listar parameter groups disponíveis
aws docdb describe-db-cluster-parameter-groups

# Listar snapshots (se houver)
aws docdb describe-db-cluster-snapshots

# Verificar versões do engine disponíveis
aws docdb describe-db-engine-versions --engine docdb

# Verificar quotas e limites
aws service-quotas list-service-quotas --service-code docdb
```

### Passo 3: Comandos de Criação (Apenas Exemplo - NÃO EXECUTAR)

Estes são exemplos de como seria criar recursos (para referência futura):

```bash
# EXEMPLO - NÃO EXECUTAR NO MÓDULO 1
# Comando para criar cluster (será usado no Módulo 2)
aws docdb create-db-cluster \
    --db-cluster-identifier meu-cluster \
    --engine docdb \
    --master-username docdbadmin \
    --master-password MinhaSenh@123 \
    --backup-retention-period 7 \
    --storage-encrypted

# EXEMPLO - NÃO EXECUTAR NO MÓDULO 1  
# Comando para criar instância (será usado no Módulo 2)
aws docdb create-db-instance \
    --db-instance-identifier meu-cluster-instance-1 \
    --db-instance-class db.t3.medium \
    --engine docdb \
    --db-cluster-identifier meu-cluster
```

**Nota:** Estes comandos são apenas para demonstração. A criação real será feita no Módulo 2.

---

## 🐍 Parte 2: Boto3 (Python SDK)

### Passo 1: Conceitos do Boto3

O Boto3 é o SDK oficial da AWS para Python. Para DocumentDB:

```bash
# Instalação (apenas demonstração)
pip install boto3

# Dependências relacionadas (para uso futuro)
pip install pymongo  # Para conectar ao DocumentDB
```

### Passo 2: Estrutura Básica do Cliente DocumentDB

```python
# Exemplo conceitual - NÃO EXECUTAR no Módulo 1
import boto3
from botocore.exceptions import ClientError

class DocumentDBManager:
    def __init__(self, region_name='us-east-1'):
        """
        Inicializa o cliente DocumentDB
        """
        self.region_name = region_name
        self.docdb_client = boto3.client('docdb', region_name=region_name)
        self.cloudwatch_client = boto3.client('cloudwatch', region_name=region_name)
    
    def list_clusters(self):
        """
        Lista clusters existentes (método de consulta)
        """
        try:
            response = self.docdb_client.describe_db_clusters()
            return response['DBClusters']
        except ClientError as e:
            print(f"Erro ao listar clusters: {e}")
            return []
    
    def get_engine_versions(self):
        """
        Lista versões disponíveis do engine
        """
        try:
            response = self.docdb_client.describe_db_engine_versions(Engine='docdb')
            return response['DBEngineVersions']
        except ClientError as e:
            print(f"Erro ao obter versões: {e}")
            return []

# Exemplo de uso (conceitual - será implementado no Módulo 2)
if __name__ == "__main__":
    # Inicializar cliente
    docdb_manager = DocumentDBManager()
    
    # Listar clusters existentes (pode ser testado)
    clusters = docdb_manager.list_clusters()
    print(f"Clusters encontrados: {len(clusters)}")
    
    # Listar versões disponíveis (pode ser testado)
    versions = docdb_manager.get_engine_versions()
    print(f"Versões disponíveis: {len(versions)}")
```

**Principais métodos que serão implementados no Módulo 2:**
- `create_cluster()` - Criar cluster
- `get_cluster_info()` - Obter informações
- `create_snapshot()` - Criar backup
- `modify_cluster()` - Modificar configurações
- `delete_cluster()` - Deletar cluster

---

## 🟢 Parte 3: Node.js SDK

### Passo 1: Conceitos do AWS SDK para Node.js

O AWS SDK para Node.js permite integração com DocumentDB em aplicações JavaScript:

```bash
# Instalação (apenas demonstração)
npm install aws-sdk mongodb
```

### Passo 2: Estrutura Básica do Cliente

```javascript
// Exemplo conceitual - NÃO EXECUTAR no Módulo 1
const AWS = require('aws-sdk');

class DocumentDBManager {
    constructor(region = 'us-east-1') {
        this.region = region;
        this.docdb = new AWS.DocDB({ region });
        this.cloudwatch = new AWS.CloudWatch({ region });
    }

    async listClusters() {
        try {
            const response = await this.docdb.describeDBClusters().promise();
            return response.DBClusters;
        } catch (error) {
            console.error('Erro ao listar clusters:', error);
            return [];
        }
    }

    async getEngineVersions() {
        try {
            const response = await this.docdb.describeDBEngineVersions({
                Engine: 'docdb'
            }).promise();
            return response.DBEngineVersions;
        } catch (error) {
            console.error('Erro ao obter versões:', error);
            return [];
        }
    }
}

// Exemplo de uso (conceitual)
async function main() {
    const manager = new DocumentDBManager();
    
    // Listar clusters existentes (pode ser testado)
    const clusters = await manager.listClusters();
    console.log(`Clusters encontrados: ${clusters.length}`);
    
    // Listar versões disponíveis (pode ser testado)
    const versions = await manager.getEngineVersions();
    console.log(`Versões disponíveis: ${versions.length}`);
}
```

**Principais métodos que serão implementados no Módulo 2:**
- `createCluster()` - Criar cluster
- `getClusterInfo()` - Obter informações
- `testConnection()` - Testar conectividade
- `createSnapshot()` - Criar backup
- `deleteCluster()` - Deletar cluster

---

## 📊 Parte 4: Comparação das Ferramentas

### AWS CLI
**Vantagens:**
- ✅ Rápido para operações pontuais
- ✅ Fácil de usar em scripts bash
- ✅ Disponível em qualquer sistema
- ✅ Ideal para automação simples

**Desvantagens:**
- ❌ Limitado para lógica complexa
- ❌ Tratamento de erro básico
- ❌ Não há tipagem

**Quando usar:**
- Scripts simples de administração
- Operações pontuais
- Automação básica
- Troubleshooting rápido

### Boto3 (Python)
**Vantagens:**
- ✅ Controle total sobre operações
- ✅ Excelente tratamento de erros
- ✅ Ideal para automação complexa
- ✅ Integração com data science

**Desvantagens:**
- ❌ Requer conhecimento Python
- ❌ Setup mais complexo

**Quando usar:**
- Automação complexa
- Scripts de administração avançados
- Integração com pipelines de dados
- Aplicações de monitoramento

### AWS SDK Node.js
**Vantagens:**
- ✅ Ideal para aplicações web
- ✅ Async/await nativo
- ✅ Integração com frontend
- ✅ Ecossistema NPM

**Desvantagens:**
- ❌ Callback hell (versões antigas)
- ❌ Menos maduro que Boto3

**Quando usar:**
- Aplicações web
- APIs REST
- Microserviços
- Aplicações serverless (Lambda)

---

## 🎯 Preparação para o Módulo 2

No próximo módulo, você irá:

1. **Criar clusters reais** usando essas ferramentas
2. **Implementar scripts completos** de administração
3. **Testar conectividade** com aplicações
4. **Automatizar operações** de backup e monitoramento

### Comandos que Serão Usados:
- `aws docdb create-db-cluster`
- `aws docdb create-db-instance`
- `aws docdb create-db-cluster-snapshot`
- `aws docdb modify-db-cluster`

### Scripts que Serão Desenvolvidos:
- Criação automatizada de clusters
- Monitoramento de métricas
- Backup e restore automatizados
- Testes de conectividade

---

## ✅ Checklist de Conclusão

### Conhecimentos Adquiridos:

- ✅ Compreendeu a estrutura do AWS CLI para DocumentDB
- ✅ Conheceu os conceitos do Boto3 (Python SDK)
- ✅ Entendeu o AWS SDK para Node.js
- ✅ Comparou as vantagens de cada ferramenta
- ✅ Identificou quando usar cada uma
- ✅ Preparou-se para implementação prática no Módulo 2

---

## 📝 Resumo das Ferramentas

### Para Começar:
- **Console AWS:** Exploração e aprendizado visual
- **AWS CLI:** Operações rápidas e scripts simples

### Para Produção:
- **Boto3:** Automação robusta em Python
- **Node.js SDK:** Aplicações web e APIs
- **Terraform:** Infraestrutura como código (será visto no Módulo 2)

### Próximos Passos:
- **Módulo 2:** Implementação prática com criação de recursos
- **Módulo 3:** Segurança e configurações avançadas
- **Módulo 4:** Performance e otimização
- **Módulo 5:** Alta disponibilidade e disaster recovery

---

[⬅️ Exercício 2](../exercicio2-console-aws/README.md) | [🏠 Módulo 1 Home](../README.md)