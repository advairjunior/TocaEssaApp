# Perfil público, Pix e pedidos coletivos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar perfil público do artista, apoio voluntário por Pix estático e agrupamento visual e operacional de pedidos musicais equivalentes.

**Architecture:** O perfil persistirá dados privados, mas as apresentações continuarão expondo somente uma projeção pública. Um serviço de domínio gerará o BR Code Pix com CRC16 sob demanda. Pedidos permanecerão registros individuais; uma projeção agrupada, calculada no servidor, comandará as telas e ações coletivas do artista.

**Tech Stack:** .NET 10 Minimal API, Entity Framework Core com PostgreSQL/SQLite, xUnit, Flutter/Dart, `http`, `qr_flutter`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-14-perfil-publico-pix-e-pedidos-coletivos-design.md`

## Global Constraints

- O apoio é voluntário e não garante aceitação, execução ou posição na fila.
- O MVP não confirma pagamentos e não armazena comprovantes.
- A chave Pix nunca integra a apresentação ou o perfil público.
- Apenas apresentações do tipo `Publica` oferecem apoio via Pix.
- Valores aceitos ficam entre R$ 1,00 e R$ 1.000,00.
- Pedidos individuais continuam persistidos para autoria, cancelamento, estatísticas e avaliação.
- Pedidos equivalentes usam música e artista com espaços normalizados e comparação sem diferenciação de maiúsculas.
- Não adicionar outro pacote de QR Code; `qr_flutter: ^4.1.0` já está no projeto.

---

### Task 1: Persistir contatos públicos e configuração privada de Pix

**Files:**
- Modify: `servidor/TocaEssaApp.Api/Dominio/Modelos.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RegistrosDoBanco.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/BancoTocaEssa.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.Contas.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.Persistencia.cs`
- Modify: `servidor/TocaEssaApp.Api/Program.cs`
- Create: `testes/TocaEssaApp.Testes/PerfilArtisticoPublicoTestes.cs`

**Interfaces:**
- Produces: `PerfilArtistico` com apenas campos públicos `Instagram`, `Whatsapp` e `ApoioPixDisponivel`.
- Produces: `ConfiguracaoPerfilArtistico` com perfil público e campos privados de edição.
- Produces: `SalvarPerfilArtistico` com contatos, visibilidade e configuração Pix.
- Produces: `RepositorioTocaEssa.ObterConfiguracaoPerfil()` e `RepositorioTocaEssa.SalvarPerfil(SalvarPerfilArtistico dados)`.

- [ ] **Step 1: Escrever testes de projeção, persistência e retrocompatibilidade**

```csharp
[Fact]
public void PerfilExpõeSomenteContatosAutorizadosENuncaAChavePix()
{
    var repositorio = new RepositorioTocaEssa();
    repositorio.SalvarPerfil(new SalvarPerfilArtistico(
        "Duo Aurora", "Voz e violão", "duoaurora", true,
        "5511999999999", false, true, "chave-secreta",
        "DUO AURORA", "SAO PAULO", "Obrigado pelo apoio"));

    var publico = repositorio.ObterPerfil()!;
    var privado = repositorio.ObterConfiguracaoPerfil()!;

    Assert.Equal("duoaurora", publico.Instagram);
    Assert.Null(publico.Whatsapp);
    Assert.True(publico.ApoioPixDisponivel);
    Assert.Equal("chave-secreta", privado.PixChave);
}

