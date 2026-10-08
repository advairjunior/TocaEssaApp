import 'package:flutter/foundation.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';

/// Uma música que pode tocar no show: item do setlist ou pedido do público.
class MusicaDoPalco {
  MusicaDoPalco.doSetlist(ItemDoSetlist this.item) : pedido = null;
  MusicaDoPalco.doPedido(GrupoPedidoMusical this.pedido) : item = null;

  final ItemDoSetlist? item;
  final GrupoPedidoMusical? pedido;

  String get titulo => item?.titulo ?? pedido!.musica;
  String? get artista => item?.artista ?? pedido!.artista;
  String? get tom => item?.tom ?? pedido!.tomPreferido;
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

  MusicaDoPalco? get proxima {
    final indice = proximaIndex;
    return indice < 0 ? null : MusicaDoPalco.doSetlist(itens[indice]);
  }

  /// Tom da próxima e a música que vem depois dela, para já se preparar.
  String? get detalheDaProxima {
    final indice = proximaIndex;
    if (indice < 0) return null;
    final item = itens[indice];
    final seguinte = itens.skip(indice + 1).where((i) => !i.tocada);
    final partes = [
      if (item.tom != null) 'Tom ${item.tom}',
      if (seguinte.isNotEmpty) 'Depois: ${seguinte.first.titulo}',
    ];
    return partes.isEmpty ? null : partes.join(' · ');
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
    final musicas = itens.map(MusicaDoPalco.doSetlist).toList();
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
