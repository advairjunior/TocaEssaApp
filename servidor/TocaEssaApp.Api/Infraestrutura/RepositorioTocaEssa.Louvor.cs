using System.Collections.Concurrent;
using System.Text.Json;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    private const int TamanhoMaximoDoNomeDoCantor = 40;

    // Louvor: quem canta no microfone e quem fica com cada parte. Nada é
    // escalado sozinho: o botão de cada hino ou a troca à mão gravam aqui.
    private readonly ConcurrentDictionary<Guid, IReadOnlyList<string>> _cantoresDoLouvor = new();
    private readonly ConcurrentDictionary<Guid, IReadOnlyList<EscolhaAMao>> _escolhasDoLouvor = new();
    // Quem toca os solos e o instrumento de cada um.
    private readonly ConcurrentDictionary<Guid, IReadOnlyList<Solista>> _solistasDoLouvor = new();

    public LouvorDoArtista ObterLouvor(string token, Guid apresentacaoId)
    {
        var apresentacao = ObterApresentacaoDoArtista(token, apresentacaoId);
        return MontarLouvor(apresentacao);
    }

    /// Nomes sem espaço sobrando, sem vazio e sem repetir (sem acento nem
    /// maiúscula). Quem sai da lista sai também das partes escolhidas à mão.
    public LouvorDoArtista DefinirCantoresDoLouvor(
        string token, Guid apresentacaoId, IReadOnlyList<string>? nomes)
    {
        var apresentacao = ObterApresentacaoDoArtista(token, apresentacaoId);
        lock (_sincronizacao)
        {
            var cantores = new List<string>();
            foreach (var nome in nomes ?? [])
            {
                var limpo = Limpar(nome);
                if (limpo.Length > 0 && !cantores.Any(cantor => MesmoCantor(cantor, limpo)))
                    cantores.Add(limpo);
            }
            _cantoresDoLouvor[apresentacaoId] = cantores;
            ManterSoQuemEstaNoLouvor(apresentacaoId);
            SalvarEstado();
            return MontarLouvor(apresentacao);
        }
    }

    /// Solistas sem nome vazio nem repetido; o instrumento pode ficar vazio
    /// (toca qualquer "(Solo)"). Quem sai sai também das escolhas à mão.
    public LouvorDoArtista DefinirSolistasDoLouvor(
        string token, Guid apresentacaoId, IReadOnlyList<Solista>? solistas)
    {
        var apresentacao = ObterApresentacaoDoArtista(token, apresentacaoId);
        lock (_sincronizacao)
        {
            var limpos = new List<Solista>();
            foreach (var solista in solistas ?? [])
            {
                var nome = Limpar(solista?.Nome);
                if (nome.Length > 0 && !limpos.Any(outro => MesmoCantor(outro.Nome, nome)))
                    limpos.Add(new Solista(nome, Limpar(solista!.Instrumento)));
            }
            _solistasDoLouvor[apresentacaoId] = limpos;
            ManterSoQuemEstaNoLouvor(apresentacaoId);
            SalvarEstado();
            return MontarLouvor(apresentacao);
        }
    }

    private static string Limpar(string? valor)
    {
        var limpo = string.Join(' ', (valor ?? string.Empty)
            .Split(' ', StringSplitOptions.RemoveEmptyEntries));
        return limpo.Length > TamanhoMaximoDoNomeDoCantor
            ? limpo[..TamanhoMaximoDoNomeDoCantor].TrimEnd()
            : limpo;
    }

    // Cantores e solistas: quem pode estar numa escolha à mão.
    private List<string> NomesDoLouvor(Guid apresentacaoId) =>
    [
        .. _cantoresDoLouvor.GetValueOrDefault(apresentacaoId) ?? [],
        .. (_solistasDoLouvor.GetValueOrDefault(apresentacaoId) ?? [])
            .Select(solista => solista.Nome)
    ];

    // Parte que fica sem ninguém volta a ficar sem escala, em vez de virar
    // Todos sem o artista pedir.
    private void ManterSoQuemEstaNoLouvor(Guid apresentacaoId)
    {
        var nomes = NomesDoLouvor(apresentacaoId);
        var escolhas = new List<EscolhaAMao>();
        foreach (var escolha in _escolhasDoLouvor.GetValueOrDefault(apresentacaoId) ?? [])
        {
            var ficam = escolha.Cantores.Where(nomes.Contains).ToList();
            if (escolha.Cantores.Count == 0 || ficam.Count > 0)
                escolhas.Add(escolha with { Cantores = ficam });
        }
        _escolhasDoLouvor[apresentacaoId] = escolhas;
    }

    /// [cantores] nulo deixa a parte sem escala; vazio deixa a parte com Todos.
    public LouvorDoArtista EscolherParteDoLouvor(
        string token, Guid apresentacaoId, Guid itemId, int indice,
        IReadOnlyList<string>? cantores)
    {
        var apresentacao = ObterApresentacaoDoArtista(token, apresentacaoId);
        lock (_sincronizacao)
        {
            if (!_itensDoSetlist.TryGetValue(itemId, out var item) ||
                item.ApresentacaoId != apresentacaoId)
                throw new ItemDoSetlistNaoEncontradoException();
            var partes = LetraDoHino.Separar(LetraDoItem(apresentacao.ArtistaId, item));
            var nomesDoLouvor = NomesDoLouvor(apresentacaoId);
            if (indice < 0 || indice >= partes.Count ||
                cantores?.Any(nome => !nomesDoLouvor.Contains(nome)) == true)
                throw new EscolhaDoLouvorInvalidaException();

            var escolhas = (_escolhasDoLouvor.GetValueOrDefault(apresentacaoId) ?? [])
                .Where(escolha => escolha.ItemId != itemId || escolha.Indice != indice)
                .ToList();
            if (cantores is not null)
                escolhas.Add(new EscolhaAMao(itemId, indice,
                    nomesDoLouvor.Distinct().Where(cantores.Contains).ToList()));
            _escolhasDoLouvor[apresentacaoId] = escolhas;
            SalvarEstado();
            return MontarLouvor(apresentacao);
        }
    }

    /// Botão "Escalar automático" do hino: refaz todas as partes dele pelos
    /// pontos dos outros hinos.
    public LouvorDoArtista EscalarHinoDoLouvor(string token, Guid apresentacaoId, Guid itemId)
    {
        var apresentacao = ObterApresentacaoDoArtista(token, apresentacaoId);
        lock (_sincronizacao)
        {
            if (!_itensDoSetlist.TryGetValue(itemId, out var item) ||
                item.ApresentacaoId != apresentacaoId)
                throw new ItemDoSetlistNaoEncontradoException();
            var escolhas = _escolhasDoLouvor.GetValueOrDefault(apresentacaoId) ?? [];
            var doHino = EscalaDeCantores.EscalarHino(
                HinosParaEscala(apresentacao),
                itemId,
                _cantoresDoLouvor.GetValueOrDefault(apresentacaoId) ?? [],
                escolhas,
                _solistasDoLouvor.GetValueOrDefault(apresentacaoId) ?? []);
            _escolhasDoLouvor[apresentacaoId] =
            [
                .. escolhas.Where(escolha => escolha.ItemId != itemId),
                .. doHino
            ];
            SalvarEstado();
            return MontarLouvor(apresentacao);
        }
    }

    /// Botão "Escalar todos os hinos": refaz a escala da lista inteira, na
    /// ordem, cada hino pelos pontos dos anteriores.
    public LouvorDoArtista EscalarTodosOsHinosDoLouvor(string token, Guid apresentacaoId)
    {
        var apresentacao = ObterApresentacaoDoArtista(token, apresentacaoId);
        lock (_sincronizacao)
        {
            _escolhasDoLouvor[apresentacaoId] = EscalaDeCantores.EscalarTodos(
                HinosParaEscala(apresentacao),
                _cantoresDoLouvor.GetValueOrDefault(apresentacaoId) ?? [],
                _escolhasDoLouvor.GetValueOrDefault(apresentacaoId) ?? [],
                _solistasDoLouvor.GetValueOrDefault(apresentacaoId) ?? []);
            SalvarEstado();
            return MontarLouvor(apresentacao);
        }
    }

    private List<HinoParaEscala> HinosParaEscala(Apresentacao apresentacao) =>
        ItensDaSetlist(apresentacao.Id)
            .Select(item => new HinoParaEscala(
                item.Id, LetraDoHino.Separar(LetraDoItem(apresentacao.ArtistaId, item))))
            .ToList();

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
                escalado.Partes))
            .ToList();
        return new LouvorDoArtista(
            cantores, escala.Placar, hinos, solistas, escala.PlacarDosSolos);
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
