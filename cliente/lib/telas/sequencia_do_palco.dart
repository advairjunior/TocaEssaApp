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
  // Muda a cada alteração feita neste aparelho: uma atualização que começou
  // antes dela traz dados velhos e é descartada.
  int _versaoLocal = 0;

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
    aSeguir = await _lerASeguirSemErro() ?? const [];
    _avisar();
    buscarCifras();
  }

  Future<List<String>?> _lerASeguirSemErro() async {
    try {
      return await api.listarPedidosASeguir(apresentacaoId);
    } catch (_) {
      return null;
    }
  }

  /// Traz o que mudou em outro aparelho da banda: setlist, pedidos e a
  /// sequência a seguir. A música que o colega começou vira a atual, para
  /// a cifra estar a um toque. Falhas ficam para a próxima atualização.
  Future<void> recarregar() async {
    final versao = _versaoLocal;
    final List<ItemDoSetlist> novosItens;
    final List<GrupoPedidoMusical> novosPedidos;
    final List<String>? novaSequencia;
    try {
      final resultados = await Future.wait([
        api.obterSetlist(apresentacaoId),
        api.listarGruposDePedidosDoArtista(apresentacaoId),
        _lerASeguirSemErro(),
      ]);
      novosItens = resultados[0] as List<ItemDoSetlist>;
      novosPedidos = resultados[1] as List<GrupoPedidoMusical>;
      novaSequencia = resultados[2] as List<String>?;
    } catch (_) {
      return;
    }
    if (versao != _versaoLocal || _descartada) return;
    final jaTocadas = {
      for (final i in itens)
        if (i.tocada) i.id
    };
    final jaTocando = {for (final p in tocandoAgora) p.pedidoRepresentativoId};
    final setlistMudou = !_mesmosItens(itens, novosItens);
    itens = novosItens;
    pedidos = novosPedidos;
    if (novaSequencia != null) aSeguir = novaSequencia;
    final pedidoComecado = tocandoAgora
        .where((p) => !jaTocando.contains(p.pedidoRepresentativoId))
        .firstOrNull;
    final itemComecado =
        itens.where((i) => i.tocada && !jaTocadas.contains(i.id)).lastOrNull;
    if (pedidoComecado != null) {
      _atual = MusicaDoPalco.doPedido(pedidoComecado);
    } else if (itemComecado != null) {
      _atual = MusicaDoPalco.doSetlist(itemComecado);
    } else if (_atual != null && !_continuaTocando(_atual!)) {
      _atual = null;
    }
    _avisar();
    if (setlistMudou) buscarCifras();
  }

  static bool _mesmosItens(List<ItemDoSetlist> a, List<ItemDoSetlist> b) =>
      a.length == b.length &&
      [
        for (var i = 0; i < a.length; i++)
          a[i].id == b[i].id &&
              a[i].titulo == b[i].titulo &&
              a[i].artista == b[i].artista
      ].every((igual) => igual);

  bool _continuaTocando(MusicaDoPalco musica) {
    if (musica.item case final item?) {
      return itens.any((i) => i.id == item.id && i.tocada);
    }
    final id = musica.pedido!.pedidoRepresentativoId;
    return tocandoAgora.any((p) => p.pedidoRepresentativoId == id);
  }

  void substituirItens(List<ItemDoSetlist> novos) {
    itens = novos;
    _avisar();
    buscarCifras();
  }

  Future<void> marcar(ItemDoSetlist item, bool tocada) async {
    salvando = true;
    _versaoLocal++;
    _avisar();
    try {
      final atualizado =
          await api.marcarItemDoSetlist(apresentacaoId, item.id, tocada);
      itens = itens.map((i) => i.id == atualizado.id ? atualizado : i).toList();
    } finally {
      salvando = false;
      _versaoLocal++;
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

  MusicaDoPalco? _atual;

  /// Música começada neste aparelho ou, ao abrir, o pedido tocando agora.
  MusicaDoPalco? get atual =>
      _atual ??
      (tocandoAgora.isEmpty
          ? null
          : MusicaDoPalco.doPedido(tocandoAgora.first));

  /// Encerra o pedido que estava tocando e começa a música. Responde como
  /// desfazer o começo.
  Future<Future<void> Function()> comecar(MusicaDoPalco musica) async {
    final anterior = _atual;
    await finalizarTocando();
    if (musica.pedido case final pedido?) {
      final marcado = await tocarPedido(pedido);
      _atual = musica;
      _avisar();
      return () async {
        await desfazerPedido(pedido, marcado);
        _atual = anterior;
        _avisar();
      };
    }
    final item = musica.item!;
    await marcar(item, true);
    _atual = musica;
    _avisar();
    return () async {
      await marcar(item, false);
      _atual = anterior;
      _avisar();
    };
  }

  /// Coloca o pedido em Tocando agora, tira da sequência e marca a mesma
  /// música no setlist. Responde o item marcado, para poder desfazer.
  Future<ItemDoSetlist?> tocarPedido(GrupoPedidoMusical pedido) async {
    await alterarStatus(pedido, StatusPedidoMusical.tocandoAgora);
    aSeguir =
        aSeguir.where((id) => id != pedido.pedidoRepresentativoId).toList();
    _avisar();
    await _gravarASeguir(() =>
        api.tirarPedidoASeguir(apresentacaoId, pedido.pedidoRepresentativoId));
    final titulo = pedido.musica.trim().toLowerCase();
    final noSetlist = itens
        .where((i) => !i.tocada && i.titulo.trim().toLowerCase() == titulo)
        .firstOrNull;
    if (noSetlist != null) await marcar(noSetlist, true);
    return noSetlist;
  }

  Future<void> desfazerPedido(
      GrupoPedidoMusical pedido, ItemDoSetlist? marcado) async {
    await alterarStatus(pedido, StatusPedidoMusical.aceito);
    aSeguir = [
      pedido.pedidoRepresentativoId,
      ...aSeguir.where((id) => id != pedido.pedidoRepresentativoId),
    ];
    _avisar();
    await _gravarASeguir(() => api.colocarPedidoASeguir(
        apresentacaoId, pedido.pedidoRepresentativoId,
        noInicio: true));
    if (marcado != null) await marcar(marcado, false);
  }

  /// Grava a sequência no servidor sem travar o show: o pedido já está
  /// tocando (ou de volta) e a lista só vale para pedidos aceitos.
  Future<void> _gravarASeguir(Future<List<String>> Function() gravar) async {
    _versaoLocal++;
    try {
      aSeguir = await gravar();
      _avisar();
    } catch (_) {
      // A próxima atualização traz a sequência do servidor.
    } finally {
      _versaoLocal++;
    }
  }

  /// Começar a próxima música encerra o pedido que estava tocando.
  Future<void> finalizarTocando() async {
    for (final pedido in tocandoAgora) {
      await alterarStatus(pedido, StatusPedidoMusical.finalizado);
    }
  }

  Future<void> alterarStatus(
      GrupoPedidoMusical pedido, StatusPedidoMusical status) async {
    salvando = true;
    _versaoLocal++;
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
      _versaoLocal++;
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
