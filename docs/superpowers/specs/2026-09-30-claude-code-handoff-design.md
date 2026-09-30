# Transição dos projetos pessoais para o Claude Code

## Objetivo

Preparar `TocaEssaApp`, `juntoApp` e `testando dropshipping` para serem
abertos como três projetos independentes no Claude Code desktop com a conta
pessoal do proprietário. Cada pasta deverá fornecer contexto suficiente para
uma conversa nova continuar o trabalho sem depender do histórico do Codex.

## Princípios

- Manter os três projetos isolados por pasta e por contexto.
- Não criar regras pessoais em `~/.claude`, pois o computador também utiliza
  uma conta Claude corporativa.
- Não copiar informações, código ou instruções da empresa para os projetos
  pessoais.
- Versionar regras úteis à continuidade no próprio repositório quando houver
  histórico Git confiável.
- Nunca incluir credenciais, `.env`, bancos, caches, dependências ou mídia
  pesada sem revisão explícita.
- Preservar alterações existentes e não executar operações Git destrutivas.

## Estrutura por projeto

Cada raiz receberá:

```text
CLAUDE.md
.claude/rules/
docs/claude/CONTEXTO_ATUAL.md
docs/claude/COMO_CONTINUAR.md
```

`CLAUDE.md` conterá somente as regras essenciais e referências aos documentos
detalhados. `.claude/rules/` separará fluxo de trabalho, segurança e convenções
específicas para reduzir conflitos. `CONTEXTO_ATUAL.md` registrará arquitetura,
estado, decisões, comandos e riscos. `COMO_CONTINUAR.md` fornecerá um prompt
curto de abertura e uma checklist para validar se o Claude carregou o contexto.

## TocaEssaApp

O contexto registrará Flutter Web/PWA, ASP.NET Core, SQLite/PostgreSQL, Render,
deploy automático pela `main`, isolamento multiartista e contratos públicos por
código. As regras exigirão preservação da compatibilidade pública, autorização
por proprietário, migrações idempotentes e testes proporcionais à alteração.

O estado inicial será a `main` sincronizada com
`github.com/advairjunior/TocaEssaApp`, mantendo `.vs/` fora do Git.

## juntoApp

O `CLAUDE.md` importará `@AGENTS.md`, preservando integralmente as regras de
código em português e arquitetura existentes. Regras adicionais destacarão que
a branch `codex/corrige-travamento-camera` contém commits locais e muitas
alterações rastreadas e não rastreadas ainda não consolidadas.

Nenhuma preparação poderá limpar, trocar ou sobrescrever essa branch. Antes de
qualquer nova tarefa, Claude deverá executar inspeções somente leitura, explicar
o estado encontrado e trabalhar ao redor das alterações existentes.

## testando dropshipping

O projeto ainda não possui commit inicial. O contexto distinguirá documentos
comerciais, scripts, ferramentas locais, dependências, saídas e mídias. Regras
específicas impedirão publicação automática, anúncios, compras, mensagens a
fornecedores ou mudanças em contas externas sem autorização explícita.

As regras comerciais proibirão alegações médicas, depoimentos inventados,
preços ou prazos não confirmados e uso de material sem licença. `.pnpm-store`,
`.tools`, `.video-tools`, `node_modules`, `outputs` e mídias serão revisados
antes de qualquer commit inicial.

## Uso no Claude Code desktop

O usuário abrirá separadamente estas pastas:

- `C:\Users\Usuário\Documents\ChatGPT\TocaEssaApp`
- `C:\Users\Usuário\Documents\EntreNosApp`
- `C:\Users\Usuário\Documents\ChatGPT\testando dropshipping`

Em cada projeto, o primeiro chat deverá executar `/context` para confirmar o
carregamento do `CLAUDE.md`. No juntoApp, deverá também confirmar a importação
de `AGENTS.md`. O primeiro prompt de cada projeto pedirá uma auditoria somente
leitura antes de autorizar qualquer alteração.

## Critérios de conclusão

- Os três projetos possuem instruções independentes e sem contradições.
- Nenhuma credencial ou conteúdo corporativo é incluído.
- O trabalho não commitado do juntoApp permanece intacto.
- O TocaEssaApp permanece limpo, exceto pelo `.vs/` local já existente.
- O projeto de dropshipping não recebe commit inicial automaticamente.
- Cada documento de continuidade aponta para arquivos e comandos existentes.
