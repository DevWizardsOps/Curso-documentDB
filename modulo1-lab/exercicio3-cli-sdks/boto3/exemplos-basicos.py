#!/usr/bin/env python3
"""
Exemplos Básicos - AWS SDK Boto3 para DocumentDB
Módulo 1 - Conceitos e Consultas (SEM criar recursos)

Este arquivo contém exemplos teóricos de como usar Boto3 com DocumentDB.
IMPORTANTE: Estes são exemplos conceituais para aprendizado.
"""

import boto3
import json
from datetime import datetime, timedelta
from botocore.exceptions import ClientError, NoCredentialsError


class DocumentDBManager:
    """
    Classe para gerenciar operações do DocumentDB via Boto3
    Foco em operações de consulta e monitoramento
    """
    
    def __init__(self, region_name='us-east-1'):
        """
        Inicializa o cliente DocumentDB
        
        Args:
            region_name (str): Região AWS para conectar
        """
        try:
            self.docdb_client = boto3.client('docdb', region_name=region_name)
            self.cloudwatch_client = boto3.client('cloudwatch', region_name=region_name)
            self.logs_client = boto3.client('logs', region_name=region_name)
            self.region = region_name
            print(f"✅ Cliente DocumentDB inicializado na região: {region_name}")
        except NoCredentialsError:
            print("❌ Erro: Credenciais AWS não configuradas")
            raise
        except Exception as e:
            print(f"❌ Erro ao inicializar cliente: {e}")
            raise

    def list_clusters(self):
        """
        Lista todos os clusters DocumentDB na região
        
        Returns:
            list: Lista de clusters com informações básicas
        """
        try:
            response = self.docdb_client.describe_db_clusters()
            clusters = []
            
            for cluster in response['DBClusters']:
                cluster_info = {
                    'identifier': cluster['DBClusterIdentifier'],
                    'status': cluster['Status'],
                    'engine': cluster['Engine'],
                    'engine_version': cluster['EngineVersion'],
                    'endpoint': cluster.get('Endpoint', 'N/A'),
                    'reader_endpoint': cluster.get('ReaderEndpoint', 'N/A'),
                    'port': cluster.get('Port', 27017),
                    'multi_az': cluster.get('MultiAZ', False),
                    'backup_retention': cluster.get('BackupRetentionPeriod', 0),
                    'created_time': cluster.get('ClusterCreateTime', 'N/A')
                }
                clusters.append(cluster_info)
            
            print(f"📋 Encontrados {len(clusters)} clusters")
            return clusters
            
        except ClientError as e:
            print(f"❌ Erro ao listar clusters: {e}")
            return []

    def get_cluster_details(self, cluster_identifier):
        """
        Obtém detalhes específicos de um cluster
        
        Args:
            cluster_identifier (str): Identificador do cluster
            
        Returns:
            dict: Detalhes completos do cluster
        """
        try:
            response = self.docdb_client.describe_db_clusters(
                DBClusterIdentifier=cluster_identifier
            )
            
            if not response['DBClusters']:
                print(f"❌ Cluster '{cluster_identifier}' não encontrado")
                return None
            
            cluster = response['DBClusters'][0]
            
            details = {
                'basic_info': {
                    'identifier': cluster['DBClusterIdentifier'],
                    'status': cluster['Status'],
                    'engine': f"{cluster['Engine']} {cluster['EngineVersion']}",
                    'created': cluster.get('ClusterCreateTime', 'N/A')
                },
                'connectivity': {
                    'endpoint': cluster.get('Endpoint', 'N/A'),
                    'reader_endpoint': cluster.get('ReaderEndpoint', 'N/A'),
                    'port': cluster.get('Port', 27017),
                    'vpc_security_groups': [sg['VpcSecurityGroupId'] for sg in cluster.get('VpcSecurityGroups', [])]
                },
                'configuration': {
                    'multi_az': cluster.get('MultiAZ', False),
                    'backup_retention_period': cluster.get('BackupRetentionPeriod', 0),
                    'preferred_backup_window': cluster.get('PreferredBackupWindow', 'N/A'),
                    'preferred_maintenance_window': cluster.get('PreferredMaintenanceWindow', 'N/A'),
                    'storage_encrypted': cluster.get('StorageEncrypted', False),
                    'kms_key_id': cluster.get('KmsKeyId', 'Default')
                },
                'network': {
                    'db_subnet_group_name': cluster.get('DBSubnetGroup', 'N/A'),
                    'availability_zones': cluster.get('AvailabilityZones', [])
                }
            }
            
            print(f"✅ Detalhes obtidos para cluster: {cluster_identifier}")
            return details
            
        except ClientError as e:
            print(f"❌ Erro ao obter detalhes do cluster: {e}")
            return None

    def list_instances(self, cluster_identifier=None):
        """
        Lista instâncias DocumentDB
        
        Args:
            cluster_identifier (str, optional): Filtrar por cluster específico
            
        Returns:
            list: Lista de instâncias
        """
        try:
            if cluster_identifier:
                response = self.docdb_client.describe_db_instances(
                    Filters=[
                        {
                            'Name': 'db-cluster-id',
                            'Values': [cluster_identifier]
                        }
                    ]
                )
            else:
                response = self.docdb_client.describe_db_instances()
            
            instances = []
            for instance in response['DBInstances']:
                instance_info = {
                    'identifier': instance['DBInstanceIdentifier'],
                    'status': instance['DBInstanceStatus'],
                    'instance_class': instance['DBInstanceClass'],
                    'availability_zone': instance.get('AvailabilityZone', 'N/A'),
                    'cluster_identifier': instance.get('DBClusterIdentifier', 'N/A'),
                    'endpoint': instance.get('Endpoint', {}).get('Address', 'N/A'),
                    'port': instance.get('Endpoint', {}).get('Port', 27017),
                    'promotion_tier': instance.get('PromotionTier', 0),
                    'created_time': instance.get('InstanceCreateTime', 'N/A')
                }
                instances.append(instance_info)
            
            print(f"📋 Encontradas {len(instances)} instâncias")
            return instances
            
        except ClientError as e:
            print(f"❌ Erro ao listar instâncias: {e}")
            return []

    def list_snapshots(self, cluster_identifier=None, snapshot_type='all'):
        """
        Lista snapshots disponíveis
        
        Args:
            cluster_identifier (str, optional): Filtrar por cluster
            snapshot_type (str): 'manual', 'automated', ou 'all'
            
        Returns:
            list: Lista de snapshots
        """
        try:
            params = {}
            if cluster_identifier:
                params['DBClusterIdentifier'] = cluster_identifier
            if snapshot_type != 'all':
                params['SnapshotType'] = snapshot_type
            
            response = self.docdb_client.describe_db_cluster_snapshots(**params)
            
            snapshots = []
            for snapshot in response['DBClusterSnapshots']:
                snapshot_info = {
                    'identifier': snapshot['DBClusterSnapshotIdentifier'],
                    'cluster_identifier': snapshot['DBClusterIdentifier'],
                    'status': snapshot['Status'],
                    'snapshot_type': snapshot['SnapshotType'],
                    'created_time': snapshot.get('SnapshotCreateTime', 'N/A'),
                    'allocated_storage': snapshot.get('AllocatedStorage', 0),
                    'engine': snapshot.get('Engine', 'N/A'),
                    'engine_version': snapshot.get('EngineVersion', 'N/A')
                }
                snapshots.append(snapshot_info)
            
            print(f"📋 Encontrados {len(snapshots)} snapshots")
            return snapshots
            
        except ClientError as e:
            print(f"❌ Erro ao listar snapshots: {e}")
            return []

    def get_cluster_metrics(self, cluster_identifier, hours=1):
        """
        Obtém métricas do CloudWatch para um cluster
        
        Args:
            cluster_identifier (str): Identificador do cluster
            hours (int): Número de horas para buscar métricas
            
        Returns:
            dict: Métricas do cluster
        """
        try:
            end_time = datetime.utcnow()
            start_time = end_time - timedelta(hours=hours)
            
            metrics = {}
            
            # Lista de métricas importantes
            metric_names = [
                'CPUUtilization',
                'DatabaseConnections',
                'ReadLatency',
                'WriteLatency',
                'ReadThroughput',
                'WriteThroughput'
            ]
            
            for metric_name in metric_names:
                try:
                    response = self.cloudwatch_client.get_metric_statistics(
                        Namespace='AWS/DocDB',
                        MetricName=metric_name,
                        Dimensions=[
                            {
                                'Name': 'DBClusterIdentifier',
                                'Value': cluster_identifier
                            }
                        ],
                        StartTime=start_time,
                        EndTime=end_time,
                        Period=300,  # 5 minutos
                        Statistics=['Average', 'Maximum']
                    )
                    
                    datapoints = response['Datapoints']
                    if datapoints:
                        # Ordenar por timestamp
                        datapoints.sort(key=lambda x: x['Timestamp'])
                        
                        metrics[metric_name] = {
                            'latest_average': datapoints[-1].get('Average', 0),
                            'latest_maximum': datapoints[-1].get('Maximum', 0),
                            'datapoints_count': len(datapoints),
                            'period_hours': hours
                        }
                    else:
                        metrics[metric_name] = {
                            'latest_average': 0,
                            'latest_maximum': 0,
                            'datapoints_count': 0,
                            'period_hours': hours
                        }
                        
                except ClientError as e:
                    print(f"⚠️ Erro ao obter métrica {metric_name}: {e}")
                    metrics[metric_name] = None
            
            print(f"📊 Métricas obtidas para cluster: {cluster_identifier}")
            return metrics
            
        except Exception as e:
            print(f"❌ Erro ao obter métricas: {e}")
            return {}

    def list_parameter_groups(self):
        """
        Lista parameter groups disponíveis
        
        Returns:
            list: Lista de parameter groups
        """
        try:
            response = self.docdb_client.describe_db_cluster_parameter_groups()
            
            parameter_groups = []
            for pg in response['DBClusterParameterGroups']:
                pg_info = {
                    'name': pg['DBClusterParameterGroupName'],
                    'family': pg['DBParameterGroupFamily'],
                    'description': pg.get('Description', 'N/A')
                }
                parameter_groups.append(pg_info)
            
            print(f"📋 Encontrados {len(parameter_groups)} parameter groups")
            return parameter_groups
            
        except ClientError as e:
            print(f"❌ Erro ao listar parameter groups: {e}")
            return []

    def get_parameter_group_parameters(self, parameter_group_name):
        """
        Obtém parâmetros de um parameter group específico
        
        Args:
            parameter_group_name (str): Nome do parameter group
            
        Returns:
            list: Lista de parâmetros
        """
        try:
            response = self.docdb_client.describe_db_cluster_parameters(
                DBClusterParameterGroupName=parameter_group_name
            )
            
            parameters = []
            for param in response['Parameters']:
                param_info = {
                    'name': param['ParameterName'],
                    'value': param.get('ParameterValue', 'N/A'),
                    'description': param.get('Description', 'N/A'),
                    'is_modifiable': param.get('IsModifiable', False),
                    'data_type': param.get('DataType', 'N/A'),
                    'allowed_values': param.get('AllowedValues', 'N/A')
                }
                parameters.append(param_info)
            
            print(f"📋 Encontrados {len(parameters)} parâmetros")
            return parameters
            
        except ClientError as e:
            print(f"❌ Erro ao obter parâmetros: {e}")
            return []

    def check_cluster_events(self, cluster_identifier, hours=24):
        """
        Verifica eventos recentes de um cluster
        
        Args:
            cluster_identifier (str): Identificador do cluster
            hours (int): Horas para buscar eventos
            
        Returns:
            list: Lista de eventos
        """
        try:
            start_time = datetime.utcnow() - timedelta(hours=hours)
            
            response = self.docdb_client.describe_events(
                SourceIdentifier=cluster_identifier,
                SourceType='db-cluster',
                StartTime=start_time,
                Duration=hours * 60  # em minutos
            )
            
            events = []
            for event in response['Events']:
                event_info = {
                    'date': event.get('Date', 'N/A'),
                    'message': event.get('Message', 'N/A'),
                    'event_categories': event.get('EventCategories', []),
                    'source_id': event.get('SourceId', 'N/A')
                }
                events.append(event_info)
            
            print(f"📋 Encontrados {len(events)} eventos nas últimas {hours} horas")
            return events
            
        except ClientError as e:
            print(f"❌ Erro ao verificar eventos: {e}")
            return []

    def generate_connection_string(self, cluster_identifier, username='docdbadmin'):
        """
        Gera string de conexão MongoDB para o cluster
        
        Args:
            cluster_identifier (str): Identificador do cluster
            username (str): Nome de usuário
            
        Returns:
            str: String de conexão MongoDB
        """
        try:
            cluster_details = self.get_cluster_details(cluster_identifier)
            if not cluster_details:
                return None
            
            endpoint = cluster_details['connectivity']['endpoint']
            port = cluster_details['connectivity']['port']
            
            # String de conexão básica (sem senha por segurança)
            connection_string = (
                f"mongodb://{username}:PASSWORD@{endpoint}:{port}/"
                f"?tls=true&tlsCAFile=global-bundle.pem&replicaSet=rs0"
                f"&readPreference=secondaryPreferred&retryWrites=false"
            )
            
            print(f"🔗 String de conexão gerada para: {cluster_identifier}")
            print("⚠️ Substitua 'PASSWORD' pela senha real")
            
            return connection_string
            
        except Exception as e:
            print(f"❌ Erro ao gerar string de conexão: {e}")
            return None

    def print_cluster_summary(self, cluster_identifier):
        """
        Imprime um resumo completo do cluster
        
        Args:
            cluster_identifier (str): Identificador do cluster
        """
        print(f"\n{'='*60}")
        print(f"RESUMO DO CLUSTER: {cluster_identifier}")
        print(f"{'='*60}")
        
        # Detalhes básicos
        details = self.get_cluster_details(cluster_identifier)
        if details:
            print(f"\n📋 INFORMAÇÕES BÁSICAS:")
            for key, value in details['basic_info'].items():
                print(f"  {key.replace('_', ' ').title()}: {value}")
            
            print(f"\n🔗 CONECTIVIDADE:")
            for key, value in details['connectivity'].items():
                print(f"  {key.replace('_', ' ').title()}: {value}")
            
            print(f"\n⚙️ CONFIGURAÇÃO:")
            for key, value in details['configuration'].items():
                print(f"  {key.replace('_', ' ').title()}: {value}")
        
        # Instâncias
        print(f"\n🖥️ INSTÂNCIAS:")
        instances = self.list_instances(cluster_identifier)
        for instance in instances:
            print(f"  • {instance['identifier']} ({instance['instance_class']}) - {instance['status']}")
        
        # Métricas recentes
        print(f"\n📊 MÉTRICAS (última hora):")
        metrics = self.get_cluster_metrics(cluster_identifier, 1)
        for metric_name, metric_data in metrics.items():
            if metric_data:
                avg = metric_data['latest_average']
                max_val = metric_data['latest_maximum']
                print(f"  • {metric_name}: Avg={avg:.2f}, Max={max_val:.2f}")
        
        # String de conexão
        print(f"\n🔗 STRING DE CONEXÃO:")
        conn_str = self.generate_connection_string(cluster_identifier)
        if conn_str:
            print(f"  {conn_str}")
        
        print(f"\n{'='*60}")


