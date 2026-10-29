using System.Collections.Concurrent;
using System.Security.Cryptography;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

// Comando da TV passado a um ajudante, sem conta: só ele mexe na linha até o
// dono retomar. Na memória, como o conteúdo da TV.
public sealed partial class RepositorioTocaEssa
{
    private readonly ConcurrentDictionary<Guid, (Guid Id, string TokenHash)> _comandosDasTvs = new();

    /// Gera o link do ajudante; um novo desfaz o anterior.
    public NovoComando PassarComando(string token)
    {
        var conta = ExigirRegistroArtista(token);
        var comando = new NovoComando(Guid.NewGuid(), Convert.ToHexString(RandomNumberGenerator.GetBytes(32)));
        _comandosDasTvs[conta.Id] = (comando.Id, GerarHashToken(comando.Token));
        return comando;
    }

    public EstadoDoComando EstadoDoComando(string token) =>
        new(_comandosDasTvs.ContainsKey(ExigirRegistroArtista(token).Id));

    public void RetomarComando(string token) =>
        _comandosDasTvs.TryRemove(ExigirRegistroArtista(token).Id, out _);

    public ComandoDoAjudante ObterComando(string tokenDoAjudante)
    {
        var (artistaId, comandoId) = ContaDoComando(tokenDoAjudante);
        return new ComandoDoAjudante(comandoId, _conteudosDasTvs.GetValueOrDefault(artistaId));
    }

    public void IrParaALinhaPeloAjudante(string tokenDoAjudante, int linha)
    {
        var (artistaId, _) = ContaDoComando(tokenDoAjudante);
        MudarALinhaDaTv(artistaId, linha);
    }

    private bool TvComAjudante(Guid artistaId) => _comandosDasTvs.ContainsKey(artistaId);

    private (Guid ArtistaId, Guid ComandoId) ContaDoComando(string tokenDoAjudante)
    {
        var hash = GerarHashToken(tokenDoAjudante ?? string.Empty);
        foreach (var (artistaId, comando) in _comandosDasTvs)
            if (comando.TokenHash == hash) return (artistaId, comando.Id);
        throw new ComandoNaoEncontradoException();
    }

    // O celular do ajudante recebe o mesmo aviso das TVs.
    private void AvisarAjudante(Guid artistaId, ConteudoDaTv conteudo)
    {
        if (_comandosDasTvs.TryGetValue(artistaId, out var comando))
            _notificador?.PublicarEvento(CanalDaTv.DoComando(comando.Id), CanalDaTv.EventoDaLinha(conteudo));
    }
}
