# TocaEssaApp Multiartista Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir múltiplas contas artísticas com perfil, apresentações e operações privadas completamente isolados, preservando os dados já existentes em produção.

**Architecture:** A conta resolvida pelo token será a raiz de autorização. Perfis serão armazenados por `ArtistaId`, apresentações carregarão o proprietário e todas as operações privadas exigirão token e validarão esse vínculo; as rotas públicas continuarão resolvendo apresentações pelo código. A inicialização migrará de forma idempotente o perfil e as apresentações legados para a conta artística existente.

**Tech Stack:** .NET 10, ASP.NET Core Minimal APIs, Entity Framework Core, PostgreSQL no Render, SQLite local/testes, xUnit, Flutter/Dart.

**Spec:** `docs/superpowers/specs/2026-09-30-multiartista-design.md`

## Global Constraints

- Uma conta artística representa exatamente um perfil artístico nesta etapa.
- Contas de público e artista continuam independentes.
- Nenhum identificador de artista será aceito do cliente para definir propriedade.
- Rotas públicas por código e códigos existentes devem permanecer compatíveis.
- Migração deve preservar IDs, códigos, pedidos, avaliações, participantes, imagens e cifras.
- Recurso privado de outro artista deve responder como não encontrado.
- Nenhuma exclusão em cascata ou endpoint para apagar conta artística será criado.
- Todo código de produção novo ou alterado deve nascer de um teste que falhou pelo motivo esperado.

## Review Focus

- Banco legado com dados e exatamente uma conta deve migrar sem trocar IDs ou códigos; coberto na Task 1.
- Banco legado com dados e nenhuma ou várias contas deve falhar sem gravar associação arbitrária; coberto na Task 1.
- Dois cadastros simultâneos com o mesmo e-mail normalizado devem produzir uma conta; coberto na Task 2.
- Um token válido não pode administrar um ID pertencente a outra conta; coberto nas Tasks 3 e 4.
- Rotas públicas devem continuar funcionando sem token depois do isolamento privado; coberto na Task 5.

---

### Task 1: Modelo de propriedade e migração idempotente

**Files:**
- Modify: `servidor/TocaEssaApp.Api/Dominio/Modelos.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RegistrosDoBanco.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/BancoTocaEssa.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.Persistencia.cs`
- Create: `testes/TocaEssaApp.Testes/MigracaoMultiartistaTestes.cs`

**Interfaces:**
- Produces: `PerfilArtisticoRegistro.ArtistaId : Guid`.
- Produces: `ApresentacaoRegistro.ArtistaId : Guid`.
- Produces: `Apresentacao.ArtistaId : Guid`, preenchido pelo servidor e preservado por operações `with`.
- Produces: `_configuracoesPerfis : ConcurrentDictionary<Guid, ConfiguracaoPerfilArtistico>` no lugar do perfil global.
- Produces: estrutura persistida com índices único em perfil por artista e comum em apresentação por artista.

- [ ] **Step 1: Escrever fixtures e testes de migração que falham**

Criar bancos SQLite no esquema anterior e testar `BancoLegadoComUmaContaAdotaPerfilEApresentacoes`, `MigracaoPodeExecutarDuasVezes` e `BancoLegadoComDadosSemProprietarioUnicoFalhaSemAlterarDados`. Asserções: IDs/código permanecem iguais, os novos `ArtistaId` correspondem à conta existente e o caso ambíguo lança `InvalidOperationException`.

- [ ] **Step 2: Executar os testes e confirmar RED**

Run: `dotnet test TocaEssaApp.sln --filter FullyQualifiedName~MigracaoMultiartistaTestes`

Expected: FAIL porque as colunas e a migração ainda não existem.

- [ ] **Step 3: Adicionar propriedade ao domínio e registros**

Adicionar `Guid ArtistaId` ao final de `Apresentacao` e aos registros de perfil/apresentação. Substituir `_perfil` e `_configuracaoPerfil` pelo dicionário de configurações indexado pelo artista.

- [ ] **Step 4: Implementar migração SQLite e PostgreSQL em `GarantirEstrutura()`**

Adicionar colunas inicialmente anuláveis, associar órfãos somente quando existir exatamente uma conta, validar ausência de órfãos e criar `IX_PerfisArtisticos_ArtistaId` único e `IX_Apresentacoes_ArtistaId`. No PostgreSQL, tornar as colunas `NOT NULL`; no SQLite, reconstruir tabelas legadas quando necessário para materializar a restrição. Toda a alteração deve ser transacional e repetível.

- [ ] **Step 5: Carregar e salvar os novos vínculos**

Carregar contas e perfis por artista antes de materializar apresentações; persistir cada perfil e apresentação com o proprietário sem alterar relações filhas.

