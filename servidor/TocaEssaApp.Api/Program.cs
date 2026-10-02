using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;
using Microsoft.Extensions.FileProviders;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);

var arquivoBanco = builder.Configuration["Aplicacao:ArquivoBanco"]
    ?? Path.Combine("dados", "tocaessa.db");
var arquivoJsonLegado = builder.Configuration["Aplicacao:ArquivoDados"]
    ?? Path.Combine("dados", "tocaessa.json");
var conexaoPostgres = builder.Configuration.GetConnectionString("DefaultConnection");
if (!Path.IsPathRooted(arquivoBanco))
    arquivoBanco = Path.Combine(builder.Environment.ContentRootPath, arquivoBanco);
if (!Path.IsPathRooted(arquivoJsonLegado))
    arquivoJsonLegado = Path.Combine(builder.Environment.ContentRootPath, arquivoJsonLegado);
var pastaFotos = Path.Combine(Path.GetDirectoryName(arquivoBanco)!, "fotos");
Directory.CreateDirectory(pastaFotos);
var notificadorTempoReal = new NotificadorTempoReal();
builder.Services.AddSingleton(notificadorTempoReal);
builder.Services.AddSingleton(new RepositorioTocaEssa(
    conexaoPostgres ?? arquivoBanco, arquivoJsonLegado, notificadorTempoReal));
builder.Services.AddSingleton(new ArmazenamentoDeImagens(
    builder.Configuration, conexaoPostgres ?? arquivoBanco));
builder.Services.ConfigureHttpJsonOptions(opcoes =>
    opcoes.SerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddCors(opcoes => opcoes.AddDefaultPolicy(politica => politica
    .AllowAnyOrigin()
    .AllowAnyHeader()
    .AllowAnyMethod()));

var app = builder.Build();

app.UseMiddleware<TocaEssaApp.Api.TratamentoDeErros>();
app.UseCors();
app.UseDefaultFiles();
app.UseStaticFiles();
app.Use(async (contexto, proximo) =>
{
    if (contexto.Request.Path.StartsWithSegments("/api/perfil-artistico") ||
        contexto.Request.Path.StartsWithSegments("/api/apresentacoes") ||
        contexto.Request.Path.StartsWithSegments("/api/artista/cifras") ||
        contexto.Request.Path.StartsWithSegments("/api/artista/repertorios"))
    {
        var repositorio = contexto.RequestServices.GetRequiredService<RepositorioTocaEssa>();
        repositorio.ValidarSessaoArtista(ObterToken(contexto.Request) ?? string.Empty);
    }
    await proximo();
});
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(pastaFotos),
    RequestPath = "/arquivos"
});

app.MapGet("/api/arquivos/{**chave}", async Task<IResult> (
    string chave, ArmazenamentoDeImagens armazenamento, CancellationToken cancelamento) =>
{
    var arquivo = await armazenamento.Abrir(chave, cancelamento);
    return arquivo is null
        ? Results.NotFound()
        : Results.File(arquivo.Value.Conteudo, arquivo.Value.TipoDeConteudo);
});

app.MapGet("/api/saude", () => Results.Ok(new { status = "ok" }));

app.MapGet("/api/tempo-real/{codigo}", async Task (
    string codigo,
    HttpResponse resposta,
    NotificadorTempoReal notificador,
    CancellationToken cancelamento) =>
{
    resposta.ContentType = "text/event-stream";
    resposta.Headers.CacheControl = "no-cache";
    resposta.Headers.Append("X-Accel-Buffering", "no");
    await foreach (var evento in notificador.Assinar(codigo, cancelamento))
    {
        var mensagem = evento == "pulso" ? ": pulso\n\n" : $"data: {evento}\n\n";
        await resposta.WriteAsync(mensagem, cancelamento);
        await resposta.Body.FlushAsync(cancelamento);
    }
});

