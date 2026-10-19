using System.Collections.Concurrent;
using System.Globalization;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    public ResultadoCifraDoArtista ObterCifraDoArtista(
        string token, string musica, string? artista)
    {
        var conta = ObterRegistroArtista(token)
            ?? throw new SessaoArtistaInvalidaException();
        ValidarIdentificacao(musica, artista);
        var chave = CriarChave(conta.Id, musica, artista);
        var registro = ProcurarMesmaMusica(_cifrasDoArtista, chave);
        return new ResultadoCifraDoArtista(
            registro is null ? null : ParaDominio(registro),
            null,
            CriarPesquisa(musica, artista),
            ProcurarMesmaMusica(_cifrasEmTexto, chave)?.Conteudo);
    }

    /// Situação da cifra de cada música do repertório, para o acervo mostrar
    /// o que falta colar sem consultar música por música.
    public IReadOnlyCollection<CifraDaMusicaDoRepertorio> ListarCifrasDoRepertorio(
        string token, Guid repertorioId)
    {
        var conta = ObterRegistroArtista(token)
            ?? throw new SessaoArtistaInvalidaException();
        if (!_repertorios.TryGetValue(repertorioId, out var repertorio) ||
            repertorio.ArtistaId != conta.Id)
            throw new RepertorioNaoEncontradoException();
        return _musicasDoRepertorio.Values
            .Where(musica => musica.RepertorioId == repertorioId)
            .OrderBy(musica => musica.Ordem)
            .Select(musica =>
            {
                var chave = CriarChave(conta.Id, musica.Titulo, musica.Artista);
                return new CifraDaMusicaDoRepertorio(
                    musica.Id,
                    ProcurarMesmaMusica(_cifrasEmTexto, chave) is not null,
                    ProcurarMesmaMusica(_cifrasDoArtista, chave)?.Url,
                    CriarPesquisa(musica.Titulo, musica.Artista));
            })
            .ToArray();
    }

    /// Título e cantor iguais; se não houver, a única cifra com o mesmo
    /// título (cantor escrito diferente ou ausente). Com duas, não chuta.
    private static T? ProcurarMesmaMusica<T>(
        ConcurrentDictionary<(Guid ArtistaId, string Musica, string Artista), T> registros,
        (Guid ArtistaId, string Musica, string Artista) chave) where T : class
    {
        if (registros.TryGetValue(chave, out var exato)) return exato;
        var mesmoTitulo = registros
            .Where(par => par.Key.ArtistaId == chave.ArtistaId && par.Key.Musica == chave.Musica)
            .Take(2)
            .ToArray();
        return mesmoTitulo.Length == 1 ? mesmoTitulo[0].Value : null;
    }

    private const int TamanhoMaximoDaCifraEmTexto = 20_000;

    /// Letra e cifra coladas no app. Guarda os espaços que alinham os
    /// acordes; tira só linhas e espaços sobrando nas bordas. Vazio apaga.
    public ResultadoCifraDoArtista SalvarCifraEmTexto(
        string token, string musica, string? artista, string? texto)
    {
        lock (_sincronizacao)
        {
            var conta = ObterRegistroArtista(token)
                ?? throw new SessaoArtistaInvalidaException();
            ValidarIdentificacao(musica, artista);
            var conteudo = LimparCifraEmTexto(texto);
            if (conteudo.Length > TamanhoMaximoDaCifraEmTexto)
                throw new DadosDeCifraInvalidosException();
            var chave = CriarChave(conta.Id, musica, artista);
            if (conteudo.Length == 0)
            {
                _cifrasEmTexto.TryRemove(chave, out _);
            }
            else
            {
                var tomAnterior = TomDaCifra(_cifrasEmTexto.GetValueOrDefault(chave)?.Conteudo);
                var registro = _cifrasEmTexto.GetValueOrDefault(chave) ?? new CifraEmTextoRegistro
                {
                    Id = Guid.NewGuid(),
                    ArtistaId = conta.Id,
                    MusicaNormalizada = chave.Musica,
                    ArtistaNormalizado = chave.Artista
                };
                registro.Musica = musica.Trim();
                registro.Artista = string.IsNullOrWhiteSpace(artista) ? null : artista.Trim();
                registro.Conteudo = conteudo;
                registro.AtualizadaEm = DateTimeOffset.UtcNow;
                _cifrasEmTexto[chave] = registro;
                AcompanharTomDaCifra(conta.Id, musica, artista, tomAnterior, conteudo);
                EscalarHinosDaLetraNova(conta.Id, conteudo);
            }
            SalvarEstado();
            return ObterCifraDoArtista(token, musica, artista);
        }
    }

    private static string LimparCifraEmTexto(string? texto)
    {
        var linhas = (texto ?? string.Empty)
            .Replace("\r\n", "\n").Replace('\r', '\n')
            .Split('\n')
            .Select(linha => linha.TrimEnd())
            .ToList();
        while (linhas.Count > 0 && linhas[0].Length == 0) linhas.RemoveAt(0);
        while (linhas.Count > 0 && linhas[^1].Length == 0) linhas.RemoveAt(linhas.Count - 1);
        // Várias linhas em branco seguidas, comuns ao copiar do site, viram uma.
        linhas = linhas.Where((linha, i) => linha.Length > 0 || linhas[i - 1].Length > 0).ToList();
        return string.Join('\n', linhas);
    }

    private static readonly Regex TomDoCabecalho =
        new(@"^\s*Tom:\s*([A-G][#b]?m?)(?![\w#])", RegexOptions.Multiline);

    private static string? TomDaCifra(string? conteudo) =>
        conteudo is not null && TomDoCabecalho.Match(conteudo) is { Success: true } achado
            ? achado.Groups[1].Value
            : null;

    /// "Tom: E" da cifra colada preenche o tom das músicas do artista que
    /// ainda estão sem tom, no acervo e na setlist. Trocar o "Tom:" depois
    /// leva junto o tom que veio da cifra; tom escolhido à mão fica.
    private void AcompanharTomDaCifra(
        Guid artistaId, string musica, string? artista, string? tomAnterior, string conteudo)
    {
        if (TomDaCifra(conteudo) is not { } tom) return;
        bool VeioDaCifra(string? atual) =>
            string.IsNullOrWhiteSpace(atual) || (tomAnterior is not null && atual == tomAnterior);
        foreach (var item in _musicasDoRepertorio.Values.Where(m =>
                     m.ArtistaId == artistaId && VeioDaCifra(m.Tom) &&
                     MesmaMusica(m.Titulo, m.Artista, musica, artista)))
            item.Tom = tom;
        foreach (var item in _itensDoSetlist.Values.Where(i =>
                     i.ArtistaId == artistaId && VeioDaCifra(i.Tom) &&
                     MesmaMusica(i.Titulo, i.Artista, musica, artista)))
            item.Tom = tom;
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
            ValidarIdentificacao(musica, artista);
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

    private static string CriarPesquisa(string musica, string? artista)
    {
        var termos = $"site:cifraclub.com.br {musica.Trim()} {artista?.Trim()} cifra";
        return $"https://www.google.com/search?q={Uri.EscapeDataString(termos)}";
    }

    private static void ValidarIdentificacao(string? musica, string? artista)
    {
        if (string.IsNullOrWhiteSpace(musica) || musica.Trim().Length > 200 ||
            artista?.Trim().Length > 200)
            throw new DadosDeCifraInvalidosException();
    }

    private static Uri ValidarUrl(string? url)
    {
        if (string.IsNullOrWhiteSpace(url) || url.Length > 2048 ||
            !Uri.TryCreate(url.Trim(), UriKind.Absolute, out var uri) ||
            (uri.Scheme != Uri.UriSchemeHttps && uri.Scheme != Uri.UriSchemeHttp) ||
            !string.IsNullOrEmpty(uri.UserInfo) || string.IsNullOrWhiteSpace(uri.IdnHost) ||
            HostLocalOuPrivado(uri.IdnHost))
            throw new UrlDeCifraInvalidaException();
        return uri;
    }

    private static bool HostLocalOuPrivado(string host)
    {
        host = host.TrimEnd('.');
        if (host.Length > 253 ||
            host.EndsWith(".local", StringComparison.OrdinalIgnoreCase) ||
            !HostDnsValido(host)) return true;
        if (host.Equals("localhost", StringComparison.OrdinalIgnoreCase) ||
            host.EndsWith(".localhost", StringComparison.OrdinalIgnoreCase)) return true;
        if (!IPAddress.TryParse(host, out var ip)) return !host.Contains('.');
        if (ip.IsIPv4MappedToIPv6) ip = ip.MapToIPv4();
        if (IPAddress.IsLoopback(ip) || ip.Equals(IPAddress.Any) ||
            ip.Equals(IPAddress.IPv6Any) || ip.IsIPv6LinkLocal ||
            ip.IsIPv6SiteLocal || ip.IsIPv6Multicast) return true;
        var bytes = ip.GetAddressBytes();
        if (bytes.Length == 16) return (bytes[0] & 0xE0) != 0x20;
        return bytes[0] == 0 || bytes[0] == 10 || bytes[0] == 127 ||
            (bytes[0] == 100 && bytes[1] is >= 64 and <= 127) ||
            (bytes[0] == 169 && bytes[1] == 254) ||
            (bytes[0] == 172 && bytes[1] is >= 16 and <= 31) ||
            (bytes[0] == 192 && (bytes[1] == 0 || bytes[1] == 168)) ||
            (bytes[0] == 198 && bytes[1] is 18 or 19) || bytes[0] >= 224;
    }

    private static bool HostDnsValido(string host)
    {
        if (IPAddress.TryParse(host, out _)) return true;
        foreach (var rotulo in host.Split('.'))
        {
            if (rotulo.Length is < 1 or > 63 || rotulo[0] == '-' ||
                rotulo[^1] == '-') return false;
            if (rotulo.Any(caractere =>
                    !(caractere is >= 'a' and <= 'z' or >= 'A' and <= 'Z' or
                        >= '0' and <= '9' or '-')))
                return false;
        }
        return host.Contains('.');
    }

    private static CifraDoArtista ParaDominio(CifraDoArtistaRegistro item) =>
        new(item.Id, item.ArtistaId, item.Musica, item.Artista, item.Url,
            item.Fonte, item.CriadaEm, item.AtualizadaEm);
}
