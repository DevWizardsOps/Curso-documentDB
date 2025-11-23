#!/bin/bash

# Script de Validação - Exercício 5: Operações de Manutenção e Atualizações
# Valida se todos os itens do checklist foram concluídos

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Função para imprimir cabeçalho
print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  VALIDAÇÃO - EXERCÍCIO 5: MANUTENÇÃO          ${NC}"
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
        echo -e "${YELLOW}Por favor, informe seu ID de aluno:${NC}"
        read -p "ID do aluno: " STUDENT_ID
    fi
    
    if [ -z "$STUDENT_ID" ]; then
        print_result "FAIL" "ID do aluno é obrigatório"
        exit 1
    fi
    
    echo -e "${BLUE}Validando recursos para o aluno: ${STUDENT_ID}${NC}"
    echo
}

# Função para verificar cluster base
check_base_cluster() {
    echo -e "${BLUE}1. Verificando cluster base...${NC}"
    
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    
    # Verificar se o cluster existe
    if ! aws docdb describe-db-clusters --db-cluster-identifier "$cluster_id" &> /dev/null; then
        print_result "FAIL" "Cluster base não encontrado: $cluster_id"
        print_result "WARN" "Execute primeiro o Exercício 1 para criar o cluster"
        return 1
    fi
    
    # Obter informações do cluster
    local cluster_info=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$cluster_id" \
        --query 'DBClusters[0].[Status,EngineVersion,PreferredMaintenanceWindow]' \
        --output text 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        local status=$(echo "$cluster_info" | cut -f1)
        local version=$(echo "$cluster_info" | cut -f2)
        local maint_window=$(echo "$cluster_info" | cut -f3)
        
        case "$status" in
            "available")
                print_result "PASS" "Cluster disponível: $cluster_id"
                ;;
            *)
                print_result "WARN" "Cluster em status: $status"
                ;;
        esac
        
        print_result "INFO" "Versão atual: $version"
        
        if [ -n "$maint_window" ] && [ "$maint_window" != "None" ]; then
            print_result "PASS" "Janela de manutenção configurada: $maint_window"
        else
            print_result "WARN" "Janela de manutenção não configurada"
        fi
        
        # Salvar informações para uso posterior
        export CLUSTER_VERSION="$version"
        export CLUSTER_STATUS="$status"
    else
        print_result "FAIL" "Erro ao obter informações do cluster"
        return 1
    fi
    
    echo
}

# Função para verificar snapshots pré-upgrade
check_pre_upgrade_snapshots() {
    echo -e "${BLUE}2. Verificando snapshots pré-upgrade...${NC}"
    
    # Buscar snapshots com padrões de pré-upgrade
    local snapshot_patterns=(
        "${STUDENT_ID}-pre-upgrade-snapshot-"
        "pre-upgrade-${STUDENT_ID}-"
    )
    
    local snapshots_found=0
    local recent_snapshots=0
    
    for pattern in "${snapshot_patterns[@]}"; do
        local snapshots=$(aws docdb describe-db-cluster-snapshots \
            --snapshot-type manual \
            --query "DBClusterSnapshots[?starts_with(DBClusterSnapshotIdentifier, '$pattern')].{ID:DBClusterSnapshotIdentifier,Status:Status,Created:SnapshotCreateTime}" \
            --output text 2>/dev/null)
        
        if [ -n "$snapshots" ]; then
            while IFS=$'\t' read -r snap_id status created; do
                if [ -n "$snap_id" ]; then
                    ((snapshots_found++))
                    
                    case "$status" in
                        "available")
                            print_result "PASS" "Snapshot pré-upgrade encontrado: $snap_id"
                            ;;
                        "creating")
                            print_result "WARN" "Snapshot em criação: $snap_id"
                            ;;
                        *)
                            print_result "WARN" "Snapshot em status: $status ($snap_id)"
                            ;;
                    esac
                    
                    # Verificar se é recente (últimos 7 dias)
                    if [ -n "$created" ]; then
                        local created_epoch=$(date -d "$created" +%s 2>/dev/null || echo "0")
                        local week_ago=$(($(date +%s) - 604800))
                        
                        if [ "$created_epoch" -gt "$week_ago" ]; then
                            ((recent_snapshots++))
                        fi
                    fi
                fi
            done <<< "$snapshots"
        fi
    done
    
    if [ $snapshots_found -gt 0 ]; then
        print_result "PASS" "Snapshots pré-upgrade encontrados: $snapshots_found"
        if [ $recent_snapshots -gt 0 ]; then
            print_result "PASS" "Snapshots recentes (últimos 7 dias): $recent_snapshots"
        else
            print_result "WARN" "Nenhum snapshot recente encontrado"
        fi
    else
        print_result "FAIL" "Nenhum snapshot pré-upgrade encontrado"
        print_result "INFO" "Padrões esperados:"
        for pattern in "${snapshot_patterns[@]}"; do
            print_result "INFO" "  - ${pattern}YYYYMMDD"
        done
    fi
    
    echo
}

