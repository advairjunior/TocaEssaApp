part of 'sequencia_do_palco.dart';

/// Pedidos do público vistos pela sequência do palco.
extension PedidosDaSequencia on SequenciaDoPalco {
  /// Título normalizado → quantidade de pedidos aguardando ou aceitos.
  Map<String, int> get pedidosNaFila {
    final mapa = <String, int>{};
    for (final g in pedidos) {
      if (g.status == StatusPedidoMusical.aguardando ||
          g.status == StatusPedidoMusical.aceito) {
        final chave = g.musica.toLowerCase().trim();
        mapa[chave] = (mapa[chave] ?? 0) + g.quantidadePedidos;
      }
    }
    return mapa;
  }

  int get tocadas => itens.where((i) => i.tocada).length;
  int get proximaIndex => itens.indexWhere((i) => !i.tocada);

  /// Pedidos marcados para tocar a seguir que continuam aceitos, em ordem.
  List<GrupoPedidoMusical> get pedidosASeguir => [
        for (final id in aSeguir)
          ...pedidos.where((p) =>
              p.pedidoRepresentativoId == id &&
              p.tipo == TipoPedido.musica &&
              p.status == StatusPedidoMusical.aceito),
      ];

  List<GrupoPedidoMusical> get pedidosNovos => pedidos
      .where((p) =>
          p.tipo == TipoPedido.musica &&
          p.status == StatusPedidoMusical.aguardando)
      .toList();

  List<GrupoPedidoMusical> get pedidosAceitos => pedidos
      .where((p) =>
          p.tipo == TipoPedido.musica && p.status == StatusPedidoMusical.aceito)
      .toList();

  List<GrupoPedidoMusical> get alosPendentes => pedidos
      .where((p) =>
          p.tipo == TipoPedido.alo &&
          (p.status == StatusPedidoMusical.aguardando ||
              p.status == StatusPedidoMusical.aceito))
      .toList();

  /// Marca o pedido para tocar a seguir, ou desmarca, já buscando a cifra.
  Future<void> alternarASeguir(GrupoPedidoMusical pedido) async {
    final id = pedido.pedidoRepresentativoId;
    _versaoLocal++;
    try {
      aSeguir = aSeguir.contains(id)
          ? await api.tirarPedidoASeguir(apresentacaoId, id)
          : await api.colocarPedidoASeguir(apresentacaoId, id);
    } finally {
      _versaoLocal++;
    }
    _avisar();
    if (aSeguir.contains(id)) {
      await atualizarCifra(MusicaDoPalco.doPedido(pedido));
    }
  }

  List<GrupoPedidoMusical> get tocandoAgora => pedidos
      .where((p) =>
          p.tipo == TipoPedido.musica &&
          p.status == StatusPedidoMusical.tocandoAgora)
      .toList();
}

/// Cifras das músicas da sequência: consulta, situação e atualização.
extension CifrasDaSequencia on SequenciaDoPalco {
  /// Sem cifra colada no app (o link do site é só reserva). Só conta depois
  /// de consultada, para não acusar falha de rede.
  bool estaSemCifra(MusicaDoPalco musica) {
    final resultado = cifraDe(musica);
    return resultado != null && resultado.texto == null;
  }

  List<ItemDoSetlist> get semCifra => itens
      .where((i) => !i.tocada && estaSemCifra(MusicaDoPalco.doSetlist(i)))
      .toList();

  Future<void> buscarCifras() async {
    final musicas = [
      ...itens.map(MusicaDoPalco.doSetlist),
      ...pedidosASeguir.map(MusicaDoPalco.doPedido),
    ];
    final resultados = await Future.wait(musicas.map(_consultarCifraSemErro));
    _cifras = {
      for (final (indice, musica) in musicas.indexed)
        if (resultados[indice] case final resultado?)
          SequenciaDoPalco._chave(musica.titulo, musica.artista): resultado,
    };
    _avisar();
  }

  Future<void> atualizarCifra(MusicaDoPalco musica) async {
    final resultado = await _consultarCifraSemErro(musica);
    if (resultado == null) return;
    _cifras = {
      ..._cifras,
      SequenciaDoPalco._chave(musica.titulo, musica.artista): resultado
    };
    _avisar();
  }

  Future<ResultadoCifraDoArtista?> _consultarCifraSemErro(
      MusicaDoPalco musica) async {
    try {
      return await api.consultarCifra(musica.titulo, musica.artista);
    } catch (_) {
      // Sem a busca antecipada, o toque em Tocar busca a cifra na hora.
      return null;
    }
  }
}
