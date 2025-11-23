# Função melhorada para limpar recursos criados manualmente nos labs
# Esta é uma versão melhorada que deve substituir a função cleanup_lab_resources no manage-curso.sh

cleanup_lab_resources() {
    local stack_name=$1
    
    if [ -z "$stack_name" ]; then
        error "Nome da stack não fornecido"
        return 1
    fi
    
    # Arrays para rastrear falhas
    declare -a FAILED_RESOURCES
    declare -a SUCCESS_RESOURCES
    
    # Obter prefixo da stack
    log "Obtendo informações da stack..."
    local prefixo=$(aws cloudformation describe-stacks \
        --stack-name $stack_name \
        --query 'Stacks[0].Parameters[?ParameterKey==`PrefixoAluno`].ParameterValue' \
        --output text 2>/dev/null)
    
    if [ -z "$prefixo" ] || [ "$prefixo" = "None" ]; then
        prefixo="aluno"
    fi
    
    log "Buscando recursos com prefixo: ${prefixo}*"
    
    # FASE 1: LISTAR RECURSOS (descoberta dinâmica)
    echo -e "\n${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  FASE 1: LISTANDO RECURSOS A SEREM DELETADOS  ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}\n"
    
    local total_resources=0
    
    # Arrays para armazenar recursos encontrados
    declare -a FOUND_CLUSTERS
    declare -a FOUND_INSTANCES
    declare -a FOUND_SNAPSHOTS
    declare -a FOUND_PARAM_GROUPS
    declare -a FOUND_SUBNET_GROUPS
    declare -a FOUND_SECURITY_GROUPS
    declare -a FOUND_DASHBOARDS
    declare -a FOUND_ALARMS
    declare -a FOUND_SNS_TOPICS
    declare -a FOUND_EVENT_RULES
    declare -a FOUND_LOG_GROUPS
    declare -a FOUND_S3_BUCKETS
    
    log "Descobrindo clusters DocumentDB que começam com '${prefixo}'..."
    FOUND_CLUSTERS=($(aws docdb describe-db-clusters \
        --query "DBClusters[?starts_with(DBClusterIdentifier, '${prefixo}')].DBClusterIdentifier" \
        --output text 2>/dev/null))
    
    for cluster in "${FOUND_CLUSTERS[@]}"; do
        if [ -n "$cluster" ] && [ "$cluster" != "None" ]; then
            echo "  📦 Cluster: $cluster"
            ((total_resources++))
            
            # Descobrir instâncias do cluster
            local instances=$(aws docdb describe-db-clusters \
                --db-cluster-identifier "$cluster" \
                --query 'DBClusters[0].DBClusterMembers[].DBInstanceIdentifier' \
                --output text 2>/dev/null)
            for instance in $instances; do
                if [ -n "$instance" ] && [ "$instance" != "None" ]; then
                    FOUND_INSTANCES+=("$instance")
                    echo "    └─ 💾 Instance: $instance"
                    ((total_resources++))
                fi
            done
        fi
    done
    
    log "Descobrindo snapshots que começam com '${prefixo}'..."
    FOUND_SNAPSHOTS=($(aws docdb describe-db-cluster-snapshots \
        --snapshot-type manual \
        --query "DBClusterSnapshots[?starts_with(DBClusterSnapshotIdentifier, '${prefixo}')].DBClusterSnapshotIdentifier" \
        --output text 2>/dev/null))
    
    for snapshot in "${FOUND_SNAPSHOTS[@]}"; do
        if [ -n "$snapshot" ] && [ "$snapshot" != "None" ]; then
            echo "  📸 Snapshot: $snapshot"
            ((total_resources++))
        fi
    done
    
    log "Descobrindo parameter groups que começam com '${prefixo}'..."
    FOUND_PARAM_GROUPS=($(aws docdb describe-db-cluster-parameter-groups \
        --query "DBClusterParameterGroups[?starts_with(DBClusterParameterGroupName, '${prefixo}')].DBClusterParameterGroupName" \
        --output text 2>/dev/null))
    
    for pg in "${FOUND_PARAM_GROUPS[@]}"; do
        if [ -n "$pg" ] && [ "$pg" != "None" ]; then
            echo "  ⚙️  Parameter Group: $pg"
            ((total_resources++))
        fi
    done
    
    log "Descobrindo subnet groups que começam com '${prefixo}'..."
    FOUND_SUBNET_GROUPS=($(aws docdb describe-db-subnet-groups \
        --query "DBSubnetGroups[?starts_with(DBSubnetGroupName, '${prefixo}')].DBSubnetGroupName" \
        --output text 2>/dev/null))
    
    for sg in "${FOUND_SUBNET_GROUPS[@]}"; do
        if [ -n "$sg" ] && [ "$sg" != "None" ]; then
            echo "  🌐 Subnet Group: $sg"
            ((total_resources++))
        fi
    done
    
    log "Descobrindo security groups que começam com '${prefixo}'..."
    local sg_ids=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=${prefixo}*" \
        --query 'SecurityGroups[].GroupName' \
        --output text 2>/dev/null)
    
    for sg_name in $sg_ids; do
        if [ -n "$sg_name" ] && [ "$sg_name" != "None" ]; then
            FOUND_SECURITY_GROUPS+=("$sg_name")
            echo "  🔒 Security Group: $sg_name"
            ((total_resources++))
        fi
    done
    
    log "Descobrindo dashboards CloudWatch que começam com '${prefixo}'..."
    local all_dashboards=$(aws cloudwatch list-dashboards --query 'DashboardEntries[].DashboardName' --output text 2>/dev/null)
    for dashboard in $all_dashboards; do
        if [[ "$dashboard" =~ ^${prefixo} ]]; then
            FOUND_DASHBOARDS+=("$dashboard")
            echo "  📊 Dashboard: $dashboard"
            ((total_resources++))
        fi
    done
    
    log "Descobrindo alarmes CloudWatch que começam com '${prefixo}'..."
    FOUND_ALARMS=($(aws cloudwatch describe-alarms \
        --query "MetricAlarms[?starts_with(AlarmName, '${prefixo}')].AlarmName" \
        --output text 2>/dev/null))
    
    for alarm in "${FOUND_ALARMS[@]}"; do
        if [ -n "$alarm" ] && [ "$alarm" != "None" ]; then
            echo "  🚨 Alarme: $alarm"
            ((total_resources++))
        fi
    done
    
    log "Descobrindo regras EventBridge que começam com '${prefixo}'..."
    FOUND_EVENT_RULES=($(aws events list-rules \
        --query "Rules[?starts_with(Name, '${prefixo}')].Name" \
        --output text 2>/dev/null))
    
    for rule in "${FOUND_EVENT_RULES[@]}"; do
        if [ -n "$rule" ] && [ "$rule" != "None" ]; then
            echo "  📅 EventBridge Rule: $rule"
            ((total_resources++))
        fi
    done
    
    log "Descobrindo tópicos SNS que contêm '${prefixo}'..."
    local all_topics=$(aws sns list-topics --query 'Topics[].TopicArn' --output text 2>/dev/null)
    for topic in $all_topics; do
        if [[ "$topic" =~ ${prefixo} ]]; then
            FOUND_SNS_TOPICS+=("$topic")
            echo "  📢 SNS Topic: $(basename $topic)"
            ((total_resources++))
        fi
    done
    
    log "Descobrindo log groups que contêm '${prefixo}'..."
    local all_log_groups=$(aws logs describe-log-groups --query 'logGroups[].logGroupName' --output text 2>/dev/null)
    for log_group in $all_log_groups; do
        if [[ "$log_group" =~ ${prefixo} ]]; then
            FOUND_LOG_GROUPS+=("$log_group")
            echo "  📝 Log Group: $log_group"
            ((total_resources++))
        fi
    done
    
    log "Descobrindo buckets S3 que contêm '${prefixo}'..."
    local all_buckets=$(aws s3 ls | awk '{print $3}')
    for bucket in $all_buckets; do
        if [[ "$bucket" =~ ${prefixo} ]]; then
            FOUND_S3_BUCKETS+=("$bucket")
            echo "  🪣 S3 Bucket: $bucket"
            ((total_resources++))
        fi
    done
    
    echo -e "\n${YELLOW}Total de recursos encontrados: $total_resources${NC}\n"
    
    if [ $total_resources -eq 0 ]; then
        success "Nenhum recurso de lab encontrado para deletar"
        return 0
    fi
    
    warning "Esta ação irá deletar $total_resources recursos!"
    read -p "Digite 'DELETE-LABS' para confirmar: " CONFIRM
    
    if [ "$CONFIRM" != "DELETE-LABS" ]; then
        error "Operação cancelada"
        return 1
    fi
    
    # FASE 2: DELEÇÃO (usando recursos descobertos)
    echo -e "\n${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  FASE 2: DELETANDO RECURSOS (ordem correta)   ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}\n"
    
    # PASSO 1: Deletar instâncias DocumentDB primeiro
    if [ ${#FOUND_INSTANCES[@]} -gt 0 ]; then
        log "Deletando ${#FOUND_INSTANCES[@]} instâncias DocumentDB..."
        for instance in "${FOUND_INSTANCES[@]}"; do
            if [ -n "$instance" ] && [ "$instance" != "None" ]; then
                log "  Deletando instância: $instance"
                aws docdb delete-db-instance --db-instance-identifier "$instance" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("Instance: $instance") || \
                    FAILED_RESOURCES+=("Instance: $instance")
            fi
        done
        sleep 5
    fi
    
    # PASSO 2: Deletar clusters DocumentDB
    if [ ${#FOUND_CLUSTERS[@]} -gt 0 ]; then
        log "Deletando ${#FOUND_CLUSTERS[@]} clusters DocumentDB..."
        for cluster in "${FOUND_CLUSTERS[@]}"; do
            if [ -n "$cluster" ] && [ "$cluster" != "None" ]; then
                log "  Deletando cluster: $cluster"
                aws docdb delete-db-cluster --db-cluster-identifier "$cluster" --skip-final-snapshot 2>/dev/null && \
                    SUCCESS_RESOURCES+=("Cluster: $cluster") || \
                    FAILED_RESOURCES+=("Cluster: $cluster")
            fi
        done
    fi
    
    # PASSO 3: Aguardar clusters serem deletados antes de remover recursos dependentes
    if [ ${#FOUND_CLUSTERS[@]} -gt 0 ]; then
        log "Aguardando clusters serem deletados (pode levar até 10 minutos)..."
        log "Verificando status dos clusters a cada 30 segundos..."
        
        local max_wait=600  # 10 minutos
        local elapsed=0
        local all_deleted=false
        
        while [ $elapsed -lt $max_wait ]; do
            local clusters_remaining=0
            
            for cluster in "${FOUND_CLUSTERS[@]}"; do
                if aws docdb describe-db-clusters --db-cluster-identifier "$cluster" &> /dev/null 2>&1; then
                    ((clusters_remaining++))
                fi
            done
            
            if [ $clusters_remaining -eq 0 ]; then
                all_deleted=true
                success "Todos os clusters foram deletados!"
                break
            fi
            
            log "Clusters restantes: $clusters_remaining - Aguardando... (${elapsed}s/${max_wait}s)"
            sleep 30
            elapsed=$((elapsed + 30))
        done
        
        if [ "$all_deleted" = false ]; then
            warning "Timeout aguardando deleção de clusters (10 min)"
            warning "Alguns clusters ainda podem estar sendo deletados"
            warning "Recursos dependentes podem falhar ao deletar"
        fi
    fi
    
    # PASSO 4: Deletar snapshots (não têm dependências)
    if [ ${#FOUND_SNAPSHOTS[@]} -gt 0 ]; then
        log "Deletando ${#FOUND_SNAPSHOTS[@]} snapshots..."
        for snapshot in "${FOUND_SNAPSHOTS[@]}"; do
            if [ -n "$snapshot" ] && [ "$snapshot" != "None" ]; then
                aws docdb delete-db-cluster-snapshot --db-cluster-snapshot-identifier "$snapshot" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("Snapshot: $snapshot") || \
                    FAILED_RESOURCES+=("Snapshot: $snapshot")
            fi
        done
    fi
    
    # PASSO 5: Deletar parameter groups
    if [ ${#FOUND_PARAM_GROUPS[@]} -gt 0 ]; then
        log "Deletando ${#FOUND_PARAM_GROUPS[@]} parameter groups..."
        for pg in "${FOUND_PARAM_GROUPS[@]}"; do
            if [ -n "$pg" ] && [ "$pg" != "None" ]; then
                aws docdb delete-db-cluster-parameter-group --db-cluster-parameter-group-name "$pg" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("ParamGroup: $pg") || \
                    FAILED_RESOURCES+=("ParamGroup: $pg")
            fi
        done
    fi
    
    # PASSO 6: Deletar subnet groups
    if [ ${#FOUND_SUBNET_GROUPS[@]} -gt 0 ]; then
        log "Deletando ${#FOUND_SUBNET_GROUPS[@]} subnet groups..."
        for sg in "${FOUND_SUBNET_GROUPS[@]}"; do
            if [ -n "$sg" ] && [ "$sg" != "None" ]; then
                aws docdb delete-db-subnet-group --db-subnet-group-name "$sg" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("SubnetGroup: $sg") || \
                    FAILED_RESOURCES+=("SubnetGroup: $sg")
            fi
        done
    fi
    
    # PASSO 7: Remover regras dos Security Groups primeiro
    if [ ${#FOUND_SECURITY_GROUPS[@]} -gt 0 ]; then
        log "Removendo regras de ${#FOUND_SECURITY_GROUPS[@]} security groups..."
        for sg_name in "${FOUND_SECURITY_GROUPS[@]}"; do
            local sg_id=$(aws ec2 describe-security-groups \
                --filters "Name=group-name,Values=$sg_name" \
                --query 'SecurityGroups[0].GroupId' \
                --output text 2>/dev/null)
            
            if [ -n "$sg_id" ] && [ "$sg_id" != "None" ]; then
                log "  Removendo regras do SG: $sg_name"
                
                # Remover regras de ingress
                aws ec2 describe-security-groups --group-ids "$sg_id" \
                    --query 'SecurityGroups[0].IpPermissions' \
                    --output json 2>/dev/null | \
                    jq -c '.[]' 2>/dev/null | while read rule; do
                        aws ec2 revoke-security-group-ingress --group-id "$sg_id" --ip-permissions "$rule" 2>/dev/null || true
                    done
                
                # Remover regras de egress
                aws ec2 describe-security-groups --group-ids "$sg_id" \
                    --query 'SecurityGroups[0].IpPermissionsEgress' \
                    --output json 2>/dev/null | \
                    jq -c '.[]' 2>/dev/null | while read rule; do
                        aws ec2 revoke-security-group-egress --group-id "$sg_id" --ip-permissions "$rule" 2>/dev/null || true
                    done
            fi
        done
        
        sleep 5
    fi
    
    # PASSO 8: Deletar Security Groups
    if [ ${#FOUND_SECURITY_GROUPS[@]} -gt 0 ]; then
        log "Deletando ${#FOUND_SECURITY_GROUPS[@]} security groups..."
        for sg_name in "${FOUND_SECURITY_GROUPS[@]}"; do
            local sg_id=$(aws ec2 describe-security-groups \
                --filters "Name=group-name,Values=$sg_name" \
                --query 'SecurityGroups[0].GroupId' \
                --output text 2>/dev/null)
            
            if [ -n "$sg_id" ] && [ "$sg_id" != "None" ]; then
                aws ec2 delete-security-group --group-id "$sg_id" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("SecurityGroup: $sg_name") || \
                    FAILED_RESOURCES+=("SecurityGroup: $sg_name")
            fi
        done
    fi
    
    # PASSO 9: Deletar recursos de monitoramento (sem dependências)
    
    # Dashboards
    if [ ${#FOUND_DASHBOARDS[@]} -gt 0 ]; then
        log "Deletando ${#FOUND_DASHBOARDS[@]} dashboards..."
        for dashboard in "${FOUND_DASHBOARDS[@]}"; do
            if [ -n "$dashboard" ] && [ "$dashboard" != "None" ]; then
                aws cloudwatch delete-dashboards --dashboard-names "$dashboard" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("Dashboard: $dashboard") || \
                    FAILED_RESOURCES+=("Dashboard: $dashboard")
            fi
        done
    fi
    
    # Alarmes
    if [ ${#FOUND_ALARMS[@]} -gt 0 ]; then
        log "Deletando ${#FOUND_ALARMS[@]} alarmes..."
        for alarm in "${FOUND_ALARMS[@]}"; do
            if [ -n "$alarm" ] && [ "$alarm" != "None" ]; then
                aws cloudwatch delete-alarms --alarm-names "$alarm" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("Alarm: $alarm") || \
                    FAILED_RESOURCES+=("Alarm: $alarm")
            fi
        done
    fi
    
    # Regras EventBridge (remover targets primeiro)
    if [ ${#FOUND_EVENT_RULES[@]} -gt 0 ]; then
        log "Deletando ${#FOUND_EVENT_RULES[@]} regras EventBridge..."
        for rule in "${FOUND_EVENT_RULES[@]}"; do
            if [ -n "$rule" ] && [ "$rule" != "None" ]; then
                # Remover targets
                local targets=$(aws events list-targets-by-rule --rule "$rule" --query 'Targets[].Id' --output text 2>/dev/null)
                if [ -n "$targets" ]; then
                    aws events remove-targets --rule "$rule" --ids $targets 2>/dev/null || true
                fi
                
                aws events delete-rule --name "$rule" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("EventRule: $rule") || \
                    FAILED_RESOURCES+=("EventRule: $rule")
            fi
        done
    fi
    
    # Tópicos SNS
    if [ ${#FOUND_SNS_TOPICS[@]} -gt 0 ]; then
        log "Deletando ${#FOUND_SNS_TOPICS[@]} tópicos SNS..."
        for topic in "${FOUND_SNS_TOPICS[@]}"; do
            if [ -n "$topic" ] && [ "$topic" != "None" ]; then
                aws sns delete-topic --topic-arn "$topic" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("SNSTopic: $(basename $topic)") || \
                    FAILED_RESOURCES+=("SNSTopic: $(basename $topic)")
            fi
        done
    fi
    
    # Log Groups
    if [ ${#FOUND_LOG_GROUPS[@]} -gt 0 ]; then
        log "Deletando ${#FOUND_LOG_GROUPS[@]} log groups..."
        for log_group in "${FOUND_LOG_GROUPS[@]}"; do
            if [ -n "$log_group" ] && [ "$log_group" != "None" ]; then
                aws logs delete-log-group --log-group-name "$log_group" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("LogGroup: $log_group") || \
                    FAILED_RESOURCES+=("LogGroup: $log_group")
            fi
        done
    fi
    
    # Buckets S3
    if [ ${#FOUND_S3_BUCKETS[@]} -gt 0 ]; then
        log "Deletando ${#FOUND_S3_BUCKETS[@]} buckets S3..."
        for bucket in "${FOUND_S3_BUCKETS[@]}"; do
            if [ -n "$bucket" ]; then
                log "  Esvaziando bucket: $bucket"
                aws s3 rm "s3://${bucket}" --recursive 2>/dev/null || true
                aws s3 rb "s3://${bucket}" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("S3Bucket: $bucket") || \
                    FAILED_RESOURCES+=("S3Bucket: $bucket")
            fi
        done
    fi
    
    # FASE 3: RELATÓRIO FINAL
    echo -e "\n${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  FASE 3: RELATÓRIO FINAL                       ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}\n"
    
    local success_count=${#SUCCESS_RESOURCES[@]}
    local failed_count=${#FAILED_RESOURCES[@]}
    
    echo -e "${GREEN}✅ Recursos deletados com sucesso: $success_count${NC}"
    if [ $success_count -gt 0 ] && [ $success_count -le 10 ]; then
        for resource in "${SUCCESS_RESOURCES[@]}"; do
            echo "  ✓ $resource"
        done
    elif [ $success_count -gt 10 ]; then
        echo "  (Lista completa omitida - muitos recursos)"
    fi
    
    echo ""
    
    if [ $failed_count -gt 0 ]; then
        echo -e "${RED}❌ Recursos que falharam ao deletar: $failed_count${NC}"
        for resource in "${FAILED_RESOURCES[@]}"; do
            echo "  ✗ $resource"
        done
        echo ""
        echo -e "${YELLOW}💡 Dicas para recursos que falharam:${NC}"
        echo "  • Aguarde alguns minutos e tente novamente"
        echo "  • Alguns recursos podem ter dependências ainda ativas"
        echo "  • Verifique manualmente no console AWS se necessário"
    else
        echo -e "${GREEN}✨ Todos os recursos foram deletados com sucesso!${NC}"
    fi
    
    echo ""
}
