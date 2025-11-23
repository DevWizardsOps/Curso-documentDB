#!/bin/bash

# Script de Validação - Exercício 4: Monitoramento com CloudWatch e EventBridge
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
    echo -e "${BLUE}  VALIDAÇÃO - EXERCÍCIO 4: MONITORAMENTO       ${NC}"
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

# Função para verificar dashboards do CloudWatch
check_cloudwatch_dashboards() {
    echo -e "${BLUE}1. Verificando dashboards do CloudWatch...${NC}"
    
    local dashboard_patterns=(
        "${STUDENT_ID}-DocumentDB-Dashboard"
        "${STUDENT_ID}-DocumentDB-Dashboard-ByAWSCli"
    )
    
    local dashboards_found=0
    
    for dashboard_name in "${dashboard_patterns[@]}"; do
        if aws cloudwatch get-dashboard --dashboard-name "$dashboard_name" &> /dev/null; then
            print_result "PASS" "Dashboard encontrado: $dashboard_name"
            ((dashboards_found++))
            
            # Verificar se o dashboard contém métricas do cluster correto
            local dashboard_body=$(aws cloudwatch get-dashboard \
                --dashboard-name "$dashboard_name" \
                --query 'DashboardBody' \
                --output text 2>/dev/null)
            
            if echo "$dashboard_body" | grep -q "${STUDENT_ID}-lab-cluster-console" 2>/dev/null; then
                print_result "PASS" "Dashboard configurado para o cluster do aluno"
            else
                print_result "WARN" "Dashboard pode não estar configurado para o cluster correto"
            fi
            
            # Verificar widgets essenciais
            local essential_metrics=("CPUUtilization" "DatabaseConnections" "ReadLatency" "WriteLatency")
            local metrics_found=0
            
            for metric in "${essential_metrics[@]}"; do
                if echo "$dashboard_body" | grep -q "$metric" 2>/dev/null; then
                    ((metrics_found++))
                fi
            done
            
            if [ $metrics_found -ge 3 ]; then
                print_result "PASS" "Dashboard contém métricas essenciais ($metrics_found/4)"
            else
                print_result "WARN" "Dashboard com poucas métricas essenciais ($metrics_found/4)"
            fi
        else
            print_result "INFO" "Dashboard não encontrado: $dashboard_name"
        fi
    done
    
    if [ $dashboards_found -eq 0 ]; then
        print_result "FAIL" "Nenhum dashboard encontrado com prefixo do aluno"
        print_result "INFO" "Dashboards esperados:"
        for dashboard_name in "${dashboard_patterns[@]}"; do
            print_result "INFO" "  - $dashboard_name"
        done
    else
        print_result "PASS" "Dashboards encontrados: $dashboards_found"
    fi
    
    echo
}

# Função para verificar tópico SNS
check_sns_topic() {
    echo -e "${BLUE}2. Verificando tópico SNS...${NC}"
    
    local topic_name="${STUDENT_ID}-documentdb-alerts"
    
    # Verificar se o tópico existe
    local topic_arn=$(aws sns list-topics \
        --query "Topics[?contains(TopicArn, '$topic_name')].TopicArn" \
        --output text 2>/dev/null)
    
    if [ -n "$topic_arn" ] && [ "$topic_arn" != "None" ]; then
        print_result "PASS" "Tópico SNS encontrado: $topic_name"
        print_result "INFO" "ARN: $topic_arn"
        
        # Verificar subscriptions
        local subscriptions=$(aws sns list-subscriptions-by-topic \
            --topic-arn "$topic_arn" \
            --query 'Subscriptions[].Protocol' \
            --output text 2>/dev/null)
        
        if [ -n "$subscriptions" ]; then
            local sub_count=$(echo "$subscriptions" | wc -w)
            print_result "PASS" "Subscriptions configuradas: $sub_count"
            
            if echo "$subscriptions" | grep -q "email"; then
                print_result "PASS" "Subscription por email configurada"
            else
                print_result "WARN" "Nenhuma subscription por email encontrada"
            fi
        else
            print_result "WARN" "Nenhuma subscription encontrada no tópico"
        fi
        
        # Salvar ARN para uso posterior
        export TOPIC_ARN="$topic_arn"
    else
        print_result "FAIL" "Tópico SNS não encontrado: $topic_name"
        return 1
    fi
    
    echo
}

