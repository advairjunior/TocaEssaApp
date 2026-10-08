import 'package:flutter/foundation.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/pedidos_a_seguir.dart';

/// Uma música que pode tocar no show: item do setlist ou pedido do público.
class MusicaDoPalco {
  MusicaDoPalco.doSetlist(ItemDoSetlist this.item) : pedido = null;
  MusicaDoPalco.doPedido(GrupoPedidoMusical this.pedido) : item = null;

  final ItemDoSetlist? item;
  final GrupoPedidoMusical? pedido;

  String get titulo => item?.titulo ?? pedido!.musica;
  String? get artista => item != null ? item!.artista : pedido!.artista;
  String? get tom => item != null ? item!.tom : pedido!.tomPreferido;
}

/// Sequência de músicas do show: setlist, pedidos do público e a cifra de cada
/// música, buscada antes para abrir na hora no palco. Compartilhada pela
/// setlist e pelo modo palco.
class SequenciaDoPalco extends ChangeNotifier {
  SequenciaDoPalco({required this.api, required this.apresentacaoId});

  final ApiTocaEssa api;
  final String apresentacaoId;

  List<ItemDoSetlist> itens = const [];
  List<GrupoPedidoMusical> pedidos = const [];
  // ids dos pedidos marcados para tocar a seguir, em ordem
  List<String> aSeguir = const [];
  bool salvando = false;
  // título e artista normalizados → cifra consultada
  Map<String, ResultadoCifraDoArtista> _cifras = {};
  bool _descartada = false;

  static String _chave(String titulo, String? artista) =>
      '${titulo.trim().toLowerCase()}|${artista?.trim().toLowerCase() ?? ''}';

  /// Falha do setlist sobe para quem chamou; sem os pedidos, o setlist segue.
  Future<void> carregar() async {
    final resultados = await Future.wait([
      api.obterSetlist(apresentacaoId),
      api
          .listarGruposDePedidosDoArtista(apresentacaoId)
          .catchError((_) => <GrupoPedidoMusical>[]),
    ]);
    itens = resultados[0] as List<ItemDoSetlist>;
    pedidos = resultados[1] as List<GrupoPedidoMusical>;
    aSeguir = await PedidosASeguir.ler(apresentacaoId);
    _avisar();
    buscarCifras();
  }

  void substituirItens(List<ItemDoSetlist> novos) {
    itens = novos;
    _avisar();
    buscarCifras();
  }

  Future<void> marcar(ItemDoSetlist item, bool tocada) async {
    salvando = true;
    _avisar();
    try {
      final atualizado =
          await api.marcarItemDoSetlist(apresentacaoId, item.id, tocada);
      itens = itens.map((i) => i.id == atualizado.id ? atualizado : i).toList();
    } finally {
      salvando = false;
      _avisar();
    }
  }

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

  List<GrupoPedidoMusical> get tocandoAgora => pedidos
      .where((p) =>
          p.tipo == TipoPedido.musica &&
          p.status == StatusPedidoMusical.tocandoAgora)
      .toList();

  /// Pedidos marcados para tocar a seguir vêm antes do setlist.
  MusicaDoPalco? get proxima => _sequenciaRestante().firstOrNull;

  List<MusicaDoPalco> _sequenciaRestante() => [
        ...pedidosASeguir.map(MusicaDoPalco.doPedido),
        ...itens.where((i) => !i.tocada).map(MusicaDoPalco.doSetlist),
      ];

  /// Tom da próxima e a música que vem depois dela, para já se preparar.
  String? get detalheDaProxima {
    final restante = _sequenciaRestante();
    if (restante.isEmpty) return null;
    final musica = restante.first;
    final quantidade = musica.pedido?.quantidadePedidos;
    final partes = [
      if (quantidade != null)
        quantidade == 1 ? 'Pedido' : '$quantidade pedidos',
      if (musica.tom?.isNotEmpty == true) 'Tom ${musica.tom}',
      if (restante.length > 1) 'Depois: ${restante[1].titulo}',
    ];
    return partes.isEmpty ? null : partes.join(' · ');
  }

  /// Coloca o pedido em Tocando agora, tira da sequência e marca a mesma
  /// música no setlist. Responde o item marcado, para poder desfazer.
  Future<ItemDoSetlist?> tocarPedido(GrupoPedidoMusical pedido) async {
    await _alterarStatus(pedido, StatusPedidoMusical.tocandoAgora);
    aSeguir =
        aSeguir.where((id) => id != pedido.pedidoRepresentativoId).toList();
    _avisar();
    await PedidosASeguir.remover(apresentacaoId, pedido.pedidoRepresentativoId);
    final titulo = pedido.musica.trim().toLowerCase();
    final noSetlist = itens
        .where((i) => !i.tocada && i.titulo.trim().toLowerCase() == titulo)
        .firstOrNull;
    if (noSetlist != null) await marcar(noSetlist, true);
    return noSetlist;
  }

  Future<void> desfazerPedido(
      GrupoPedidoMusical pedido, ItemDoSetlist? marcado) async {
    await _alterarStatus(pedido, StatusPedidoMusical.aceito);
    aSeguir = [
      pedido.pedidoRepresentativoId,
      ...aSeguir.where((id) => id != pedido.pedidoRepresentativoId),
    ];
    _avisar();
    await PedidosASeguir.adicionarNoInicio(
        apresentacaoId, pedido.pedidoRepresentativoId);
    if (marcado != null) await marcar(marcado, false);
  }

  /// Começar a próxima música encerra o pedido que estava tocando.
  Future<void> finalizarTocando() async {
    for (final pedido in tocandoAgora) {
      await _alterarStatus(pedido, StatusPedidoMusical.finalizado);
    }
  }

  Future<void> _alterarStatus(
      GrupoPedidoMusical pedido, StatusPedidoMusical status) async {
    salvando = true;
    _avisar();
    try {
      final atualizado = await api.alterarStatusDoGrupo(
          apresentacaoId, pedido.pedidoRepresentativoId, status);
      pedidos = pedidos
          .map((p) => p.pedidoRepresentativoId == pedido.pedidoRepresentativoId
              ? atualizado
              : p)
          .toList();
    } finally {
      salvando = false;
      _avisar();
    }
  }

  ResultadoCifraDoArtista? cifraDe(MusicaDoPalco musica) =>
      _cifras[_chave(musica.titulo, musica.artista)];

  // Só conta como sem cifra depois de consultada, para não acusar falha de rede.
  bool estaSemCifra(MusicaDoPalco musica) {
    final resultado = cifraDe(musica);
    return resultado != null && resultado.cifra == null;
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
          _chave(musica.titulo, musica.artista): resultado,
    };
    _avisar();
  }

  Future<void> atualizarCifra(MusicaDoPalco musica) async {
    final resultado = await _consultarCifraSemErro(musica);
    if (resultado == null) return;
    _cifras = {..._cifras, _chave(musica.titulo, musica.artista): resultado};
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

  void _avisar() {
    if (!_descartada) notifyListeners();
  }

  @override
  void dispose() {
    _descartada = true;
    super.dispose();
  }
}
