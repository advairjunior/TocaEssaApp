using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

// A nota da galera na hora e a noite de karaokê na memória de cada um.
public sealed partial class RepositorioTocaEssa
{
    /// Vale para quem está cantando agora; votar de novo troca a nota.
    public NoiteDeKaraoke DarNotaNoKaraoke(string codigo, string token, int estrelas)
    {
        if (estrelas is < 1 or > 5) throw new NotaDoKaraokeInvalidaException();
        var (apresentacao, publicoId) = ExigirNaGalera(codigo, token);
        return GravarKaraoke(apresentacao, estado =>
        {
            var vez = estado.EmAndamento ?? throw new NinguemCantandoException();
            if (vez.PublicoId == publicoId) throw new NaoVotaNaPropriaVezException();
            var votada = vez with { Notas = new(vez.Notas) { [publicoId] = estrelas } };
            return estado with { Vezes = [.. estado.Vezes.SkipLast(1), votada] };
        }, publicoId);
    }

    /// Quantas músicas a pessoa cantou, a média delas e se foi a Voz da
    /// noite (só depois de encerrada); nulo fora do karaokê.
    private KaraokeDoPublico? KaraokeDoPublico(Apresentacao apresentacao, Guid publicoId)
    {
        if (apresentacao.Tipo != TipoApresentacao.Karaoke) return null;
        var vezes = EstadoDoKaraoke(apresentacao.Id).Vezes;
        var linha = PlacarDoKaraoke.Calcular(vezes).FirstOrDefault(item => item.PublicoId == publicoId);
        var voz = apresentacao.Status == StatusApresentacao.Encerrada &&
                  PlacarDoKaraoke.VozDaNoite(vezes) == publicoId;
        return new KaraokeDoPublico(linha?.Musicas ?? 0, linha?.Media, voz);
    }
}
