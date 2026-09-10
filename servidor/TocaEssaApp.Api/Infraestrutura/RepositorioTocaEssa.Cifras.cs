using System.Globalization;
using System.Net;
using System.Text;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    public ResultadoCifraDoArtista ObterCifraDoArtista(
        string token, string musica, string? artista)
    {
        var conta = ObterRegistroArtista(token)
            ?? throw new SessaoArtistaInvalidaException();
        var chave = CriarChave(conta.Id, musica, artista);
        _cifrasDoArtista.TryGetValue(chave, out var registro);
        return new ResultadoCifraDoArtista(
            registro is null ? null : ParaDominio(registro),
            CriarSugestao(musica, artista),
            CriarPesquisa(musica, artista));
    }

    public IReadOnlyCollection<CifraDoArtista> ListarCifrasDoArtista(string token)
    {
        var conta = ObterRegistroArtista(token)
            ?? throw new SessaoArtistaInvalidaException();
        return _cifrasDoArtista.Values
            .Where(item => item.ArtistaId == conta.Id)
            .OrderBy(item => item.Musica)
            .Select(ParaDominio)
            .ToArray();
    }

    public CifraDoArtista SalvarCifraDoArtista(
        string token, string musica, string? artista, string url)
    {
        lock (_sincronizacao)
        {
            var conta = ObterRegistroArtista(token)
                ?? throw new SessaoArtistaInvalidaException();
            var endereco = ValidarUrl(url);
            var chave = CriarChave(conta.Id, musica, artista);
            var agora = DateTimeOffset.UtcNow;
            var registro = _cifrasDoArtista.GetValueOrDefault(chave);
            registro ??= new CifraDoArtistaRegistro
            {
                Id = Guid.NewGuid(),
                ArtistaId = conta.Id,
                MusicaNormalizada = chave.Musica,
                ArtistaNormalizado = chave.Artista,
                CriadaEm = agora
            };
            registro.Musica = musica.Trim();
            registro.Artista = string.IsNullOrWhiteSpace(artista) ? null : artista.Trim();
            registro.Url = endereco.AbsoluteUri;
            registro.Fonte = endereco.IdnHost.ToLowerInvariant();
            registro.AtualizadaEm = agora;
            _cifrasDoArtista[chave] = registro;
            SalvarEstado();
            return ParaDominio(registro);
        }
    }

    public void RemoverCifraDoArtista(string token, Guid id)
    {
        lock (_sincronizacao)
        {
            var conta = ObterRegistroArtista(token)
                ?? throw new SessaoArtistaInvalidaException();
            var item = _cifrasDoArtista.SingleOrDefault(par =>
                par.Value.Id == id && par.Value.ArtistaId == conta.Id);
            if (item.Value is null) throw new CifraDoArtistaNaoEncontradaException();
            _cifrasDoArtista.TryRemove(item.Key, out _);
            SalvarEstado();
        }
    }

    private static (Guid ArtistaId, string Musica, string Artista) CriarChave(
        Guid artistaId, string musica, string? artista) =>
        (artistaId, Normalizar(musica), Normalizar(artista));

    private static string Normalizar(string? valor)
    {
        if (string.IsNullOrWhiteSpace(valor)) return string.Empty;
        var decomposto = valor.Replace("&", " e ").Normalize(NormalizationForm.FormD);
        var resultado = new StringBuilder();
        var espaco = false;
        foreach (var caractere in decomposto)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(caractere) ==
                UnicodeCategory.NonSpacingMark) continue;
            if (char.IsLetterOrDigit(caractere))
            {
                if (espaco && resultado.Length > 0) resultado.Append(' ');
                resultado.Append(char.ToLowerInvariant(caractere));
                espaco = false;
            }
            else espaco = true;
        }
        return resultado.ToString();
    }

    private static string? CriarSugestao(string musica, string? artista)
    {
        var artistaSlug = Normalizar(artista).Replace(' ', '-');
        var musicaSlug = Normalizar(musica).Replace(' ', '-');
        return string.IsNullOrEmpty(artistaSlug) || string.IsNullOrEmpty(musicaSlug)
            ? null
            : $"https://www.cifraclub.com.br/{artistaSlug}/{musicaSlug}/";
    }

    private static string CriarPesquisa(string musica, string? artista)
    {
        var termos = $"site:cifraclub.com.br {musica.Trim()} {artista?.Trim()} cifra";
        return $"https://www.google.com/search?q={Uri.EscapeDataString(termos)}";
    }

    private static Uri ValidarUrl(string url)
    {
        if (url.Length > 2048 || !Uri.TryCreate(url.Trim(), UriKind.Absolute, out var uri) ||
            (uri.Scheme != Uri.UriSchemeHttps && uri.Scheme != Uri.UriSchemeHttp) ||
            !string.IsNullOrEmpty(uri.UserInfo) || string.IsNullOrWhiteSpace(uri.IdnHost) ||
            HostLocalOuPrivado(uri.IdnHost))
            throw new UrlDeCifraInvalidaException();
        return uri;
    }

    private static bool HostLocalOuPrivado(string host)
    {
        if (host.Equals("localhost", StringComparison.OrdinalIgnoreCase) ||
            host.EndsWith(".localhost", StringComparison.OrdinalIgnoreCase)) return true;
        if (!IPAddress.TryParse(host, out var ip)) return !host.Contains('.');
        if (IPAddress.IsLoopback(ip) || ip.IsIPv6LinkLocal || ip.IsIPv6SiteLocal) return true;
        var bytes = ip.GetAddressBytes();
        return bytes.Length == 4 && (bytes[0] == 10 || bytes[0] == 127 ||
            (bytes[0] == 169 && bytes[1] == 254) ||
            (bytes[0] == 172 && bytes[1] is >= 16 and <= 31) ||
            (bytes[0] == 192 && bytes[1] == 168));
    }

    private static CifraDoArtista ParaDominio(CifraDoArtistaRegistro item) =>
        new(item.Id, item.ArtistaId, item.Musica, item.Artista, item.Url,
            item.Fonte, item.CriadaEm, item.AtualizadaEm);
}
