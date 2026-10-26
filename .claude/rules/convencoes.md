# Convenções de código

## Idioma

- Todo código, comentários, commits, nomes de classes, métodos e variáveis em português do Brasil.
- Exceções: palavras reservadas da linguagem, nomes de frameworks e bibliotecas externas.

## Servidor (.NET / ASP.NET Core)

- Minimal APIs agrupadas por assunto em `Rotas/` (`app.MapearRotasDoX()`, chamadas pelo `Program.cs`) — sem controllers.
- Teto de 350 linhas por arquivo, no app e no servidor (testes `tamanho_dos_arquivos_test.dart` e `TamanhoDosArquivosTestes.cs`): ao passar, dividir por responsabilidade.
- Complexidade ciclomática de no máximo 10 por função ou método (1 de base, mais 1 por `if`, `case`, laço, `catch`, `&&`, `||`, ternário, `?.` e `??`): acima disso, extrair funções pequenas e testadas. Regras do vibe-coding-toolkit (github.com/soumatheusgomes/vibe-coding-toolkit), trazidas pelo proprietário.
- Dividir por responsabilidade, nunca num número de linha qualquer; uma divisão de arquivo por commit, mantendo o que outros arquivos usam.
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
