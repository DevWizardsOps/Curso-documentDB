# Checklist de Manutenção do DocumentDB

## 📋 Visão Geral

Este checklist deve ser usado para todas as manutenções planejadas no DocumentDB, incluindo upgrades de versão, modificações de instâncias, e aplicação de patches.

---

## 🗓️ FASE 1: Planejamento (1-2 semanas antes)

### Definição de Escopo

- [ ] Identificar tipo de manutenção necessária
  - [ ] Upgrade de versão (major/minor)
  - [ ] Modificação de instância (resize)
  - [ ] Mudança de configuração
  - [ ] Aplicação de patches

- [ ] Determinar impacto da manutenção
  - [ ] Downtime esperado: _______ minutos
  - [ ] Breaking changes: Sim / Não
  - [ ] Requer teste em staging: Sim / Não
  - [ ] Requer atualização de aplicações: Sim / Não

### Documentação

- [ ] Revisar release notes (se upgrade)
- [ ] Documentar estado atual do sistema
  - [ ] Versão atual: _____________
  - [ ] Instance class atual: _____________
  - [ ] Número de instâncias: _____________
  - [ ] Baseline de performance (CPU, Memória, Latency)

- [ ] Revisar compatibilidade
  - [ ] Drivers de aplicação compatíveis: Sim / Não
  - [ ] Features deprecated removidas: Sim / Não
  - [ ] Mudanças de comportamento: Sim / Não

### Ambiente de Teste

- [ ] Criar/atualizar ambiente de staging
- [ ] Replicar configuração de produção
- [ ] Executar manutenção em staging primeiro
- [ ] Testar aplicações após manutenção
- [ ] Documentar resultados do teste
- [ ] Identificar problemas e soluções

### Aprovações

- [ ] Obter aprovação do gestor técnico
- [ ] Obter aprovação do product owner
- [ ] Agendar janela de manutenção
  - Data: ___/___/_____ 
  - Hora início: _____:_____ 
  - Hora fim: _____:_____
  - Timezone: _____________

### Comunicação

- [ ] Criar comunicado de manutenção
- [ ] Notificar stakeholders (email/Slack)
- [ ] Atualizar status page (se aplicável)
- [ ] Agendar lembretes (1 semana, 1 dia, 1 hora antes)

### Preparação de Rollback

- [ ] Documentar procedimento de rollback
- [ ] Testar rollback em staging
- [ ] Preparar scripts de rollback
- [ ] Identificar critérios de rollback
  - [ ] Performance degradada >30%
  - [ ] Erro crítico de aplicação
  - [ ] Instabilidade do cluster
  - [ ] Outros: _________________

---

## ⚙️ FASE 2: Preparação (1 dia antes)

### Backup e Segurança

- [ ] Criar snapshot manual pré-manutenção
  - Snapshot ID: _______________________
  - Horário: ___/___/_____ _____:_____
  - Status: Available / Pending / Failed

- [ ] Verificar backups automáticos ativos
- [ ] Confirmar período de retenção adequado
- [ ] Testar restauração de backup (opcional mas recomendado)

### Validação do Ambiente

- [ ] Verificar status do cluster: Available
- [ ] Verificar saúde de todas as instâncias
- [ ] Verificar replica lag < 1 segundo
- [ ] Confirmar absence de operações pesadas agendadas
- [ ] Verificar espaço em disco disponível

### Métricas Baseline

- [ ] Capturar baseline de performance (últimas 24h)
  - CPU média: _____% 
  - Memória livre: _____ GB
  - Conexões ativas: _____
  - Read latency: _____ ms
  - Write latency: _____ ms
  - IOPS: _____

- [ ] Exportar métricas para comparação posterior

### Recursos e Equipe

- [ ] Confirmar disponibilidade da equipe
  - Engenheiro primário: _______________
  - Engenheiro backup: _______________
  - On-call: _______________

- [ ] Preparar ferramentas e acessos
  - [ ] AWS Console access
  - [ ] AWS CLI configurado
  - [ ] Scripts de manutenção testados
  - [ ] Acesso ao mongosh
  - [ ] VPN/Bastion configurado

- [ ] Preparar canais de comunicação
  - [ ] Slack channel: #_______________
  - [ ] War room (se necessário)
  - [ ] Bridge line (se necessário)

### Revisão Final

- [ ] Revisar runbook de manutenção
- [ ] Revisar runbook de rollback
- [ ] Confirmar horário da manutenção
- [ ] Última verificação com stakeholders

---

## 🚀 FASE 3: Execução (Durante a manutenção)

### Pré-Manutenção

- [ ] Notificar início da manutenção (Slack/Email/Status page)
- [ ] Registrar horário de início: ___:___
- [ ] Verificar última vez que cluster está saudável
- [ ] Fazer screenshot das métricas atuais

### Durante a Execução

- [ ] Executar script/comandos de manutenção
- [ ] Registrar cada passo executado
- [ ] Monitorar logs em tempo real
- [ ] Observar métricas CloudWatch
- [ ] Registrar quaisquer erros ou avisos

**Log de Execução:**
```
___:___ - Ação: ________________________________
___:___ - Ação: ________________________________
___:___ - Ação: ________________________________
___:___ - Ação: ________________________________
```

