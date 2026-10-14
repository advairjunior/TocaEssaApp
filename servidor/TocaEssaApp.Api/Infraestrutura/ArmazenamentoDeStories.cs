using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Amazon.Runtime;
using Amazon.S3;
using Amazon.S3.Model;

namespace TocaEssaApp.Api.Infraestrutura;

/// Arquivos dos stories. Com o R2 configurado, o celular manda e assiste
/// direto no R2 por URLs assinadas, sem o vídeo passar pelo servidor. Sem
/// R2 (local e testes), os arquivos ficam numa pasta e as URLs assinadas
/// apontam para rotas da própria API.
public sealed partial class ArmazenamentoDeStories : IDisposable
{
    public const string RotaLocal = "/api/stories-locais";
    private static readonly TimeSpan ValidadeDoEnvio = TimeSpan.FromMinutes(15);
    private static readonly TimeSpan ValidadeDaLeitura = TimeSpan.FromHours(1);

    private readonly string? _bucket;
    private readonly AmazonS3Client? _clienteR2;
    private readonly string _pastaLocal;
    // Chave só desta execução: URL local assinada não vale depois de reiniciar.
    private readonly byte[] _segredoLocal = RandomNumberGenerator.GetBytes(32);

    public ArmazenamentoDeStories(IConfiguration configuracao, string pastaLocal)
    {
        _pastaLocal = pastaLocal;
        _bucket = configuracao["Armazenamento:R2:NomeDoBucket"];
        var endpoint = configuracao["Armazenamento:R2:Endpoint"];
        var chave = configuracao["Armazenamento:R2:IdentificadorDaChave"];
        var segredo = configuracao["Armazenamento:R2:SegredoDaChave"];
        if (new[] { _bucket, endpoint, chave, segredo }.All(item => !string.IsNullOrWhiteSpace(item)))
        {
            _clienteR2 = new AmazonS3Client(
                new BasicAWSCredentials(chave, segredo),
                new AmazonS3Config
                {
                    ServiceURL = endpoint,
                    ForcePathStyle = true,
                    AuthenticationRegion = "auto"
                });
        }
    }

    public bool UsaR2 => _clienteR2 is not null;

    /// URL para o celular mandar o arquivo com PUT, e os cabeçalhos que ele
    /// precisa repetir.
    public async Task<(string Url, IReadOnlyDictionary<string, string> Cabecalhos)> UrlDeEnvio(
        string chave, string tipoDeConteudo)
    {
        var cabecalhos = new Dictionary<string, string> { ["Content-Type"] = tipoDeConteudo };
        if (_clienteR2 is null) return (AssinarLocal(chave, ValidadeDoEnvio), cabecalhos);
        var url = await _clienteR2.GetPreSignedURLAsync(new GetPreSignedUrlRequest
        {
            BucketName = _bucket,
            Key = chave,
            Verb = HttpVerb.PUT,
            ContentType = tipoDeConteudo,
            Expires = DateTime.UtcNow.Add(ValidadeDoEnvio)
        });
        return (url, cabecalhos);
    }

    public async Task<string> UrlDeLeitura(string chave)
    {
        if (_clienteR2 is null) return AssinarLocal(chave, ValidadeDaLeitura);
        return await _clienteR2.GetPreSignedURLAsync(new GetPreSignedUrlRequest
        {
            BucketName = _bucket,
            Key = chave,
            Verb = HttpVerb.GET,
            Expires = DateTime.UtcNow.Add(ValidadeDaLeitura)
        });
    }

    /// Tamanho do que chegou na chave; nulo se nada chegou.
    public async Task<long?> TamanhoGuardado(string chave, CancellationToken cancelamento)
    {
        if (_clienteR2 is null)
        {
            var arquivo = new FileInfo(CaminhoLocal(chave));
            return arquivo.Exists ? arquivo.Length : null;
        }
        try
        {
            var dados = await _clienteR2.GetObjectMetadataAsync(_bucket, chave, cancelamento);
            return dados.ContentLength;
        }
        catch (AmazonS3Exception erro) when (erro.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    public async Task Apagar(string chave, CancellationToken cancelamento)
    {
        if (_clienteR2 is null)
        {
            File.Delete(CaminhoLocal(chave));
            return;
        }
        await _clienteR2.DeleteObjectAsync(_bucket, chave, cancelamento);
    }

    /// Só para as rotas locais: confere a URL assinada por esta execução.
    public bool AssinaturaLocalValida(string chave, long expira, string? assinatura) =>
        ChaveValida(chave) &&
        DateTimeOffset.UtcNow.ToUnixTimeSeconds() <= expira &&
        assinatura is not null &&
        CryptographicOperations.FixedTimeEquals(
            Encoding.ASCII.GetBytes(Assinatura(chave, expira)),
            Encoding.ASCII.GetBytes(assinatura));

    public string CaminhoLocal(string chave) =>
        ChaveValida(chave)
            ? Path.Combine(_pastaLocal, chave.Replace('/', Path.DirectorySeparatorChar))
            : throw new ArgumentException("Chave de story inválida.", nameof(chave));

    public void Dispose() => _clienteR2?.Dispose();

    private string AssinarLocal(string chave, TimeSpan validade)
    {
        var expira = DateTimeOffset.UtcNow.Add(validade).ToUnixTimeSeconds();
        return $"{RotaLocal}/{chave}?expira={expira}&assinatura={Assinatura(chave, expira)}";
    }

    private string Assinatura(string chave, long expira) =>
        Convert.ToHexString(HMACSHA256.HashData(
            _segredoLocal, Encoding.UTF8.GetBytes($"{chave}|{expira}"))).ToLowerInvariant();

    private static bool ChaveValida(string chave) => FormatoDaChave().IsMatch(chave);

    [GeneratedRegex(@"^envios/[0-9a-f-]{36}/[0-9a-f-]{36}\.(mp4|mov|jpg|png|heic)$")]
    private static partial Regex FormatoDaChave();
}
