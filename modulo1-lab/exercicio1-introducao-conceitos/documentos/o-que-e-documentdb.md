# O que é o AWS DocumentDB

## Definição

O AWS DocumentDB (com compatibilidade MongoDB) é um serviço de banco de dados de documentos totalmente gerenciado que oferece suporte a cargas de trabalho do MongoDB. O DocumentDB facilita o armazenamento, a consulta e a indexação de dados JSON.

## Características Principais

### Arquitetura Gerenciada
- **Separação de Compute e Storage**: Arquitetura que permite escalabilidade independente
- **Multi-AZ por padrão**: Alta disponibilidade automática
- **Backup automático**: Backup contínuo para S3
- **Patching automático**: Atualizações de segurança sem intervenção

### Compatibilidade MongoDB
- **API MongoDB 3.6 e 4.0**: Compatível com drivers e ferramentas existentes
- **Workloads suportadas**: Aplicações web, catálogos de conteúdo, perfis de usuário
- **Migração facilitada**: Uso de ferramentas nativas do MongoDB

### Integração AWS
- **VPC nativo**: Isolamento de rede completo
- **IAM integration**: Controle de acesso granular
- **CloudWatch**: Monitoramento e métricas integradas
- **EventBridge**: Eventos de cluster automatizados

## Posicionamento no Mercado

### Quando Usar DocumentDB
- ✅ Aplicações que já usam MongoDB
- ✅ Necessidade de gerenciamento automático
- ✅ Integração com ecossistema AWS
- ✅ Workloads de leitura intensiva
- ✅ Necessidade de alta disponibilidade

### Quando NÃO Usar DocumentDB
- ❌ Necessidade de sharding nativo
- ❌ Uso intensivo de transações ACID
- ❌ Dependência de features específicas do MongoDB 5.0+
- ❌ Necessidade de controle total sobre configuração
- ❌ Workloads que requerem GridFS

## Diferenças Arquiteturais

### MongoDB Tradicional
```
Aplicação → MongoDB Server → Storage Local
```

### AWS DocumentDB
```
Aplicação → DocumentDB Compute → Aurora Storage (S3)
```

## Casos de Uso Típicos

1. **Catálogos de Produtos**: E-commerce com estruturas flexíveis
2. **Perfis de Usuário**: Dados semi-estruturados de usuários
3. **Gestão de Conteúdo**: CMS com documentos variados
4. **IoT e Sensores**: Dados de telemetria em JSON
5. **Aplicações Mobile**: Backend para apps móveis

## Limitações Importantes

- Sem suporte a sharding automático
- Transações limitadas (apenas single-document)
- Algumas operações de agregação não suportadas
- GridFS não disponível
- Baseado em versões mais antigas do MongoDB

## Próximos Passos

Continue para os próximos documentos para entender:
- [Comparativo com MongoDB](./comparativo-mongodb.md)
- [Casos de Uso Detalhados](./casos-de-uso.md)