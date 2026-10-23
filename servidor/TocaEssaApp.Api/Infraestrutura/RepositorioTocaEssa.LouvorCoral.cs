using System.Collections.Concurrent;
using System.Text.Json;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

// Coral do louvor: canta junto de quem tem a parte, só nas partes marcadas.
// Fica fora das escolhas à mão para que escalar de novo não o apague.
public sealed partial class RepositorioTocaEssa
{
    private readonly ConcurrentDictionary<Guid, IReadOnlyList<ParteDoCoral>> _coralDoLouvor = new();

    public LouvorDoArtista MarcarCoralDoLouvor(
        string token, Guid apresentacaoId, Guid itemId, int indice, bool coral)
    {
        var apresentacao = ObterApresentacaoDoArtista(token, apresentacaoId);
        lock (_sincronizacao)
        {
            if (!_itensDoSetlist.TryGetValue(itemId, out var item) ||
                item.ApresentacaoId != apresentacaoId)
                throw new ItemDoSetlistNaoEncontradoException();
            var partes = LetraDoHino.Separar(LetraDoItem(apresentacao.ArtistaId, item));
            if (indice < 0 || indice >= partes.Count)
                throw new EscolhaDoLouvorInvalidaException();

            var parte = new ParteDoCoral(itemId, indice);
            var marcadas = (_coralDoLouvor.GetValueOrDefault(apresentacaoId) ?? [])
                .Where(outra => outra != parte)
                .ToList();
            if (coral) marcadas.Add(parte);
            _coralDoLouvor[apresentacaoId] = marcadas;
            SalvarEstado();
            return MontarLouvor(apresentacao);
        }
    }

    /// Com "Coral nos refrões" ligado, escalar os [hinos] também põe o
    /// coral em todo refrão deles. Desligado, o coral fica como está.
    private void MarcarCoralNosRefroes(
        Guid apresentacaoId, IEnumerable<HinoParaEscala> hinos)
    {
        if (!ConfiguracaoDoLouvor(apresentacaoId).CoralNosRefroes) return;
        var marcadas = (_coralDoLouvor.GetValueOrDefault(apresentacaoId) ?? []).ToList();
        foreach (var hino in hinos)
            for (var indice = 0; indice < hino.Partes.Count; indice++)
                if (hino.Partes[indice].Tipo == TipoDaParte.Refrao &&
                    !marcadas.Contains(new ParteDoCoral(hino.ItemId, indice)))
                    marcadas.Add(new ParteDoCoral(hino.ItemId, indice));
        _coralDoLouvor[apresentacaoId] = marcadas;
    }

    private IReadOnlyList<ParteEscalada> ComCoral(
        Guid apresentacaoId, Guid itemId, IReadOnlyList<ParteEscalada> partes)
    {
        var marcadas = _coralDoLouvor.GetValueOrDefault(apresentacaoId) ?? [];
        return partes
            .Select((parte, indice) =>
                parte with { Coral = marcadas.Contains(new ParteDoCoral(itemId, indice)) })
            .ToList();
    }

    private void CarregarCoral(ApresentacaoRegistro registro)
    {
        if (LerJson<List<ParteDoCoral>>(registro.CoralDoLouvor) is { Count: > 0 } coral)
            _coralDoLouvor[registro.Id] = coral;
    }

    private void EscreverCoral(ApresentacaoRegistro registro) =>
        registro.CoralDoLouvor =
            _coralDoLouvor.GetValueOrDefault(registro.Id) is { Count: > 0 } coral
                ? JsonSerializer.Serialize(coral)
                : null;
}