[Fact]
public void NovosDadosDoPerfilPersistemEPerfilAntigoContinuaValido()
{
    var arquivo = Path.Combine(Path.GetTempPath(), $"perfil-{Guid.NewGuid()}.db");
    try
    {
        var repositorio = new RepositorioTocaEssa(arquivo);
        repositorio.SalvarPerfil(new SalvarPerfilArtistico(
            "Duo Aurora", null, null, false, null, false, false));

        var reiniciado = new RepositorioTocaEssa(arquivo);
        var perfil = reiniciado.ObterPerfil()!;

        Assert.Null(perfil.Instagram);
        Assert.Null(perfil.Whatsapp);
        Assert.False(perfil.ApoioPixDisponivel);
    }
    finally
    {
        foreach (var item in new[] { arquivo, $"{arquivo}-shm", $"{arquivo}-wal" })
            if (File.Exists(item)) File.Delete(item);
    }
}
```

- [ ] **Step 2: Executar os testes e confirmar falha pela ausência dos novos contratos**

Run: `dotnet test testes/TocaEssaApp.Testes/TocaEssaApp.Testes.csproj --filter PerfilArtisticoPublicoTestes`

Expected: FAIL de compilação porque os novos campos e métodos ainda não existem.

- [ ] **Step 3: Implementar modelos e projeção pública**

```csharp
public sealed record PerfilArtistico(
    Guid Id, string NomeArtistico, string? Bio, string? FotoUrl = null,
    string? Instagram = null, string? Whatsapp = null,
    bool ApoioPixDisponivel = false);

public sealed record ConfiguracaoPerfilArtistico(
    PerfilArtistico Perfil, string? Instagram, bool ExibirInstagram,
    string? Whatsapp, bool ExibirWhatsapp, bool PixAtivo, string? PixChave,
    string? PixNomeBeneficiario, string? PixCidadeBeneficiario,
    string? PixMensagem);

public sealed record SalvarPerfilArtistico(
    string NomeArtistico, string? Bio, string? Instagram = null,
    bool ExibirInstagram = false, string? Whatsapp = null,
    bool ExibirWhatsapp = false, bool PixAtivo = false,
    string? PixChave = null, string? PixNomeBeneficiario = null,
    string? PixCidadeBeneficiario = null, string? PixMensagem = null);
```

Persistir campos privados em `PerfilArtisticoRegistro`; formar `PerfilArtistico` aplicando os controles de visibilidade. Atualizar todas as apresentações em memória quando o perfil mudar.

- [ ] **Step 4: Evoluir PostgreSQL e SQLite sem perder bancos existentes**

Adicionar colunas opcionais a `PerfisArtisticos` por `ADD COLUMN IF NOT EXISTS` no PostgreSQL e `AdicionarColunaSqliteSeNecessario` no SQLite. Usar `false` como padrão para os três controles booleanos.

- [ ] **Step 5: Atualizar os endpoints privados do perfil**

`GET /api/perfil-artistico` retorna `ConfiguracaoPerfilArtistico`; `PUT /api/perfil-artistico` valida comprimentos, Instagram, WhatsApp e consistência do Pix antes de salvar. As apresentações continuam serializando somente `PerfilArtistico`.

- [ ] **Step 6: Executar testes focados e toda a suíte do servidor**

Run: `dotnet test testes/TocaEssaApp.Testes/TocaEssaApp.Testes.csproj --filter PerfilArtisticoPublicoTestes`

Expected: PASS.

Run: `dotnet test TocaEssaApp.sln`

Expected: PASS sem regressões.

- [ ] **Step 7: Commit**

```powershell
git add servidor/TocaEssaApp.Api testes/TocaEssaApp.Testes/PerfilArtisticoPublicoTestes.cs
git commit -m "feat: ampliar perfil publico do artista"
```

---

### Task 2: Gerar Pix Copia e Cola com validação e CRC16

**Files:**
- Create: `servidor/TocaEssaApp.Api/Dominio/ServicoPix.cs`
- Modify: `servidor/TocaEssaApp.Api/Dominio/Modelos.cs`
- Modify: `servidor/TocaEssaApp.Api/Program.cs`
- Create: `testes/TocaEssaApp.Testes/ServicoPixTestes.cs`
- Create: `testes/TocaEssaApp.Testes/ApoioPixApiTestes.cs`

**Interfaces:**
- Produces: `ApoioPix(decimal Valor, string PixCopiaECola, string Mensagem)`.
- Produces: `ServicoPix.Gerar(string chave, string nome, string cidade, decimal valor, string? mensagem): string`.
- Produces: `GET /api/publico/apresentacoes/{codigo}/apoio-pix?valor=10.00`.

- [ ] **Step 1: Escrever testes do payload**

```csharp
[Theory]
[InlineData(1)]
[InlineData(10)]
[InlineData(1000)]
public void PayloadPixTerminaComCrc16Valido(decimal valor)
{
    var payload = ServicoPix.Gerar(
        "123e4567-e89b-12d3-a456-426614174000",
        "DUO AURORA", "SAO PAULO", valor, "TocaEssa");

    Assert.StartsWith("000201", payload);
    Assert.Contains($"54{valor.ToString("0.00").Length:00}{valor:0.00}", payload);
    Assert.Matches("6304[0-9A-F]{4}$", payload);
    Assert.True(ServicoPix.CrcEhValido(payload));
}

