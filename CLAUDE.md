# TocaEssaApp

Flutter Web/PWA + ASP.NET Core + SQLite (local) / PostgreSQL (Render).
Deploy automático via `main` → Render. Painel multiartista com rotas públicas por código.

## Regras essenciais

- **Idioma:** todo código, commits e nomes de variáveis em português do Brasil.
- **TDD:** todo código novo ou alterado nasce de um teste que falhou pelo motivo esperado.
- **Compatibilidade pública:** rotas sem autenticação não mudam contrato sem autorização explícita.
- **Migrações:** idempotentes — nunca destrutivas, nunca sobrescrevem dados existentes.
- **Git destrutivo:** `reset --hard`, `push --force`, `branch -D` somente após autorização explícita.
- **Push:** somente após autorização explícita; apresentar commits e resultados de testes antes.
- **Credenciais:** nenhuma chave, senha ou `.env` entra no repositório.
- **`.vs/`:** pasta local do Visual Studio — nunca incluir em commits.

## Regras detalhadas

@.claude/rules/fluxo.md
@.claude/rules/seguranca.md
@.claude/rules/convencoes.md

## Contexto e continuidade

- Arquitetura e estado atual: `docs/claude/CONTEXTO_ATUAL.md`
- Como abrir uma nova conversa: `docs/claude/COMO_CONTINUAR.md`

## Referências rápidas

- Plano de produto: `PLANO_IMPLEMENTACAO.md`
- Deploy e smoke test: `docs/DEPLOY_RENDER.md`
- Executar localmente: `.\rodar.ps1`
