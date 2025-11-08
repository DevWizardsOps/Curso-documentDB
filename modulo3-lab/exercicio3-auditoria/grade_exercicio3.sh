#!/bin/bash

# Script de Validação - Exercício 3: Auditoria DocumentDB
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
    echo -e "${BLUE}  VALIDAÇÃO - EXERCÍCIO 3: AUDITORIA DOCUMENTDB ${NC}"
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

# Função para verificar se mongosh está instalado
check_mongosh() {
    if ! command -v mongosh &> /dev/null; then
        print_result "FAIL" "mongosh não está instalado"
        print_result "INFO" "Instale com: npm install -g mongosh"
        exit 1
    fi
    
    print_result "PASS" "mongosh instalado e disponível"
}

# Função para obter o ID do aluno
get_student_id() {
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Por favor, informe seu ID de aluno (mesmo usado nos exercícios anteriores):${NC}"
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

# Função para verificar cluster e parameter group
check_cluster_and_parameter_group() {
    echo -e "${BLUE}1. Verificando cluster e parameter group de auditoria...${NC}"
    
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    local parameter_group_name="${STUDENT_ID}-lab-audit-parameter-group"
    
    # Verificar se cluster existe
    if aws docdb describe-db-clusters --db-cluster-identifier "$cluster_id" &> /dev/null; then
        print_result "PASS" "Cluster encontrado: $cluster_id"
        
        # Verificar status do cluster
        local cluster_status
        cluster_status=$(aws docdb describe-db-clusters \
            --db-cluster-identifier "$cluster_id" \
            --query 'DBClusters[0].Status' \
            --output text 2>/dev/null)
        
        if [ "$cluster_status" = "available" ]; then
            print_result "PASS" "Cluster disponível"
        else
            print_result "WARN" "Cluster em status: $cluster_status"
        fi
        
        # Verificar parameter group atual do cluster
        local current_pg
        current_pg=$(aws docdb describe-db-clusters \
            --db-cluster-identifier "$cluster_id" \
            --query 'DBClusters[0].DBClusterParameterGroup' \
            --output text 2>/dev/null)
        
        print_result "INFO" "Parameter Group atual: $current_pg"
        
        if [ "$current_pg" = "$parameter_group_name" ]; then
            print_result "PASS" "Cluster usando parameter group customizado"
        else
            print_result "WARN" "Cluster não está usando parameter group customizado"
        fi
        
    else
        print_result "FAIL" "Cluster não encontrado: $cluster_id"
        print_result "INFO" "Execute primeiro os exercícios anteriores"
        exit 1
    fi
    
    # Verificar se parameter group customizado existe
    if aws docdb describe-db-cluster-parameter-groups --db-cluster-parameter-group-name "$parameter_group_name" &> /dev/null; then
        print_result "PASS" "Parameter group customizado encontrado: $parameter_group_name"
        
        # Verificar configuração de auditoria
        local audit_setting
        audit_setting=$(aws docdb describe-db-cluster-parameters \
            --db-cluster-parameter-group-name "$parameter_group_name" \
            --query 'Parameters[?ParameterName==`audit_logs`].ParameterValue' \
            --output text 2>/dev/null)
        
        if [ -n "$audit_setting" ]; then
            print_result "INFO" "Configuração audit_logs: $audit_setting"
            
            case "$audit_setting" in
                "all"|"dml"|"enabled")
                    print_result "PASS" "Auditoria habilitada corretamente"
                    ;;
                "disabled")
                    print_result "FAIL" "Auditoria desabilitada"
                    ;;
                *)
                    print_result "WARN" "Configuração de auditoria não reconhecida: $audit_setting"
                    ;;
            esac
        else
            print_result "WARN" "Configuração audit_logs não encontrada"
        fi
        
    else
        print_result "FAIL" "Parameter group customizado não encontrado: $parameter_group_name"
    fi
    
    echo
}