[Theory]
[InlineData(0)]
[InlineData(1000.01)]
public void RejeitaValorForaDoIntervalo(decimal valor) =>
    Assert.Throws<ValorApoioPixInvalidoException>(() =>
        ServicoPix.Gerar("chave", "ARTISTA", "RECIFE", valor, null));
```

- [ ] **Step 2: Executar e observar a falha esperada**

Run: `dotnet test testes/TocaEssaApp.Testes/TocaEssaApp.Testes.csproj --filter "ServicoPixTestes|ApoioPixApiTestes"`

Expected: FAIL porque `ServicoPix` e o endpoint ainda não existem.

- [ ] **Step 3: Implementar BR Code estático**

Construir campos EMV como `id + tamanho de dois dígitos + valor`, normalizar nome/cidade para caracteres aceitos, usar moeda `986`, país `BR`, valor com ponto e calcular CRC16/CCITT-FALSE sobre o payload terminado em `6304`.

- [ ] **Step 4: Implementar endpoint público seguro**

Validar apresentação existente e do tipo `Publica`, perfil com Pix ativo e configuração completa e valor dentro do intervalo. Retornar apenas `ApoioPix`; nunca serializar a chave isoladamente. Responder 404/recurso indisponível quando apoio não estiver configurado.

- [ ] **Step 5: Rodar testes focados e suíte do servidor**

Run: `dotnet test testes/TocaEssaApp.Testes/TocaEssaApp.Testes.csproj --filter "ServicoPixTestes|ApoioPixApiTestes"`

Expected: PASS.

Run: `dotnet test TocaEssaApp.sln`

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add servidor/TocaEssaApp.Api testes/TocaEssaApp.Testes/ServicoPixTestes.cs testes/TocaEssaApp.Testes/ApoioPixApiTestes.cs
git commit -m "feat: gerar apoio voluntario via pix"
```

---

### Task 3: Editar contatos e Pix no perfil do artista

**Files:**
- Modify: `cliente/lib/dominio/modelos.dart`
- Modify: `cliente/lib/infraestrutura/api_toca_essa_cifras_perfil.dart`
- Modify: `cliente/lib/telas/painel_do_artista.dart`
- Modify: `cliente/lib/telas/painel_do_artista_estado.dart`
- Modify: `cliente/lib/telas/painel_do_artista_aba_perfil.dart`
- Create: `cliente/lib/telas/painel_do_artista_perfil_publico.dart`
- Create: `cliente/test/perfil_artistico_publico_test.dart`

**Interfaces:**
- Consumes: JSON de `ConfiguracaoPerfilArtistico` e `SalvarPerfilArtistico` da Task 1.
- Produces: modelo Dart `ConfiguracaoPerfilArtistico` e método `salvarPerfil(ConfiguracaoPerfilArtisticoEdicao dados)`.
- Produces: `EditorPerfilPublicoArtista({required ConfiguracaoPerfilArtistico valor, required ValueChanged<ConfiguracaoPerfilArtisticoEdicao> onChanged})`.

- [ ] **Step 1: Escrever teste de widget para visibilidade e validação**

```dart
testWidgets('artista configura contatos publicos e apoio pix', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: EditorPerfilPublicoArtista(
        valor: ConfiguracaoPerfilArtistico.vazia(),
        onChanged: (_) {},
      ),
    ),
  ));

  expect(find.text('Perfil público e apoio'), findsOneWidget);
  expect(find.text('Exibir Instagram ao público'), findsOneWidget);
  expect(find.text('Aceitar apoio por Pix'), findsOneWidget);
  await tester.tap(find.text('Aceitar apoio por Pix'));
  await tester.pump();
  expect(find.text('Chave Pix'), findsOneWidget);
  expect(find.text('Nome do beneficiário'), findsOneWidget);
});
```