- [ ] **Step 6: Executar testes de migração e regressão de persistência**

Run: `dotnet test TocaEssaApp.sln --filter "FullyQualifiedName~MigracaoMultiartistaTestes|FullyQualifiedName~RepositorioTocaEssaTestes"`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add servidor/TocaEssaApp.Api/Dominio/Modelos.cs servidor/TocaEssaApp.Api/Infraestrutura/RegistrosDoBanco.cs servidor/TocaEssaApp.Api/Infraestrutura/BancoTocaEssa.cs servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.cs servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.Persistencia.cs testes/TocaEssaApp.Testes/MigracaoMultiartistaTestes.cs
git commit -m "feat: adicionar propriedade multiartista"
```

### Task 2: Cadastro múltiplo e perfil isolado

**Files:**
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.Contas.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.cs`
- Modify: `servidor/TocaEssaApp.Api/TratamentoDeErros.cs`
- Modify: `testes/TocaEssaApp.Testes/RepositorioTocaEssaTestes.cs`
- Create: `testes/TocaEssaApp.Testes/ContasArtistasTestes.cs`

**Interfaces:**
- Produces: `EmailArtistaJaCadastradoException`.
- Produces: `ExigirRegistroArtista(string token) : ContaArtistaRegistro`.
- Produces: `ObterPerfil(string token) : PerfilArtistico?`.
- Produces: `ObterConfiguracaoPerfil(string token) : ConfiguracaoPerfilArtistico?`.
- Produces: `SalvarPerfil(string token, SalvarPerfilArtistico dados) : PerfilArtistico`.
- Produces: `AtualizarFotoPerfil(string token, string fotoUrl) : PerfilArtistico`.

- [ ] **Step 1: Escrever testes de contas e perfis que falham**

Testar `DoisArtistasPodemCriarContaEEntrar`, `EmailArtisticoDuplicadoIgnoraMaiusculasEEspacos`, `CadastrosConcorrentesNaoDuplicamEmail` e `CadaArtistaPossuiSeuProprioPerfil` usando repositório real.

- [ ] **Step 2: Executar e confirmar RED**

Run: `dotnet test TocaEssaApp.sln --filter FullyQualifiedName~ContasArtistasTestes`

Expected: FAIL na segunda conta e no perfil isolado.

- [ ] **Step 3: Trocar a regra global por unicidade de e-mail**

Em `CriarContaArtista`, remover `_contasArtistas.IsEmpty`, verificar `EmailNormalizado` dentro do lock e traduzir violação única do banco para `EmailArtistaJaCadastradoException`. Manter hash e sessão atuais.

- [ ] **Step 4: Isolar operações de perfil pelo token**

Implementar as interfaces acima usando `_configuracoesPerfis[conta.Id]`. Atualizar somente apresentações cujo `ArtistaId` corresponda ao perfil alterado. Nome da foto continua baseado no ID do perfil.

- [ ] **Step 5: Atualizar erro e fixtures antigas**

Mapear e-mail artístico duplicado para HTTP 409 com “Este e-mail já possui uma conta de artista.” e remover `ContaArtistaJaConfiguradaException`. Atualizar helpers dos testes antigos para criar conta, obter token e configurar o perfil explicitamente.

- [ ] **Step 6: Executar testes de conta/perfil**

Run: `dotnet test TocaEssaApp.sln --filter "FullyQualifiedName~ContasArtistasTestes|FullyQualifiedName~RepositorioTocaEssaTestes|FullyQualifiedName~PerfilArtisticoPublicoTestes"`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.Contas.cs servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.cs servidor/TocaEssaApp.Api/TratamentoDeErros.cs testes/TocaEssaApp.Testes
git commit -m "feat: permitir contas e perfis de varios artistas"
```

### Task 3: Apresentações isoladas por artista

**Files:**
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.Apresentacoes.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.Persistencia.cs`
- Create: `testes/TocaEssaApp.Testes/ApresentacoesMultiartistaTestes.cs`
- Modify: demais testes em `testes/TocaEssaApp.Testes/*.cs` que criam apresentação diretamente.

**Interfaces:**
- Produces: `ListarApresentacoes(string token) : IReadOnlyCollection<Apresentacao>`.
- Produces: `CriarApresentacao(string token, string nome, DateOnly data, string local, TipoApresentacao tipo) : Apresentacao`.
- Produces: `ObterApresentacaoDoArtista(string token, Guid apresentacaoId) : Apresentacao`.
- Produces: versões com `token` de editar, excluir, alterar status e atualizar foto retrospectiva.
- Preserves: `ObterApresentacaoPublica(string codigo)` sem autenticação.

- [ ] **Step 1: Escrever testes de propriedade que falham**