def main():
    """
    Função principal com exemplos de uso
    """
    print("🚀 Exemplos Boto3 para DocumentDB - Módulo 1")
    print("=" * 50)
    
    try:
        # Inicializar manager
        docdb_manager = DocumentDBManager(region_name='us-east-1')
        
        # Exemplo 1: Listar todos os clusters
        print("\n1️⃣ Listando clusters disponíveis:")
        clusters = docdb_manager.list_clusters()
        for cluster in clusters:
            print(f"  • {cluster['identifier']} - {cluster['status']}")
        
        # Exemplo 2: Se houver clusters, mostrar detalhes do primeiro
        if clusters:
            first_cluster = clusters[0]['identifier']
            print(f"\n2️⃣ Detalhes do cluster: {first_cluster}")
            docdb_manager.print_cluster_summary(first_cluster)
        
        # Exemplo 3: Listar parameter groups
        print("\n3️⃣ Parameter groups disponíveis:")
        parameter_groups = docdb_manager.list_parameter_groups()
        for pg in parameter_groups:
            print(f"  • {pg['name']} ({pg['family']})")
        
        # Exemplo 4: Listar snapshots
        print("\n4️⃣ Snapshots disponíveis:")
        snapshots = docdb_manager.list_snapshots()
        for snapshot in snapshots[:5]:  # Mostrar apenas os 5 primeiros
            print(f"  • {snapshot['identifier']} - {snapshot['status']}")
        
        print("\n✅ Exemplos executados com sucesso!")
        
    except Exception as e:
        print(f"❌ Erro durante execução: {e}")