# Função para verificar alarmes do CloudWatch
check_cloudwatch_alarms() {
    echo -e "${BLUE}3. Verificando alarmes do CloudWatch...${NC}"
    
    # Buscar alarmes com prefixo do aluno
    local alarms=$(aws cloudwatch describe-alarms \
        --query "MetricAlarms[?starts_with(AlarmName, '$STUDENT_ID')].AlarmName" \
        --output text 2>/dev/null)
    
    if [ -n "$alarms" ]; then
        local alarm_count=$(echo "$alarms" | wc -w)
        print_result "PASS" "Alarmes encontrados: $alarm_count"
        
        # Verificar alarmes específicos
        local essential_alarms=(
            "${STUDENT_ID}-DocumentDB-HighCPU"
        )
        
        local essential_found=0
        
        for alarm_name in "${essential_alarms[@]}"; do
            if echo "$alarms" | grep -q "$alarm_name"; then
                print_result "PASS" "Alarme essencial encontrado: $alarm_name"
                ((essential_found++))
                
                # Verificar configuração do alarme
                local alarm_info=$(aws cloudwatch describe-alarms \
                    --alarm-names "$alarm_name" \
                    --query 'MetricAlarms[0].[Threshold,ComparisonOperator,AlarmActions[0]]' \
                    --output text 2>/dev/null)
                
                if [ $? -eq 0 ]; then
                    local threshold=$(echo "$alarm_info" | cut -f1)
                    local operator=$(echo "$alarm_info" | cut -f2)
                    local action=$(echo "$alarm_info" | cut -f3)
                    
                    print_result "INFO" "  Threshold: $threshold, Operator: $operator"
                    
                    if [ -n "$action" ] && [ "$action" != "None" ]; then
                        print_result "PASS" "  Ação configurada no alarme"
                        
                        if echo "$action" | grep -q "$STUDENT_ID-documentdb-alerts"; then
                            print_result "PASS" "  Alarme vinculado ao tópico SNS correto"
                        else
                            print_result "WARN" "  Alarme pode não estar vinculado ao tópico SNS correto"
                        fi
                    else
                        print_result "WARN" "  Nenhuma ação configurada no alarme"
                    fi
                fi
            else
                print_result "INFO" "Alarme essencial não encontrado: $alarm_name"
            fi
        done
        
        # Listar todos os alarmes do aluno
        echo -e "${BLUE}   Alarmes encontrados:${NC}"
        for alarm in $alarms; do
            local state=$(aws cloudwatch describe-alarms \
                --alarm-names "$alarm" \
                --query 'MetricAlarms[0].StateValue' \
                --output text 2>/dev/null)
            echo "   - $alarm ($state)"
        done
        
    else
        print_result "FAIL" "Nenhum alarme encontrado com prefixo: $STUDENT_ID"
    fi
    
    echo
}

# Função para verificar regras do EventBridge
check_eventbridge_rules() {
    echo -e "${BLUE}4. Verificando regras do EventBridge...${NC}"
    
    # Buscar regras com prefixo do aluno
    local rules=$(aws events list-rules \
        --query "Rules[?starts_with(Name, '$STUDENT_ID')].Name" \
        --output text 2>/dev/null)
    
    if [ -n "$rules" ]; then
        local rule_count=$(echo "$rules" | wc -w)
        print_result "PASS" "Regras EventBridge encontradas: $rule_count"
        
        # Verificar regras específicas
        local essential_rules=(
            "${STUDENT_ID}-documentdb-failover-events"
            "${STUDENT_ID}-documentdb-backup-events"
        )
        
        local rules_found=0
        
        for rule_name in "${essential_rules[@]}"; do
            if echo "$rules" | grep -q "$rule_name"; then
                print_result "PASS" "Regra encontrada: $rule_name"
                ((rules_found++))
                
                # Verificar estado da regra
                local rule_state=$(aws events describe-rule \
                    --name "$rule_name" \
                    --query 'State' \
                    --output text 2>/dev/null)
                
                if [ "$rule_state" = "ENABLED" ]; then
                    print_result "PASS" "  Regra habilitada"
                else
                    print_result "WARN" "  Regra não habilitada (estado: $rule_state)"
                fi
                
                # Verificar targets da regra
                local targets=$(aws events list-targets-by-rule \
                    --rule "$rule_name" \
                    --query 'Targets[].Arn' \
                    --output text 2>/dev/null)
                
                if [ -n "$targets" ]; then
                    local target_count=$(echo "$targets" | wc -w)
                    print_result "PASS" "  Targets configurados: $target_count"
                    
                    if echo "$targets" | grep -q "$STUDENT_ID-documentdb-alerts"; then
                        print_result "PASS" "  Target vinculado ao tópico SNS correto"
                    else
                        print_result "WARN" "  Target pode não estar vinculado ao tópico SNS correto"
                    fi
                else
                    print_result "WARN" "  Nenhum target configurado para a regra"
                fi
            else
                print_result "INFO" "Regra não encontrada: $rule_name"
            fi
        done
        
        # Listar todas as regras do aluno
        echo -e "${BLUE}   Regras encontradas:${NC}"
        for rule in $rules; do
            local state=$(aws events describe-rule \
                --name "$rule" \
                --query 'State' \
                --output text 2>/dev/null)
            echo "   - $rule ($state)"
        done
        
    else
        print_result "FAIL" "Nenhuma regra EventBridge encontrada com prefixo: $STUDENT_ID"
    fi
    
    echo
}