Testar que dois artistas veem listas diferentes, que o criador é gravado automaticamente e que editar, excluir, alterar status ou foto usando token alheio lança `ApresentacaoNaoEncontradaException` sem modificar o recurso.

- [ ] **Step 2: Executar e confirmar RED**

Run: `dotnet test TocaEssaApp.sln --filter FullyQualifiedName~ApresentacoesMultiartistaTestes`

Expected: FAIL porque as operações ainda são globais.

- [ ] **Step 3: Implementar listagem, criação e resolução privadas**

Resolver a conta pelo token, buscar seu perfil e gravar `ArtistaId = conta.Id`. Filtrar listagens pelo proprietário. Centralizar a autorização em `ObterApresentacaoDoArtista` para evitar verificações divergentes.

- [ ] **Step 4: Aplicar resolução privada a todas as mutações de apresentação**

Editar, excluir, alterar status e foto devem primeiro resolver a apresentação com token. Manter publicação em tempo real pelo código após mutações válidas.

- [ ] **Step 5: Atualizar fixtures existentes**

Criar helper de teste que retorna `(Repositorio, Token, Apresentacao)` e substituir os usos diretos antigos, sem criar atalhos de produção sem autenticação.

- [ ] **Step 6: Executar testes de apresentações e históricos públicos**

Run: `dotnet test TocaEssaApp.sln --filter "FullyQualifiedName~ApresentacoesMultiartistaTestes|FullyQualifiedName~HistoricoPublicoTestes|FullyQualifiedName~ApoioPixApiTestes"`

Expected: PASS, inclusive acesso público por código.

- [ ] **Step 7: Commit**

```bash
git add servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.Apresentacoes.cs servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.Persistencia.cs testes/TocaEssaApp.Testes
git commit -m "feat: isolar apresentacoes por artista"
```

### Task 4: Autorizar fila, estatísticas e participantes privados

**Files:**
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.Pedidos.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.PedidosColetivos.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.Participantes.cs`
- Modify: outros parciais de `RepositorioTocaEssa` que recebam `apresentacaoId` em operação artística.
- Create: `testes/TocaEssaApp.Testes/AutorizacaoArtistaTestes.cs`

**Interfaces:**
- Consumes: `ObterApresentacaoDoArtista(string token, Guid apresentacaoId)` da Task 3.
- Produces: versões autenticadas das operações privadas de pedidos, grupos, fila, estatísticas e participantes.
- Preserves: operações públicas que recebem código e identidade pública.

- [ ] **Step 1: Escrever testes de acesso cruzado que falham**

Para cada família de operação, usar token do artista B contra apresentação do artista A e afirmar `ApresentacaoNaoEncontradaException`: listar pedidos, estatísticas, participantes, alterar pedido/grupo, abrir pedidos e reordenar fila. Confirmar que pedidos e posições permanecem intactos.

- [ ] **Step 2: Executar e confirmar RED**

Run: `dotnet test TocaEssaApp.sln --filter FullyQualifiedName~AutorizacaoArtistaTestes`

Expected: FAIL porque IDs ainda bastam para administrar recursos.

- [ ] **Step 3: Adicionar token às assinaturas privadas**

Antes de ler ou alterar pedidos, chamar a resolução centralizada da apresentação. Não modificar assinaturas públicas por código.

- [ ] **Step 4: Executar testes de autorização e regressão da fila**

Run: `dotnet test TocaEssaApp.sln --filter "FullyQualifiedName~AutorizacaoArtistaTestes|FullyQualifiedName~PedidosColetivosTestes|FullyQualifiedName~RepositorioTocaEssaTestes"`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add servidor/TocaEssaApp.Api/Infraestrutura testes/TocaEssaApp.Testes
git commit -m "fix: proteger gestao privada entre artistas"
```

### Task 5: Propagar identidade nas rotas HTTP

**Files:**
- Modify: `servidor/TocaEssaApp.Api/Program.cs`
- Modify: `servidor/TocaEssaApp.Api/TratamentoDeErros.cs`
- Create: `testes/TocaEssaApp.Testes/MultiartistaApiTestes.cs`

**Interfaces:**
- Consumes: métodos autenticados das Tasks 2–4.
- Produces: todas as rotas privadas extraem `ObterToken(http)` e passam o token ao repositório.
- Preserves: contratos JSON e URLs atuais do Flutter.

- [ ] **Step 1: Escrever teste HTTP ponta a ponta que falha**

Com `WebApplicationFactory<Program>`, cadastrar dois artistas, salvar dois perfis, criar uma apresentação para cada um e afirmar: listas isoladas, GET/PUT do perfil isolados, tentativa cruzada por ID retorna 404 e ambos os códigos públicos retornam 200 sem autorização.

- [ ] **Step 2: Executar e confirmar RED**

