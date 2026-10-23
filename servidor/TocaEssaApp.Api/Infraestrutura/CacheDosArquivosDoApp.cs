using Microsoft.AspNetCore.StaticFiles;

namespace TocaEssaApp.Api.Infraestrutura;

/// O app do Flutter não muda de nome a cada versão: o navegador confere
/// index.html e os scripts a cada abertura (responde 304 quando nada mudou)
/// para não ficar preso numa versão velha. Fontes, ícones e imagens mudam
/// pouco e ficam guardados por um dia.
public static class CacheDosArquivosDoApp
{
    private static readonly string[] PastasQueMudamPouco = ["/assets", "/icons", "/canvaskit"];

    public static StaticFileOptions Opcoes() => new()
    {
        OnPrepareResponse = contexto =>
        {
            var caminho = contexto.Context.Request.Path;
            var mudaPouco = caminho.Equals("/favicon.png", StringComparison.OrdinalIgnoreCase) ||
                PastasQueMudamPouco.Any(pasta => caminho.StartsWithSegments(pasta));
            contexto.Context.Response.Headers.CacheControl =
                mudaPouco ? "public, max-age=86400" : "no-cache";
        }
    };
}