### Monitoramento

- [ ] Acompanhar progresso da manutenção
- [ ] Verificar status do cluster periodicamente
- [ ] Monitorar conexões ativas
- [ ] Observar alertas do CloudWatch
- [ ] Verificar logs de erro

### Critérios de Go/No-Go

Se qualquer critério abaixo falhar, considere rollback:

- [ ] Cluster retorna ao status "available"
- [ ] Todas as instâncias estão "available"
- [ ] Versão/configuração aplicada corretamente
- [ ] Sem erros críticos nos logs
- [ ] Replica lag < 5 segundos

---

## ✅ FASE 4: Validação Pós-Manutenção

### Validação Técnica

- [ ] Confirmar versão/configuração aplicada
  - Esperado: _____________
  - Atual: _____________

- [ ] Verificar status de todas as instâncias
- [ ] Verificar topologia do cluster
- [ ] Testar conexão com mongosh
- [ ] Executar queries de teste

**Queries de Validação:**
```javascript
// Verificar versão
db.version()

// Testar escrita
db.test_maint.insertOne({test: true, ts: new Date()})

// Testar leitura
db.test_maint.findOne({test: true})

// Verificar replica set
rs.status()

// Limpar
db.test_maint.drop()
```

### Validação de Performance

- [ ] Comparar métricas com baseline
  - CPU atual vs baseline: ___% vs ___%
  - Memória livre vs baseline: ___ GB vs ___ GB
  - Read latency vs baseline: ___ ms vs ___ ms
  - Write latency vs baseline: ___ ms vs ___ ms

- [ ] Verificar que não há degradação > 10%
- [ ] Verificar conexões ativas normalizaram
- [ ] Verificar replica lag < 1 segundo

### Validação de Aplicação

- [ ] Verificar health checks das aplicações
- [ ] Executar smoke tests
- [ ] Verificar logs de erro das aplicações
- [ ] Confirmar funcionalidades críticas operando
- [ ] Testar fluxos end-to-end principais

### Monitoramento Estendido

- [ ] Configurar monitoramento adicional por 24-48h
- [ ] Verificar alertas CloudWatch
- [ ] Observar métricas de negócio
- [ ] Acompanhar feedback de usuários

---

## 📢 FASE 5: Comunicação e Fechamento

### Notificação

- [ ] Registrar horário de conclusão: ___:___
- [ ] Calcular duração total: _____ minutos
- [ ] Notificar conclusão da manutenção
  - [ ] Email para stakeholders
  - [ ] Mensagem no Slack
  - [ ] Atualizar status page

### Documentação

- [ ] Documentar manutenção realizada
  - Data/Hora: ___/___/_____ _____:_____
  - Tipo: _______________________
  - Duração: _____ minutos
  - Status: Sucesso / Sucesso com issues / Falha
  
- [ ] Documentar problemas encontrados
- [ ] Documentar soluções aplicadas
- [ ] Atualizar runbooks se necessário

### Post-Mortem (se houve problemas)

- [ ] Agendar reunião de post-mortem
- [ ] Documentar timeline de eventos
- [ ] Identificar root causes
- [ ] Criar action items
- [ ] Atualizar procedimentos

### Limpeza

- [ ] Manter snapshot pré-manutenção por 7-30 dias
- [ ] Limpar resources temporários
- [ ] Arquivar logs de manutenção
- [ ] Atualizar documentação do sistema

---

## 🔄 PROCEDIMENTO DE ROLLBACK

Execute se manutenção falhar ou causar problemas críticos:

### Decisão de Rollback

- [ ] Avaliar impacto vs tempo de rollback
- [ ] Obter aprovação de rollback
- [ ] Notificar equipe e stakeholders

### Execução de Rollback

- [ ] Registrar horário de início: ___:___
- [ ] Restaurar a partir do snapshot pré-manutenção
  ```bash
  aws docdb restore-db-cluster-from-snapshot \
    --snapshot-identifier <snapshot-id> \
    --db-cluster-identifier <cluster-id-rollback>
  ```
- [ ] Aguardar cluster estar disponível
- [ ] Recriar instâncias necessárias
- [ ] Atualizar DNS/endpoints (se necessário)
- [ ] Validar rollback bem-sucedido

### Pós-Rollback

- [ ] Notificar conclusão do rollback
- [ ] Verificar aplicações funcionando
- [ ] Agendar nova tentativa de manutenção
- [ ] Documentar lições aprendidas

---

## 📊 Métricas de Sucesso

Uma manutenção é considerada bem-sucedida se:

- ✅ Completada dentro da janela planejada
- ✅ Sem perda de dados
- ✅ Performance igual ou melhor que baseline
- ✅ Todas as aplicações funcionando
- ✅ Nenhum rollback necessário
- ✅ Downtime <= estimativa inicial

---

## 📝 Notas Adicionais

_______________________________________________________________________________
_______________________________________________________________________________
_______________________________________________________________________________
_______________________________________________________________________________

---

## ✍️ Assinaturas

**Executado por:** _______________________  
**Data:** ___/___/_____  
**Horário:** _____:_____

**Revisado por:** _______________________  
**Data:** ___/___/_____

---

**Versão:** 1.0  
**Última atualização:** 2025-01-01
