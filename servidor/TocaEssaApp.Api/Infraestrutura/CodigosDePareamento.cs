using System.Security.Cryptography;

namespace TocaEssaApp.Api.Infraestrutura;

/// Códigos curtos que a TV mostra até alguém conectá-la. Ficam só na memória:
/// se o servidor dormir, a TV pede outro ao abrir.
public sealed class CodigosDePareamento(Func<DateTimeOffset> agora)
{
    // Sem 0/O e 1/I, que se confundem na TV.
    private const string Caracteres = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private static readonly TimeSpan Validade = TimeSpan.FromMinutes(10);
    private readonly Dictionary<string, (Guid TvId, DateTimeOffset VenceEm)> _codigos = [];
    private readonly object _trava = new();

    public string Gerar(Guid tvId)
    {
        lock (_trava)
        {
            Esquecer(tvId);
            string codigo;
            do codigo = Sortear(); while (_codigos.ContainsKey(codigo));
            _codigos[codigo] = (tvId, agora() + Validade);
            return codigo;
        }
    }

    public string? CodigoDa(Guid tvId)
    {
        lock (_trava)
            return _codigos.FirstOrDefault(par => par.Value.TvId == tvId && Valido(par.Value)).Key;
    }

    /// A TV do código, que sai da lista: cada código conecta uma vez só.
    public Guid? Usar(string codigo)
    {
        lock (_trava)
        {
            var chave = codigo.Trim().ToUpperInvariant();
            if (!_codigos.Remove(chave, out var pendente) || !Valido(pendente)) return null;
            return pendente.TvId;
        }
    }

    private bool Valido((Guid TvId, DateTimeOffset VenceEm) pendente) => pendente.VenceEm > agora();

    private void Esquecer(Guid tvId)
    {
        foreach (var codigo in _codigos.Where(par => par.Value.TvId == tvId || !Valido(par.Value))
                     .Select(par => par.Key).ToList())
            _codigos.Remove(codigo);
    }

    private static string Sortear() =>
        string.Concat(Enumerable.Range(0, 4)
            .Select(_ => Caracteres[RandomNumberGenerator.GetInt32(Caracteres.Length)]));
}
