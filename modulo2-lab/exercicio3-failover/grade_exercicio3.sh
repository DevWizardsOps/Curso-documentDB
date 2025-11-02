#!/bin/bash

# Script de Validação - Exercício 3: Gerenciamento de Failover
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
    echo -e "${BLUE}  VALIDAÇÃO - EXERCÍCIO 3: FAILOVER            ${NC}"
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
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Por favor, informe seu ID de aluno:${NC}"
        read -p "ID do aluno: " STUDENT_ID
    else
        STUDENT_ID=$1
    fi
    
    if [ -z "$STUDENT_ID" ]; then
        print_result "FAIL" "ID do aluno é obrigatório"
        exit 1
    fi
    
    echo -e "${BLUE}Validando recursos para o aluno: ${STUDENT_ID}${NC}"
    echo
}

# Função para verificar cluster e topologia
check_cluster_topology() {
    echo -e "${BLUE}1. Verificando cluster e topologia...${NC}"
    
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    
    # Verificar se o cluster existe
    if ! aws docdb describe-db-clusters --db-cluster-identifier "$cluster_id" &> /dev/null; then
        print_result "FAIL" "Cluster $cluster_id não encontrado"
        return 1
    fi
    
    # Obter status do cluster
    local cluster_status=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$cluster_id" \
        --query 'DBClusters[0].Status' \
        --output text 2>/dev/null)
    
    case "$cluster_status" in
        "available")
            print_result "PASS" "Cluster disponível: $cluster_id"
            ;;
        *)
            print_result "WARN" "Cluster em status: $cluster_status"
            ;;
    esac
    
    # Verificar membros do cluster
    local cluster_members=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$cluster_id" \
        --query 'DBClusters[0].DBClusterMembers' \
        --output json 2>/dev/null)
    
    if [ $? -eq 0 ] && [ "$cluster_members" != "null" ]; then
        local member_count=$(echo "$cluster_members" | jq '. | length' 2>/dev/null || echo "0")
        local primary_count=$(echo "$cluster_members" | jq '[.[] | select(.IsClusterWriter == true)] | length' 2>/dev/null || echo "0")
        local replica_count=$(echo "$cluster_members" | jq '[.[] | select(.IsClusterWriter == false)] | length' 2>/dev/null || echo "0")
        
        print_result "PASS" "Total de instâncias: $member_count"
        print_result "PASS" "Instâncias primárias: $primary_count"
        print_result "PASS" "Instâncias réplicas: $replica_count"
        
        if [ "$replica_count" -gt 0 ]; then
            print_result "PASS" "Cluster configurado para failover (tem réplicas)"
        else
            print_result "WARN" "Cluster sem réplicas - failover limitado"
        fi
        
        # Mostrar topologia atual
        echo -e "${BLUE}   Topologia atual:${NC}"
        local primary_instance=$(echo "$cluster_members" | jq -r '.[] | select(.IsClusterWriter == true) | .DBInstanceIdentifier' 2>/dev/null)
        if [ -n "$primary_instance" ]; then
            echo "   - Primária: $primary_instance"
        fi
        
        local replica_instances=$(echo "$cluster_members" | jq -r '.[] | select(.IsClusterWriter == false) | .DBInstanceIdentifier' 2>/dev/null)
        if [ -n "$replica_instances" ]; then
            echo "$replica_instances" | while read -r replica; do
                echo "   - Réplica: $replica"
            done
        fi
    else
        print_result "FAIL" "Erro ao obter membros do cluster"
        return 1
    fi
    
    echo
}

# Função para verificar logs de failover
check_failover_logs() {
    echo -e "${BLUE}2. Verificando evidências de failover...${NC}"
    
    # Verificar se existem logs de teste de failover
    local log_files=(
        "failover-test-*.log"
        "endpoint-monitor-*.log"
        "./scripts/failover-test-*.log"
        "./scripts/endpoint-monitor-*.log"
    )
    
    local logs_found=0
    
    for pattern in "${log_files[@]}"; do
        if ls $pattern 2>/dev/null | head -1 >/dev/null; then
            local latest_log=$(ls -t $pattern 2>/dev/null | head -1)
            if [ -f "$latest_log" ]; then
                print_result "PASS" "Log de teste encontrado: $latest_log"
                ((logs_found++))
                
                # Verificar conteúdo do log
                if grep -q "Failover completo" "$latest_log" 2>/dev/null; then
                    print_result "PASS" "Evidência de failover completo no log"
                elif grep -q "Failover iniciado" "$latest_log" 2>/dev/null; then
                    print_result "WARN" "Failover iniciado mas pode não ter completado"
                fi
                
                # Extrair métricas se disponível
                local rto=$(grep "RTO Total:" "$latest_log" 2>/dev/null | tail -1 | sed 's/.*RTO Total: \([0-9]*\)s.*/\1/')
                if [ -n "$rto" ] && [ "$rto" -gt 0 ]; then
                    print_result "PASS" "RTO medido: ${rto}s"
                    if [ "$rto" -lt 120 ]; then
                        print_result "PASS" "RTO dentro do esperado (<120s)"
                    else
                        print_result "WARN" "RTO acima do esperado (>120s)"
                    fi
                fi
                
                break
            fi
        fi
    done
    
    if [ $logs_found -eq 0 ]; then
        print_result "WARN" "Nenhum log de teste de failover encontrado"
        print_result "INFO" "Execute: ./scripts/test-failover.sh ${STUDENT_ID}-lab-cluster-console"
    fi
    
    echo
}

