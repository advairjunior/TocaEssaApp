# Convenções de código

## Idioma

- Todo código, comentários, commits, nomes de classes, métodos e variáveis em português do Brasil.
- Exceções: palavras reservadas da linguagem, nomes de frameworks e bibliotecas externas.

## Servidor (.NET / ASP.NET Core)

- Minimal APIs no `Program.cs` — sem controllers.
- Repositório dividido em arquivos parciais por domínio: `RepositorioTocaEssa.Contas.cs`, `RepositorioTocaEssa.Apresentacoes.cs`, etc.
- Operações privadas recebem `string token` e resolvem a conta internamente — nunca recebem `ArtistaId` do cliente.
- Erros de negócio como exceções de domínio; mapeamento para HTTP em `TratamentoDeErros.cs`.

## Cliente (Flutter)

- Estado do painel em `painel_do_artista_estado.dart`.
- Comunicação com a API em `ApiTocaEssa`.
- Redesenho de telas é permitido dentro do plano de UX aprovado pelo proprietário (tema escuro mantido); comportamentos existentes continuam protegidos por testes e comportamentos novos nascem de teste que falha.

## Testes

- Repositório real em SQLite para testes de integração — sem mocks de banco.
- Testes proporcionais à alteração: mudança simples recebe teste simples; nova feature recebe suite completa.
- Helpers de teste criam conta, obtêm token e configuram perfil explicitamente — sem atalhos de produção.
- Filtro por namespace para rodar testes específicos: `--filter FullyQualifiedName~NomeDaClasseTestes`.

## Estrutura de pastas

```
servidor/TocaEssaApp.Api/   → API .NET
cliente/                    → Flutter Web/PWA
testes/TocaEssaApp.Testes/  → testes xUnit
docs/                       → documentação
```