if __name__ == "__main__":
    main()


# ============================================================================
# EXEMPLOS ADICIONAIS PARA ESTUDO
# ============================================================================

def example_error_handling():
    """
    Exemplo de tratamento de erros com Boto3
    """
    try:
        client = boto3.client('docdb', region_name='us-east-1')
        
        # Tentar acessar cluster inexistente
        response = client.describe_db_clusters(
            DBClusterIdentifier='cluster-inexistente'
        )
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']
        
        if error_code == 'DBClusterNotFoundFault':
            print("Cluster não encontrado")
        elif error_code == 'AccessDenied':
            print("Acesso negado - verifique permissões IAM")
        else:
            print(f"Erro: {error_code} - {error_message}")
    
    except NoCredentialsError:
        print("Credenciais AWS não configuradas")
    
    except Exception as e:
        print(f"Erro inesperado: {e}")


def example_pagination():
    """
    Exemplo de paginação com Boto3
    """
    client = boto3.client('docdb', region_name='us-east-1')
    
    # Usar paginator para listar muitos snapshots
    paginator = client.get_paginator('describe_db_cluster_snapshots')
    
    page_iterator = paginator.paginate(
        SnapshotType='manual',
        PaginationConfig={
            'MaxItems': 100,
            'PageSize': 20
        }
    )
    
    all_snapshots = []
    for page in page_iterator:
        all_snapshots.extend(page['DBClusterSnapshots'])
    
    print(f"Total de snapshots encontrados: {len(all_snapshots)}")


