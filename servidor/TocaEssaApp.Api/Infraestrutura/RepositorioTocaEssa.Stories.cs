using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

/// Stories do show: vídeos e fotos que o público manda sem conta. Todos do
/// show veem durante a apresentação e até 24 h depois; o artista guarda por
/// 7 dias. O arquivo vai direto para o armazenamento; aqui ficam os dados.
public sealed partial class RepositorioTocaEssa
{
    private const long Megabyte = 1024 * 1024;
    private const long TamanhoMaximoDoVideo = 100 * Megabyte;
    private const long TamanhoMaximoDaFoto = 15 * Megabyte;
    private const long TamanhoMaximoPorShow = 3_000_000_000;
    private const int EnviosPorAparelho = 10;
    private const int EnviosPorShow = 300;
    private const int DenunciasParaEsconder = 3;
    private static readonly TimeSpan StoriesDepoisDoFim = TimeSpan.FromHours(24);
    private static readonly TimeSpan ValidadeParaOArtista = TimeSpan.FromDays(7);
    // Envio que não foi confirmado nesse tempo não vai mais ser.
    private static readonly TimeSpan EsperaPelaConfirmacao = TimeSpan.FromHours(1);

    private static readonly IReadOnlyDictionary<string, (TipoDeStory Tipo, string Extensao)>
        TiposAceitos = new Dictionary<string, (TipoDeStory, string)>
        {
            ["video/mp4"] = (TipoDeStory.Video, "mp4"),
            ["video/quicktime"] = (TipoDeStory.Video, "mov"),
            ["image/jpeg"] = (TipoDeStory.Foto, "jpg"),
            ["image/png"] = (TipoDeStory.Foto, "png"),
            ["image/heic"] = (TipoDeStory.Foto, "heic"),
        };

    public EnvioCriado CriarEnvio(string codigo, PedidoDeEnvio pedido)
    {
        lock (_sincronizacao)
        {
            var show = ObterShowDosStories(codigo);
            if (!RecebeStories(show)) throw new StoriesFechadosException();
            var tipoDeConteudo = pedido.TipoDeConteudo.Trim().ToLowerInvariant();
            var aparelho = pedido.Aparelho.Trim();
            var nome = string.IsNullOrWhiteSpace(pedido.Nome) ? null : pedido.Nome.Trim();
            if (!TiposAceitos.TryGetValue(tipoDeConteudo, out var aceito) ||
                aceito.Tipo != pedido.Tipo ||
                pedido.Tamanho <= 0 ||
                pedido.Tamanho > (pedido.Tipo == TipoDeStory.Video
                    ? TamanhoMaximoDoVideo
                    : TamanhoMaximoDaFoto) ||
                aparelho.Length is 0 or > 64 ||
                nome?.Length > 40)
                throw new EnvioInvalidoException();

            DescartarNaoConfirmados(show.Id);
            var doShow = _enviosDoPublico.Values
                .Where(envio => envio.ApresentacaoId == show.Id)
                .ToArray();
            if (doShow.Count(envio => envio.IdentificadorDoAparelho == aparelho) >= EnviosPorAparelho ||
                doShow.Length >= EnviosPorShow ||
                doShow.Sum(envio => envio.Tamanho) + pedido.Tamanho > TamanhoMaximoPorShow)
                throw new LimiteDeEnviosException();

            var agora = Agora();
            var id = Guid.NewGuid();
            var registro = new EnvioDoPublicoRegistro
            {
                Id = id,
                ApresentacaoId = show.Id,
                ArtistaId = show.ArtistaId,
                Chave = $"envios/{show.Id}/{id}.{aceito.Extensao}",
                Tipo = pedido.Tipo,
                TipoDeConteudo = tipoDeConteudo,
                Tamanho = pedido.Tamanho,
                Nome = nome,
                IdentificadorDoAparelho = aparelho,
                CriadoEm = agora,
                ExpiraEm = agora + ValidadeParaOArtista
            };
            _enviosDoPublico[id] = registro;
            SalvarEstado();
            return new EnvioCriado(id, registro.Chave, tipoDeConteudo);
        }
    }

    /// Chave do arquivo de um envio ainda não confirmado, para conferir no
    /// armazenamento antes de confirmar.
    public string ObterChaveDoEnvioPendente(string codigo, Guid envioId)
    {
        var show = ObterShowDosStories(codigo);
        return _enviosDoPublico.TryGetValue(envioId, out var envio) &&
               envio.ApresentacaoId == show.Id && !envio.Confirmado
            ? envio.Chave
            : throw new EnvioNaoEncontradoException();
    }

    /// [tamanhoGuardado] é o que o armazenamento tem na chave (nulo se nada
    /// chegou). Diferente do declarado: o envio é descartado.
    public StoryDoShow ConfirmarEnvio(string codigo, Guid envioId, long? tamanhoGuardado)
    {
        lock (_sincronizacao)
        {
            var show = ObterShowDosStories(codigo);
            if (!_enviosDoPublico.TryGetValue(envioId, out var envio) ||
                envio.ApresentacaoId != show.Id || envio.Confirmado)
                throw new EnvioNaoEncontradoException();
            if (tamanhoGuardado != envio.Tamanho)
            {
                _enviosDoPublico.TryRemove(envioId, out _);
                SalvarEstado();
                throw new EnvioInvalidoException();
            }
            envio.Confirmado = true;
            SalvarEstado();
            return ParaStory(envio);
        }
    }