# Função para verificar evidências de upgrade
check_upgrade_evidence() {
    echo -e "${BLUE}3. Verificando evidências de upgrade...${NC}"
    
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    
    # Verificar logs de upgrade
    local log_files=(
        "upgrade-${cluster_id}-*.log"
        "upgrade-*.log"
        "./scripts/upgrade-*.log"
    )
    
    local logs_found=0
    
    for pattern in "${log_files[@]}"; do
        if ls $pattern 2>/dev/null | head -1 >/dev/null; then
            local latest_log=$(ls -t $pattern 2>/dev/null | head -1)
            if [ -f "$latest_log" ]; then
                print_result "PASS" "Log de upgrade encontrado: $latest_log"
                ((logs_found++))
                
                # Verificar conteúdo do log
                if grep -q "Upgrade concluído" "$latest_log" 2>/dev/null; then
                    print_result "PASS" "Evidência de upgrade completo no log"
                elif grep -q "Iniciando upgrade" "$latest_log" 2>/dev/null; then
                    print_result "WARN" "Upgrade iniciado mas pode não ter completado"
                fi
                
                # Verificar se há informações de versão
                local version_info=$(grep -E "Versão.*->|Version.*:" "$latest_log" 2>/dev/null | tail -1)
                if [ -n "$version_info" ]; then
                    print_result "INFO" "Informação de versão: $version_info"
                fi
                
                break
            fi
        fi
    done
    
    # Verificar se a versão atual é diferente da padrão
    if [ -n "$CLUSTER_VERSION" ]; then
        # Versões comuns iniciais vs versões de upgrade
        case "$CLUSTER_VERSION" in
            "4.0.0"|"3.6.0")
                print_result "WARN" "Cluster ainda na versão inicial: $CLUSTER_VERSION"
                ;;
            "5.0.0"|"5.0.1"|"4.0.1")
                print_result "PASS" "Cluster em versão atualizada: $CLUSTER_VERSION"
                ;;
            *)
                print_result "INFO" "Versão do cluster: $CLUSTER_VERSION"
                ;;
        esac
    fi
    
    if [ $logs_found -eq 0 ]; then
        print_result "WARN" "Nenhum log de upgrade encontrado"
        print_result "INFO" "Execute: ./scripts/upgrade-cluster.sh ${cluster_id} 5.0.0"
    fi
    
    echo
}

