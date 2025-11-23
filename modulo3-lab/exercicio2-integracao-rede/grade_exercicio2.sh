#!/bin/bash

# Script de Validação - Exercício 2: Integração com VPC e Security Groups
# Valida se todos os itens do checklist foram concluídos

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir cabeçalho
print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  VALIDAÇÃO - EXERCÍCIO 2: INTEGRAÇÃO DE REDE  ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo
}

# Função para imprimir resultado
print_result() {
    local status=$1
    local message=$2
    
    if [ "$status" = "PASS" ]; then
        echo -e "✅ ${GREEN}PASS${NC} - $message"
    elif [ "$status" = "FAIL" ]; then
        echo -e "❌ ${RED}FAIL${NC} - $message"
    elif [ "$status" = "WARN" ]; then
        echo -e "⚠️  ${YELLOW}WARN${NC} - $message"
    else
        echo -e "ℹ️  ${BLUE}INFO${NC} - $message"
    fi
}

# Função para verificar se AWS CLI está configurado
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_result "FAIL" "AWS CLI não está instalado"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_result "FAIL" "AWS CLI não está configurado ou sem permissões"
        exit 1
    fi
    
    print_result "PASS" "AWS CLI configurado e funcionando"
}

# Função para obter o ID do aluno
get_student_id() {
    # Usar variável de ambiente $ID se estiver definida
    if [ -n "$ID" ]; then
        STUDENT_ID="$ID"
        echo -e "${BLUE}Usando ID do ambiente: ${STUDENT_ID}${NC}"
    elif [ -n "$1" ]; then
        STUDENT_ID="$1"
    else
        echo -e "${YELLOW}Por favor, informe seu ID de aluno (mesmo usado no Módulo 2):${NC}"
        read -p "ID do aluno: " STUDENT_ID
    fi
    
    if [ -z "$STUDENT_ID" ]; then
        print_result "FAIL" "ID do aluno é obrigatório"
        exit 1
    fi
    
    echo -e "${BLUE}Validando recursos para o aluno: ${STUDENT_ID}${NC}"
    echo
}

# Função para verificar cluster e obter informações de rede
check_cluster_network() {
    echo -e "${BLUE}1. Verificando cluster e configuração de rede...${NC}"
    
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    
    if aws docdb describe-db-clusters --db-cluster-identifier "$cluster_id" &> /dev/null; then
        print_result "PASS" "Cluster encontrado: $cluster_id"
        
        # Obter informações de rede (usando comando do README)
        CLUSTER_SUBNET_GROUP=$(aws docdb describe-db-clusters \
            --db-cluster-identifier "$cluster_id" \
            --query 'DBClusters[0].DBSubnetGroup' \
            --output text 2>/dev/null)
        
        # Obter VPC do subnet group (comando exato do README)
        if [ -n "$CLUSTER_SUBNET_GROUP" ] && [ "$CLUSTER_SUBNET_GROUP" != "None" ]; then
            CLUSTER_VPC=$(aws docdb describe-db-subnet-groups \
                --db-subnet-group-name "$CLUSTER_SUBNET_GROUP" \
                --query 'DBSubnetGroups[0].VpcId' \
                --output text 2>/dev/null)
        fi
        
        CLUSTER_SECURITY_GROUPS=$(aws docdb describe-db-clusters \
            --db-cluster-identifier "$cluster_id" \
            --query 'DBClusters[0].VpcSecurityGroups[*].VpcSecurityGroupId' \
            --output text 2>/dev/null)
        
        print_result "INFO" "VPC: $CLUSTER_VPC"
        print_result "INFO" "Subnet Group: $CLUSTER_SUBNET_GROUP"
        print_result "INFO" "Security Groups: $CLUSTER_SECURITY_GROUPS"
        
    else
        print_result "FAIL" "Cluster não encontrado: $cluster_id"
        print_result "INFO" "Execute primeiro o Módulo 2 - Exercício 1"
        exit 1
    fi
    
    echo
}

