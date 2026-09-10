# Cifras do Artista Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar à fila do artista uma ação que sugere, confirma, salva e reutiliza links externos de cifras entre apresentações.

**Architecture:** O backend mantém associações isoladas por conta artística, gera sugestões determinísticas e valida links sem acessá-los. O Flutter consulta essa associação sob demanda, apresenta uma janela de escolha e abre a página em nova aba por uma abstração testável.

**Tech Stack:** .NET 10, ASP.NET Core Minimal APIs, EF Core com SQLite/PostgreSQL, Flutter Web, Dart, package `web`, xUnit e Flutter Test.

**Spec:** `docs/superpowers/specs/2026-09-10-cifras-do-artista-design.md`

## Global Constraints

- Não copiar nem renderizar letras ou acordes no TocaEssa.
- Não adicionar API externa paga ou que exija nova conta nesta etapa.
- Salvar a cifra no perfil geral da conta artística.
- Aceitar links HTTP/HTTPS de outros sites, após validação de segurança.
- Abrir a cifra externamente sem alterar o pedido musical nem o estado da fila.
- Manter arquivos novos ou alterados preferencialmente com no máximo 350 linhas.

---

### Task 1: Domínio, segurança e persistência das cifras

**Files:**
- Modify: `servidor/TocaEssaApp.Api/Dominio/Modelos.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RegistrosDoBanco.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/BancoTocaEssa.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.Persistencia.cs`
- Create: `servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.Cifras.cs`
- Create: `testes/TocaEssaApp.Testes/CifrasDoArtistaTestes.cs`

**Interfaces:**
- Produces: `CifraDoArtista`, `ResultadoCifraDoArtista`, `RepositorioTocaEssa.ObterCifraDoArtista`, `ListarCifrasDoArtista`, `SalvarCifraDoArtista` e `RemoverCifraDoArtista`.
- Produces: persistência `CifraDoArtistaRegistro` indexada unicamente por `ArtistaId + MusicaNormalizada + ArtistaNormalizado`.

- [ ] **Step 1: Escrever testes de domínio e isolamento que falham**

Adicionar testes que criem duas contas artísticas e validem:

```csharp
var salva = repositorio.SalvarCifraDoArtista(tokenA, "Evidências", "Chitãozinho & Xororó",
    "https://www.cifraclub.com.br/chitaozinho-e-xororo/evidencias/");
Assert.Equal(salva.Id,
    repositorio.ObterCifraDoArtista(tokenA, " evidencias ", "CHITAOZINHO E XORORO")!.Cifra!.Id);
Assert.Null(repositorio.ObterCifraDoArtista(tokenB, "Evidências", "Chitãozinho & Xororó").Cifra);
Assert.Null(repositorio.ObterCifraDoArtista(tokenA, "Evidências", null).Cifra);
```

Também cobrir substituição, remoção, reinício com SQLite e rejeição de `javascript:`, credenciais embutidas, `localhost`, loopback e redes privadas.

- [ ] **Step 2: Executar o teste e confirmar a falha**

Run: `dotnet test testes/TocaEssaApp.Testes/TocaEssaApp.Testes.csproj --no-restore -c Release --filter CifrasDoArtistaTestes`

Expected: FAIL porque os tipos e métodos de cifras ainda não existem.

- [ ] **Step 3: Criar modelos e regras mínimas**

Adicionar ao domínio:

```csharp
public sealed record CifraDoArtista(Guid Id, Guid ArtistaId, string Musica,
    string? Artista, string Url, string Fonte, DateTimeOffset CriadaEm,
    DateTimeOffset AtualizadaEm);
public sealed record ResultadoCifraDoArtista(CifraDoArtista? Cifra,
    string? UrlSugerida, string UrlPesquisa);
public sealed record SalvarCifraDoArtista(string Musica, string? Artista, string Url);
```