# Função para verificar instâncias e status de reinicialização
check_instances_status() {
    echo -e "${BLUE}2. Verificando status das instâncias...${NC}"
    
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    
    # Listar instâncias do cluster
    local instances_info
    instances_info=$(aws docdb describe-db-instances \
        --filters "Name=db-cluster-id,Values=$cluster_id" \
        --query 'DBInstances[*].{Instance:DBInstanceIdentifier,Status:DBInstanceStatus,Pending:PendingModifiedValues}' \
        --output json 2>/dev/null)
    
    if [ -n "$instances_info" ] && [ "$instances_info" != "[]" ]; then
        local total_instances=0
        local available_instances=0
        
        # Processar JSON usando jq ou parsing simples
        if command -v jq &> /dev/null; then
            # Usar jq se disponível
            total_instances=$(echo "$instances_info" | jq length)
            available_instances=$(echo "$instances_info" | jq '[.[] | select(.Status == "available")] | length')
            
            echo "$instances_info" | jq -r '.[] | "\(.Instance) \(.Status)"' | while read instance_id status; do
                print_result "INFO" "Instância: $instance_id - Status: $status"
            done
        else
            # Parsing simples sem jq
            total_instances=$(echo "$instances_info" | grep -o '"Instance"' | wc -l)
            available_instances=$(echo "$instances_info" | grep -c '"Status": "available"')
            
            # Extrair informações básicas
            echo "$instances_info" | grep -o '"Instance": "[^"]*"' | sed 's/"Instance": "//;s/"//' | while read instance_id; do
                local status=$(echo "$instances_info" | grep -A1 "\"Instance\": \"$instance_id\"" | grep '"Status"' | sed 's/.*"Status": "//;s/".*//')
                print_result "INFO" "Instância: $instance_id - Status: $status"
            done
        fi
        
        print_result "INFO" "Total de instâncias: $total_instances (Disponíveis: $available_instances)"
        
        if [ "$available_instances" -eq "$total_instances" ]; then
            print_result "PASS" "Todas as instâncias estão disponíveis"
        else
            print_result "WARN" "Nem todas as instâncias estão disponíveis"
        fi
        
    else
        print_result "FAIL" "Nenhuma instância encontrada para o cluster"
    fi
    
    echo
}

# Função para verificar log group do CloudWatch
check_cloudwatch_log_group() {
    echo -e "${BLUE}3. Verificando log group do CloudWatch...${NC}"
    
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    local log_group_name="/aws/docdb/$cluster_id/audit"
    
    # Verificar se log group existe
    if aws logs describe-log-groups --log-group-name-prefix "$log_group_name" --query "logGroups[?logGroupName=='$log_group_name']" --output text | grep -q "$log_group_name"; then
        print_result "PASS" "Log group encontrado: $log_group_name"
        
        # Verificar informações do log group
        local retention_days
        retention_days=$(aws logs describe-log-groups \
            --log-group-name-prefix "$log_group_name" \
            --query "logGroups[?logGroupName=='$log_group_name'].retentionInDays" \
            --output text 2>/dev/null)
        
        if [ -n "$retention_days" ] && [ "$retention_days" != "None" ]; then
            print_result "INFO" "Retenção configurada: $retention_days dias"
        else
            print_result "INFO" "Retenção: Nunca expira"
        fi
        
    else
        print_result "FAIL" "Log group não encontrado: $log_group_name"
        print_result "INFO" "Execute: aws logs create-log-group --log-group-name $log_group_name"
    fi
    
    echo
}

# Função para verificar exportação de logs habilitada
check_log_export_configuration() {
    echo -e "${BLUE}4. Verificando configuração de exportação de logs...${NC}"
    
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    
    # Verificar configuração de exportação de logs
    local enabled_logs
    enabled_logs=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$cluster_id" \
        --query 'DBClusters[0].EnabledCloudwatchLogsExports' \
        --output text 2>/dev/null)
    
    if [ -n "$enabled_logs" ] && [ "$enabled_logs" != "None" ]; then
        if echo "$enabled_logs" | grep -q "audit"; then
            print_result "PASS" "Exportação de logs de auditoria habilitada"
        else
            print_result "FAIL" "Exportação de logs de auditoria não habilitada"
            print_result "INFO" "Logs habilitados: $enabled_logs"
        fi
    else
        print_result "FAIL" "Nenhuma exportação de logs habilitada"
    fi
    
    echo
}

