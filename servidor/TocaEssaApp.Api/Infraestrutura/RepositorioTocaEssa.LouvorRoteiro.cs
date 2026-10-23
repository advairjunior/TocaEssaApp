using System.Collections.Concurrent;
using System.Text.Json;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

// Roteiro público do louvor e gravação da escala junto da apresentação.
public sealed partial class RepositorioTocaEssa
{
    /// Roteiro pelo código, sem token, só em evento Louvor. O hino atual é o
    /// último tocado na ordem da setlist.
    public RoteiroDoLouvor ObterRoteiroDoLouvor(string codigo)
    {
        var apresentacao = ObterApresentacaoPublica(codigo);
        if (apresentacao is not { Tipo: TipoApresentacao.Louvor })
            throw new ApresentacaoNaoEncontradaException();
        var louvor = MontarLouvor(apresentacao);
        return new RoteiroDoLouvor(
            apresentacao.Nome,
            louvor.Cantores,
            louvor.Hinos.LastOrDefault(hino => hino.Tocado)?.ItemId,
            louvor.Hinos,
            louvor.Solistas);
    }

    private LouvorDoArtista MontarLouvor(Apresentacao apresentacao)
    {
        var itens = ItensDaSetlist(apresentacao.Id);
        var letras = itens.ToDictionary(
            item => item.Id, item => LetraDoItem(apresentacao.ArtistaId, item));
        var cantores = _cantoresDoLouvor.GetValueOrDefault(apresentacao.Id) ?? [];
        var solistas = _solistasDoLouvor.GetValueOrDefault(apresentacao.Id) ?? [];
        var escala = EscalaDeCantores.Montar(
            itens.Select(item => new HinoParaEscala(
                item.Id, LetraDoHino.Separar(letras[item.Id]))).ToList(),
            cantores,
            _escolhasDoLouvor.GetValueOrDefault(apresentacao.Id) ?? [],
            solistas);
        var hinos = itens.Zip(escala.Hinos, (item, escalado) => new HinoDoLouvor(
                item.Id,
                item.Titulo,
                item.Artista,
                item.Tom,
                item.Tocada,
                !string.IsNullOrWhiteSpace(letras[item.Id]),
                ComCoral(apresentacao.Id, item.Id, escalado.Partes)))
            .ToList();
        return new LouvorDoArtista(
            cantores, escala.Placar, hinos, solistas, escala.PlacarDosSolos,
            ConfiguracaoDoLouvor(apresentacao.Id));
    }

    private string? LetraDoItem(Guid artistaId, ItemDoSetlistRegistro item) =>
        ProcurarMesmaMusica(_cifrasEmTexto, CriarChave(artistaId, item.Titulo, item.Artista))
            ?.Conteudo;

    private static bool MesmoCantor(string um, string outro) =>
        Normalizar(um) == Normalizar(outro);

    private void CarregarLouvor(ApresentacaoRegistro registro)
    {
        if (LerJson<List<string>>(registro.CantoresDoLouvor) is { Count: > 0 } cantores)
            _cantoresDoLouvor[registro.Id] = cantores;
        if (LerJson<List<EscolhaAMao>>(registro.EscolhasDoLouvor) is { Count: > 0 } escolhas)
            _escolhasDoLouvor[registro.Id] = escolhas;
        if (LerJson<List<Solista>>(registro.SolistasDoLouvor) is { Count: > 0 } solistas)
            _solistasDoLouvor[registro.Id] = solistas;
        if (LerJson<ConfiguracaoDaEscala>(registro.ConfiguracaoDoLouvor) is { } configuracao)
            _configuracoesDoLouvor[registro.Id] = configuracao;
        CarregarCoral(registro);
    }

    private void EscreverLouvor(ApresentacaoRegistro registro)
    {
        registro.CantoresDoLouvor =
            _cantoresDoLouvor.GetValueOrDefault(registro.Id) is { Count: > 0 } cantores
                ? JsonSerializer.Serialize(cantores)
                : null;
        registro.EscolhasDoLouvor =
            _escolhasDoLouvor.GetValueOrDefault(registro.Id) is { Count: > 0 } escolhas
                ? JsonSerializer.Serialize(escolhas)
                : null;
        registro.SolistasDoLouvor =
            _solistasDoLouvor.GetValueOrDefault(registro.Id) is { Count: > 0 } solistas
                ? JsonSerializer.Serialize(solistas)
                : null;
        registro.ConfiguracaoDoLouvor =
            _configuracoesDoLouvor.GetValueOrDefault(registro.Id) is { } configuracao &&
            configuracao != new ConfiguracaoDaEscala()
                ? JsonSerializer.Serialize(configuracao)
                : null;
        EscreverCoral(registro);
    }

    private static T? LerJson<T>(string? json) where T : class
    {
        if (string.IsNullOrWhiteSpace(json)) return null;
        try
        {
            return JsonSerializer.Deserialize<T>(json);
        }
        catch (JsonException)
        {
            return null;
        }
    }
}
