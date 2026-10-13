using System.Globalization;
using System.Text;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    // Fora disso, o show foi iniciado ou encerrado por engano.
    private static readonly TimeSpan DuracaoMinimaDoShow = TimeSpan.FromMinutes(30);
    private static readonly TimeSpan DuracaoMaximaDoShow = TimeSpan.FromHours(12);
    private const int PessoasParaFavorita = 2;

    private static readonly StatusPedidoMusical[] StatusRecusados =
        [StatusPedidoMusical.NaoConhecemos, StatusPedidoMusical.AindaNaoSabemosTocar];

    private DadosDaRetrospectiva MontarRetrospectiva(Guid apresentacaoId)
    {
        var validos = _pedidos.Values
            .Where(item => item.ApresentacaoId == apresentacaoId &&
                           item.Status != StatusPedidoMusical.CanceladoPeloPublico)
            .ToArray();
        var musicas = validos.Where(item => item.Tipo == TipoPedido.Musica).ToArray();
        var porMusica = musicas.GroupBy(item => NormalizarMusica(item.Musica)).ToArray();
        var tocadas = porMusica.Where(grupo => grupo.Any(Comecado)).ToArray();
        var pares = musicas
            .GroupBy(item => (IdentificarSolicitante(item), NormalizarMusica(item.Musica)))
            .ToArray();
        var (votos, avaliadores) = ContarVotos(musicas);
        var (iniciadaEm, encerradaEm) = DuracaoPlausivel(apresentacaoId);

        return new DadosDaRetrospectiva(
            tocadas.Select(ContarPessoas)
                .Where(item => item.Quantidade >= PessoasParaFavorita)
                .OrderByDescending(item => item.Quantidade)
                .ThenBy(item => item.Musica)
                .FirstOrDefault(),
            tocadas.Length,
            pares.Length,
            pares.Count(par => par.Any(Comecado)),
            avaliadores,
            votos.Length == 0 ? null : Math.Round(votos.Average(), 1),
            _itensDoSetlist.Values
                .Where(item => item.ApresentacaoId == apresentacaoId && item.Tocada)
                .Select(item => NormalizarMusica(item.Titulo))
                .Concat(tocadas.Select(grupo => grupo.Key))
                .Distinct()
                .Count(),
            validos
                .Where(item => item.Tipo == TipoPedido.Alo &&
                               item.Status == StatusPedidoMusical.Finalizado)
                .Select(item => (IdentificarSolicitante(item), NormalizarMusica(item.DestinatarioAlo)))
                .Distinct()
                .Count(),
            iniciadaEm,
            encerradaEm,
            MaisPedidasPorPessoas(porMusica),
            MaisPedidasPorPessoas(musicas
                .Where(item => StatusRecusados.Contains(item.Status))
                .GroupBy(item => NormalizarMusica(item.Musica))));
    }

    private static bool Comecado(PedidoMusical pedido) => StatusComecados.Contains(pedido.Status);

    /// Quantas pessoas diferentes pediram a música, com o nome do primeiro pedido.
    private static MusicaMaisPedida ContarPessoas(IGrouping<string, PedidoMusical> grupo) =>
        new(grupo.OrderBy(item => item.CriadoEm).First().Musica.Trim(),
            grupo.Select(IdentificarSolicitante).Distinct().Count());

    private static IReadOnlyCollection<MusicaMaisPedida> MaisPedidasPorPessoas(
        IEnumerable<IGrouping<string, PedidoMusical>> grupos) => grupos
        .Select(ContarPessoas)
        .OrderByDescending(item => item.Quantidade)
        .ThenBy(item => item.Musica)
        .Take(5)
        .ToArray();

    /// Um voto por pessoa por música: o último que ela deu.
    private (int[] Votos, int Avaliadores) ContarVotos(IReadOnlyCollection<PedidoMusical> musicas)
    {
        var musicaDoPedido = musicas.ToDictionary(item => item.Id, item => NormalizarMusica(item.Musica));
        var avaliacoes = _avaliacoes.Values
            .Where(item => musicaDoPedido.ContainsKey(item.PedidoId))
            .ToArray();
        var votos = avaliacoes
            .GroupBy(item => (item.IdentificadorAvaliador, musicaDoPedido[item.PedidoId]))
            .Select(grupo => grupo.MaxBy(item => item.AvaliadoEm)!.Estrelas)
            .ToArray();
        return (votos, avaliacoes.Select(item => item.IdentificadorAvaliador).Distinct().Count());
    }

    private (DateTimeOffset? IniciadaEm, DateTimeOffset? EncerradaEm) DuracaoPlausivel(
        Guid apresentacaoId)
    {
        var show = _apresentacoes.Values.First(item => item.Id == apresentacaoId);
        var estado = EstadoDoRelogioDe(apresentacaoId);
        if (show.Status != StatusApresentacao.Encerrada ||
            estado is not { IniciadaEm: { } inicio, EncerradaEm: { } fim })
            return (null, null);
        var duracao = fim - inicio;
        return duracao < DuracaoMinimaDoShow || duracao > DuracaoMaximaDoShow
            ? (null, null)
            : (inicio, fim);
    }

    /// Ignora acentos, maiúsculas e espaços repetidos: "Evidências" e
    /// "evidencias" são a mesma música.
    private static string NormalizarMusica(string? valor)
    {
        if (string.IsNullOrWhiteSpace(valor)) return string.Empty;
        var semAcento = new StringBuilder();
        foreach (var letra in valor.Normalize(NormalizationForm.FormD))
            if (CharUnicodeInfo.GetUnicodeCategory(letra) != UnicodeCategory.NonSpacingMark)
                semAcento.Append(letra);
        return string.Join(' ', semAcento.ToString().Split(
                (char[]?)null, StringSplitOptions.RemoveEmptyEntries))
            .ToUpperInvariant();
    }
}