# Função para verificar modificações de instâncias
check_instance_modifications() {
    echo -e "${BLUE}4. Verificando modificações de instâncias...${NC}"
    
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    
    # Obter instâncias do cluster
    local instances=$(aws docdb describe-db-instances \
        --filters "Name=db-cluster-id,Values=$cluster_id" \
        --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus]' \
        --output text 2>/dev/null)
    
    if [ -n "$instances" ]; then
        local instance_count=0
        local modified_instances=0
        
        echo -e "${BLUE}   Instâncias do cluster:${NC}"
        
        while IFS=$'\t' read -r instance_id instance_class status; do
            if [ -n "$instance_id" ]; then
                ((instance_count++))
                echo "   - $instance_id: $instance_class ($status)"
                
                # Verificar se foi modificada (não é a classe padrão inicial)
                case "$instance_class" in
                    "db.t3.medium")
                        print_result "INFO" "Instância em classe inicial: $instance_id"
                        ;;
                    "db.r5.large"|"db.r5.xlarge"|"db.r6g.large"|"db.r6g.xlarge")
                        print_result "PASS" "Instância modificada para classe superior: $instance_id"
                        ((modified_instances++))
                        ;;
                    *)
                        print_result "INFO" "Instância em classe: $instance_class ($instance_id)"
                        ;;
                esac
            fi
        done <<< "$instances"
        
        print_result "PASS" "Total de instâncias: $instance_count"
        
        if [ $modified_instances -gt 0 ]; then
            print_result "PASS" "Instâncias modificadas: $modified_instances"
        else
            print_result "WARN" "Nenhuma instância parece ter sido modificada"
        fi
        
        # Verificar se há mais de uma instância (escalonamento horizontal)
        if [ $instance_count -gt 1 ]; then
            print_result "PASS" "Cluster com múltiplas instâncias (escalonamento horizontal)"
        else
            print_result "INFO" "Cluster com instância única"
        fi
    else
        print_result "FAIL" "Nenhuma instância encontrada no cluster"
    fi
    
    echo
}

# Função para verificar parameter groups customizados
check_custom_parameter_groups() {
    echo -e "${BLUE}5. Verificando parameter groups customizados...${NC}"
    
    # Buscar parameter groups com prefixo do aluno
    local param_groups=$(aws docdb describe-db-cluster-parameter-groups \
        --query "DBClusterParameterGroups[?starts_with(DBClusterParameterGroupName, '$STUDENT_ID')].{Name:DBClusterParameterGroupName,Family:DBParameterGroupFamily,Description:Description}" \
        --output text 2>/dev/null)
    
    if [ -n "$param_groups" ]; then
        local pg_count=0
        
        while IFS=$'\t' read -r pg_name family description; do
            if [ -n "$pg_name" ]; then
                ((pg_count++))
                print_result "PASS" "Parameter group customizado encontrado: $pg_name"
                print_result "INFO" "  Família: $family"
                
                if [ -n "$description" ]; then
                    print_result "INFO" "  Descrição: $description"
                fi
            fi
        done <<< "$param_groups"
        
        print_result "PASS" "Parameter groups customizados: $pg_count"
        
        # Verificar se algum está aplicado ao cluster
        local cluster_id="${STUDENT_ID}-lab-cluster-console"
        local applied_pg=$(aws docdb describe-db-clusters \
            --db-cluster-identifier "$cluster_id" \
            --query 'DBClusters[0].DBClusterParameterGroup' \
            --output text 2>/dev/null)
        
        if [ -n "$applied_pg" ] && [ "$applied_pg" != "None" ]; then
            if echo "$applied_pg" | grep -q "$STUDENT_ID"; then
                print_result "PASS" "Parameter group customizado aplicado ao cluster: $applied_pg"
            else
                print_result "WARN" "Cluster usando parameter group padrão: $applied_pg"
            fi
        else
            print_result "WARN" "Cluster usando parameter group padrão"
        fi
    else
        print_result "FAIL" "Nenhum parameter group customizado encontrado"
        print_result "INFO" "Crie com: aws docdb create-db-cluster-parameter-group --db-cluster-parameter-group-name ${STUDENT_ID}-custom-docdb-params"
    fi
    
    echo
}

