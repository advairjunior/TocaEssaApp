# Segurança

## Credenciais e dados sensíveis

- Nenhuma chave de API, senha, token ou string de conexão entra em nenhum arquivo versionado.
- Arquivos `.env`, `appsettings.Production.json` com credenciais reais e `*.db` nunca são commitados.
- Antes de qualquer commit, confirmar que `git diff --check` não lista arquivos suspeitos.

## Compatibilidade pública

- Rotas públicas (por código de apresentação, sem token) nunca mudam de contrato sem autorização explícita.
- Nenhum identificador de artista é aceito do cliente para definir propriedade — a conta vem sempre do token.
- Recurso privado de outro artista responde como não encontrado, sem revelar a existência.

## Operações Git

- Nunca executar `git reset --hard`, `git push --force`, `git branch -D` sem autorização explícita.
- Nunca usar `--no-verify` para contornar hooks.
- Em caso de conflito de merge, investigar e resolver — nunca descartar alterações do proprietário.

## Migrações de banco

- Toda migração deve ser idempotente: executar duas vezes produz o mesmo resultado.
- Dados existentes (IDs, códigos, pedidos, avaliações, fotos) nunca são apagados nem renumerados.
- Se houver ambiguidade de propriedade, interromper a migração e registrar diagnóstico — nunca atribuir dados a uma conta arbitrária.

## Testes de segurança obrigatórios

- Token de um artista não pode administrar apresentação de outro artista.
- Rotas públicas continuam respondendo sem token depois de qualquer mudança de autorização.