app.MapPost("/api/artista/contas", (
    CriarContaArtista requisicao, RepositorioTocaEssa repositorio) =>
{
    var erros = ValidarConta(requisicao.Nome, requisicao.Email, requisicao.Senha);
    if (erros.Count > 0) return Results.ValidationProblem(erros);
    var sessao = repositorio.CriarContaArtista(
        requisicao.Nome.Trim(), requisicao.Email.Trim(), requisicao.Senha);
    return Results.Created("/api/artista/conta", sessao);
});

app.MapPost("/api/artista/sessoes", (
    EntrarContaArtista requisicao, RepositorioTocaEssa repositorio) =>
{
    if (string.IsNullOrWhiteSpace(requisicao.Email) ||
        string.IsNullOrWhiteSpace(requisicao.Senha))
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["credenciais"] = ["Informe o e-mail e a senha."]
        });
    return Results.Ok(repositorio.EntrarContaArtista(requisicao.Email, requisicao.Senha));
});

app.MapGet("/api/artista/conta", (HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ObterContaArtista(ObterToken(http) ?? string.Empty)));

app.MapDelete("/api/artista/sessoes/atual", (
    HttpRequest http, RepositorioTocaEssa repositorio) =>
{
    repositorio.EncerrarSessaoArtista(ObterToken(http) ?? string.Empty);
    return Results.NoContent();
});

app.MapGet("/api/artista/cifras/consulta", (
    string musica, string? artista, HttpRequest http,
    RepositorioTocaEssa repositorio) =>
    string.IsNullOrWhiteSpace(musica)
        ? Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["musica"] = ["Informe a música."]
        })
        : Results.Ok(repositorio.ObterCifraDoArtista(
            ObterToken(http) ?? string.Empty, musica, artista)));

app.MapGet("/api/artista/cifras", (
    HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ListarCifrasDoArtista(
        ObterToken(http) ?? string.Empty)));

app.MapPut("/api/artista/cifras", (
    SalvarCifraDoArtista requisicao, HttpRequest http,
    RepositorioTocaEssa repositorio) =>
{
    if (string.IsNullOrWhiteSpace(requisicao.Musica))
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["musica"] = ["Informe a música."]
        });
    return Results.Ok(repositorio.SalvarCifraDoArtista(
        ObterToken(http) ?? string.Empty, requisicao.Musica,
        requisicao.Artista, requisicao.Url));
});

app.MapDelete("/api/artista/cifras/{id:guid}", (
    Guid id, HttpRequest http, RepositorioTocaEssa repositorio) =>
{
    repositorio.RemoverCifraDoArtista(
        ObterToken(http) ?? string.Empty, id);
    return Results.NoContent();
});

// Repertórios do artista
app.MapGet("/api/artista/repertorios", (
    HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ListarRepertorios(ObterToken(http) ?? string.Empty)));

app.MapPost("/api/artista/repertorios", (
    CriarRepertorio requisicao, HttpRequest http, RepositorioTocaEssa repositorio) =>
{
    if (string.IsNullOrWhiteSpace(requisicao.Nome))
        return Results.ValidationProblem(new Dictionary<string, string[]>
            { ["nome"] = ["Informe o nome do repertório."] });
    return Results.Ok(repositorio.CriarRepertorio(ObterToken(http) ?? string.Empty,
        requisicao.Nome));
});

app.MapDelete("/api/artista/repertorios/{id:guid}", (
    Guid id, HttpRequest http, RepositorioTocaEssa repositorio) =>
{
    repositorio.ExcluirRepertorio(ObterToken(http) ?? string.Empty, id);
    return Results.NoContent();
});

app.MapPost("/api/artista/repertorios/{id:guid}/musicas", (
    Guid id, AdicionarMusicaAoRepertorio requisicao,
    HttpRequest http, RepositorioTocaEssa repositorio) =>
{
    if (string.IsNullOrWhiteSpace(requisicao.Titulo))
        return Results.ValidationProblem(new Dictionary<string, string[]>
            { ["titulo"] = ["Informe o título da música."] });
    return Results.Ok(repositorio.AdicionarMusicaAoRepertorio(
        ObterToken(http) ?? string.Empty, id, requisicao.Titulo,
        requisicao.Artista, requisicao.Tom));
});

