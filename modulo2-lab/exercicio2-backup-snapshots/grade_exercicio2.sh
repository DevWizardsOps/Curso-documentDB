#!/bin/bash

# Script de Validação - Exercício 2: Backup e Snapshots Automáticos
# Valida se todos os itens do checklist foram concluídos

# Remover set -e para permitir que o script continue mesmo com falhas
# set -

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir cabeçalho
print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  VALIDAÇÃO - EXERCÍCIO 2: BACKUP E SNAPSHOTS  ${NC}"
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

# Função para verificar política de backup
check_backup_policy() {
    echo -e "${BLUE}1. Verificando política de backup automático...${NC}"
    
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    
    # Verificar se o cluster existe
    if ! aws docdb describe-db-clusters --db-cluster-identifier "$cluster_id" &> /dev/null; then
        print_result "FAIL" "Cluster $cluster_id não encontrado"
        return 1
    fi
    
    # Obter configurações de backup
    local backup_info=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$cluster_id" \
        --query 'DBClusters[0].[BackupRetentionPeriod, PreferredBackupWindow]' \
        --output text 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        print_result "FAIL" "Erro ao obter informações de backup do cluster"
        return 1
    fi
    
    local retention_period=$(echo "$backup_info" | cut -f1)
    local backup_window=$(echo "$backup_info" | cut -f2)
    
    # Verificar período de retenção (deve ser >= 7 dias)
    if [ "$retention_period" -ge 7 ]; then
        print_result "PASS" "Período de retenção configurado: $retention_period dias"
    else
        print_result "FAIL" "Período de retenção insuficiente: $retention_period dias (mínimo: 7)"
    fi
    
    # Verificar janela de backup
    if [ -n "$backup_window" ] && [ "$backup_window" != "None" ]; then
        print_result "PASS" "Janela de backup configurada: $backup_window"
    else
        print_result "WARN" "Janela de backup não configurada explicitamente"
    fi
    
    echo
}