# Função para verificar scripts de manutenção
check_maintenance_scripts() {
    echo -e "${BLUE}6. Verificando scripts de manutenção...${NC}"
    
    local scripts_dir="./scripts"
    local required_scripts=(
        "upgrade-cluster.sh"
        "modify-instance.sh"
    )
    
    local scripts_found=0
    
    for script in "${required_scripts[@]}"; do
        local script_path="$scripts_dir/$script"
        if [ -f "$script_path" ]; then
            print_result "PASS" "Script encontrado: $script"
            ((scripts_found++))
            
            # Verificar se o script é executável
            if [ -x "$script_path" ]; then
                print_result "PASS" "Script executável: $script"
            else
                print_result "WARN" "Script não executável: $script (execute: chmod +x $script_path)"
            fi
            
            # Verificar se o script tem comandos corretos do DocumentDB
            if grep -q "docdb" "$script_path" 2>/dev/null; then
                print_result "PASS" "Script contém comandos DocumentDB: $script"
            else
                print_result "WARN" "Script pode não ter comandos DocumentDB: $script"
            fi
        else
            print_result "FAIL" "Script não encontrado: $script_path"
        fi
    done
    
    if [ $scripts_found -eq ${#required_scripts[@]} ]; then
        print_result "PASS" "Todos os scripts de manutenção estão presentes"
    else
        print_result "WARN" "Scripts de manutenção incompletos ($scripts_found/${#required_scripts[@]})"
    fi
    
    # Verificar checklist de manutenção
    local checklist_file="./checklists/manutencao.md"
    if [ -f "$checklist_file" ]; then
        print_result "PASS" "Checklist de manutenção disponível"
    else
        print_result "WARN" "Checklist de manutenção não encontrado"
    fi
    
    echo
}

# Função para verificar recursos opcionais
check_optional_resources() {
    echo -e "${BLUE}7. Verificando recursos opcionais...${NC}"
    
    # Verificar cluster de rollback
    local rollback_cluster="${STUDENT_ID}-lab-cluster-rollback"
    if aws docdb describe-db-clusters --db-cluster-identifier "$rollback_cluster" &> /dev/null; then
        print_result "PASS" "Cluster de rollback encontrado: $rollback_cluster (opcional)"
        
        local rollback_status=$(aws docdb describe-db-clusters \
            --db-cluster-identifier "$rollback_cluster" \
            --query 'DBClusters[0].Status' \
            --output text 2>/dev/null)
        print_result "INFO" "Status do cluster de rollback: $rollback_status"
    else
        print_result "INFO" "Cluster de rollback não encontrado (opcional)"
    fi
    
    # Verificar instâncias adicionais (escalonamento horizontal)
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    local additional_instances=$(aws docdb describe-db-instances \
        --filters "Name=db-cluster-id,Values=$cluster_id" \
        --query 'length(DBInstances[?contains(DBInstanceIdentifier, `4`) || contains(DBInstanceIdentifier, `3`)])' \
        --output text 2>/dev/null)
    
    if [ "$additional_instances" -gt 0 ]; then
        print_result "PASS" "Instâncias adicionais criadas (escalonamento horizontal): $additional_instances"
    else
        print_result "INFO" "Nenhuma instância adicional encontrada (opcional)"
    fi
    
    echo
}

# Função para gerar relatório final
generate_report() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}                RELATÓRIO FINAL                ${NC}"
    echo -e "${BLUE}================================================${NC}"
    
    local total_checks=5
    local passed_checks=0
    
    # Revalidar itens principais
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    
    # 1. Janela de manutenção configurada
    local maint_window=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$cluster_id" \
        --query 'DBClusters[0].PreferredMaintenanceWindow' \
        --output text 2>/dev/null)
    if [ -n "$maint_window" ] && [ "$maint_window" != "None" ]; then
        ((passed_checks++))
    fi
    
    # 2. Snapshot pré-upgrade criado
    local pre_upgrade_snapshots=$(aws docdb describe-db-cluster-snapshots \
        --snapshot-type manual \
        --query "DBClusterSnapshots[?starts_with(DBClusterSnapshotIdentifier, '${STUDENT_ID}-pre-upgrade') || starts_with(DBClusterSnapshotIdentifier, 'pre-upgrade-${STUDENT_ID}')].DBClusterSnapshotIdentifier" \
        --output text 2>/dev/null)
    if [ -n "$pre_upgrade_snapshots" ]; then
        ((passed_checks++))
    fi
    
    # 3. Upgrade executado (evidência por versão ou logs)
    local current_version=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$cluster_id" \
        --query 'DBClusters[0].EngineVersion' \
        --output text 2>/dev/null)
    if [ "$current_version" != "4.0.0" ] && [ "$current_version" != "3.6.0" ] || \
       ls upgrade-*.log 2>/dev/null | head -1 >/dev/null || \
       ls ./scripts/upgrade-*.log 2>/dev/null | head -1 >/dev/null; then
        ((passed_checks++))
    fi
    
    # 4. Instância modificada
    local instances=$(aws docdb describe-db-instances \
        --filters "Name=db-cluster-id,Values=$cluster_id" \
        --query 'DBInstances[*].DBInstanceClass' \
        --output text 2>/dev/null)
    if echo "$instances" | grep -qE "db\.r5\.|db\.r6g\." 2>/dev/null; then
        ((passed_checks++))
    fi
    
    # 5. Parameter group customizado
    local custom_pg=$(aws docdb describe-db-cluster-parameter-groups \
        --query "DBClusterParameterGroups[?starts_with(DBClusterParameterGroupName, '$STUDENT_ID')].DBClusterParameterGroupName" \
        --output text 2>/dev/null)
    if [ -n "$custom_pg" ]; then
        ((passed_checks++))
    fi
    
    echo "Checklist do Exercício 5:"
    echo "✅ Janela de manutenção configurada: $([ $passed_checks -ge 1 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Snapshot pré-upgrade criado: $([ $passed_checks -ge 2 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Upgrade executado (ou simulado): $([ $passed_checks -ge 3 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Instância modificada: $([ $passed_checks -ge 4 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Parameter group customizado: $([ $passed_checks -ge 5 ] && echo "SIM" || echo "NÃO")"
    echo
    
    local percentage=$((passed_checks * 100 / total_checks))
    
    if [ $percentage -eq 100 ]; then
        print_result "PASS" "Exercício 5 CONCLUÍDO com sucesso! ($passed_checks/$total_checks)"
    elif [ $percentage -ge 80 ]; then
        print_result "WARN" "Exercício 5 PARCIALMENTE concluído ($passed_checks/$total_checks)"
    else
        print_result "FAIL" "Exercício 5 INCOMPLETO ($passed_checks/$total_checks)"
    fi
    
    echo
    echo -e "${BLUE}Parabéns! ${NC}Você completou todos os exercícios do módulo DocumentDB!"
    echo
    echo -e "${MAGENTA}💡 Dicas para completar o exercício:${NC}"
    echo -e "   • Janela: aws docdb modify-db-cluster --preferred-maintenance-window"
    echo -e "   • Snapshot: aws docdb create-db-cluster-snapshot --db-cluster-snapshot-identifier ${STUDENT_ID}-pre-upgrade-snapshot-\$(date +%Y%m%d)"
    echo -e "   • Upgrade: ./scripts/upgrade-cluster.sh ${cluster_id} 5.0.0"
    echo -e "   • Instância: ./scripts/modify-instance.sh ${cluster_id}-1 db.r5.large"
    echo -e "   • Parameter: aws docdb create-db-cluster-parameter-group --db-cluster-parameter-group-name ${STUDENT_ID}-custom-docdb-params"
}

# Função principal
main() {
    print_header
    
    # Verificar pré-requisitos
    check_aws_cli
    
    # Obter ID do aluno
    get_student_id "$1"
    
    # Executar validações
    check_base_cluster
    check_pre_upgrade_snapshots
    check_upgrade_evidence
    check_instance_modifications
    check_custom_parameter_groups
    check_maintenance_scripts
    check_optional_resources
    
    # Gerar relatório final
    generate_report
}

# Executar script
main "$@"