app.MapPut("/api/artista/repertorios/{repertorioId:guid}/musicas/{musicaId:guid}", (
    Guid repertorioId, Guid musicaId, EditarMusicaDoRepertorio requisicao,
    HttpRequest http, RepositorioTocaEssa repositorio) =>
{
    if (string.IsNullOrWhiteSpace(requisicao.Titulo))
        return Results.ValidationProblem(new Dictionary<string, string[]>
            { ["titulo"] = ["Informe o título da música."] });
    return Results.Ok(repositorio.EditarMusicaDoRepertorio(
        ObterToken(http) ?? string.Empty, repertorioId, musicaId,
        requisicao.Titulo, requisicao.Artista, requisicao.Tom));
});

app.MapDelete("/api/artista/repertorios/{repertorioId:guid}/musicas/{musicaId:guid}", (
    Guid repertorioId, Guid musicaId, HttpRequest http, RepositorioTocaEssa repositorio) =>
{
    repositorio.RemoverMusicaDoRepertorio(
        ObterToken(http) ?? string.Empty, repertorioId, musicaId);
    return Results.NoContent();
});

// Setlist da apresentação
app.MapGet("/api/apresentacoes/{id:guid}/setlist", (
    Guid id, HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ObterSetlist(ObterToken(http) ?? string.Empty, id)));

app.MapPost("/api/apresentacoes/{id:guid}/setlist/importar", (
    Guid id, ImportarRepertorio requisicao,
    HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ImportarRepertorioParaSetlist(
        ObterToken(http) ?? string.Empty, id, requisicao.RepertorioId)));

app.MapPatch("/api/apresentacoes/{apresentacaoId:guid}/setlist/{itemId:guid}/tocada", (
    Guid apresentacaoId, Guid itemId, MarcarItemDoSetlist requisicao,
    HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.MarcarItemDoSetlist(
        ObterToken(http) ?? string.Empty, apresentacaoId, itemId, requisicao.Tocada)));

app.MapDelete("/api/apresentacoes/{id:guid}/setlist", (
    Guid id, HttpRequest http, RepositorioTocaEssa repositorio) =>
{
    repositorio.LimparSetlist(ObterToken(http) ?? string.Empty, id);
    return Results.NoContent();
});

app.MapGet("/api/perfil-artistico", (
    HttpRequest http, RepositorioTocaEssa repositorio) =>
    repositorio.ObterConfiguracaoPerfil(
        ObterToken(http) ?? string.Empty) is { } perfil
        ? Results.Ok(perfil)
        : Results.NotFound());

app.MapPut("/api/perfil-artistico", (
    SalvarPerfilArtistico requisicao, HttpRequest http,
    RepositorioTocaEssa repositorio) =>
{
    if (string.IsNullOrWhiteSpace(requisicao.NomeArtistico))
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["nomeArtistico"] = ["Informe o nome artístico."]
        });
    }

    var token = ObterToken(http) ?? string.Empty;
    repositorio.SalvarPerfilDaConta(token, requisicao);
    return Results.Ok(repositorio.ObterConfiguracaoPerfil(token));
});

app.MapPost("/api/perfil-artistico/foto", async Task<IResult> (
    HttpRequest http, IFormFile foto, RepositorioTocaEssa repositorio,
    ArmazenamentoDeImagens armazenamento, CancellationToken cancelamento) =>
{
    const long limite = 5 * 1024 * 1024;
    if (foto.Length == 0 || foto.Length > limite)
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["foto"] = ["Escolha uma imagem de até 5 MB."]
        });

    await using var memoria = new MemoryStream();
    await foto.CopyToAsync(memoria);
    var imagem = DetectarImagem(memoria.ToArray());
    if (imagem is null)
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["foto"] = ["Use uma imagem JPG, PNG ou WebP válida."]
        });

    var token = ObterToken(http) ?? string.Empty;
    var perfil = repositorio.ObterPerfil(token)
        ?? throw new PerfilArtisticoNaoCadastradoException();
    var nomeArquivo = $"perfil-{perfil.Id}{imagem.Value.Extensao}";
    var url = await armazenamento.Salvar(
        nomeArquivo, imagem.Value.Tipo, memoria.ToArray(), cancelamento);
    return Results.Ok(repositorio.AtualizarFotoPerfil(token, url));
}).DisableAntiforgery();

