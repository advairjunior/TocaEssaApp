using System.Collections.Concurrent;
using System.Security.Cryptography;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

// TVs da conta: o código para conectar e a letra que o celular do dono manda.
public sealed partial class RepositorioTocaEssa
{
    private readonly ConcurrentDictionary<Guid, TvDaContaRegistro> _telasDaTv = new();
    // TVs que ainda mostram o código, pelo hash do token: só na memória.
    private readonly ConcurrentDictionary<string, Guid> _tvsEsperando = new();
    private readonly ConcurrentDictionary<Guid, ConteudoDaTv> _conteudosDasTvs = new();
    private readonly CodigosDePareamento _codigosDasTvs = new(() => DateTimeOffset.UtcNow);

    public NovaTv CriarTv()
    {
        var id = Guid.NewGuid();
        var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        _tvsEsperando[GerarHashToken(token)] = id;
        return new NovaTv(id, token, _codigosDasTvs.Gerar(id));
    }

    public EstadoDaTv ObterEstadoDaTv(string tokenDaTv)
    {
        var hash = GerarHashToken(tokenDaTv);
        if (_tvsEsperando.TryGetValue(hash, out var esperando))
            return new EstadoDaTv(false,
                _codigosDasTvs.CodigoDa(esperando) ?? _codigosDasTvs.Gerar(esperando), null);
        var tv = _telasDaTv.Values.FirstOrDefault(item => item.TokenHash == hash)
            ?? throw new TvNaoEncontradaException();
        return new EstadoDaTv(true, null, _conteudosDasTvs.GetValueOrDefault(tv.ArtistaId));
    }

    public TvDaConta ParearTv(string token, string codigo)
    {
        var conta = ExigirRegistroArtista(token);
        lock (_sincronizacao)
        {
            var tvId = _codigosDasTvs.Usar(codigo) ?? throw new CodigoDaTvNaoEncontradoException();
            var hash = _tvsEsperando.First(par => par.Value == tvId).Key;
            _tvsEsperando.TryRemove(hash, out _);
            var registro = new TvDaContaRegistro
            {
                Id = tvId,
                ArtistaId = conta.Id,
                TokenHash = hash,
                CriadaEm = DateTimeOffset.UtcNow
            };
            _telasDaTv[tvId] = registro;
            SalvarEstado();
            return ParaDominio(registro);
        }
    }

    public IReadOnlyList<TvDaConta> ListarTvs(string token)
    {
        var conta = ExigirRegistroArtista(token);
        return [.. TvsDaConta(conta.Id).OrderBy(item => item.CriadaEm).Select(ParaDominio)];
    }

    public void DesconectarTv(string token, Guid tvId)
    {
        var conta = ExigirRegistroArtista(token);
        lock (_sincronizacao)
        {
            if (!_telasDaTv.TryGetValue(tvId, out var tv) || tv.ArtistaId != conta.Id)
                throw new TvNaoEncontradaException();
            _telasDaTv.TryRemove(tvId, out _);
            SalvarEstado();
        }
    }

    public void MostrarNaTv(string token, MostrarNaTv requisicao)
    {
        var conta = ExigirRegistroArtista(token);
        requisicao.Validar();
        var conteudo = _conteudosDasTvs.AddOrUpdate(conta.Id,
            _ => NovoConteudo(requisicao, 1),
            (_, anterior) => NovoConteudo(requisicao, anterior.Versao + 1));
        AvisarTvs(conta.Id, conteudo);
    }

    public void IrParaALinhaNaTv(string token, int linha)
    {
        var conta = ExigirRegistroArtista(token);
        Dominio.MostrarNaTv.ValidarLinha(linha);
        if (!_conteudosDasTvs.TryGetValue(conta.Id, out var anterior))
            throw new TvSemMusicaException();
        var conteudo = anterior with { Linha = linha };
        _conteudosDasTvs[conta.Id] = conteudo;
        AvisarTvs(conta.Id, conteudo);
    }

    public void LimparTv(string token)
    {
        var conta = ExigirRegistroArtista(token);
        if (_conteudosDasTvs.TryRemove(conta.Id, out var anterior))
            AvisarTvs(conta.Id, anterior with { Versao = anterior.Versao + 1 });
    }

    private IEnumerable<TvDaContaRegistro> TvsDaConta(Guid artistaId) =>
        _telasDaTv.Values.Where(item => item.ArtistaId == artistaId);

    private void AvisarTvs(Guid artistaId, ConteudoDaTv conteudo)
    {
        foreach (var tv in TvsDaConta(artistaId))
            _notificador?.PublicarEvento(CanalDaTv.De(tv.Id), CanalDaTv.EventoDaLinha(conteudo));
    }

    private static ConteudoDaTv NovoConteudo(MostrarNaTv requisicao, int versao) =>
        new(requisicao.Titulo.Trim(), requisicao.Subtitulo?.Trim(), requisicao.Texto,
            requisicao.ASeguir?.Trim(), requisicao.Codigo?.Trim(), requisicao.Linha, versao);

    private static TvDaConta ParaDominio(TvDaContaRegistro registro) =>
        new(registro.Id, registro.CriadaEm);
}
