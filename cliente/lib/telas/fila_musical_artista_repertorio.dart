part of 'fila_musical_artista.dart';

/// Pedidos que ainda não estão no acervo do artista.
extension _RepertorioDaFila on _FilaMusicalArtistaState {
  /// Primeiro repertório que já tem a música do pedido.
  Repertorio? _repertorioDe(GrupoPedidoMusical pedido) => _repertorios
      ?.where((repertorio) => repertorio.musicas.any((musica) => mesmaMusica(
          musica.titulo, musica.artista, pedido.musica, pedido.artista)))
      .firstOrNull;

  /// Ação do selo "Fora do acervo"; nula quando o selo não aparece.
  VoidCallback? _foraDoAcervo(GrupoPedidoMusical pedido) =>
      _repertorios == null ||
              pedido.tipo != TipoPedido.musica ||
              pedido.status == StatusPedidoMusical.canceladoPeloPublico ||
              _repertorioDe(pedido) != null
          ? null
          : () => _adicionarAoRepertorio(pedido);

  // O tom do pedido é o de quem pediu, não o da banda.
  MusicaParaRepertorio _musicaDo(GrupoPedidoMusical pedido) => (
        titulo: pedido.musica,
        artista: pedido.artista,
        tom: null,
        linkDoVideo: null
      );

  Future<void> _adicionarAoRepertorio(GrupoPedidoMusical pedido) async {
    final resultado = await adicionarAoRepertorio(context,
        api: widget.api, musicas: [_musicaDo(pedido)]);
    if (resultado != null) await _carregarRepertorios();
  }

  /// Pedidos de música do show, os mais pedidos primeiro; os que estão fora
  /// do acervo começam marcados.
  Future<void> _levarPedidosAoRepertorio() async {
    final pedidos = _pedidos
        .where((pedido) =>
            pedido.tipo == TipoPedido.musica &&
            pedido.status != StatusPedidoMusical.canceladoPeloPublico)
        .toList()
      ..sort((a, b) => b.quantidadePedidos.compareTo(a.quantidadePedidos));
    await escolherParaRepertorio(
      context,
      api: widget.api,
      titulo: 'Pedidos para o repertório',
      nomeSugerido: 'Pedidos · ${widget.apresentacao.nome}',
      opcoes: [
        for (final pedido in pedidos)
          if (_repertorioDe(pedido) case final repertorio)
            OpcaoParaRepertorio(
              musica: _musicaDo(pedido),
              marcada: repertorio == null,
              detalhe: [
                if (pedido.quantidadePedidos > 1)
                  'pedida ${pedido.quantidadePedidos}x',
                if (pedido.status == StatusPedidoMusical.naoConhecemos ||
                    pedido.status == StatusPedidoMusical.aindaNaoSabemosTocar)
                  pedido.status.rotulo,
                repertorio == null
                    ? 'fora do acervo'
                    : 'já em "${repertorio.nome}"',
              ].join(' · '),
            ),
      ],
    );
    if (mounted) await _carregarRepertorios();
  }
}