app.MapPost("/api/publico/contas", (
    CriarPerfilPublico requisicao, RepositorioTocaEssa repositorio) =>
{
    var erros = ValidarPerfilPublico(requisicao.Nome, requisicao.Email, requisicao.Senha);
    if (erros.Count > 0) return Results.ValidationProblem(erros);
    var sessao = repositorio.CriarPerfilPublico(
        requisicao.Nome.Trim(), requisicao.Email.Trim(), requisicao.Senha);
    return Results.Created("/api/publico/perfil", sessao);
});

app.MapPost("/api/publico/sessoes", (
    EntrarPerfilPublico requisicao, RepositorioTocaEssa repositorio) =>
{
    if (string.IsNullOrWhiteSpace(requisicao.Email) ||
        string.IsNullOrWhiteSpace(requisicao.Senha))
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["credenciais"] = ["Informe o e-mail e a senha."]
        });
    return Results.Ok(repositorio.EntrarPerfilPublico(requisicao.Email, requisicao.Senha));
});

app.MapGet("/api/publico/perfil", (HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ObterPerfilPublico(ObterToken(http) ?? string.Empty)));

app.MapGet("/api/publico/estatisticas", (
    HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ObterEstatisticasDoPublico(
        ObterToken(http) ?? string.Empty)));

app.MapGet("/api/publico/apresentacoes", (
    HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ListarApresentacoesDoPublico(ObterToken(http) ?? string.Empty)));

app.MapGet("/api/publico/historico", (
    HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ListarHistoricoDoPublico(ObterToken(http) ?? string.Empty)));

app.MapGet("/api/publico/apresentacoes/{codigo}/apoio-pix", (
    string codigo, decimal valor, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.GerarApoioPix(codigo, valor)));

app.MapDelete("/api/publico/sessoes/atual", (
    HttpRequest http, RepositorioTocaEssa repositorio) =>
{
    repositorio.EncerrarSessaoPublica(ObterToken(http) ?? string.Empty);
    return Results.NoContent();
});

app.MapPost("/api/publico/perfil/foto", async Task<IResult> (
    HttpRequest http, IFormFile foto, RepositorioTocaEssa repositorio,
    ArmazenamentoDeImagens armazenamento, CancellationToken cancelamento) =>
{
    var token = ObterToken(http) ?? throw new SessaoPublicaInvalidaException();
    var perfil = repositorio.ObterPerfilPublico(token);
    const long limite = 5 * 1024 * 1024;
    if (foto.Length == 0 || foto.Length > limite)
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["foto"] = ["Escolha uma imagem de até 5 MB."]
        });

    await using var memoria = new MemoryStream();
    await foto.CopyToAsync(memoria);
    var imagem = DetectarImagem(memoria.ToArray());
    if (imagem is null)
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["foto"] = ["Use uma imagem JPG, PNG ou WebP válida."]
        });

    var nomeArquivo = $"publico-{perfil.Id}{imagem.Value.Extensao}";
    var url = await armazenamento.Salvar(
        nomeArquivo, imagem.Value.Tipo, memoria.ToArray(), cancelamento);
    return Results.Ok(repositorio.AtualizarFotoPerfilPublico(token, url));
}).DisableAntiforgery();

app.MapGet("/api/apresentacoes", (
    HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ListarApresentacoes(
        ObterToken(http) ?? string.Empty)));