def example_waiter():
    """
    Exemplo de uso de waiters (para operações assíncronas)
    """
    client = boto3.client('docdb', region_name='us-east-1')
    
    # Exemplo conceitual - aguardar cluster ficar disponível
    # waiter = client.get_waiter('db_cluster_available')
    # waiter.wait(
    #     DBClusterIdentifier='my-cluster',
    #     WaiterConfig={
    #         'Delay': 30,  # segundos entre checks
    #         'MaxAttempts': 40  # máximo de tentativas
    #     }
    # )
    
    print("Waiter example - aguardaria cluster ficar disponível")


# ============================================================================
# CONFIGURAÇÕES E CONSTANTES
# ============================================================================

# Configurações padrão
DEFAULT_REGION = 'us-east-1'
DEFAULT_ENGINE_VERSION = '5.0.0'
DEFAULT_INSTANCE_CLASS = 'db.t3.medium'

# Métricas importantes do DocumentDB
IMPORTANT_METRICS = [
    'CPUUtilization',
    'DatabaseConnections',
    'ReadLatency',
    'WriteLatency',
    'ReadThroughput',
    'WriteThroughput',
    'NetworkReceiveThroughput',
    'NetworkTransmitThroughput',
    'FreeableMemory',
    'SwapUsage'
]

# Parâmetros importantes do DocumentDB
IMPORTANT_PARAMETERS = [
    'tls',
    'audit_logs',
    'ttl_monitor',
    'profiler',
    'profiler_threshold_ms'
]

print("📚 Arquivo de exemplos Boto3 carregado com sucesso!")
print("💡 Execute main() para ver exemplos em ação")
print("📖 Explore as funções individuais para aprender mais")