# Função para verificar distribuição Multi-AZ
check_multi_az() {
    echo -e "${BLUE}2. Verificando distribuição Multi-AZ...${NC}"
    
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    
    # DocumentDB não tem campo MultiAZ como RDS, verificar por número de AZs
    local availability_zones
    availability_zones=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$cluster_id" \
        --query 'DBClusters[0].AvailabilityZones' \
        --output text 2>/dev/null)
    
    local az_count=$(echo "$availability_zones" | wc -w)
    
    if [ "$az_count" -ge 2 ]; then
        print_result "PASS" "Cluster configurado Multi-AZ ($az_count AZs)"
    else
        print_result "WARN" "Cluster em apenas $az_count AZ (recomendado: 2+)"
    fi
    
    # Mostrar AZs disponíveis
    if [ "$az_count" -gt 0 ]; then
        print_result "INFO" "AZs utilizadas: $availability_zones"
    fi
    
    # Verificar instâncias por AZ
    local instances_info
    instances_info=$(aws docdb describe-db-instances \
        --filters "Name=db-cluster-id,Values=$cluster_id" \
        --query 'DBInstances[*].[DBInstanceIdentifier,AvailabilityZone]' \
        --output text 2>/dev/null)
    
    if [ -n "$instances_info" ]; then
        print_result "INFO" "Distribuição de instâncias por AZ:"
        echo "$instances_info" | while read instance az; do
            print_result "INFO" "  $instance → $az"
        done
    fi
    
    echo
}

# Função para analisar subnets
check_subnets() {
    echo -e "${BLUE}3. Analisando configuração de subnets...${NC}"
    
    if [ -z "$CLUSTER_VPC" ] || [ "$CLUSTER_VPC" = "None" ]; then
        print_result "WARN" "VPC do cluster não identificada - usando subnet group"
        # Tentar obter VPC via subnet group
        if [ -n "$CLUSTER_SUBNET_GROUP" ]; then
            CLUSTER_VPC=$(aws docdb describe-db-subnet-groups \
                --db-subnet-group-name "$CLUSTER_SUBNET_GROUP" \
                --query 'DBSubnetGroups[0].VpcId' \
                --output text 2>/dev/null)
        fi
        
        if [ -z "$CLUSTER_VPC" ] || [ "$CLUSTER_VPC" = "None" ]; then
            print_result "FAIL" "Não foi possível identificar VPC"
            return
        fi
    fi
    
    # Listar subnets da VPC
    local subnets_info
    subnets_info=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$CLUSTER_VPC" \
        --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock,MapPublicIpOnLaunch]' \
        --output text 2>/dev/null)
    
    local total_subnets=0
    local public_subnets=0
    local private_subnets=0
    
    if [ -n "$subnets_info" ]; then
        while read subnet_id az cidr public_ip; do
            ((total_subnets++))
            if [ "$public_ip" = "True" ]; then
                ((public_subnets++))
                print_result "INFO" "Subnet Pública: $subnet_id ($az) - $cidr"
            else
                ((private_subnets++))
                print_result "INFO" "Subnet Privada: $subnet_id ($az) - $cidr"
            fi
        done <<< "$subnets_info"
        
        print_result "PASS" "Total de subnets: $total_subnets (Públicas: $public_subnets, Privadas: $private_subnets)"
        
        if [ "$private_subnets" -gt 0 ]; then
            print_result "PASS" "DocumentDB corretamente em subnets privadas"
        else
            print_result "WARN" "Nenhuma subnet privada encontrada"
        fi
    else
        print_result "FAIL" "Não foi possível listar subnets da VPC"
    fi
    
    # Verificar subnet group do DocumentDB
    if [ -n "$CLUSTER_SUBNET_GROUP" ]; then
        local subnet_group_info
        subnet_group_info=$(aws docdb describe-db-subnet-groups \
            --db-subnet-group-name "$CLUSTER_SUBNET_GROUP" \
            --query 'DBSubnetGroups[0].Subnets[*].[SubnetIdentifier,AvailabilityZone.Name]' \
            --output text 2>/dev/null)
        
        if [ -n "$subnet_group_info" ]; then
            local subnet_group_count
            subnet_group_count=$(echo "$subnet_group_info" | wc -l)
            print_result "PASS" "Subnet Group contém $subnet_group_count subnets"
            
            if [ "$subnet_group_count" -ge 2 ]; then
                print_result "PASS" "Subnet Group atende requisito mínimo (2+ subnets)"
            else
                print_result "WARN" "Subnet Group tem menos de 2 subnets"
            fi
        fi
    fi
    
    echo
}