app.MapPost("/api/apresentacoes", (CriarApresentacao requisicao, HttpRequest http, RepositorioTocaEssa repositorio) =>
{
    var erros = new Dictionary<string, string[]>();
    if (string.IsNullOrWhiteSpace(requisicao.Nome)) erros["nome"] = ["Informe o nome da apresentação."];
    if (string.IsNullOrWhiteSpace(requisicao.Local)) erros["local"] = ["Informe o local."];
    if (requisicao.Data == default) erros["data"] = ["Informe a data."];
    if (erros.Count > 0) return Results.ValidationProblem(erros);

    var apresentacao = repositorio.CriarApresentacao(
        ObterToken(http) ?? string.Empty, requisicao.Nome.Trim(),
        requisicao.Data, requisicao.Local.Trim(), requisicao.Tipo);
    var enderecoConfigurado = builder.Configuration["Aplicacao:EnderecoPublico"]?.TrimEnd('/');
    var enderecoPublico = string.IsNullOrWhiteSpace(enderecoConfigurado)
        ? $"{http.Scheme}://{http.Host}"
        : enderecoConfigurado;
    var linkPublico = $"{enderecoPublico}/#/publico/{apresentacao.Codigo}";

    return Results.Created($"/api/apresentacoes/{apresentacao.Id}",
        new ApresentacaoCriada(apresentacao, linkPublico));
});

app.MapPut("/api/apresentacoes/{apresentacaoId:guid}", (
    Guid apresentacaoId, EditarApresentacao requisicao, HttpRequest http,
    RepositorioTocaEssa repositorio) =>
{
    var erros = new Dictionary<string, string[]>();
    if (string.IsNullOrWhiteSpace(requisicao.Nome)) erros["nome"] = ["Informe o nome da apresentação."];
    if (string.IsNullOrWhiteSpace(requisicao.Local)) erros["local"] = ["Informe o local."];
    if (requisicao.Data == default) erros["data"] = ["Informe a data."];
    if (erros.Count > 0) return Results.ValidationProblem(erros);

    return Results.Ok(repositorio.EditarApresentacao(
        ObterToken(http) ?? string.Empty, apresentacaoId,
        requisicao.Nome.Trim(), requisicao.Data,
        requisicao.Local.Trim(), requisicao.Tipo));
});