- [ ] **Step 2: Rodar o teste e confirmar falha pelos controles ausentes**

Run: `flutter test test/perfil_artistico_publico_test.dart`

Working directory: `cliente`

Expected: FAIL porque a nova seção não existe.

- [ ] **Step 3: Implementar modelos, serialização e API**

Manter `PerfilArtistico` apenas com dados públicos. Criar modelo privado de edição e enviar todos os campos no `PUT /api/perfil-artistico`, preservando valores carregados quando o usuário salva.

- [ ] **Step 4: Implementar formulário progressivo**

Exibir Instagram e WhatsApp com interruptores de publicação. Exibir chave, beneficiário, cidade e mensagem somente com Pix ativo. Acrescentar aviso recomendando chave aleatória e informar que o app não confirma pagamentos.

- [ ] **Step 5: Rodar teste focado, análise e testes Flutter**

Run: `flutter test test/perfil_artistico_publico_test.dart`

Expected: PASS.

Run: `flutter analyze`

Expected: No issues found.

Run: `flutter test`

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add cliente/lib cliente/test/perfil_artistico_publico_test.dart
git commit -m "feat: configurar perfil publico e pix"
```

---

### Task 4: Exibir perfil e modal de apoio na apresentação pública

**Files:**
- Modify: `cliente/lib/dominio/modelos.dart`
- Modify: `cliente/lib/infraestrutura/api_toca_essa_apresentacoes.dart`
- Modify: `cliente/lib/telas/componentes_publico_cabecalho.dart`
- Create: `cliente/lib/telas/perfil_publico_artista.dart`
- Create: `cliente/lib/telas/apoio_pix_artista.dart`
- Create: `cliente/test/apoio_pix_artista_test.dart`

**Interfaces:**
- Consumes: `PerfilArtistico` público e `ApoioPix` das Tasks 1 e 2.
- Produces: `ApiTocaEssa.obterApoioPix(String codigo, double valor)`.
- Produces: `PerfilPublicoArtista({required PerfilArtistico perfil, required VoidCallback? abrirInstagram, required VoidCallback? abrirWhatsapp, required VoidCallback? apoiar})`.
- Produces: `ApoioPixArtista({required Future<ApoioPix> Function(double valor) carregar})`.

- [ ] **Step 1: Escrever testes da experiência pública**

```dart
testWidgets('perfil mostra somente contatos autorizados', (tester) async {
  await tester.pumpWidget(MaterialApp(home: PerfilPublicoArtista(
    perfil: const PerfilArtistico(
      id: '1', nomeArtistico: 'Duo Aurora', instagram: 'duoaurora',
      apoioPixDisponivel: true),
    abrirInstagram: () {},
    abrirWhatsapp: null,
    apoiar: () {},
  )));

  expect(find.text('Instagram'), findsOneWidget);
  expect(find.text('WhatsApp'), findsNothing);
  expect(find.text('Apoiar o artista'), findsOneWidget);
});

testWidgets('apoio oferece valores sugeridos e codigo copiavel', (tester) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: ApoioPixArtista(
    carregar: (valor) async => ApoioPix(
      valor: valor,
      pixCopiaECola: '00020101021126580014BR.GOV.BCB.PIX6304ABCD',
      mensagem: 'Obrigado pelo apoio',
    ),
  ))));
  expect(find.text('R\$ 5'), findsOneWidget);
  expect(find.text('R\$ 10'), findsOneWidget);
  expect(find.text('R\$ 20'), findsOneWidget);
  await tester.tap(find.text('R\$ 10'));
  await tester.pumpAndSettle();
  expect(find.byType(QrImageView), findsOneWidget);
  expect(find.text('Copiar código Pix'), findsOneWidget);
});
```

- [ ] **Step 2: Rodar e observar a falha esperada**

Run: `flutter test test/apoio_pix_artista_test.dart`

Working directory: `cliente`

Expected: FAIL porque os widgets ainda não existem.

- [ ] **Step 3: Implementar acesso ao perfil do artista**

Tornar foto/nome do cabeçalho acionáveis e abrir uma folha/modal responsiva com foto ampliável, bio, links autorizados e apoio. Formar links `https://instagram.com/<usuario>` e `https://wa.me/<numero>` sem aceitar esquemas fornecidos pelo servidor.