# Função para verificar scripts de failover
check_failover_scripts() {
    echo -e "${BLUE}3. Verificando scripts de failover...${NC}"
    
    local scripts_dir="./scripts"
    local required_scripts=(
        "test-failover.sh"
        "monitor-endpoints.sh"
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
            if grep -q "describe-db-clusters" "$script_path" 2>/dev/null; then
                print_result "PASS" "Script atualizado com comandos corretos: $script"
            else
                print_result "WARN" "Script pode ter comandos desatualizados: $script"
            fi
        else
            print_result "FAIL" "Script não encontrado: $script_path"
        fi
    done
    
    if [ $scripts_found -eq ${#required_scripts[@]} ]; then
        print_result "PASS" "Todos os scripts de failover estão presentes"
    else
        print_result "WARN" "Scripts de failover incompletos ($scripts_found/${#required_scripts[@]})"
    fi
    
    echo
}

# Função para verificar aplicação de exemplo
check_example_application() {
    echo -e "${BLUE}4. Verificando aplicação de exemplo...${NC}"
    
    local example_file="./exemplos/connection-failover.js"
    
    if [ -f "$example_file" ]; then
        print_result "PASS" "Aplicação de exemplo encontrada: $example_file"
        
        # Verificar se o arquivo foi personalizado com o endpoint do aluno
        if grep -q "${STUDENT_ID}-lab-cluster-console" "$example_file" 2>/dev/null; then
            print_result "PASS" "Aplicação configurada com endpoint do aluno"
        else
            print_result "WARN" "Aplicação não configurada com endpoint específico do aluno"
            print_result "INFO" "Edite o arquivo e configure: ${STUDENT_ID}-lab-cluster-console.cluster-xxxxx.us-east-1.docdb.amazonaws.com"
        fi
        
        # Verificar se tem lógica de retry
        if grep -q "retry\|reconnect" "$example_file" 2>/dev/null; then
            print_result "PASS" "Aplicação tem lógica de reconexão"
        else
            print_result "WARN" "Aplicação pode não ter lógica de reconexão adequada"
        fi
        
        # Verificar se node_modules existe (se npm install foi executado)
        if [ -d "./exemplos/node_modules" ]; then
            print_result "PASS" "Dependências instaladas (node_modules encontrado)"
        else
            print_result "WARN" "Dependências não instaladas (execute: cd exemplos && npm install)"
        fi
    else
        print_result "FAIL" "Aplicação de exemplo não encontrada: $example_file"
    fi
    
    echo
}

# Função para testar failover em tempo real (opcional)
test_live_failover() {
    echo -e "${BLUE}5. Teste de failover em tempo real (opcional)...${NC}"
    
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    
    # Verificar se o cluster está disponível para teste
    local cluster_status=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$cluster_id" \
        --query 'DBClusters[0].Status' \
        --output text 2>/dev/null)
    
    if [ "$cluster_status" != "available" ]; then
        print_result "WARN" "Cluster não disponível para teste de failover (status: $cluster_status)"
        return
    fi
    
    # Verificar se há múltiplas instâncias
    local member_count=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$cluster_id" \
        --query 'length(DBClusters[0].DBClusterMembers)' \
        --output text 2>/dev/null)
    
    if [ "$member_count" -lt 2 ]; then
        print_result "WARN" "Cluster tem apenas $member_count instância(s) - failover limitado"
        return
    fi
    
    echo -e "${YELLOW}Deseja executar um teste de failover em tempo real? (y/N):${NC}"
    read -p "Resposta: " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_result "INFO" "Iniciando teste de failover..."
        
        # Obter primária atual
        local current_primary=$(aws docdb describe-db-clusters \
            --db-cluster-identifier "$cluster_id" \
            --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' \
            --output text 2>/dev/null)
        
        print_result "INFO" "Primária atual: $current_primary"
        
        # Executar failover
        if aws docdb failover-db-cluster --db-cluster-identifier "$cluster_id" &>/dev/null; then
            print_result "PASS" "Comando de failover executado com sucesso"
            
            # Aguardar alguns segundos
            echo -e "${BLUE}Aguardando failover completar...${NC}"
            sleep 10
            
            # Verificar nova primária
            local new_primary=$(aws docdb describe-db-clusters \
                --db-cluster-identifier "$cluster_id" \
                --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' \
                --output text 2>/dev/null)
            
            if [ "$new_primary" != "$current_primary" ]; then
                print_result "PASS" "Failover bem-sucedido: $current_primary → $new_primary"
            else
                print_result "WARN" "Primária não mudou - pode ainda estar em processo"
            fi
        else
            print_result "FAIL" "Erro ao executar comando de failover"
        fi
    else
        print_result "INFO" "Teste de failover em tempo real pulado"
    fi
    
    echo
}

# Função para gerar relatório final
generate_report() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}                RELATÓRIO FINAL                ${NC}"
    echo -e "${BLUE}================================================${NC}"
    
    local total_checks=4
    local passed_checks=0
    
    # Revalidar itens principais
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    
    # 1. Cluster com múltiplas instâncias
    if aws docdb describe-db-clusters --db-cluster-identifier "$cluster_id" &> /dev/null; then
        local member_count=$(aws docdb describe-db-clusters \
            --db-cluster-identifier "$cluster_id" \
            --query 'length(DBClusters[0].DBClusterMembers)' \
            --output text 2>/dev/null)
        if [ "$member_count" -ge 2 ]; then
            ((passed_checks++))
        fi
    fi
    
    # 2. Scripts de failover
    if [ -f "./scripts/test-failover.sh" ] && [ -f "./scripts/monitor-endpoints.sh" ]; then
        ((passed_checks++))
    fi
    
    # 3. Evidência de teste de failover
    if ls failover-test-*.log 2>/dev/null | head -1 >/dev/null || \
       ls ./scripts/failover-test-*.log 2>/dev/null | head -1 >/dev/null; then
        ((passed_checks++))
    fi
    
    # 4. Aplicação de exemplo configurada
    if [ -f "./exemplos/connection-failover.js" ]; then
        if grep -q "${STUDENT_ID}-lab-cluster-console" "./exemplos/connection-failover.js" 2>/dev/null; then
            ((passed_checks++))
        fi
    fi
    
    echo "Checklist do Exercício 3:"
    echo "✅ Cluster com múltiplas instâncias: $([ $passed_checks -ge 1 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Scripts de failover disponíveis: $([ $passed_checks -ge 2 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Teste de failover executado: $([ $passed_checks -ge 3 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Aplicação configurada para failover: $([ $passed_checks -ge 4 ] && echo "SIM" || echo "NÃO")"
    echo
    
    local percentage=$((passed_checks * 100 / total_checks))
    
    if [ $percentage -eq 100 ]; then
        print_result "PASS" "Exercício 3 CONCLUÍDO com sucesso! ($passed_checks/$total_checks)"
    elif [ $percentage -ge 75 ]; then
        print_result "WARN" "Exercício 3 PARCIALMENTE concluído ($passed_checks/$total_checks)"
    else
        print_result "FAIL" "Exercício 3 INCOMPLETO ($passed_checks/$total_checks)"
    fi
    
    echo
    echo -e "${BLUE}Próximo passo: ${NC}Exercício 4 - Monitoramento"
    echo
    echo -e "${MAGENTA}💡 Dicas para completar o exercício:${NC}"
    echo -e "   • Execute: ./scripts/test-failover.sh ${STUDENT_ID}-lab-cluster-console"
    echo -e "   • Configure: ./exemplos/connection-failover.js com seu endpoint"
    echo -e "   • Teste: cd exemplos && npm install && node connection-failover.js"
}

# Função principal
main() {
    print_header
    
    # Verificar pré-requisitos
    check_aws_cli
    
    # Obter ID do aluno
    get_student_id "$1"
    
    # Executar validações
    check_cluster_topology
    check_failover_logs
    check_failover_scripts
    check_example_application
    test_live_failover
    
    # Gerar relatório final
    generate_report
}

# Executar script
main "$@"