app.MapDelete("/api/apresentacoes/{apresentacaoId:guid}", (
    Guid apresentacaoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
{
    repositorio.ExcluirApresentacao(
        ObterToken(http) ?? string.Empty, apresentacaoId);
    return Results.NoContent();
});

app.MapPatch("/api/apresentacoes/{apresentacaoId:guid}/status", (
    Guid apresentacaoId, AlterarStatusApresentacao requisicao, HttpRequest http,
    RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.AlterarStatusApresentacao(
        ObterToken(http) ?? string.Empty, apresentacaoId, requisicao.Status)));

app.MapGet("/api/publico/apresentacoes/{codigo}", (string codigo, RepositorioTocaEssa repositorio) =>
    repositorio.ObterApresentacaoPublica(codigo) is { } apresentacao
        ? Results.Ok(apresentacao)
        : Results.NotFound());

app.MapPost("/api/publico/apresentacoes/{codigo}/pedidos", (
    string codigo, CriarPedidoMusical requisicao, HttpRequest http,
    RepositorioTocaEssa repositorio) =>
{
    if (requisicao.Tipo == TipoPedido.Musica && string.IsNullOrWhiteSpace(requisicao.Musica))
        return Results.ValidationProblem(new Dictionary<string, string[]> { ["musica"] = ["Informe a música."] });
    if (requisicao.Tipo == TipoPedido.Alo && string.IsNullOrWhiteSpace(requisicao.DestinatarioAlo))
        return Results.ValidationProblem(new Dictionary<string, string[]> { ["destinatarioAlo"] = ["Informe para quem é o Alô."] });
    var pedido = repositorio.CriarPedido(
        codigo, requisicao.Musica?.Trim() ?? string.Empty, requisicao.Artista?.Trim(),
        requisicao.NomeSolicitante?.Trim(), ObterToken(http),
        requisicao.FormaParticipacao, requisicao.TomPreferido?.Trim(),
        requisicao.Recado?.Trim(), requisicao.Tipo,
        requisicao.DestinatarioAlo?.Trim());
    return Results.Created($"/api/publico/apresentacoes/{codigo}/pedidos/{pedido.Id}", pedido);
});

app.MapGet("/api/publico/apresentacoes/{codigo}/fila", (
    string codigo, HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ListarFilaPublica(
        codigo, http.Headers["X-Identificador-Publico"].FirstOrDefault(), ObterToken(http))));

app.MapGet("/api/publico/apresentacoes/{codigo}/participantes", (
    string codigo, HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ListarParticipantesDaResenha(
        codigo, ObterToken(http) ?? string.Empty)));

app.MapPost("/api/publico/apresentacoes/{codigo}/participacoes", (
    string codigo, HttpRequest http, RepositorioTocaEssa repositorio) =>
{
    repositorio.RegistrarParticipacaoNaResenha(
        codigo, ObterToken(http) ?? string.Empty);
    return Results.NoContent();
});

app.MapGet("/api/publico/apresentacoes/{codigo}/pedidos/{pedidoId:guid}", (
    string codigo, Guid pedidoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
    repositorio.ObterPedidoPublico(codigo, pedidoId, ObterToken(http)) is { } pedido
        ? Results.Ok(pedido)
        : Results.NotFound());

app.MapGet("/api/publico/apresentacoes/{codigo}/meus-pedidos", (
    string codigo, HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ListarPedidosDoPublico(
        codigo, ObterToken(http) ?? string.Empty)));

app.MapPatch("/api/publico/apresentacoes/{codigo}/pedidos/{pedidoId:guid}/cancelar", (
    string codigo, Guid pedidoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.CancelarPedidoPeloPublico(
        codigo, pedidoId, ObterToken(http))));

app.MapPut("/api/publico/apresentacoes/{codigo}/pedidos/{pedidoId:guid}/avaliacao", (
    string codigo, Guid pedidoId, AvaliarPedidoMusical requisicao,
    HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.AvaliarPedidoPeloPublico(
        codigo, pedidoId, requisicao.Estrelas,
        requisicao.IdentificadorAvaliador, ObterToken(http))));

app.MapGet("/api/apresentacoes/{apresentacaoId:guid}/pedidos", (
    Guid apresentacaoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ListarPedidosDoArtista(
        ObterToken(http) ?? string.Empty, apresentacaoId)));

app.MapGet("/api/apresentacoes/{apresentacaoId:guid}/grupos-pedidos", (
    Guid apresentacaoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ListarGruposDePedidosDoArtista(
        ObterToken(http) ?? string.Empty, apresentacaoId)));

app.MapGet("/api/apresentacoes/{apresentacaoId:guid}/estatisticas", (
    Guid apresentacaoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ObterEstatisticasDaApresentacao(
        ObterToken(http) ?? string.Empty, apresentacaoId)));

app.MapGet("/api/apresentacoes/{apresentacaoId:guid}/participantes", (
    Guid apresentacaoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ListarParticipantesDaResenha(
        ObterToken(http) ?? string.Empty, apresentacaoId)));

app.MapPost("/api/apresentacoes/{apresentacaoId:guid}/foto-retrospectiva", async Task<IResult> (
    Guid apresentacaoId, HttpRequest http, IFormFile foto,
    RepositorioTocaEssa repositorio,
    ArmazenamentoDeImagens armazenamento, CancellationToken cancelamento) =>
{
    const long limite = 8 * 1024 * 1024;
    var token = ObterToken(http) ?? string.Empty;
    var apresentacao = repositorio.ObterApresentacaoDoArtista(
        token, apresentacaoId);
    if (apresentacao.Tipo != TipoApresentacao.ResenhaEntreAmigos)
        throw new RecursoDisponivelSomenteNaResenhaException();
    if (foto.Length == 0 || foto.Length > limite)
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["foto"] = ["Escolha uma imagem de até 8 MB."]
        });

    await using var memoria = new MemoryStream();
    await foto.CopyToAsync(memoria);
    var imagem = DetectarImagem(memoria.ToArray());
    if (imagem is null)
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["foto"] = ["Use uma imagem JPG, PNG ou WebP válida."]
        });

    var nomeArquivo = $"resenha-{apresentacaoId}{imagem.Value.Extensao}";
    var url = await armazenamento.Salvar(
        nomeArquivo, imagem.Value.Tipo, memoria.ToArray(), cancelamento);
    return Results.Ok(repositorio.AtualizarFotoRetrospectiva(
        token, apresentacaoId, url));
}).DisableAntiforgery();