# Função para verificar snapshot manual
check_manual_snapshot() {
    echo -e "${BLUE}2. Verificando snapshots manuais...${NC}"
    
    # Definir os dois padrões de snapshots
    local snapshot_console="${STUDENT_ID}-lab-snapshot-manual-console-001"
    local snapshot_cli="${STUDENT_ID}-lab-snapshot-manual-001"
    
    local found_snapshots=0
    local region=$(aws configure get region)
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    
    # Verificar snapshot criado via Console
    echo -e "${BLUE}   2.1. Verificando snapshot via Console...${NC}"
    local console_status
    console_status=$(aws docdb describe-db-cluster-snapshots \
        --db-cluster-snapshot-identifier "$snapshot_console" \
        --query 'DBClusterSnapshots[0].Status' \
        --output text 2>/dev/null) || console_status="NotFound"
    
    if [ "$console_status" != "NotFound" ] && [ "$console_status" != "None" ]; then
        case "$console_status" in
            "available")
                print_result "PASS" "Snapshot Console criado: $snapshot_console"
                ((found_snapshots++))
                
                # Verificar tags do snapshot console
                local console_arn="arn:aws:rds:${region}:${account_id}:cluster-snapshot:${snapshot_console}"
                local console_tags
                console_tags=$(aws docdb list-tags-for-resource \
                    --resource-name "$console_arn" \
                    --query 'TagList[?Key==`Purpose`].Value' \
                    --output text 2>/dev/null) || console_tags=""
                
                if [ -n "$console_tags" ] && [ "$console_tags" != "None" ]; then
                    print_result "PASS" "Tags configuradas no snapshot Console"
                else
                    print_result "WARN" "Tags não encontradas no snapshot Console"
                fi
                ;;
            "creating")
                print_result "WARN" "Snapshot Console em criação: $snapshot_console"
                ((found_snapshots++))
                ;;
            *)
                print_result "WARN" "Snapshot Console em status: $console_status"
                ;;
        esac
    else
        print_result "INFO" "Snapshot Console não encontrado: $snapshot_console"
    fi
    
    # Verificar snapshot criado via CLI
    echo -e "${BLUE}   2.2. Verificando snapshot via CLI...${NC}"
    local cli_status
    cli_status=$(aws docdb describe-db-cluster-snapshots \
        --db-cluster-snapshot-identifier "$snapshot_cli" \
        --query 'DBClusterSnapshots[0].Status' \
        --output text 2>/dev/null) || cli_status="NotFound"
    
    if [ "$cli_status" != "NotFound" ] && [ "$cli_status" != "None" ]; then
        case "$cli_status" in
            "available")
                print_result "PASS" "Snapshot CLI criado: $snapshot_cli"
                ((found_snapshots++))
                
                # Verificar tags do snapshot CLI
                local cli_arn="arn:aws:rds:${region}:${account_id}:cluster-snapshot:${snapshot_cli}"
                local cli_tags
                cli_tags=$(aws docdb list-tags-for-resource \
                    --resource-name "$cli_arn" \
                    --query 'TagList[?Key==`Purpose`].Value' \
                    --output text 2>/dev/null) || cli_tags=""
                
                if [ -n "$cli_tags" ] && [ "$cli_tags" != "None" ]; then
                    print_result "PASS" "Tags configuradas no snapshot CLI"
                else
                    print_result "WARN" "Tags não encontradas no snapshot CLI"
                fi
                ;;
            "creating")
                print_result "WARN" "Snapshot CLI em criação: $snapshot_cli"
                ((found_snapshots++))
                ;;
            *)
                print_result "WARN" "Snapshot CLI em status: $cli_status"
                ;;
        esac
    else
        print_result "INFO" "Snapshot CLI não encontrado: $snapshot_cli"
    fi
    
    # Resultado final da verificação de snapshots
    if [ $found_snapshots -gt 0 ]; then
        print_result "PASS" "Snapshots manuais encontrados: $found_snapshots"
        if [ $found_snapshots -eq 2 ]; then
            print_result "INFO" "Ambos os métodos (Console e CLI) foram testados!"
        fi
    else
        print_result "FAIL" "Nenhum snapshot manual encontrado com os padrões esperados"
        
        # Verificar se existem outros snapshots do aluno
        local other_snapshots
        other_snapshots=$(aws docdb describe-db-cluster-snapshots \
            --snapshot-type manual \
            --query "DBClusterSnapshots[?starts_with(DBClusterSnapshotIdentifier, '$STUDENT_ID')].DBClusterSnapshotIdentifier" \
            --output text 2>/dev/null) || other_snapshots=""
        
        if [ -n "$other_snapshots" ]; then
            print_result "INFO" "Outros snapshots encontrados: $other_snapshots"
            print_result "WARN" "Verifique se os nomes seguem os padrões:"
            print_result "WARN" "  Console: $snapshot_console"
            print_result "WARN" "  CLI: $snapshot_cli"
        fi
        
        return 1
    fi
    
    echo
}

# Função para verificar cluster restaurado
check_restored_cluster() {
    echo -e "${BLUE}3. Verificando cluster restaurado...${NC}"
    
    local restored_cluster_id="${STUDENT_ID}-lab-cluster-restored"
    
    # Verificar se o cluster restaurado existe
    local cluster_status=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$restored_cluster_id" \
        --query 'DBClusters[0].Status' \
        --output text 2>/dev/null)
    
    if [ $? -ne 0 ] || [ "$cluster_status" = "None" ]; then
        print_result "FAIL" "Cluster restaurado $restored_cluster_id não encontrado"
        return 1
    fi
    
    case "$cluster_status" in
        "available")
            print_result "PASS" "Cluster restaurado e disponível: $restored_cluster_id"
            ;;
        "creating"|"backing-up"|"modifying")
            print_result "WARN" "Cluster restaurado em processo: $cluster_status"
            ;;
        *)
            print_result "WARN" "Cluster restaurado em status: $cluster_status"
            ;;
    esac
    
    # Verificar instâncias do cluster restaurado
    local instances=$(aws docdb describe-db-instances \
        --filters "Name=db-cluster-id,Values=$restored_cluster_id" \
        --query 'DBInstances[].DBInstanceStatus' \
        --output text 2>/dev/null)
    
    if [ -n "$instances" ]; then
        local instance_count=$(echo "$instances" | wc -w)
        print_result "PASS" "Instâncias no cluster restaurado: $instance_count"
    else
        print_result "WARN" "Nenhuma instância encontrada no cluster restaurado"
    fi
    
    echo
}