Implementar em `RepositorioTocaEssa.Cifras.cs` normalização Unicode, slug determinístico, pesquisa web preenchida e validação de URL. A URL manual será apenas validada e armazenada; o servidor não fará requisição ao destino.

- [ ] **Step 4: Persistir em SQLite e PostgreSQL**

Adicionar `DbSet<CifraDoArtistaRegistro>`, configuração EF, `CREATE TABLE IF NOT EXISTS` para ambos os bancos, carregamento no dicionário `_cifrasDoArtista` e gravação em `SalvarEstado()`. Configurar índice único para os três campos da chave lógica.

- [ ] **Step 5: Executar testes do backend**

Run: `dotnet test TocaEssaApp.sln --no-restore -c Release --verbosity quiet`

Expected: PASS incluindo isolamento, persistência e validação.

- [ ] **Step 6: Commit da persistência**

```bash
git add servidor/TocaEssaApp.Api testes/TocaEssaApp.Testes/CifrasDoArtistaTestes.cs
git commit -m "feat: persistir cifras por conta artística"
```

### Task 2: Endpoints autenticados de cifras

**Files:**
- Modify: `servidor/TocaEssaApp.Api/Program.cs`
- Modify: `servidor/TocaEssaApp.Api/TratamentoDeErros.cs`
- Test: `testes/TocaEssaApp.Testes/CifrasDoArtistaTestes.cs`

**Interfaces:**
- Consumes: métodos de repositório da Task 1.
- Produces: `GET /api/artista/cifras/consulta`, `GET /api/artista/cifras`, `PUT /api/artista/cifras` e `DELETE /api/artista/cifras/{id}`.

- [ ] **Step 1: Escrever testes para autenticação e entradas inválidas**

Cobrir sessão ausente, URL inválida, música vazia, consulta sem correspondência e exclusão de cifra pertencente a outra conta. A exclusão cruzada deve responder como recurso inexistente.

- [ ] **Step 2: Confirmar falha dos testes de contrato**

Run: `dotnet test testes/TocaEssaApp.Testes/TocaEssaApp.Testes.csproj --no-restore -c Release --filter CifrasDoArtistaTestes`

Expected: FAIL porque as rotas ainda não existem.

- [ ] **Step 3: Implementar rotas e proteção**

Estender o middleware artístico para `/api/artista/cifras`. Usar `ObterToken(http)` em todas as operações e retornar `ValidationProblem` para música vazia. Mapear `UrlDeCifraInvalidaException` para HTTP 400 no tratamento de erros.

- [ ] **Step 4: Executar toda a suíte do servidor**

Run: `dotnet test TocaEssaApp.sln --no-restore -c Release --verbosity quiet`

Expected: PASS.

- [ ] **Step 5: Commit da API**

```bash
git add servidor/TocaEssaApp.Api testes/TocaEssaApp.Testes/CifrasDoArtistaTestes.cs
git commit -m "feat: expor API autenticada de cifras"
```

### Task 3: Modelos, cliente HTTP e abertura externa no Flutter

**Files:**
- Modify: `cliente/lib/dominio/modelos.dart`
- Modify: `cliente/lib/infraestrutura/api_toca_essa.dart`
- Create: `cliente/lib/infraestrutura/abrir_url_externa.dart`
- Create: `cliente/lib/infraestrutura/abrir_url_externa_stub.dart`
- Create: `cliente/lib/infraestrutura/abrir_url_externa_web.dart`
- Create: `cliente/test/cifras_do_artista_test.dart`

**Interfaces:**
- Consumes: endpoints da Task 2 e token artístico já mantido por `ApiTocaEssa`.
- Produces: `CifraDoArtista`, `ResultadoCifraDoArtista`, métodos HTTP homônimos e `Future<void> abrirUrlExterna(Uri url)`.

- [ ] **Step 1: Escrever testes HTTP que falham**

Com `MockClient`, validar caminhos, `Authorization: Bearer`, query parameters codificados, JSON de consulta, PUT de confirmação e DELETE.