- [ ] **Step 4: Implementar escolha de valor e QR Code**

Usar `QrImageView(data: apoio.pixCopiaECola)` após resposta da API. Manter o código selecionável e copiável. Mostrar a frase obrigatória de contribuição voluntária. Em erro de QR, continuar exibindo o código.

- [ ] **Step 5: Rodar verificação Flutter**

Run: `flutter test test/apoio_pix_artista_test.dart`

Expected: PASS.

Run: `flutter analyze`

Expected: No issues found.

Run: `flutter test`

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add cliente/lib cliente/test/apoio_pix_artista_test.dart
git commit -m "feat: permitir apoio pix na apresentacao publica"
```

---

### Task 5: Criar projeção e ações de pedidos coletivos no servidor

**Files:**
- Modify: `servidor/TocaEssaApp.Api/Dominio/Modelos.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.Pedidos.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.Avaliacoes.cs`
- Modify: `servidor/TocaEssaApp.Api/Infraestrutura/RepositorioTocaEssa.Persistencia.cs`
- Modify: `servidor/TocaEssaApp.Api/Program.cs`
- Create: `testes/TocaEssaApp.Testes/PedidosColetivosTestes.cs`

**Interfaces:**
- Produces: `GrupoPedidoMusical(Guid PedidoRepresentativoId, IReadOnlyList<Guid> PedidoIds, string Musica, string? Artista, StatusPedidoMusical Status, int? Posicao, int QuantidadePedidos, IReadOnlyList<string> Solicitantes, ...)`.
- Produces: `RepositorioTocaEssa.ListarGruposDePedidosDoArtista(Guid apresentacaoId)`.
- Produces: `RepositorioTocaEssa.AlterarStatusDoGrupo(Guid apresentacaoId, Guid representanteId, StatusPedidoMusical status)`.
- Produces: `RepositorioTocaEssa.ReordenarGruposDaFila(Guid apresentacaoId, IReadOnlyList<Guid> representantes)`.
- Produces: endpoints `/api/apresentacoes/{id}/grupos-pedidos`, `/grupos-pedidos/{representanteId}/status` e `/fila-agrupada`.

- [ ] **Step 1: Escrever testes de normalização e contagem**

```csharp
[Fact]
public void PedidosEquivalentesFormamUmGrupoDestacado()
{
    var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
    repositorio.CriarPedido(apresentacao.Codigo, "  Evidências ",
        "Chitãozinho   & Xororó", "Ana");
    repositorio.CriarPedido(apresentacao.Codigo, "evidências",
        "chitãozinho & xororó", "Beto");

    var grupo = repositorio.ListarGruposDePedidosDoArtista(apresentacao.Id).Single();

    Assert.Equal(2, grupo.QuantidadePedidos);
    Assert.Equal(2, grupo.PedidoIds.Count);
    Assert.Equal(["Ana", "Beto"], grupo.Solicitantes);
}
```

- [ ] **Step 2: Escrever testes de ciclo coletivo**

```csharp
[Fact]
public void AceitarGrupoAlteraTodosENovaDuplicataHerdaAFila()
{
    var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
    var primeiro = repositorio.CriarPedido(
        apresentacao.Codigo, "Evidências", null, "Ana");
    repositorio.CriarPedido(
        apresentacao.Codigo, "evidências", null, "Beto");

    repositorio.AlterarStatusDoGrupo(
        apresentacao.Id, primeiro.Id, StatusPedidoMusical.Aceito);
    var terceiro = repositorio.CriarPedido(
        apresentacao.Codigo, " EVIDÊNCIAS ", null, "Carla");

    Assert.Equal(StatusPedidoMusical.Aceito, terceiro.Status);
    Assert.All(
        repositorio.ListarPedidosDoArtista(apresentacao.Id),
        pedido => Assert.Equal(StatusPedidoMusical.Aceito, pedido.Status));
    Assert.Equal(3, repositorio
        .ListarGruposDePedidosDoArtista(apresentacao.Id).Single()
        .QuantidadePedidos);
}