# Função para verificar Security Groups
check_security_groups() {
    echo -e "${BLUE}4. Verificando Security Groups...${NC}"
    
    if [ -z "$CLUSTER_SECURITY_GROUPS" ]; then
        print_result "FAIL" "Security Groups do cluster não identificados"
        return
    fi
    
    for sg_id in $CLUSTER_SECURITY_GROUPS; do
        print_result "INFO" "Analisando Security Group: $sg_id"
        
        # Verificar regras de entrada
        local inbound_rules
        inbound_rules=$(aws ec2 describe-security-groups \
            --group-ids "$sg_id" \
            --query 'SecurityGroups[0].IpPermissions[*]' \
            --output json 2>/dev/null)
        
        if [ -n "$inbound_rules" ] && [ "$inbound_rules" != "[]" ]; then
            # Verificar se há regras permissivas (0.0.0.0/0)
            local open_rules
            open_rules=$(echo "$inbound_rules" | jq -r '.[] | select(.IpRanges[]?.CidrIp == "0.0.0.0/0") | .FromPort' 2>/dev/null)
            
            if [ -n "$open_rules" ]; then
                print_result "WARN" "Security Group tem regras permissivas (0.0.0.0/0)"
                print_result "INFO" "Portas abertas publicamente: $open_rules"
            else
                print_result "PASS" "Security Group não tem regras permissivas"
            fi
            
            # Verificar regras específicas para DocumentDB (porta 27017)
            local docdb_rules
            docdb_rules=$(echo "$inbound_rules" | jq -r '.[] | select(.FromPort == 27017) | .UserIdGroupPairs[]?.GroupId // .IpRanges[]?.CidrIp' 2>/dev/null)
            
            if [ -n "$docdb_rules" ]; then
                print_result "PASS" "Regras para DocumentDB (porta 27017) encontradas"
                echo "$docdb_rules" | while read rule; do
                    if [[ "$rule" == sg-* ]]; then
                        print_result "PASS" "  Acesso restrito ao Security Group: $rule"
                    else
                        print_result "WARN" "  Acesso por CIDR: $rule"
                    fi
                done
            else
                print_result "WARN" "Nenhuma regra específica para DocumentDB (porta 27017)"
            fi
        else
            print_result "WARN" "Security Group sem regras de entrada"
        fi
    done
    
    echo
}

# Função para verificar Security Group da aplicação
check_application_security_group() {
    echo -e "${BLUE}5. Verificando Security Group da aplicação...${NC}"
    
    local app_sg_name="${STUDENT_ID}-app-client-sg"
    
    # Verificar se Security Group da aplicação existe
    if aws ec2 describe-security-groups --group-names "$app_sg_name" &> /dev/null; then
        print_result "PASS" "Security Group da aplicação encontrado: $app_sg_name"
        
        local app_sg_id
        app_sg_id=$(aws ec2 describe-security-groups \
            --group-names "$app_sg_name" \
            --query 'SecurityGroups[0].GroupId' \
            --output text 2>/dev/null)
        
        # Verificar regras de saída para DocumentDB
        local egress_rules
        egress_rules=$(aws ec2 describe-security-groups \
            --group-ids "$app_sg_id" \
            --query 'SecurityGroups[0].IpPermissionsEgress[*]' \
            --output json 2>/dev/null)
        
        if [ -n "$egress_rules" ]; then
            local docdb_egress
            docdb_egress=$(echo "$egress_rules" | jq -r '.[] | select(.FromPort == 27017) | .UserIdGroupPairs[]?.GroupId' 2>/dev/null)
            
            if [ -n "$docdb_egress" ]; then
                print_result "PASS" "Regra de saída para DocumentDB configurada"
                print_result "INFO" "  Destino: $docdb_egress"
            else
                print_result "WARN" "Nenhuma regra de saída específica para DocumentDB"
            fi
        fi
        
    else
        print_result "FAIL" "Security Group da aplicação não encontrado: $app_sg_name"
        print_result "INFO" "Execute: aws ec2 create-security-group --group-name $app_sg_name --description 'App client SG'"
    fi
    
    echo
}

# Função para testar conectividade de rede
test_network_connectivity() {
    echo -e "${BLUE}6. Testando conectividade de rede...${NC}"
    
    local cluster_endpoint
    cluster_endpoint=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "${STUDENT_ID}-lab-cluster-console" \
        --query 'DBClusters[0].Endpoint' \
        --output text 2>/dev/null)
    
    if [ -n "$cluster_endpoint" ] && [ "$cluster_endpoint" != "None" ]; then
        print_result "INFO" "Endpoint do cluster: $cluster_endpoint"
        
        # Testar resolução DNS
        if nslookup "$cluster_endpoint" &> /dev/null; then
            print_result "PASS" "Resolução DNS do endpoint funcionando"
        else
            print_result "WARN" "Falha na resolução DNS do endpoint"
        fi
        
        # Testar conectividade TCP (só funciona se estiver na mesma VPC)
        if timeout 5 bash -c "</dev/tcp/$cluster_endpoint/27017" 2>/dev/null; then
            print_result "PASS" "Conectividade TCP na porta 27017 OK"
        else
            print_result "INFO" "Conectividade TCP falhou (normal se não estiver na mesma VPC)"
        fi
        
    else
        print_result "WARN" "Endpoint do cluster não disponível"
    fi
    
    echo
}

