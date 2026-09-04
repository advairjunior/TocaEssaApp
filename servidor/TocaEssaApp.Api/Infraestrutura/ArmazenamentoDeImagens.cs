using Amazon.Runtime;
using Amazon.S3;
using Amazon.S3.Model;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed class ArmazenamentoDeImagens : IDisposable
{
    private readonly string _pastaLocal;
    private readonly string? _bucket;
    private readonly AmazonS3Client? _clienteR2;

    public ArmazenamentoDeImagens(IConfiguration configuracao, string pastaLocal)
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

    public async Task<string> Salvar(
        string nomeArquivo,
        string tipoDeConteudo,
        byte[] conteudo,
        CancellationToken cancelamento)
    {
        ValidarNome(nomeArquivo);
        if (_clienteR2 is null)
        {
            var prefixo = Path.GetFileNameWithoutExtension(nomeArquivo);
            foreach (var anterior in Directory.EnumerateFiles(_pastaLocal, $"{prefixo}.*"))
                File.Delete(anterior);
            await File.WriteAllBytesAsync(
                Path.Combine(_pastaLocal, nomeArquivo), conteudo, cancelamento);
            return $"/arquivos/{nomeArquivo}?v={DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}";
        }

        var chave = $"imagens/{nomeArquivo}";
        await using var fluxo = new MemoryStream(conteudo);
        await _clienteR2.PutObjectAsync(new PutObjectRequest
        {
            BucketName = _bucket,
            Key = chave,
            ContentType = tipoDeConteudo,
            InputStream = fluxo,
            AutoCloseStream = false,
            DisablePayloadSigning = true,
            DisableDefaultChecksumValidation = true
        }, cancelamento);
        return $"/api/arquivos/{chave}?v={DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}";
    }

    public async Task<(byte[] Conteudo, string TipoDeConteudo)?> Abrir(
        string chave,
        CancellationToken cancelamento)
    {
        if (_clienteR2 is null || string.IsNullOrWhiteSpace(chave) ||
            !chave.StartsWith("imagens/", StringComparison.Ordinal) || chave.Contains(".."))
            return null;
        try
        {
            using var resposta = await _clienteR2.GetObjectAsync(new GetObjectRequest
            {
                BucketName = _bucket,
                Key = chave
            }, cancelamento);
            await using var memoria = new MemoryStream();
            await resposta.ResponseStream.CopyToAsync(memoria, cancelamento);
            return (memoria.ToArray(), resposta.Headers.ContentType ?? "application/octet-stream");
        }
        catch (AmazonS3Exception excecao) when (excecao.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    private static void ValidarNome(string nomeArquivo)
    {
        if (string.IsNullOrWhiteSpace(nomeArquivo) || nomeArquivo != Path.GetFileName(nomeArquivo))
            throw new InvalidOperationException("Nome de imagem inválido.");
    }

    public void Dispose() => _clienteR2?.Dispose();
}