# Função para verificar logs de auditoria no CloudWatch
check_audit_logs() {
    echo -e "${BLUE}5. Verificando presença de logs de auditoria...${NC}"
    
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    local log_group_name="/aws/docdb/$cluster_id/audit"
    
    # Verificar se há log streams
    local log_streams
    log_streams=$(aws logs describe-log-streams \
        --log-group-name "$log_group_name" \
        --query 'logStreams[*].logStreamName' \
        --output text 2>/dev/null)
    
    if [ -n "$log_streams" ] && [ "$log_streams" != "None" ]; then
        local stream_count
        stream_count=$(echo "$log_streams" | wc -w)
        print_result "PASS" "$stream_count log streams encontrados"
        
        # Verificar eventos recentes em todos os log streams
        print_result "INFO" "Log streams encontrados: $log_streams"
        
        local all_events=""
        local total_events=0
        
        # Buscar eventos em todos os streams
        for stream in $log_streams; do
            local stream_events_json
            stream_events_json=$(aws logs filter-log-events \
                --log-group-name "$log_group_name" \
                --log-stream-names "$stream" \
                --start-time $(($(date +%s) - 3600))000 \
                --output json 2>/dev/null)
            
            if [ -n "$stream_events_json" ] && [ "$stream_events_json" != "{}" ]; then
                local stream_count
                if command -v jq &> /dev/null; then
                    stream_count=$(echo "$stream_events_json" | jq '.events | length')
                    local stream_messages
                    stream_messages=$(echo "$stream_events_json" | jq -r '.events[].message')
                else
                    stream_count=$(echo "$stream_events_json" | grep -c '"message"' 2>/dev/null || echo "0")
                    local stream_messages
                    stream_messages=$(echo "$stream_events_json" | grep -o '"message":"[^"]*"' | sed 's/"message":"//;s/"//')
                fi
                
                if [ "$stream_count" -gt 0 ]; then
                    print_result "INFO" "  Stream $stream: $stream_count eventos"
                    all_events="$all_events$stream_messages"$'\n'
                    ((total_events += stream_count))
                fi
            fi
        done
        
        if [ "$total_events" -gt 0 ]; then
            print_result "PASS" "$total_events eventos de auditoria na última hora"
            
            # Verificar tipos de eventos
            local auth_events
            auth_events=$(echo "$all_events" | grep -c '"atype":"authenticate"' 2>/dev/null || echo "0")
            
            # Buscar diferentes tipos de eventos DML (DocumentDB usa authCheck com command dentro)
            local dml_events=0
            
            # Buscar comandos DML de forma mais simples - procurar diretamente nas mensagens
            local insert_events=$(echo "$all_events" | grep -c '"command".*"insert"' 2>/dev/null || echo "0")
            local update_events=$(echo "$all_events" | grep -c '"command".*"update"' 2>/dev/null || echo "0")
            local delete_events=$(echo "$all_events" | grep -c '"command".*"delete"' 2>/dev/null || echo "0")
            local find_events=$(echo "$all_events" | grep -c '"command".*"find"' 2>/dev/null || echo "0")
            local query_events=$(echo "$all_events" | grep -c '"command".*"query"' 2>/dev/null || echo "0")
            local count_events=$(echo "$all_events" | grep -c '"command".*"count"' 2>/dev/null || echo "0")
            
            # Buscar também por padrões alternativos
            local insert_alt=$(echo "$all_events" | grep -c '"insert".*:' 2>/dev/null || echo "0")
            local update_alt=$(echo "$all_events" | grep -c '"update".*:' 2>/dev/null || echo "0")
            local delete_alt=$(echo "$all_events" | grep -c '"delete".*:' 2>/dev/null || echo "0")
            
            # Buscar por comandos MongoDB específicos
            local insertOne_events=$(echo "$all_events" | grep -c 'insertOne' 2>/dev/null || echo "0")
            local updateOne_events=$(echo "$all_events" | grep -c 'updateOne' 2>/dev/null || echo "0")
            local deleteOne_events=$(echo "$all_events" | grep -c 'deleteOne' 2>/dev/null || echo "0")
            local findOne_events=$(echo "$all_events" | grep -c 'findOne' 2>/dev/null || echo "0")
            
            # Também procurar por atype direto (caso existam)
            local direct_insert=$(echo "$all_events" | grep -c '"atype":"insert"' 2>/dev/null || echo "0")
            local direct_update=$(echo "$all_events" | grep -c '"atype":"update"' 2>/dev/null || echo "0")
            local direct_delete=$(echo "$all_events" | grep -c '"atype":"delete"' 2>/dev/null || echo "0")
            local direct_find=$(echo "$all_events" | grep -c '"atype":"find"' 2>/dev/null || echo "0")
            
            # Garantir que todas as variáveis são números válidos
            insert_events=${insert_events//[^0-9]/}
            update_events=${update_events//[^0-9]/}
            delete_events=${delete_events//[^0-9]/}
            find_events=${find_events//[^0-9]/}
            query_events=${query_events//[^0-9]/}
            count_events=${count_events//[^0-9]/}
            insertOne_events=${insertOne_events//[^0-9]/}
            updateOne_events=${updateOne_events//[^0-9]/}
            deleteOne_events=${deleteOne_events//[^0-9]/}
            findOne_events=${findOne_events//[^0-9]/}
            direct_insert=${direct_insert//[^0-9]/}
            direct_update=${direct_update//[^0-9]/}
            direct_delete=${direct_delete//[^0-9]/}
            direct_find=${direct_find//[^0-9]/}
            
            insert_events=${insert_events:-0}
            update_events=${update_events:-0}
            delete_events=${delete_events:-0}
            find_events=${find_events:-0}
            query_events=${query_events:-0}
            count_events=${count_events:-0}
            insertOne_events=${insertOne_events:-0}
            updateOne_events=${updateOne_events:-0}
            deleteOne_events=${deleteOne_events:-0}
            findOne_events=${findOne_events:-0}
            direct_insert=${direct_insert:-0}
            direct_update=${direct_update:-0}
            direct_delete=${direct_delete:-0}
            direct_find=${direct_find:-0}
            
            # Somar comandos DML (incluindo padrões alternativos)
            local total_insert=$((insert_events + direct_insert + insertOne_events + insert_alt))
            local total_update=$((update_events + direct_update + updateOne_events + update_alt))
            local total_delete=$((delete_events + direct_delete + deleteOne_events + delete_alt))
            local total_find=$((find_events + direct_find + findOne_events))
            
            dml_events=$((total_insert + total_update + total_delete + total_find + query_events + count_events))
            
            # Garantir que são números válidos
            auth_events=${auth_events:-0}
            dml_events=${dml_events:-0}
            
            print_result "INFO" "Eventos de autenticação: $auth_events"
            print_result "INFO" "Eventos DML: $dml_events"
            
            # Debug: mostrar tipos de eventos encontrados
            if [ "$total_insert" -gt 0 ]; then
                print_result "INFO" "  - Insert: $total_insert"
            fi
            if [ "$total_update" -gt 0 ]; then
                print_result "INFO" "  - Update: $total_update"
            fi
            if [ "$total_delete" -gt 0 ]; then
                print_result "INFO" "  - Delete: $total_delete"
            fi
            if [ "$total_find" -gt 0 ]; then
                print_result "INFO" "  - Find: $total_find"
            fi
            if [ "$query_events" -gt 0 ]; then
                print_result "INFO" "  - Query: $query_events"
            fi
            if [ "$count_events" -gt 0 ]; then
                print_result "INFO" "  - Count: $count_events"
            fi
            
            # Debug: mostrar alguns eventos para análise
            if [ "$dml_events" -eq 0 ]; then
                print_result "INFO" "Debug - Tipos de atype encontrados:"
                local unique_atypes
                unique_atypes=$(echo "$all_events" | grep -o '"atype":"[^"]*"' | sort | uniq | head -10)
                if [ -n "$unique_atypes" ]; then
                    echo "$unique_atypes" | while read atype; do
                        print_result "INFO" "  $atype"
                    done
                fi
                
                print_result "INFO" "Debug - Busca por padrões de comando:"
                local cmd_patterns=("command.*insert" "command.*update" "command.*delete" "insertOne" "updateOne" "deleteOne")
                for pattern in "${cmd_patterns[@]}"; do
                    local count=$(echo "$all_events" | grep -c "$pattern" 2>/dev/null || echo "0")
                    if [ "$count" -gt 0 ]; then
                        print_result "INFO" "  Padrão '$pattern': $count ocorrências"
                    fi
                done
                
                # Debug: contar authCheck events
                local authcheck_count
                authcheck_count=$(echo "$all_events" | grep -c '"atype":"authCheck"' 2>/dev/null || echo "0")
                print_result "INFO" "Debug - Total de eventos authCheck: $authcheck_count"
                
                # Debug: mostrar linhas que contêm "command"
                print_result "INFO" "Debug - Linhas contendo 'command':"
                local command_lines
                command_lines=$(echo "$all_events" | grep -n "command" | head -3)
                if [ -n "$command_lines" ]; then
                    echo "$command_lines" | while IFS= read -r line; do
                        print_result "INFO" "  $line"
                    done
                else
                    print_result "INFO" "  Nenhuma linha contém 'command'"
                fi
                
                # Debug: mostrar primeiras linhas dos eventos para análise
                print_result "INFO" "Debug - Primeiras 3 linhas dos eventos:"
                echo "$all_events" | head -3 | while IFS= read -r line; do
                    if [ -n "$line" ]; then
                        print_result "INFO" "  $(echo "$line" | cut -c1-100)..."
                    fi
                done
            fi
            
            if [ "$auth_events" -gt 0 ] 2>/dev/null; then
                print_result "PASS" "Logs de autenticação presentes"
            fi
            
            if [ "$dml_events" -gt 0 ] 2>/dev/null; then
                print_result "PASS" "Logs de operações DML presentes"
            else
                print_result "WARN" "Nenhum log de operação DML encontrado"
                print_result "INFO" "Execute operações no banco para gerar logs DML"
            fi
            
        else
            print_result "WARN" "Nenhum evento de auditoria recente encontrado"
            print_result "INFO" "Execute atividades no banco para gerar logs"
        fi
        
    else
        print_result "WARN" "Nenhum log stream encontrado"
        print_result "INFO" "Aguarde alguns minutos após habilitar a auditoria"
    fi
    
    echo
}

# Função para testar conectividade e gerar logs
test_database_activity() {
    echo -e "${BLUE}6. Testando conectividade e geração de logs...${NC}"
    
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    
    # Obter endpoint do cluster
    local cluster_endpoint
    cluster_endpoint=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$cluster_id" \
        --query 'DBClusters[0].Endpoint' \
        --output text 2>/dev/null)
    
    if [ -n "$cluster_endpoint" ] && [ "$cluster_endpoint" != "None" ]; then
        print_result "INFO" "Endpoint do cluster: $cluster_endpoint"
        
        # Verificar se certificado SSL existe
        if [ -f "global-bundle.pem" ]; then
            print_result "PASS" "Certificado SSL encontrado"
        else
            print_result "INFO" "Baixando certificado SSL..."
            if wget -q https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem; then
                print_result "PASS" "Certificado SSL baixado"
            else
                print_result "WARN" "Falha ao baixar certificado SSL"
            fi
        fi
        
        # Testar conexão com senha padrão primeiro
        print_result "INFO" "Tentando conexão com senha padrão (Lab12345!)..."
        local connection_success=false
        local master_password="Lab12345!"
        
        # Testar conexão com senha padrão
        if timeout 15 mongosh --tls --host "${cluster_endpoint}:27017" \
            --tlsCAFile global-bundle.pem \
            --username docdbadmin \
            --password "$master_password" \
            --retryWrites false \
            --eval "db.runCommand({ping: 1})" &> /dev/null; then
            connection_success=true
            print_result "PASS" "Conexão com senha padrão estabelecida"
        else
            print_result "WARN" "Falha na conexão com senha padrão"
            
            # Pedir nova senha se a padrão falhar
            echo -e "${YELLOW}Digite a senha correta do usuário mestre docdbadmin (ou Enter para pular):${NC}"
            read -s -p "Senha: " master_password
            echo
            
            if [ -n "$master_password" ]; then
                print_result "INFO" "Testando conexão com senha fornecida..."
                if timeout 15 mongosh --tls --host "${cluster_endpoint}:27017" \
                    --tlsCAFile global-bundle.pem \
                    --username docdbadmin \
                    --password "$master_password" \
                    --retryWrites=false \
                    --eval "db.runCommand({ping: 1})" &> /dev/null; then
                    connection_success=true
                    print_result "PASS" "Conexão com senha fornecida estabelecida"
                else
                    print_result "FAIL" "Falha na conexão com senha fornecida"
                fi
            else
                print_result "INFO" "Teste de conexão pulado"
            fi
        fi
        
        # Se conseguiu conectar, executar operações de teste
        if [ "$connection_success" = true ]; then
            print_result "INFO" "Executando operações de teste para gerar logs de auditoria..."
            
            if timeout 15 mongosh --tls --host "${cluster_endpoint}:27017" \
                --tlsCAFile global-bundle.pem \
                --username docdbadmin \
                --password "$master_password" \
                --retryWrites=false \
                --eval "
                    use testdb;
                    db.audit_test.insertOne({timestamp: new Date(), test: 'audit_validation'});
                    db.audit_test.find({test: 'audit_validation'}).limit(1);
                    db.audit_test.updateOne({test: 'audit_validation'}, {\$set: {updated: new Date()}});
                    db.audit_test.deleteOne({test: 'audit_validation'});
                    print('Operações de teste executadas com sucesso');
                " &> /dev/null; then
                print_result "PASS" "Operações DML executadas com sucesso"
                print_result "INFO" "Aguarde 2-3 minutos para os logs aparecerem no CloudWatch"
            else
                print_result "WARN" "Falha na execução das operações DML"
            fi
        fi
        
    else
        print_result "WARN" "Endpoint do cluster não disponível"
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
    
    local cluster_id="${STUDENT_ID}-lab-cluster-console"
    local parameter_group_name="${STUDENT_ID}-lab-audit-parameter-group"
    local log_group_name="/aws/docdb/$cluster_id/audit"
    
    # 1. Verificar cluster e parameter group
    if aws docdb describe-db-clusters --db-cluster-identifier "$cluster_id" &> /dev/null; then
        local current_pg
        current_pg=$(aws docdb describe-db-clusters \
            --db-cluster-identifier "$cluster_id" \
            --query 'DBClusters[0].DBClusterParameterGroup' \
            --output text 2>/dev/null)
        
        if [ "$current_pg" = "$parameter_group_name" ]; then
            ((passed_checks++))
        fi
    fi
    
    # 2. Verificar configuração de auditoria
    if aws docdb describe-db-cluster-parameter-groups --db-cluster-parameter-group-name "$parameter_group_name" &> /dev/null; then
        local audit_setting
        audit_setting=$(aws docdb describe-db-cluster-parameters \
            --db-cluster-parameter-group-name "$parameter_group_name" \
            --query 'Parameters[?ParameterName==`audit_logs`].ParameterValue' \
            --output text 2>/dev/null)
        
        if [[ "$audit_setting" =~ ^(all|dml|enabled)$ ]]; then
            ((passed_checks++))
        fi
    fi
    
    # 3. Verificar instâncias disponíveis
    local available_instances
    available_instances=$(aws docdb describe-db-instances \
        --filters "Name=db-cluster-id,Values=$cluster_id" \
        --query 'DBInstances[?DBInstanceStatus==`available`]' \
        --output json 2>/dev/null)
    
    if [ -n "$available_instances" ] && [ "$available_instances" != "[]" ]; then
        ((passed_checks++))
    fi
    
    # 4. Verificar log group
    if aws logs describe-log-groups --log-group-name-prefix "$log_group_name" --query "logGroups[?logGroupName=='$log_group_name']" --output text | grep -q "$log_group_name"; then
        ((passed_checks++))
    fi
    
    # 5. Verificar exportação de logs
    local enabled_logs
    enabled_logs=$(aws docdb describe-db-clusters \
        --db-cluster-identifier "$cluster_id" \
        --query 'DBClusters[0].EnabledCloudwatchLogsExports' \
        --output text 2>/dev/null)
    
    if echo "$enabled_logs" | grep -q "audit"; then
        ((passed_checks++))
    fi
    
    # 6. Verificar presença de logs
    local log_streams
    log_streams=$(aws logs describe-log-streams \
        --log-group-name "$log_group_name" \
        --query 'logStreams[*].logStreamName' \
        --output text 2>/dev/null)
    
    if [ -n "$log_streams" ] && [ "$log_streams" != "None" ]; then
        ((passed_checks++))
    fi
    
    # 7. Verificar eventos de auditoria (buscar em todos os streams)
    local has_events=false
    local log_streams_list
    log_streams_list=$(aws logs describe-log-streams \
        --log-group-name "$log_group_name" \
        --query 'logStreams[*].logStreamName' \
        --output text 2>/dev/null)
    
    if [ -n "$log_streams_list" ] && [ "$log_streams_list" != "None" ]; then
        for stream in $log_streams_list; do
            local stream_events_json
            stream_events_json=$(aws logs filter-log-events \
                --log-group-name "$log_group_name" \
                --log-stream-names "$stream" \
                --start-time $(($(date +%s) - 3600))000 \
                --output json 2>/dev/null)
            
            if [ -n "$stream_events_json" ] && [ "$stream_events_json" != "{}" ]; then
                local event_count
                if command -v jq &> /dev/null; then
                    event_count=$(echo "$stream_events_json" | jq '.events | length')
                else
                    event_count=$(echo "$stream_events_json" | grep -c '"message"' 2>/dev/null || echo "0")
                fi
                
                if [ "$event_count" -gt 0 ]; then
                    has_events=true
                    break
                fi
            fi
        done
    fi
    
    if [ "$has_events" = true ]; then
        ((passed_checks++))
    fi
    
    echo "Checklist do Exercício 3:"
    echo "✅ Parameter group customizado aplicado: $([ $passed_checks -ge 1 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Auditoria habilitada (audit_logs=all): $([ $passed_checks -ge 2 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Instâncias reiniciadas e disponíveis: $([ $passed_checks -ge 3 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Log group do CloudWatch criado: $([ $passed_checks -ge 4 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Exportação de logs habilitada: $([ $passed_checks -ge 5 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Log streams presentes: $([ $passed_checks -ge 6 ] && echo "SIM" || echo "NÃO")"
    echo "✅ Eventos de auditoria capturados: $([ $passed_checks -ge 7 ] && echo "SIM" || echo "NÃO")"
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
    echo -e "${BLUE}Comandos úteis para troubleshooting:${NC}"
    echo "  # Verificar parameter group:"
    echo "  aws docdb describe-db-cluster-parameters --db-cluster-parameter-group-name $parameter_group_name"
    echo
    echo "  # Verificar logs recentes:"
    echo "  aws logs filter-log-events --log-group-name $log_group_name --start-time \$(date -d '1 hour ago' +%s)000"
    echo
    echo "  # Testar conexão:"
    echo "  mongosh --tls --host \$(aws docdb describe-db-clusters --db-cluster-identifier $cluster_id --query 'DBClusters[0].Endpoint' --output text):27017 --tlsCAFile global-bundle.pem --username docdbadmin --retryWrites=false"
}

# Função principal
main() {
    print_header
    
    # Verificar pré-requisitos
    check_aws_cli
    check_mongosh
    
    # Obter ID do aluno
    get_student_id "$1"
    
    # Executar validações
    check_cluster_and_parameter_group
    check_instances_status
    check_cloudwatch_log_group
    check_log_export_configuration
    check_audit_logs
    test_database_activity
    
    # Gerar relatório final
    generate_report
}

# Executar script
main "$@"