Run: `dotnet test TocaEssaApp.sln --filter FullyQualifiedName~MultiartistaApiTestes`

Expected: FAIL no segundo cadastro ou no isolamento.

- [ ] **Step 3: Passar token por todas as rotas privadas**

Adicionar `HttpRequest http` onde faltar e encaminhar o token para perfil, apresentações, pedidos, grupos, fila, estatísticas, participantes, fotos e estado. Manter middleware como primeira barreira, mas não depender dele para propriedade.

- [ ] **Step 4: Validar os erros HTTP**

Confirmar 409 para e-mail duplicado, 401 para sessão inválida e 404 para recurso de outro artista.

- [ ] **Step 5: Executar todos os testes do servidor**

Run: `dotnet test TocaEssaApp.sln`

Expected: PASS, zero falhas.

- [ ] **Step 6: Commit**

```bash
git add servidor/TocaEssaApp.Api/Program.cs servidor/TocaEssaApp.Api/TratamentoDeErros.cs testes/TocaEssaApp.Testes
git commit -m "feat: aplicar isolamento multiartista na api"
```

### Task 6: Fluxo Flutter para nova conta sem perfil

**Files:**
- Modify: `cliente/test/widget_artista_acesso_test.dart`
- Modify: `cliente/test/widget_artista_fluxos_test.dart`
- Modify if required by failing tests: `cliente/lib/telas/acesso_do_artista.dart`
- Modify if required by failing tests: `cliente/lib/telas/painel_do_artista_estado.dart`
- Modify if required by failing tests: `cliente/lib/telas/painel_do_artista_aba_perfil.dart`

**Interfaces:**
- Consumes: 404 de perfil como `null` em `ApiTocaEssa.obterPerfil()` e lista vazia de apresentações.
- Produces: novo artista entra no painel, vê estado vazio e consegue configurar o perfil.

- [ ] **Step 1: Acrescentar teste de regressão do cadastro múltiplo**

Simular criação bem-sucedida para uma conta quando outra já existe no backend falso e afirmar que o painel é aberto sem a mensagem global de conta configurada.

- [ ] **Step 2: Acrescentar teste do estado inicial sem perfil**

Retornar perfil `null` e apresentações vazias; afirmar que a aba de perfil permite preencher e salvar o primeiro perfil e que a área de apresentações não exibe dados de outra conta.

- [ ] **Step 3: Executar os testes direcionados**

Run: `flutter test test/widget_artista_acesso_test.dart test/widget_artista_fluxos_test.dart`

Expected: PASS se o cliente já suporta corretamente o contrato; caso algum teste falhe, a falha deve demonstrar a alteração mínima necessária antes de editar a tela.

- [ ] **Step 4: Implementar somente os ajustes exigidos pelos testes**

Não redesenhar telas. Remover qualquer tratamento específico de `ContaArtistaJaConfiguradaException` ou suposição de perfil global e preservar o fluxo visual atual.

- [ ] **Step 5: Executar análise e testes completos do Flutter**

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test`

Expected: PASS, zero falhas.

- [ ] **Step 6: Commit**

```bash
git add cliente/lib cliente/test
git commit -m "test: validar primeira experiencia multiartista"
```

### Task 7: Verificação de release e documentação operacional

**Files:**
- Modify if needed: `README.md`
- Modify if needed: `docs/DEPLOY_RENDER.md`

**Interfaces:**
- Consumes: sistema multiartista completo das Tasks 1–6.
- Produces: checklist reproduzível de deploy e validação pós-migração.

- [ ] **Step 1: Documentar migração e smoke test**

Registrar que o primeiro deploy associa os dados existentes à conta atual e que a validação exige login antigo, segunda conta, duas agendas isoladas e dois links públicos.

- [ ] **Step 2: Executar verificação limpa do servidor**

Run: `dotnet build TocaEssaApp.sln --no-restore`

Expected: build concluído sem erros.

Run: `dotnet test TocaEssaApp.sln --no-build`

Expected: PASS, zero falhas.

- [ ] **Step 3: Executar verificação limpa do Flutter**

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test`

Expected: PASS, zero falhas.

- [ ] **Step 4: Inspecionar diff e invariantes**

Run: `git diff --check`

Confirmar que nenhuma rota privada ficou sem token, que nenhum método de produção oferece bypass sem autenticação e que `.vs/` ou outros arquivos locais não entram no commit.

- [ ] **Step 5: Commit final de documentação, se houver alteração**

```bash
git add README.md docs/DEPLOY_RENDER.md
git commit -m "docs: registrar deploy multiartista"
```

- [ ] **Step 6: Parar antes do push**

Apresentar commits, resultados completos dos testes e riscos de migração ao usuário. Fazer push e acompanhar o Render somente após autorização explícita.