- [ ] **Step 2: Confirmar falha**

Run: `flutter test test/cifras_do_artista_test.dart`

Expected: FAIL porque os modelos e métodos ainda não existem.

- [ ] **Step 3: Implementar modelos e cliente HTTP**

Adicionar parsers tolerantes a artista e sugestão nulos. Implementar:

```dart
Future<ResultadoCifraDoArtista> consultarCifra(String musica, String? artista);
Future<List<CifraDoArtista>> listarCifras();
Future<CifraDoArtista> salvarCifra(String musica, String? artista, String url);
Future<void> removerCifra(String id);
```

- [ ] **Step 4: Implementar abertura condicional**

O arquivo web usa `web.window.open(url.toString(), '_blank', 'noopener,noreferrer')`. O stub lança `UnsupportedError`, permitindo importação fora da Web sem adicionar dependência.

- [ ] **Step 5: Executar análise e testes específicos**

Run: `flutter analyze && flutter test test/cifras_do_artista_test.dart`

Expected: análise limpa e testes PASS.

- [ ] **Step 6: Commit da infraestrutura Flutter**

```bash
git add cliente/lib/dominio cliente/lib/infraestrutura cliente/test/cifras_do_artista_test.dart
git commit -m "feat: integrar cliente Flutter com cifras"
```

### Task 4: Experiência de cifras na fila do artista

**Files:**
- Modify: `cliente/lib/telas/cartao_pedido_artista.dart`
- Modify: `cliente/lib/telas/fila_musical_artista.dart`
- Create: `cliente/lib/telas/escolher_cifra.dart`
- Modify: `cliente/test/cifras_do_artista_test.dart`
- Modify: `cliente/test/widget_test.dart`

**Interfaces:**
- Consumes: API e abertura externa da Task 3.
- Produces: ação `Abrir cifra`, janela de sugestão/confirmação e ação `Trocar cifra` sem acoplar o cartão ao HTTP.

- [ ] **Step 1: Escrever testes de widget que falham**

Testar cartão de música com `Abrir cifra`, cartão de alô sem essa ação, associação existente abrindo diretamente, ausência abrindo a janela, confirmação de sugestão, link manual, substituição, remoção e erro preservando a fila.

- [ ] **Step 2: Confirmar falha**

Run: `flutter test test/cifras_do_artista_test.dart test/widget_test.dart`

Expected: FAIL porque a ação e a janela ainda não existem.

- [ ] **Step 3: Tornar o cartão orientado por callbacks**

Adicionar callbacks opcionais `abrirCifra` e `trocarCifra`. O cartão apenas apresenta ações quando `pedido.tipo == TipoPedido.musica`; a tela da fila continua responsável por consulta, persistência e feedback.

- [ ] **Step 4: Implementar `EscolherCifra`**

A janela recebe o resultado da consulta e retorna uma decisão tipada: confirmar sugestão, salvar URL manual, abrir pesquisa, remover ou cancelar. Validar campo manual no servidor e mostrar erros com `mostrarErro`.

- [ ] **Step 5: Integrar sem reconstruir a fila**

Em `FilaMusicalArtista`, consultar a cifra somente ao tocar na ação. Se confirmada, abrir diretamente; caso contrário, mostrar `EscolherCifra`. Não chamar `_carregar()` ao abrir ou salvar cifra e não alterar `_pedidos`, preservando rolagem e estado.

- [ ] **Step 6: Executar validação completa**

Run: `flutter analyze`

Run: `flutter test`

Run: `flutter build web --release`

Run: `dotnet test TocaEssaApp.sln --no-restore -c Release --verbosity quiet`

Expected: análise limpa, todos os testes PASS e build web concluído.

- [ ] **Step 7: Commit da experiência completa**

```bash
git add cliente/lib cliente/test
git commit -m "feat: abrir e memorizar cifras na fila artística"
```