# Função para verificar recursos opcionais
check_optional_resources() {
    echo -e "${BLUE}4. Verificando recursos opcionais...${NC}"
    
    # Verificar cluster PITR
    local pitr_cluster_id="${STUDENT_ID}-lab-cluster-pitr"
    if aws docdb describe-db-clusters --db-cluster-identifier "$pitr_cluster_id" &> /dev/null; then
        print_result "PASS" "Cluster PITR encontrado: $pitr_cluster_id (opcional)"
    else
        print_result "INFO" "Cluster PITR não encontrado (opcional)"
    fi
    
    # Listar todos os snapshots do aluno
    local all_snapshots=$(aws docdb describe-db-cluster-snapshots \
        --snapshot-type manual \
        --query "DBClusterSnapshots[?starts_with(DBClusterSnapshotIdentifier, '$STUDENT_ID')].DBClusterSnapshotIdentifier" \
        --output text 2>/dev/null)
    
    if [ -n "$all_snapshots" ]; then
        local snapshot_count=$(echo "$all_snapshots" | wc -w)
        print_result "PASS" "Total de snapshots manuais encontrados: $snapshot_count"
        
        # Mostrar lista de snapshots
        echo -e "${BLUE}   Snapshots encontrados:${NC}"
        for snapshot in $all_snapshots; do
            local status=$(aws docdb describe-db-cluster-snapshots \
                --db-cluster-snapshot-identifier "$snapshot" \
                --query 'DBClusterSnapshots[0].Status' \
                --output text 2>/dev/null)
            echo "   - $snapshot ($status)"
        done
    else
        print_result "WARN" "Nenhum snapshot manual encontrado com prefixo $STUDENT_ID"
    fi
    
    echo
}

# Função para gerar relatório final
generate_report() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}                RELATÓRIO FINAL                ${NC}"
    echo -e "${BLUE}================================================${NC}"
    
    local total_checks=3
    local passed_checks=0
    
    # Revalidar itens principais
    if aws docdb describe-db-clusters --db-cluster-identifier "${STUDENT_ID}-lab-cluster-console" &> /dev/null; then
        local retention=$(aws docdb describe-db-clusters \
            --db-cluster-identifier "${STUDENT_ID}-lab-cluster-console" \
            --query 'DBClusters[0].BackupRetentionPeriod' \
            --output text 2>/dev/null)
        if [ "$retention" -ge 7 ]; then
            ((passed_checks++))
        fi
    fi
    
    # Verificar se pelo menos um dos snapshots existe
    if aws docdb describe-db-cluster-snapshots --db-cluster-snapshot-identifier "${STUDENT_ID}-lab-snapshot-manual-console-001" &> /dev/null || \
       aws docdb describe-db-cluster-snapshots --db-cluster-snapshot-identifier "${STUDENT_ID}-lab-snapshot-manual-001" &> /dev/null; then
        ((passed_checks++))
    fi
    
    if aws docdb describe-db-clusters --db-cluster-identifier "${STUDENT_ID}-lab-cluster-restored" &> /dev/null; then
        ((passed_checks++))
    fi
    
    echo "Checklist do Exercício 2:"
    echo "✅ Política de backup configurada: $([ $passed_checks -ge 1 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Snapshot manual criado com prefixo: $([ $passed_checks -ge 2 ] && echo "SIM" || echo "NÃO")"
    echo "   (Console: ${STUDENT_ID}-lab-snapshot-manual-console-001 ou CLI: ${STUDENT_ID}-lab-snapshot-manual-001)"
    echo "✅ Cluster restaurado a partir de snapshot: $([ $passed_checks -ge 3 ] && echo "SIM" || echo "NÃO")"
    echo
    
    local percentage=$((passed_checks * 100 / total_checks))
    
    if [ $percentage -eq 100 ]; then
        print_result "PASS" "Exercício 2 CONCLUÍDO com sucesso! ($passed_checks/$total_checks)"
    elif [ $percentage -ge 66 ]; then
        print_result "WARN" "Exercício 2 PARCIALMENTE concluído ($passed_checks/$total_checks)"
    else
        print_result "FAIL" "Exercício 2 INCOMPLETO ($passed_checks/$total_checks)"
    fi
    
    echo
    echo -e "${BLUE}Próximo passo: ${NC}Exercício 3 - Failover"
}

# Função principal
main() {
    print_header
    
    # Verificar pré-requisitos
    check_aws_cli
    
    # Obter ID do aluno
    get_student_id "$1"
    
    # Executar validações
    check_backup_policy
    check_manual_snapshot
    check_restored_cluster
    check_optional_resources
    
    # Gerar relatório final
    generate_report
}

# Executar script
main "$@"