app.MapPatch("/api/apresentacoes/{apresentacaoId:guid}/pedidos/{pedidoId:guid}/status", (
    Guid apresentacaoId, Guid pedidoId, AlterarStatusPedidoMusical requisicao,
    HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.AlterarStatus(
        ObterToken(http) ?? string.Empty, apresentacaoId,
        pedidoId, requisicao.Status)));

app.MapPatch("/api/apresentacoes/{apresentacaoId:guid}/grupos-pedidos/{representanteId:guid}/status", (
    Guid apresentacaoId, Guid representanteId,
    AlterarStatusPedidoMusical requisicao, HttpRequest http,
    RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.AlterarStatusDoGrupo(
        ObterToken(http) ?? string.Empty, apresentacaoId,
        representanteId, requisicao.Status)));

app.MapPut("/api/apresentacoes/{apresentacaoId:guid}/fila", (
    Guid apresentacaoId, ReordenarFilaMusical requisicao, HttpRequest http,
    RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ReordenarFila(
        ObterToken(http) ?? string.Empty, apresentacaoId, requisicao.Pedidos)));

app.MapPut("/api/apresentacoes/{apresentacaoId:guid}/fila-agrupada", (
    Guid apresentacaoId, ReordenarFilaMusical requisicao,
    HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.ReordenarGruposDaFila(
        ObterToken(http) ?? string.Empty, apresentacaoId, requisicao.Pedidos)));

app.MapPatch("/api/apresentacoes/{apresentacaoId:guid}/pedidos", (
    Guid apresentacaoId, AlterarPedidosDaApresentacao requisicao,
    HttpRequest http, RepositorioTocaEssa repositorio) =>
    Results.Ok(repositorio.AlterarPedidos(
        ObterToken(http) ?? string.Empty, apresentacaoId, requisicao.Abertos)));

static (string Extensao, string Tipo)? DetectarImagem(byte[] dados)
{
    if (dados.Length >= 3 && dados[0] == 0xFF && dados[1] == 0xD8 && dados[2] == 0xFF)
        return (".jpg", "image/jpeg");
    if (dados.Length >= 8 && dados.AsSpan(0, 8).SequenceEqual(
            new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }))
        return (".png", "image/png");
    if (dados.Length >= 12 &&
        dados.AsSpan(0, 4).SequenceEqual("RIFF"u8) &&
        dados.AsSpan(8, 4).SequenceEqual("WEBP"u8))
        return (".webp", "image/webp");
    return null;
}

static string? ObterToken(HttpRequest http)
{
    var cabecalho = http.Headers.Authorization.ToString();
    const string prefixo = "Bearer ";
    return cabecalho.StartsWith(prefixo, StringComparison.OrdinalIgnoreCase)
        ? cabecalho[prefixo.Length..].Trim()
        : null;
}

static Dictionary<string, string[]> ValidarPerfilPublico(
    string nome, string email, string senha)
{
    var erros = new Dictionary<string, string[]>();
    if (string.IsNullOrWhiteSpace(nome) || nome.Trim().Length < 2)
        erros["nome"] = ["Informe seu nome."];
    if (string.IsNullOrWhiteSpace(email) || !email.Contains('@'))
        erros["email"] = ["Informe um e-mail válido."];
    if (string.IsNullOrWhiteSpace(senha) || senha.Length < 6)
        erros["senha"] = ["A senha deve ter pelo menos 6 caracteres."];
    return erros;
}

static Dictionary<string, string[]> ValidarConta(
    string nome, string email, string senha) =>
    ValidarPerfilPublico(nome, email, senha);

app.MapFallbackToFile("index.html");

app.Run();

public partial class Program;