# Função para verificar instância EC2 de teste (opcional)
check_test_instance() {
    echo -e "${BLUE}7. Verificando instância EC2 de teste (opcional)...${NC}"
    
    local instance_name="${STUDENT_ID}-docdb-test-client"
    
    # Verificar se instância existe
    local instance_info
    instance_info=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$instance_name" "Name=instance-state-name,Values=running,stopped,pending" \
        --query 'Reservations[*].Instances[*].[InstanceId,State.Name,SecurityGroups[0].GroupId]' \
        --output text 2>/dev/null)
    
    if [ -n "$instance_info" ]; then
        while read instance_id state sg_id; do
            print_result "PASS" "Instância EC2 encontrada: $instance_id (Estado: $state)"
            print_result "INFO" "  Security Group: $sg_id"
        done <<< "$instance_info"
    else
        print_result "INFO" "Nenhuma instância EC2 de teste encontrada (opcional)"
    fi
    
    echo
}

# Função para gerar relatório final
generate_report() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}                RELATÓRIO FINAL                ${NC}"
    echo -e "${BLUE}================================================${NC}"
    
    local total_checks=7
    local passed_checks=0
    
    # Revalidar itens principais
    if aws docdb describe-db-clusters --db-cluster-identifier "${STUDENT_ID}-lab-cluster-console" &> /dev/null; then
        ((passed_checks++))
    fi
    
    # Verificar Multi-AZ (por número de AZs)
    local availability_zones
    availability_zones=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "${STUDENT_ID}-lab-cluster-console" \
        --query 'DBClusters[0].AvailabilityZones' \
        --output text 2>/dev/null)
    local az_count=$(echo "$availability_zones" | wc -w)
    if [ "$az_count" -ge 2 ]; then
        ((passed_checks++))
    fi
    
    # Verificar subnets (subnet group existe)
    if aws docdb describe-db-subnet-groups --db-subnet-group-name "${STUDENT_ID}-docdb-lab-subnet-group" &> /dev/null; then
        ((passed_checks++))
    fi
    
    # Verificar Security Groups sem regras permissivas
    local has_secure_sg=true
    for sg_id in $CLUSTER_SECURITY_GROUPS; do
        local open_rules
        open_rules=$(aws ec2 describe-security-groups \
            --group-ids "$sg_id" \
            --query 'SecurityGroups[0].IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]' \
            --output text 2>/dev/null)
        if [ -n "$open_rules" ]; then
            has_secure_sg=false
            break
        fi
    done
    if [ "$has_secure_sg" = true ]; then
        ((passed_checks++))
    fi
    
    # Verificar Security Group da aplicação
    if aws ec2 describe-security-groups --group-names "${STUDENT_ID}-app-client-sg" &> /dev/null; then
        ((passed_checks++))
    fi
    
    # Verificar conectividade (endpoint existe)
    local cluster_endpoint
    cluster_endpoint=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "${STUDENT_ID}-lab-cluster-console" \
        --query 'DBClusters[0].Endpoint' \
        --output text 2>/dev/null)
    if [ -n "$cluster_endpoint" ] && [ "$cluster_endpoint" != "None" ]; then
        ((passed_checks++))
    fi
    
    # Verificar regras DocumentDB
    local has_docdb_rules=false
    for sg_id in $CLUSTER_SECURITY_GROUPS; do
        local docdb_rules
        docdb_rules=$(aws ec2 describe-security-groups \
            --group-ids "$sg_id" \
            --query 'SecurityGroups[0].IpPermissions[?FromPort==`27017`]' \
            --output text 2>/dev/null)
        if [ -n "$docdb_rules" ]; then
            has_docdb_rules=true
            break
        fi
    done
    if [ "$has_docdb_rules" = true ]; then
        ((passed_checks++))
    fi
    
    # Contar checks individuais
    local cluster_ok=0
    local multiaz_ok=0
    local subnets_ok=0
    local sg_secure_ok=0
    local app_sg_ok=0
    local connectivity_ok=0
    local docdb_rules_ok=0
    
    # Verificar cada item individualmente
    if aws docdb describe-db-clusters --db-cluster-identifier "${STUDENT_ID}-lab-cluster-console" &> /dev/null; then
        cluster_ok=1
    fi
    
    local az_count
    az_count=$(aws docdb describe-db-clusters --db-cluster-identifier "${STUDENT_ID}-lab-cluster-console" --query 'DBClusters[0].AvailabilityZones' --output text 2>/dev/null | wc -w)
    if [ "$az_count" -ge 2 ]; then
        multiaz_ok=1
    fi
    
    if aws docdb describe-db-subnet-groups --db-subnet-group-name "${STUDENT_ID}-docdb-lab-subnet-group" &> /dev/null; then
        subnets_ok=1
    fi
    
    local has_secure_sg=1
    for sg_id in $CLUSTER_SECURITY_GROUPS; do
        local open_rules
        open_rules=$(aws ec2 describe-security-groups --group-ids "$sg_id" --query 'SecurityGroups[0].IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]' --output text 2>/dev/null)
        if [ -n "$open_rules" ]; then
            has_secure_sg=0
            break
        fi
    done
    sg_secure_ok=$has_secure_sg
    
    if aws ec2 describe-security-groups --group-names "${STUDENT_ID}-app-client-sg" &> /dev/null; then
        app_sg_ok=1
    fi
    
    local cluster_endpoint
    cluster_endpoint=$(aws docdb describe-db-clusters --db-cluster-identifier "${STUDENT_ID}-lab-cluster-console" --query 'DBClusters[0].Endpoint' --output text 2>/dev/null)
    if [ -n "$cluster_endpoint" ] && [ "$cluster_endpoint" != "None" ]; then
        connectivity_ok=1
    fi
    
    local has_docdb_rules=0
    for sg_id in $CLUSTER_SECURITY_GROUPS; do
        local docdb_rules
        docdb_rules=$(aws ec2 describe-security-groups --group-ids "$sg_id" --query 'SecurityGroups[0].IpPermissions[?FromPort==`27017`]' --output text 2>/dev/null)
        if [ -n "$docdb_rules" ]; then
            has_docdb_rules=1
            break
        fi
    done
    docdb_rules_ok=$has_docdb_rules
    
    echo "Checklist do Exercício 2:"
    echo "✅ Cluster DocumentDB disponível: $([ $cluster_ok -eq 1 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Configuração Multi-AZ: $([ $multiaz_ok -eq 1 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Subnets configuradas: $([ $subnets_ok -eq 1 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Security Groups sem regras permissivas: $([ $sg_secure_ok -eq 1 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Security Group da aplicação criado: $([ $app_sg_ok -eq 1 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Conectividade de rede funcionando: $([ $connectivity_ok -eq 1 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Regras DocumentDB configuradas: $([ $docdb_rules_ok -eq 1 ] && echo "SIM" || echo "NÃO")"
    
    # Recalcular total
    passed_checks=$((cluster_ok + multiaz_ok + subnets_ok + sg_secure_ok + app_sg_ok + connectivity_ok + docdb_rules_ok))
    echo
    
    local percentage=$((passed_checks * 100 / total_checks))
    
    if [ $percentage -eq 100 ]; then
        print_result "PASS" "Exercício 2 CONCLUÍDO com sucesso! ($passed_checks/$total_checks)"
    elif [ $percentage -ge 75 ]; then
        print_result "WARN" "Exercício 2 PARCIALMENTE concluído ($passed_checks/$total_checks)"
    else
        print_result "FAIL" "Exercício 2 INCOMPLETO ($passed_checks/$total_checks)"
    fi
    
    echo
    echo -e "${BLUE}Próximo passo: ${NC}Exercício 3 - Controle de Acesso e TLS"
    echo -e "${BLUE}Comandos úteis:${NC}"
    echo "  export ID=\"$STUDENT_ID\""
    echo "  aws ec2 describe-security-groups --group-ids $CLUSTER_SECURITY_GROUPS"
    echo "  aws docdb describe-db-clusters --db-cluster-identifier ${STUDENT_ID}-lab-cluster-console"
}

# Função principal
main() {
    print_header
    
    # Verificar pré-requisitos
    check_aws_cli
    
    # Obter ID do aluno
    get_student_id "$1"
    
    # Executar validações
    check_cluster_network
    check_multi_az
    check_subnets
    check_security_groups
    check_application_security_group
    test_network_connectivity
    check_test_instance
    
    # Gerar relatório final
    generate_report
}

# Executar script
main "$@"