[Fact]
public void PedidoDepoisDaFinalizacaoIniciaNovoGrupoAguardando()
{
    var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
    var primeiro = repositorio.CriarPedido(
        apresentacao.Codigo, "Evidências", null, "Ana");
    repositorio.AlterarStatusDoGrupo(
        apresentacao.Id, primeiro.Id, StatusPedidoMusical.Aceito);
    repositorio.AlterarStatusDoGrupo(
        apresentacao.Id, primeiro.Id, StatusPedidoMusical.Finalizado);

    var novo = repositorio.CriarPedido(
        apresentacao.Codigo, "Evidências", null, "Beto");

    Assert.Equal(StatusPedidoMusical.Aguardando, novo.Status);
    Assert.Equal(2, repositorio
        .ListarGruposDePedidosDoArtista(apresentacao.Id).Count);
}

[Fact]
public void CancelarUmPedidoMantemOsDemaisNoGrupo()
{
    var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
    var ana = repositorio.CriarPedido(
        apresentacao.Codigo, "Evidências", null, "Ana");
    repositorio.CriarPedido(
        apresentacao.Codigo, "evidências", null, "Beto");

    repositorio.CancelarPedidoPeloPublico(apresentacao.Codigo, ana.Id);

    var grupo = repositorio.ListarGruposDePedidosDoArtista(apresentacao.Id)
        .Single(item => item.Status == StatusPedidoMusical.Aguardando);
    Assert.Equal(1, grupo.QuantidadePedidos);
    Assert.Equal(["Beto"], grupo.Solicitantes);
}

[Fact]
public void GrafiasDiferentesEAlosNaoEntramNoMesmoGrupoMusical()
{
    var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
    repositorio.CriarPedido(apresentacao.Codigo, "Evidências", null, "Ana");
    repositorio.CriarPedido(apresentacao.Codigo, "Evidencia", null, "Beto");
    repositorio.CriarPedido(apresentacao.Codigo, "", null, "Carla",
        tipo: TipoPedido.Alo, destinatarioAlo: "Mesa 4");

    var grupos = repositorio.ListarGruposDePedidosDoArtista(apresentacao.Id);

    Assert.Equal(3, grupos.Count);
    Assert.Equal(2, grupos.Count(item => item.Tipo == TipoPedido.Musica));
    Assert.Single(grupos, item => item.Tipo == TipoPedido.Alo);
}
```

- [ ] **Step 3: Rodar e confirmar falha pelos contratos ausentes**

Run: `dotnet test testes/TocaEssaApp.Testes/TocaEssaApp.Testes.csproj --filter PedidosColetivosTestes`

Expected: FAIL de compilação porque `GrupoPedidoMusical` e métodos não existem.

- [ ] **Step 4: Implementar chave canônica e projeção sem persistir grupos**

Criar função interna que aplica `Trim`, reduz sequências de espaços a um espaço e usa `ToUpperInvariant`. Agrupar apenas `TipoPedido.Musica`. Para itens ativos, derivar estado com precedência `TocandoAgora`, `Aceito`, `Aguardando`; no histórico, separar por estado terminal.

- [ ] **Step 5: Implementar ações e reordenação coletivas**

Resolver o grupo pelo representante atual, alterar todos os IDs ativos sob o mesmo bloqueio, atribuir posições contíguas na ordem de criação e salvar uma única vez. Ao criar duplicata de grupo aceito ou tocando, herdar estado e posição no fim do grupo. Manter cancelamento individual.

- [ ] **Step 6: Implementar endpoints protegidos do artista**

Adicionar listagem, alteração coletiva e reordenação coletiva mantendo os endpoints individuais existentes para compatibilidade. Notificar o mecanismo de tempo real uma vez após cada operação coletiva.

- [ ] **Step 7: Rodar testes focados e suíte completa**

Run: `dotnet test testes/TocaEssaApp.Testes/TocaEssaApp.Testes.csproj --filter PedidosColetivosTestes`

Expected: PASS.

Run: `dotnet test TocaEssaApp.sln`

Expected: PASS.

- [ ] **Step 8: Commit**

```powershell
git add servidor/TocaEssaApp.Api testes/TocaEssaApp.Testes/PedidosColetivosTestes.cs
git commit -m "feat: agrupar pedidos musicais equivalentes"
```

---

### Task 6: Destacar e gerenciar pedidos coletivos no Flutter

**Files:**
- Modify: `cliente/lib/dominio/modelos.dart`
- Modify: `cliente/lib/infraestrutura/api_toca_essa_pedidos.dart`
- Modify: `cliente/lib/telas/fila_musical_artista.dart`
- Modify: `cliente/lib/telas/fila_musical_artista_conteudo.dart`
- Modify: `cliente/lib/telas/cartao_pedido_artista.dart`
- Modify: `cliente/lib/telas/componentes_publico_fila.dart`
- Create: `cliente/test/pedidos_coletivos_test.dart`

**Interfaces:**
- Consumes: `GrupoPedidoMusical` e endpoints coletivos da Task 5.
- Produces: modelo Dart `GrupoPedidoMusical`.
- Produces: `CartaoGrupoPedidoArtista({required GrupoPedidoMusical grupo, required ValueChanged<StatusPedidoMusical> alterar, ...})`.

- [ ] **Step 1: Escrever testes dos cartões agrupados**

```dart
testWidgets('grupo repetido mostra contagem e solicitantes', (tester) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    body: CartaoGrupoPedidoArtista(
      grupo: _grupo(3, const ['Ana', 'Beto', 'Carla']),
      alterar: (_) {},
    ),
  )));

  expect(find.text('3 pedidos'), findsOneWidget);
  expect(find.textContaining('Ana, Beto e mais 1'), findsOneWidget);
});

