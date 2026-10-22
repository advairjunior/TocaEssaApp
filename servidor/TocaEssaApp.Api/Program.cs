using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;
using Microsoft.Extensions.FileProviders;
using System.Text.Json.Serialization;
using TocaEssaApp.Api.Rotas;
using static TocaEssaApp.Api.Rotas.AuxiliaresDasRotas;

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
builder.Services.AddSingleton(new ArmazenamentoDeStories(
    builder.Configuration, Path.Combine(Path.GetDirectoryName(arquivoBanco)!, "stories"),
    exigeR2: builder.Environment.IsProduction()));
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

app.MapearRotasDoArtista();
app.MapearRotasDeCifrasERepertorios();
app.MapearRotasDaSetlistEDoLouvor();
app.MapearRotasDoPublico();
app.MapearRotasDasApresentacoes();
app.MapearRotasDosStories();

app.MapFallbackToFile("index.html");

app.Run();

public partial class Program;