    public IReadOnlyList<StoryDoShow> ListarStoriesDoShow(string codigo)
    {
        var show = ObterShowDosStories(codigo);
        if (!MostraStories(show)) return [];
        return _enviosDoPublico.Values
            .Where(envio => envio.ApresentacaoId == show.Id &&
                            envio.Confirmado && !envio.Escondido)
            .OrderBy(envio => envio.CriadoEm)
            .Select(ParaStory)
            .ToArray();
    }

    /// Cada aparelho conta uma vez; com 3 denúncias o story some para o
    /// público até o artista olhar.
    public void DenunciarStory(string codigo, Guid envioId, string aparelho)
    {
        lock (_sincronizacao)
        {
            var show = ObterShowDosStories(codigo);
            if (!_enviosDoPublico.TryGetValue(envioId, out var envio) ||
                envio.ApresentacaoId != show.Id || !envio.Confirmado)
                throw new EnvioNaoEncontradoException();
            var quem = aparelho.Trim();
            if (quem.Length is 0 or > 64) throw new EnvioInvalidoException();
            var denuncias = envio.Denuncias
                .Split('\n', StringSplitOptions.RemoveEmptyEntries)
                .ToList();
            if (denuncias.Contains(quem)) return;
            denuncias.Add(quem);
            envio.Denuncias = string.Join('\n', denuncias);
            if (denuncias.Count >= DenunciasParaEsconder) envio.Escondido = true;
            SalvarEstado();
        }
    }

    /// Envios do show para o artista dono. Os vencidos saem do banco e as
    /// chaves deles voltam para apagar os arquivos.
    public EnviosDoShow ListarEnviosDoShow(string token, Guid apresentacaoId)
    {
        lock (_sincronizacao)
        {
            var show = ObterApresentacaoDoArtista(token, apresentacaoId);
            var agora = Agora();
            var doShow = _enviosDoPublico.Values
                .Where(envio => envio.ApresentacaoId == show.Id && envio.Confirmado)
                .ToArray();
            var vencidos = doShow.Where(envio => envio.ExpiraEm <= agora).ToArray();
            foreach (var vencido in vencidos) _enviosDoPublico.TryRemove(vencido.Id, out _);
            if (vencidos.Length > 0) SalvarEstado();
            return new EnviosDoShow(
                doShow.Where(envio => envio.ExpiraEm > agora)
                    .OrderBy(envio => envio.CriadoEm)
                    .Select(envio => new EnvioDoShow(
                        envio.Id, envio.Tipo, envio.Nome, envio.CriadoEm, envio.ExpiraEm,
                        envio.Escondido, envio.Chave, envio.TipoDeConteudo))
                    .ToArray(),
                vencidos.Select(envio => envio.Chave).ToArray());
        }
    }

    /// Apaga para todos; devolve a chave para apagar o arquivo.
    public string ApagarEnvio(string token, Guid apresentacaoId, Guid envioId)
    {
        lock (_sincronizacao)
        {
            var envio = ObterEnvioDoArtista(token, apresentacaoId, envioId);
            _enviosDoPublico.TryRemove(envio.Id, out _);
            SalvarEstado();
            return envio.Chave;
        }
    }

    /// Desfaz o esconder por denúncia; as denúncias recomeçam do zero.
    public void MostrarEnvio(string token, Guid apresentacaoId, Guid envioId)
    {
        lock (_sincronizacao)
        {
            var envio = ObterEnvioDoArtista(token, apresentacaoId, envioId);
            envio.Escondido = false;
            envio.Denuncias = string.Empty;
            SalvarEstado();
        }
    }

    private EnvioDoPublicoRegistro ObterEnvioDoArtista(
        string token, Guid apresentacaoId, Guid envioId)
    {
        var show = ObterApresentacaoDoArtista(token, apresentacaoId);
        return _enviosDoPublico.TryGetValue(envioId, out var envio) &&
               envio.ApresentacaoId == show.Id && envio.Confirmado
            ? envio
            : throw new EnvioNaoEncontradoException();
    }

    private Apresentacao ObterShowDosStories(string codigo) =>
        ObterApresentacaoPublica(codigo) ?? throw new ApresentacaoNaoEncontradaException();

    /// Em andamento, ou encerrado há até 24 h.
    private bool RecebeStories(Apresentacao show) => show.Status switch
    {
        StatusApresentacao.EmAndamento => true,
        StatusApresentacao.Encerrada =>
            EstadoDoRelogioDe(show.Id).EncerradaEm is { } fim &&
            Agora() < fim + StoriesDepoisDoFim,
        _ => false
    };

    private bool MostraStories(Apresentacao show) => RecebeStories(show);

    private void DescartarNaoConfirmados(Guid apresentacaoId)
    {
        var limite = Agora() - EsperaPelaConfirmacao;
        foreach (var envio in _enviosDoPublico.Values
                     .Where(envio => envio.ApresentacaoId == apresentacaoId &&
                                     !envio.Confirmado && envio.CriadoEm < limite)
                     .ToArray())
            _enviosDoPublico.TryRemove(envio.Id, out _);
    }

    private static StoryDoShow ParaStory(EnvioDoPublicoRegistro envio) =>
        new(envio.Id, envio.Tipo, envio.Nome, envio.CriadoEm, envio.Chave, envio.TipoDeConteudo);
}
