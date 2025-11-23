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
    
    # Obter parâmetros da stack
    log "Obtendo informações da stack..."
    local num_alunos=$(aws cloudformation describe-stacks \
        --stack-name $stack_name \
        --query 'Stacks[0].Parameters[?ParameterKey==`NumeroAlunos`].ParameterValue' \
        --output text 2>/dev/null)
    
    local prefixo=$(aws cloudformation describe-stacks \
        --stack-name $stack_name \
        --query 'Stacks[0].Parameters[?ParameterKey==`PrefixoAluno`].ParameterValue' \
        --output text 2>/dev/null)
    
    if [ -z "$num_alunos" ] || [ "$num_alunos" = "None" ]; then
        num_alunos=20
    fi
    
    if [ -z "$prefixo" ] || [ "$prefixo" = "None" ]; then
        prefixo="aluno"
    fi
    
    # FASE 1: LISTAR RECURSOS
    echo -e "\n${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  FASE 1: LISTANDO RECURSOS A SEREM DELETADOS  ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}\n"
    
    local total_resources=0
    
    for i in $(seq 1 $num_alunos); do
        local aluno_num=$(printf "%02d" $i)
        local aluno_id="${prefixo}${aluno_num}"
        
        echo -e "${YELLOW}Aluno: $aluno_id${NC}"
        
        # Listar clusters
        for cluster_pattern in "${aluno_id}-lab-cluster-console" "${aluno_id}-lab-cluster-terraform" "${aluno_id}-lab-cluster-restored" "${aluno_id}-lab-cluster-pitr" "${aluno_id}-lab-cluster-rollback"; do
            if aws docdb describe-db-clusters --db-cluster-identifier "$cluster_pattern" &> /dev/null; then
                echo "  📦 Cluster: $cluster_pattern"
                ((total_resources++))
            fi
        done
        
        # Listar snapshots
        local snapshots=$(aws docdb describe-db-cluster-snapshots \
            --snapshot-type manual \
            --query "DBClusterSnapshots[?starts_with(DBClusterSnapshotIdentifier, '$aluno_id')].DBClusterSnapshotIdentifier" \
            --output text 2>/dev/null)
        for snapshot in $snapshots; do
            if [ -n "$snapshot" ] && [ "$snapshot" != "None" ]; then
                echo "  📸 Snapshot: $snapshot"
                ((total_resources++))
            fi
        done
        
        # Listar security groups
        for sg_pattern in "${aluno_id}-docdb-lab-sg" "${aluno_id}-app-client-sg"; do
            if aws ec2 describe-security-groups --filters "Name=group-name,Values=$sg_pattern" --query 'SecurityGroups[0].GroupId' --output text &> /dev/null; then
                echo "  🔒 Security Group: $sg_pattern"
                ((total_resources++))
            fi
        done
        
        # Listar dashboards
        for dashboard in "${aluno_id}-DocumentDB-Dashboard" "${aluno_id}-DocumentDB-Dashboard-ByAWSCli" "${aluno_id}-Performance-Tuning-Dashboard-byAWSCLI"; do
            if aws cloudwatch get-dashboard --dashboard-name "$dashboard" &> /dev/null; then
                echo "  📊 Dashboard: $dashboard"
                ((total_resources++))
            fi
        done
        
        # Listar alarmes
        local alarms=$(aws cloudwatch describe-alarms --query "MetricAlarms[?starts_with(AlarmName, '$aluno_id')].AlarmName" --output text 2>/dev/null)
        for alarm in $alarms; do
            if [ -n "$alarm" ] && [ "$alarm" != "None" ]; then
                echo "  🚨 Alarme: $alarm"
                ((total_resources++))
            fi
        done
        
        # Listar tópicos SNS
        local topics=$(aws sns list-topics --query "Topics[?contains(TopicArn, '$aluno_id')].TopicArn" --output text 2>/dev/null)
        for topic in $topics; do
            if [ -n "$topic" ] && [ "$topic" != "None" ]; then
                echo "  📢 SNS Topic: $(basename $topic)"
                ((total_resources++))
            fi
        done
        
        # Listar buckets S3
        local buckets=$(aws s3 ls | grep "${aluno_id}-docdb-backups" | awk '{print $3}')
        for bucket in $buckets; do
            if [ -n "$bucket" ]; then
                echo "  🪣 S3 Bucket: $bucket"
                ((total_resources++))
            fi
        done
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
    
    # FASE 2: DELEÇÃO
    echo -e "\n${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  FASE 2: DELETANDO RECURSOS (ordem correta)   ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}\n"
    
    for i in $(seq 1 $num_alunos); do
        local aluno_num=$(printf "%02d" $i)
        local aluno_id="${prefixo}${aluno_num}"
        
        echo -e "${YELLOW}Processando $aluno_id...${NC}"
        
        # PASSO 1: Deletar clusters DocumentDB (e suas instâncias)
        for cluster_pattern in "${aluno_id}-lab-cluster-console" "${aluno_id}-lab-cluster-terraform" "${aluno_id}-lab-cluster-restored" "${aluno_id}-lab-cluster-pitr" "${aluno_id}-lab-cluster-rollback"; do
            if aws docdb describe-db-clusters --db-cluster-identifier "$cluster_pattern" &> /dev/null; then
                log "Deletando cluster: $cluster_pattern"
                
                # Deletar instâncias primeiro
                local instances=$(aws docdb describe-db-clusters \
                    --db-cluster-identifier "$cluster_pattern" \
                    --query 'DBClusters[0].DBClusterMembers[].DBInstanceIdentifier' \
                    --output text 2>/dev/null)
                
                for instance in $instances; do
                    if [ -n "$instance" ] && [ "$instance" != "None" ]; then
                        aws docdb delete-db-instance --db-instance-identifier "$instance" 2>/dev/null && \
                            SUCCESS_RESOURCES+=("Instance: $instance") || \
                            FAILED_RESOURCES+=("Instance: $instance")
                    fi
                done
                
                sleep 3
                
                # Deletar cluster
                aws docdb delete-db-cluster --db-cluster-identifier "$cluster_pattern" --skip-final-snapshot 2>/dev/null && \
                    SUCCESS_RESOURCES+=("Cluster: $cluster_pattern") || \
                    FAILED_RESOURCES+=("Cluster: $cluster_pattern")
            fi
        done
        
        # PASSO 2: Deletar snapshots (não têm dependências)
        local snapshots=$(aws docdb describe-db-cluster-snapshots \
            --snapshot-type manual \
            --query "DBClusterSnapshots[?starts_with(DBClusterSnapshotIdentifier, '$aluno_id')].DBClusterSnapshotIdentifier" \
            --output text 2>/dev/null)
        
        for snapshot in $snapshots; do
            if [ -n "$snapshot" ] && [ "$snapshot" != "None" ]; then
                aws docdb delete-db-cluster-snapshot --db-cluster-snapshot-identifier "$snapshot" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("Snapshot: $snapshot") || \
                    FAILED_RESOURCES+=("Snapshot: $snapshot")
            fi
        done
        
        # PASSO 3: Deletar parameter groups
        local param_groups=$(aws docdb describe-db-cluster-parameter-groups \
            --query "DBClusterParameterGroups[?starts_with(DBClusterParameterGroupName, '$aluno_id')].DBClusterParameterGroupName" \
            --output text 2>/dev/null)
        
        for pg in $param_groups; do
            if [ -n "$pg" ] && [ "$pg" != "None" ]; then
                aws docdb delete-db-cluster-parameter-group --db-cluster-parameter-group-name "$pg" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("ParamGroup: $pg") || \
                    FAILED_RESOURCES+=("ParamGroup: $pg")
            fi
        done
        
        # PASSO 4: Deletar subnet groups
        for subnet_pattern in "${aluno_id}-docdb-lab-subnet-group"; do
            if aws docdb describe-db-subnet-groups --db-subnet-group-name "$subnet_pattern" &> /dev/null; then
                aws docdb delete-db-subnet-group --db-subnet-group-name "$subnet_pattern" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("SubnetGroup: $subnet_pattern") || \
                    FAILED_RESOURCES+=("SubnetGroup: $subnet_pattern")
            fi
        done
        
        # PASSO 5: Aguardar clusters serem deletados antes de remover SGs
        log "Aguardando clusters serem deletados (pode levar até 10 minutos)..."
        log "Verificando status dos clusters a cada 30 segundos..."
        
        local max_wait=600  # 10 minutos
        local elapsed=0
        local all_deleted=false
        
        while [ $elapsed -lt $max_wait ]; do
            local clusters_remaining=0
            
            for cluster_pattern in "${aluno_id}-lab-cluster-console" "${aluno_id}-lab-cluster-terraform" "${aluno_id}-lab-cluster-restored" "${aluno_id}-lab-cluster-pitr" "${aluno_id}-lab-cluster-rollback"; do
                if aws docdb describe-db-clusters --db-cluster-identifier "$cluster_pattern" &> /dev/null; then
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
            warning "Security Groups podem falhar ao deletar se clusters ainda existirem"
        fi
        
        # PASSO 6: Remover regras dos Security Groups primeiro
        for sg_pattern in "${aluno_id}-docdb-lab-sg" "${aluno_id}-app-client-sg"; do
            local sg_id=$(aws ec2 describe-security-groups \
                --filters "Name=group-name,Values=$sg_pattern" \
                --query 'SecurityGroups[0].GroupId' \
                --output text 2>/dev/null)
            
            if [ -n "$sg_id" ] && [ "$sg_id" != "None" ]; then
                log "Removendo regras do SG: $sg_pattern"
                
                # Remover regras de ingress
                aws ec2 describe-security-groups --group-ids "$sg_id" \
                    --query 'SecurityGroups[0].IpPermissions' \
                    --output json 2>/dev/null | \
                    jq -c '.[]' 2>/dev/null | while read rule; do
                        aws ec2 revoke-security-group-ingress --group-id "$sg_id" --ip-permissions "$rule" 2>/dev/null || true
                    done
                
                # Remover regras de egress (exceto a padrão)
                aws ec2 describe-security-groups --group-ids "$sg_id" \
                    --query 'SecurityGroups[0].IpPermissionsEgress' \
                    --output json 2>/dev/null | \
                    jq -c '.[]' 2>/dev/null | while read rule; do
                        aws ec2 revoke-security-group-egress --group-id "$sg_id" --ip-permissions "$rule" 2>/dev/null || true
                    done
            fi
        done
        
        sleep 5
        
        # PASSO 7: Deletar Security Groups
        for sg_pattern in "${aluno_id}-docdb-lab-sg" "${aluno_id}-app-client-sg"; do
            local sg_id=$(aws ec2 describe-security-groups \
                --filters "Name=group-name,Values=$sg_pattern" \
                --query 'SecurityGroups[0].GroupId' \
                --output text 2>/dev/null)
            
            if [ -n "$sg_id" ] && [ "$sg_id" != "None" ]; then
                aws ec2 delete-security-group --group-id "$sg_id" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("SecurityGroup: $sg_pattern") || \
                    FAILED_RESOURCES+=("SecurityGroup: $sg_pattern")
            fi
        done
        
        # PASSO 8: Deletar recursos de monitoramento (sem dependências)
        
        # Dashboards
        for dashboard in "${aluno_id}-DocumentDB-Dashboard" "${aluno_id}-DocumentDB-Dashboard-ByAWSCli" "${aluno_id}-Performance-Tuning-Dashboard-byAWSCLI"; do
            if aws cloudwatch get-dashboard --dashboard-name "$dashboard" &> /dev/null; then
                aws cloudwatch delete-dashboards --dashboard-names "$dashboard" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("Dashboard: $dashboard") || \
                    FAILED_RESOURCES+=("Dashboard: $dashboard")
            fi
        done
        
        # Alarmes
        local alarms=$(aws cloudwatch describe-alarms \
            --query "MetricAlarms[?starts_with(AlarmName, '$aluno_id')].AlarmName" \
            --output text 2>/dev/null)
        
        for alarm in $alarms; do
            if [ -n "$alarm" ] && [ "$alarm" != "None" ]; then
                aws cloudwatch delete-alarms --alarm-names "$alarm" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("Alarm: $alarm") || \
                    FAILED_RESOURCES+=("Alarm: $alarm")
            fi
        done
        
        # Regras EventBridge (remover targets primeiro)
        local rules=$(aws events list-rules \
            --query "Rules[?starts_with(Name, '$aluno_id')].Name" \
            --output text 2>/dev/null)
        
        for rule in $rules; do
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
        
        # Tópicos SNS
        local topics=$(aws sns list-topics \
            --query "Topics[?contains(TopicArn, '$aluno_id')].TopicArn" \
            --output text 2>/dev/null)
        
        for topic in $topics; do
            if [ -n "$topic" ] && [ "$topic" != "None" ]; then
                aws sns delete-topic --topic-arn "$topic" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("SNSTopic: $(basename $topic)") || \
                    FAILED_RESOURCES+=("SNSTopic: $(basename $topic)")
            fi
        done
        
        # Log Groups
        for log_pattern in "/aws/docdb/${aluno_id}-lab-cluster-console/audit"; do
            if aws logs describe-log-groups --log-group-name-prefix "$log_pattern" &> /dev/null; then
                aws logs delete-log-group --log-group-name "$log_pattern" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("LogGroup: $log_pattern") || \
                    FAILED_RESOURCES+=("LogGroup: $log_pattern")
            fi
        done
        
        # Buckets S3
        local buckets=$(aws s3 ls | grep "${aluno_id}-docdb-backups" | awk '{print $3}')
        for bucket in $buckets; do
            if [ -n "$bucket" ]; then
                aws s3 rm "s3://${bucket}" --recursive 2>/dev/null || true
                aws s3 rb "s3://${bucket}" 2>/dev/null && \
                    SUCCESS_RESOURCES+=("S3Bucket: $bucket") || \
                    FAILED_RESOURCES+=("S3Bucket: $bucket")
            fi
        done
    done
    
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
