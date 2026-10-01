# Fluxo de trabalho

## Antes de qualquer alteração

1. Executar inspeção somente leitura: `git status`, `git log --oneline -10`.
2. Ler os arquivos relevantes para entender o estado atual.
3. Explicar o que foi encontrado antes de propor mudanças.
4. Obter autorização do proprietário antes de alterar qualquer arquivo.

## Ciclo de desenvolvimento

1. Escrever o teste que falha pelo motivo esperado (RED).
2. Executar o teste e confirmar a falha esperada.
3. Implementar o mínimo para passar (GREEN).
4. Executar testes completos do escopo afetado.
5. Fazer commit atômico por task.

## Comandos de verificação (executar na raiz)

```powershell
dotnet build TocaEssaApp.sln --no-restore
dotnet test TocaEssaApp.sln --no-build
cd cliente && flutter analyze && flutter test
```

## Commits

- Mensagem em português, imperativo: `feat:`, `fix:`, `test:`, `refactor:`, `docs:`.
- Adicionar somente os arquivos da task — nunca `git add .`.
- Nunca commitar `.vs/`, `*.db`, `fotos/`, `bin/`, `obj/`.

## Push e deploy

- Apresentar commits, resultados de testes e riscos de migração antes do push.
- Push somente após autorização explícita do proprietário.
- Após push, monitorar o Render e executar o smoke test em `docs/DEPLOY_RENDER.md`.