# Função para verificar cluster base
check_base_cluster() {
    echo -e "${BLUE}5. Verificando cluster base para monitoramento...${NC}"
    
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    
    # Verificar se o cluster existe e está disponível
    local cluster_status=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$cluster_id" \
        --query 'DBClusters[0].Status' \
        --output text 2>/dev/null)
    
    if [ $? -eq 0 ] && [ "$cluster_status" != "None" ]; then
        case "$cluster_status" in
            "available")
                print_result "PASS" "Cluster base disponível: $cluster_id"
                ;;
            *)
                print_result "WARN" "Cluster base em status: $cluster_status"
                ;;
        esac
        
        # Verificar se há métricas disponíveis
        local metrics_available=$(aws cloudwatch list-metrics \
            --namespace AWS/DocDB \
            --dimensions Name=DBClusterIdentifier,Value="$cluster_id" \
            --query 'length(Metrics)' \
            --output text 2>/dev/null)
        
        if [ "$metrics_available" -gt 0 ]; then
            print_result "PASS" "Métricas disponíveis no CloudWatch: $metrics_available"
        else
            print_result "WARN" "Poucas ou nenhuma métrica disponível no CloudWatch"
            print_result "INFO" "Aguarde alguns minutos para as métricas aparecerem"
        fi
    else
        print_result "FAIL" "Cluster base não encontrado: $cluster_id"
        print_result "WARN" "Execute primeiro o Exercício 1 para criar o cluster"
        return 1
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
    
    # 1. Dashboard criado
    if aws cloudwatch get-dashboard --dashboard-name "${STUDENT_ID}-DocumentDB-Dashboard" &> /dev/null || \
       aws cloudwatch get-dashboard --dashboard-name "${STUDENT_ID}-DocumentDB-Dashboard-ByAWSCli" &> /dev/null; then
        ((passed_checks++))
    fi
    
    # 2. Tópico SNS criado
    local topic_exists=$(aws sns list-topics \
        --query "Topics[?contains(TopicArn, '${STUDENT_ID}-documentdb-alerts')].TopicArn" \
        --output text 2>/dev/null)
    if [ -n "$topic_exists" ]; then
        ((passed_checks++))
    fi
    
    # 3. Alarmes criados
    local alarms_exist=$(aws cloudwatch describe-alarms \
        --query "MetricAlarms[?starts_with(AlarmName, '$STUDENT_ID')].AlarmName" \
        --output text 2>/dev/null)
    if [ -n "$alarms_exist" ]; then
        ((passed_checks++))
    fi
    
    # 4. Regras EventBridge criadas
    local rules_exist=$(aws events list-rules \
        --query "Rules[?starts_with(Name, '$STUDENT_ID')].Name" \
        --output text 2>/dev/null)
    if [ -n "$rules_exist" ]; then
        ((passed_checks++))
    fi
    
    echo "Checklist do Exercício 4:"
    echo "✅ Dashboard criado com prefixo: $([ $passed_checks -ge 1 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Tópico SNS criado com prefixo: $([ $passed_checks -ge 2 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Alarmes criados com prefixo: $([ $passed_checks -ge 3 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Regras EventBridge criadas com prefixo: $([ $passed_checks -ge 4 ] && echo "SIM" || echo "NÃO")"
    echo
    
    local percentage=$((passed_checks * 100 / total_checks))
    
    if [ $percentage -eq 100 ]; then
        print_result "PASS" "Exercício 4 CONCLUÍDO com sucesso! ($passed_checks/$total_checks)"
    elif [ $percentage -ge 75 ]; then
        print_result "WARN" "Exercício 4 PARCIALMENTE concluído ($passed_checks/$total_checks)"
    else
        print_result "FAIL" "Exercício 4 INCOMPLETO ($passed_checks/$total_checks)"
    fi
    
    echo
    echo -e "${BLUE}Próximo passo: ${NC}Exercício 5 - Manutenção"
    echo
    echo -e "${MAGENTA}💡 Dicas para completar o exercício:${NC}"
    echo -e "   • Dashboard: Crie via Console ou CLI com prefixo ${STUDENT_ID}"
    echo -e "   • SNS: aws sns create-topic --name ${STUDENT_ID}-documentdb-alerts"
    echo -e "   • Alarmes: Configure com dimensão DBClusterIdentifier=${STUDENT_ID}-lab-cluster-console"
    echo -e "   • EventBridge: Crie regras com prefixo ${STUDENT_ID} e pattern para eventos DocumentDB"
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
    check_cloudwatch_dashboards
    check_sns_topic
    check_cloudwatch_alarms
    check_eventbridge_rules
    
    # Gerar relatório final
    generate_report
}

# Executar script
main "$@"