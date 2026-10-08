# Como continuar o TocaEssaApp em uma nova conversa

## Prompt de abertura

Cole isso no primeiro chat ao abrir o projeto no Claude Code:

```
Projeto TocaEssaApp — Flutter Web/PWA + ASP.NET Core + PostgreSQL no Render.
Leia CLAUDE.md, docs/claude/CONTEXTO_ATUAL.md e git log --oneline -10.
Faça uma auditoria somente leitura e me conte o estado atual antes de qualquer alteração.
```

## Checklist de validação do contexto

Confirme que o Claude carregou corretamente respondendo a estas perguntas:

- [ ] O Claude mencionou que o projeto é multiartista com isolamento por `ArtistaId`?
- [ ] O Claude sabe que operações privadas extraem a conta do token, nunca do cliente?
- [ ] O Claude sabe que rotas públicas por código continuam sem autenticação?
- [ ] O Claude sabe que `main` faz deploy automático no Render?
- [ ] O Claude sabe que `.vs/` deve permanecer fora do Git?
- [ ] O Claude sabe que push requer autorização explícita?

Se algum item falhar, peça: `Releia docs/claude/CONTEXTO_ATUAL.md e CLAUDE.md`.

## Contexto de cada área de trabalho

### Próximas features

O roadmap original está entregue. As ideias futuras, com o que já foi
investigado, ficam na seção **Banco de ideias** do `PLANO_IMPLEMENTACAO.md`.

### Verificação rápida do estado do projeto

```powershell
git status
git log --oneline -10
dotnet test TocaEssaApp.sln
cd cliente; flutter analyze; flutter test
```

### Antes de fazer push

```powershell
dotnet build TocaEssaApp.sln --no-restore
dotnet test TocaEssaApp.sln --no-build
cd cliente; flutter analyze; flutter test
git diff --check
```

Apresente commits, resultados de testes e riscos de migração. Aguarde autorização.

## Onde encontrar cada coisa

| O que preciso | Onde fica |
|---------------|----------|
| Roadmap de produto | `PLANO_IMPLEMENTACAO.md` |
| Arquitetura e decisões | `docs/superpowers/specs/` |
| Planos de implementação detalhados | `docs/superpowers/plans/` |
| Deploy e smoke test | `docs/DEPLOY_RENDER.md` |
| Estado atual do projeto | `docs/claude/CONTEXTO_ATUAL.md` (este diretório) |
| Regras detalhadas | `.claude/rules/` |
