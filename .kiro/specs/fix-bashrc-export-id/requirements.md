# Requirements Document

## Introduction

Este documento especifica os requisitos para corrigir o bug no script `gerar-template.sh` que impede a criação correta da variável de ambiente `ID` no arquivo `.bashrc` dos alunos. O problema ocorre devido a um erro de sintaxe na linha que adiciona o export ao `.bashrc`, resultando em ambientes de alunos sem a variável `ID` configurada.

## Glossary

- **Script de Geração**: O arquivo `gerar-template.sh` responsável por gerar o template CloudFormation dinâmico
- **UserData**: Seção do template CloudFormation que contém comandos bash executados na inicialização da instância EC2
- **Variável ID**: Variável de ambiente que identifica o aluno (ex: aluno01, aluno02)
- **Arquivo bashrc**: Arquivo de configuração do shell bash localizado em `/home/[usuario]/.bashrc`

## Requirements

### Requirement 1

**User Story:** Como administrador do curso, eu quero que o script gerar-template.sh crie corretamente a variável de ambiente ID no .bashrc de cada aluno, para que os alunos possam identificar seu ambiente automaticamente.

#### Acceptance Criteria

1. WHEN o script gerar-template.sh é executado, THE Script de Geração SHALL adicionar a linha `export ID=[usuario]` ao arquivo bashrc de cada aluno com sintaxe bash válida
2. WHEN a instância EC2 do aluno é inicializada, THE UserData SHALL executar o comando echo que adiciona o export ID sem erros de sintaxe
3. WHEN o aluno faz login via SSH, THE Arquivo bashrc SHALL carregar a variável ID com o valor correto do usuário
4. THE Script de Geração SHALL usar aspas duplas corretamente para delimitar o comando echo que adiciona o export ID
5. WHEN o arquivo .bashrc é criado, THE Script de Geração SHALL garantir que a propriedade do arquivo pertence ao usuário do aluno

### Requirement 2

**User Story:** Como desenvolvedor, eu quero que o código do UserData seja legível e mantenha a consistência de sintaxe, para que futuras manutenções sejam mais fáceis.

#### Acceptance Criteria

1. THE Script de Geração SHALL manter o padrão de uso de aspas duplas para comandos echo no UserData
2. THE Script de Geração SHALL posicionar a linha do export ID após o bloco condicional de boas-vindas no .bashrc
3. WHEN múltiplas linhas são adicionadas ao .bashrc, THE Script de Geração SHALL usar o mesmo padrão de sintaxe para todas
4. THE Script de Geração SHALL preservar todas as outras configurações existentes do .bashrc sem alterações