testWidgets('pedido unico nao recebe destaque coletivo', (tester) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    body: CartaoGrupoPedidoArtista(
      grupo: _grupo(1, const ['Ana']),
      alterar: (_) {},
    ),
  )));

  expect(find.text('1 pedido'), findsNothing);
  expect(find.text('Pedido por Ana'), findsOneWidget);
});

GrupoPedidoMusical _grupo(int quantidade, List<String> solicitantes) =>
    GrupoPedidoMusical(
      pedidoRepresentativoId: '10000000-0000-0000-0000-000000000001',
      pedidoIds: List.generate(quantidade, (indice) => 'pedido-$indice'),
      musica: 'Evidências',
      artista: 'Chitãozinho & Xororó',
      status: StatusPedidoMusical.aguardando,
      quantidadePedidos: quantidade,
      solicitantes: solicitantes,
      tipo: TipoPedido.musica,
    );
```

- [ ] **Step 2: Rodar e observar falha pela ausência do grupo**

Run: `flutter test test/pedidos_coletivos_test.dart`

Working directory: `cliente`

Expected: FAIL porque o modelo e a apresentação coletiva não existem.

- [ ] **Step 3: Migrar a fila do artista para grupos**

Carregar `listarGruposDePedidosDoArtista`, filtrar seções pelo estado do grupo e chamar ações coletivas. Reordenar usando `pedidoRepresentativoId`. Preservar abertura de cifra usando música e artista do grupo.

- [ ] **Step 4: Aplicar destaque visual consistente**

Mostrar selo roxo **N pedidos**, nomes resumidos e borda mais luminosa somente quando `quantidadePedidos > 1`. Na fila pública, usar a contagem real além da lista de solicitantes já existente. Evitar animações contínuas ou cores que pareçam pagamento confirmado.

- [ ] **Step 5: Rodar testes e análise**

Run: `flutter test test/pedidos_coletivos_test.dart`

Expected: PASS.

Run: `flutter analyze`

Expected: No issues found.

Run: `flutter test`

Expected: PASS.

- [ ] **Step 6: Verificar integração completa**

Run: `dotnet test TocaEssaApp.sln`

Expected: PASS.

Run: `flutter build web --release`

Working directory: `cliente`

Expected: build concluído sem erro.

- [ ] **Step 7: Commit**

```powershell
git add cliente/lib cliente/test/pedidos_coletivos_test.dart
git commit -m "feat: destacar pedidos coletivos nas filas"
```
