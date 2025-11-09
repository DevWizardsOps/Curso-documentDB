#!/bin/bash

# Grade script para Exercício 2 - Otimização de RTO/RPO
# Módulo 5 - Replicação, Backup e Alta Disponibilidade

set -e

ID="${ID:-seu-id}"
SCORE=0
MAX_SCORE=100
CLUSTER_ID="$ID-lab-cluster-console"

echo "=========================================="
echo "GRADE - Exercício 2: Otimização RTO/RPO"
echo "Aluno: $ID"
echo "=========================================="

# Função para verificar e pontuar
check_and_score() {
    local description="$1"
    local points="$2"
    local command="$3"
    
    echo -n "Verificando: $description... "
    
    if eval "$command" &>/dev/null; then
        echo "✅ OK (+$points pontos)"
        SCORE=$((SCORE + points))
    else
        echo "❌ FALHOU (0 pontos)"
    fi
}

# Teste 1: Verificar arquivo de requisitos SLA (15 pontos)
check_and_score "Arquivo de requisitos SLA criado" 15 \
"test -f sla-requirements.json"

# Teste 2: Verificar script RTO calculator (20 pontos)
check_and_score "Script RTO calculator existe" 20 \
"test -f scripts/rto-calculator.js"

# Teste 3: Verificar cenários de disaster recovery (15 pontos)
check_and_score "Cenários de DR documentados" 15 \
"test -f scenarios/instance-failure-recovery.sh && test -f scenarios/data-corruption-recovery.sh"

# Teste 4: Verificar função Lambda de recovery (15 pontos)
check_and_score "Função Lambda de recovery automático" 15 \
"test -f lambda/automated-recovery.py"

# Teste 5: Verificar configuração de backup otimizado (10 pontos)
echo -n "Verificando: Configuração de backup otimizada... "
BACKUP_RETENTION=$(aws docdb describe-db-clusters \
--db-cluster-identifier $CLUSTER_ID \
--query 'DBClusters[0].BackupRetentionPeriod' \
--output text 2>/dev/null || echo "0")

if [ "$BACKUP_RETENTION" -ge 7 ]; then
    echo "✅ OK (+10 pontos)"
    SCORE=$((SCORE + 10))
else
    echo "❌ FALHOU (0 pontos) - Retention: $BACKUP_RETENTION dias"
fi

# Teste 6: Verificar EventBridge para automação (10 pontos)
check_and_score "Regras EventBridge para automação" 10 \
"aws events list-rules --query 'Rules[?contains(Name, \`$ID\`) && contains(Name, \`failure\`)].Name' --output text | grep -q '$ID'"

# Teste 7: Verificar dashboard RTO/RPO (10 pontos)
check_and_score "Dashboard RTO/RPO criado" 10 \
"aws cloudwatch list-dashboards --query 'DashboardEntries[?contains(DashboardName, \`$ID-RTO-RPO\`)].DashboardName' --output text | grep -q '$ID'"

# Teste 8: Verificar alertas de SLA (5 pontos)
check_and_score "Alertas de SLA configurados" 5 \
"aws cloudwatch describe-alarms --query 'MetricAlarms[?contains(AlarmName, \`$ID\`) && contains(AlarmName, \`SLA\`)].AlarmName' --output text | grep -q 'SLA'"

echo ""

# Teste adicional: Verificar tópico SNS para recovery
echo -n "Verificando: Tópico SNS para notificações de recovery... "
RECOVERY_TOPIC=$(aws sns list-topics \
--query "Topics[?contains(TopicArn, '$ID-docdb-recovery')].TopicArn" \
--output text 2>/dev/null || echo "")

if [ ! -z "$RECOVERY_TOPIC" ]; then
    echo "✅ OK (Bonus +5 pontos)"
    SCORE=$((SCORE + 5))
else
    echo "⚠️  Tópico SNS não encontrado"
fi

echo ""
echo "=========================================="
echo "RESULTADO FINAL"
echo "=========================================="
echo "Pontuação: $SCORE/$MAX_SCORE"

if [ $SCORE -ge 80 ]; then
    echo "Status: ✅ APROVADO (Excelente!)"
elif [ $SCORE -ge 60 ]; then
    echo "Status: ⚠️  APROVADO (Bom trabalho)"
elif [ $SCORE -ge 40 ]; then
    echo "Status: ⚠️  PARCIAL (Precisa melhorar)"
else
    echo "Status: ❌ REPROVADO (Revisar exercício)"
fi

echo ""
echo "Detalhes da avaliação:"
echo "- Definição de SLA: Objetivos claros de RTO/RPO"
echo "- Análise Automatizada: Scripts para cálculo de RTO"
echo "- Cenários de DR: Planos estruturados de recuperação"
echo "- Automação: Recovery automático via Lambda"
echo "- Monitoramento: Dashboards e alertas de SLA"

if [ $SCORE -lt 80 ]; then
    echo ""
    echo "Dicas para melhorar:"
    echo "1. Defina objetivos claros de RTO/RPO por ambiente"
    echo "2. Implemente automação de recovery com Lambda"
    echo "3. Configure backup com retention adequada (≥7 dias)"
    echo "4. Crie cenários documentados de disaster recovery"
    echo "5. Configure alertas proativos para breach de SLA"
fi

# Mostrar configuração atual de backup
if aws docdb describe-db-clusters --db-cluster-identifier $CLUSTER_ID &>/dev/null; then
    echo ""
    echo "Configuração atual de backup:"
    aws docdb describe-db-clusters \
    --db-cluster-identifier $CLUSTER_ID \
    --query 'DBClusters[0].{Retention:BackupRetentionPeriod,Window:PreferredBackupWindow,MultiAZ:MultiAZ}' \
    --output table 2>/dev/null || echo "Não foi possível obter configuração de backup"
fi

# Verificar se há snapshots recentes
echo ""
echo "Snapshots recentes:"
aws docdb describe-db-cluster-snapshots \
--db-cluster-identifier $CLUSTER_ID \
--snapshot-type automated \
--max-items 3 \
--query 'DBClusterSnapshots[*].{Snapshot:DBClusterSnapshotIdentifier,Created:SnapshotCreateTime,Status:Status}' \
--output table 2>/dev/null || echo "Não foi possível listar snapshots"

echo ""
echo "🎯 Objetivos de RTO/RPO recomendados:"
echo "- Production: RTO < 2min, RPO < 5min"
echo "- Staging: RTO < 15min, RPO < 30min"
echo "- Development: RTO < 1h, RPO < 2h"

echo ""
echo "💡 Próximos passos:"
echo "- Execute testes de recovery para validar RTO real"
echo "- Implemente automação de backup cross-region"
echo "- Configure monitoramento contínuo de SLA"

exit 0