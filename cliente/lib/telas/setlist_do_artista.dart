import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/abrir_url_externa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_lista.dart';
import 'escolher_cifra.dart';

class SetlistDoArtista extends StatefulWidget {
  const SetlistDoArtista({
    super.key,
    required this.api,
    required this.apresentacao,
    this.incorporada = false,
    this.abrirUrl = abrirNaAbaDaCifra,
    this.prepararAbertura = prepararAberturaNaAbaDaCifra,
  });

  final ApiTocaEssa api;
  final Apresentacao apresentacao;
  final bool incorporada;
  final Future<void> Function(Uri url) abrirUrl;
  final FinalizarAberturaExterna Function() prepararAbertura;

  @override
  State<SetlistDoArtista> createState() => _SetlistDoArtistaState();
}

class _SetlistDoArtistaState extends State<SetlistDoArtista> {
  List<ItemDoSetlist> _itens = [];
  // título normalizado → quantidade de pedidos na fila
  Map<String, int> _pedidosNaFila = {};
  bool _carregando = true;
  bool _salvando = false;
  // id do item → cifra buscada antes do show, para abrir na hora no palco e
  // avisar quais músicas ainda estão sem cifra.
  Map<String, ResultadoCifraDoArtista> _cifras = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final resultados = await Future.wait([
        widget.api.obterSetlist(widget.apresentacao.id),
        widget.api
            .listarGruposDePedidosDoArtista(widget.apresentacao.id)
            .catchError((_) => <GrupoPedidoMusical>[]),
      ]);
      if (!mounted) return;
      final itens = resultados[0] as List<ItemDoSetlist>;
      final grupos = resultados[1] as List<GrupoPedidoMusical>;
      final mapa = <String, int>{};
      for (final g in grupos) {
        if (g.status == StatusPedidoMusical.aguardando ||
            g.status == StatusPedidoMusical.aceito) {
          final chave = g.musica.toLowerCase().trim();
          mapa[chave] = (mapa[chave] ?? 0) + g.quantidadePedidos;
        }
      }
      setState(() {
        _itens = itens;
        _pedidosNaFila = mapa;
      });
      _buscarCifras();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _marcar(ItemDoSetlist item, bool tocada) async {
    setState(() => _salvando = true);
    try {
      final atualizado = await widget.api
          .marcarItemDoSetlist(widget.apresentacao.id, item.id, tocada);
      if (!mounted) return;
      setState(() {
        _itens =
            _itens.map((i) => i.id == atualizado.id ? atualizado : i).toList();
      });
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _buscarCifras() async {
    final itens = _itens;
    final resultados = await Future.wait(itens.map(_consultarCifraSemErro));
    if (!mounted) return;
    setState(() {
      _cifras = {
        for (final (indice, item) in itens.indexed)
          if (resultados[indice] case final resultado?) item.id: resultado,
      };
    });
  }

  Future<void> _atualizarCifra(ItemDoSetlist item) async {
    final resultado = await _consultarCifraSemErro(item);
    if (!mounted || resultado == null) return;
    setState(() => _cifras = {..._cifras, item.id: resultado});
  }

  Future<ResultadoCifraDoArtista?> _consultarCifraSemErro(
      ItemDoSetlist item) async {
    try {
      return await widget.api.consultarCifra(item.titulo, item.artista);
    } catch (_) {
      // Sem a busca antecipada, o toque em Tocar busca a cifra na hora.
      return null;
    }
  }

  /// Abre a cifra da próxima música e a marca como tocada num único toque.
  /// A cifra abre antes de qualquer espera para o Safari aceitar a nova aba.
  Future<void> _tocarProxima() async {
    final indice = _proximaIndex;
    if (indice < 0) return;
    final item = _itens[indice];
    final preBuscada = _cifras[item.id];
    final url = preBuscada?.cifra?.url;
    if (url != null) {
      widget.abrirUrl(Uri.parse(url)).catchError((Object erro) {
        if (mounted) mostrarErro(context, erro);
      });
    } else if (preBuscada == null) {
      _abrirCifra(item);
    }
    await _marcar(item, true);
    final marcada = _itens.any((i) => i.id == item.id && i.tocada);
    if (!mounted || !marcada) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${item.titulo} marcada como tocada.'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () => _marcar(item, false),
        ),
      ));
    if (url == null && preBuscada != null) {
      await _mostrarEscolhaDaCifra(item, preBuscada);
    }
  }

  Future<void> _abrirCifra(ItemDoSetlist item) async {
    FinalizarAberturaExterna? finalizar;
    try {
      finalizar = widget.prepararAbertura();
      final resultado =
          await widget.api.consultarCifra(item.titulo, item.artista);
      if (!mounted) {
        await finalizar(null);
        return;
      }
      if (resultado.cifra != null) {
        await finalizar(Uri.parse(resultado.cifra!.url));
        return;
      }
      await finalizar(null);
      await _mostrarEscolhaDaCifra(item, resultado);
    } catch (erro) {
      await finalizar?.call(null);
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _escolherCifra(ItemDoSetlist item) async {
    try {
      final resultado =
          await widget.api.consultarCifra(item.titulo, item.artista);
      await _mostrarEscolhaDaCifra(item, resultado);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  /// Responde se o artista decidiu algo; falso quando fechou sem escolher.
  Future<bool> _mostrarEscolhaDaCifra(
      ItemDoSetlist item, ResultadoCifraDoArtista resultado,
      {String? rotuloColarEProxima}) async {
    if (!mounted) return false;
    final decisao = await mostrarEscolhaDeCifra(
      context,
      musica: item.titulo,
      artista: item.artista,
      resultado: resultado,
      abrirUrl: widget.abrirUrl,
      rotuloColarEProxima: rotuloColarEProxima,
    );
    if (decisao == null || !mounted) return false;
    switch (decisao.tipo) {
      case TipoDecisaoCifra.remover:
        final cifra = resultado.cifra;
        if (cifra == null) return false;
        await widget.api.removerCifra(cifra.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link da cifra removido.')),
          );
        }
      case TipoDecisaoCifra.salvar:
        await widget.api.salvarCifra(item.titulo, item.artista, decisao.url!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cifra salva.')),
          );
        }
    }
    await _atualizarCifra(item);
    return true;
  }

  /// Pede, uma a uma, a cifra das músicas que faltam tocar e estão sem cifra,
  /// para resolver tudo antes de subir no palco. Fechar a escolha interrompe.
  Future<void> _resolverSemCifra() async {
    final pendentes = _semCifra;
    for (final (indice, item) in pendentes.indexed) {
      final resultado = _cifras[item.id];
      if (resultado == null || !mounted) return;
      final ultima = indice == pendentes.length - 1;
      try {
        if (!await _mostrarEscolhaDaCifra(item, resultado,
            rotuloColarEProxima:
                ultima ? 'Colar e concluir' : 'Colar e próxima')) {
          return;
        }
      } catch (erro) {
        if (mounted) mostrarErro(context, erro);
        return;
      }
    }
  }

  Future<void> _mostrarImportarRepertorio() async {
    List<Repertorio>? repertorios;
    try {
      repertorios = await widget.api.listarRepertorios();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
      return;
    }
    if (!mounted) return;

    if (repertorios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Nenhum repertório criado. Crie um em Repertórios, no menu da sua conta.'),
        ),
      );
      return;
    }

    final selecionado = await showModalBottomSheet<Repertorio>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: CoresTocaEssa.superficie,
      builder: (_) => _SelecionarRepertorioSheet(repertorios: repertorios!),
    );
    if (selecionado == null || !mounted) return;

    setState(() => _carregando = true);
    try {
      final novos = await widget.api.importarRepertorioParaSetlist(
          widget.apresentacao.id, selecionado.id);
      if (!mounted) return;
      setState(() => _itens = novos);
      _buscarCifras();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Repertório "${selecionado.nome}" importado.')),
      );
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  int get _tocadas => _itens.where((i) => i.tocada).length;
  int get _proximaIndex => _itens.indexWhere((i) => !i.tocada);
  // Só conta como sem cifra depois de consultada, para não acusar falha de rede.
  bool _estaSemCifra(ItemDoSetlist item) =>
      _cifras.containsKey(item.id) && _cifras[item.id]!.cifra == null;
  List<ItemDoSetlist> get _semCifra =>
      _itens.where((i) => !i.tocada && _estaSemCifra(i)).toList();

  /// Tom da próxima e a música que vem depois dela, para já se preparar.
  String? _detalheDaProxima(int proxima) {
    final item = _itens[proxima];
    final seguinte = _itens.skip(proxima + 1).where((i) => !i.tocada);
    final partes = [
      if (item.tom != null) 'Tom ${item.tom}',
      if (seguinte.isNotEmpty) 'Depois: ${seguinte.first.titulo}',
    ];
    return partes.isEmpty ? null : partes.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.incorporada) {
      return Scaffold(
        appBar: AppBar(title: const Text('Setlist')),
        body: _construirCorpo(context),
      );
    }
    return _construirCorpo(context);
  }

  Widget _construirCorpo(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_itens.isEmpty) {
      return _construirVazio();
    }
    final proxima = _proximaIndex;
    return Column(
      children: [
        Expanded(child: _construirLista(context, proxima)),
        if (proxima >= 0)
          _BarraProxima(
            titulo: _itens[proxima].titulo,
            detalhe: _detalheDaProxima(proxima),
            salvando: _salvando,
            tocar: _tocarProxima,
          ),
      ],
    );
  }

  Widget _construirLista(BuildContext context, int proxima) {
    return ConteudoMobile(
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _construirProgresso(context),
          if (_semCifra.isNotEmpty) ...[
            const SizedBox(height: EspacoTocaEssa.base),
            _AvisoSemCifra(
              quantidade: _semCifra.length,
              resolver: _resolverSemCifra,
            ),
          ],
          const SizedBox(height: EspacoTocaEssa.base + 4),
          GrupoDeLinhas(
            recuoDivisoria: 60,
            linhas: [
              for (final (indice, item) in _itens.indexed)
                _LinhaSetlist(
                  item: item,
                  salvando: _salvando,
                  eProxima: indice == proxima,
                  semCifra: _estaSemCifra(item),
                  pedidosNaFila:
                      _pedidosNaFila[item.titulo.toLowerCase().trim()] ?? 0,
                  marcar: (tocada) => _marcar(item, tocada),
                  abrirCifra: () => _abrirCifra(item),
                  escolherCifra: () => _escolherCifra(item),
                ),
            ],
          ),
          const SizedBox(height: EspacoTocaEssa.base),
        ],
      ),
    );
  }

  Widget _construirProgresso(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final total = _itens.length;
    final restantes = total - _tocadas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_tocadas de $total tocadas', style: texto.titleMedium),
                  Text(
                    restantes == 0
                        ? 'Setlist completo!'
                        : restantes == 1
                            ? 'Falta 1 música'
                            : 'Faltam $restantes músicas',
                    style: texto.bodyMedium
                        ?.copyWith(color: CoresTocaEssa.textoSecundario),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _mostrarImportarRepertorio,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Trocar repertório'),
            ),
          ],
        ),
        const SizedBox(height: EspacoTocaEssa.pequeno),
        LinearProgressIndicator(
          value: total > 0 ? _tocadas / total : 0,
          minHeight: 6,
          borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
          color: restantes == 0 ? CoresTocaEssa.sucesso : null,
        ),
      ],
    );
  }

  Widget _construirVazio() => Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EstadoVazio(
                icone: Icons.playlist_play_rounded,
                titulo: 'Nenhum repertório nesta apresentação',
                descricao:
                    'Importe um repertório para acompanhar o que já tocou.',
              ),
              FilledButton.icon(
                onPressed: _mostrarImportarRepertorio,
                icon: const Icon(Icons.playlist_add_rounded),
                label: const Text('Importar repertório'),
              ),
            ],
          ),
        ),
      );
}

/// Barra fixa no rodapé: um toque abre a cifra da próxima música, para não
/// haver silêncio entre uma música e outra no palco.
class _BarraProxima extends StatelessWidget {
  const _BarraProxima({
    required this.titulo,
    required this.detalhe,
    required this.salvando,
    required this.tocar,
  });

  final String titulo;
  final String? detalhe;
  final bool salvando;
  final VoidCallback tocar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Material(
      color: CoresTocaEssa.superficie,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                EspacoTocaEssa.medio,
                20,
                EspacoTocaEssa.medio,
              ),
              child: Row(
                children: [
                  const Icon(Icons.skip_next_rounded,
                      color: CoresTocaEssa.roxoClaro),
                  const SizedBox(width: EspacoTocaEssa.pequeno),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Próxima: $titulo',
                          style: texto.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (detalhe != null)
                          Text(
                            detalhe!,
                            style: texto.bodyMedium?.copyWith(
                                color: CoresTocaEssa.textoSecundario),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: EspacoTocaEssa.pequeno),
                  FilledButton.icon(
                    onPressed: salvando ? null : tocar,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Tocar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Avisa, antes do show, quantas músicas que faltam tocar estão sem cifra,
/// para o artista não precisar escolher cifra no meio da apresentação.
class _AvisoSemCifra extends StatelessWidget {
  const _AvisoSemCifra({required this.quantidade, required this.resolver});

  final int quantidade;
  final VoidCallback resolver;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        EspacoTocaEssa.base,
        EspacoTocaEssa.pequeno,
        EspacoTocaEssa.pequeno,
        EspacoTocaEssa.pequeno,
      ),
      decoration: BoxDecoration(
        color: CoresTocaEssa.atencao.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: CoresTocaEssa.atencao),
          const SizedBox(width: EspacoTocaEssa.pequeno),
          Expanded(
            child: Text(
              quantidade == 1
                  ? '1 música sem cifra'
                  : '$quantidade músicas sem cifra',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          TextButton(onPressed: resolver, child: const Text('Resolver')),
        ],
      ),
    );
  }
}

/// Uma música do setlist. A linha inteira marca e desmarca como tocada,
/// alvo grande para usar no palco.
class _LinhaSetlist extends StatelessWidget {
  const _LinhaSetlist({
    required this.item,
    required this.salvando,
    required this.eProxima,
    required this.semCifra,
    required this.pedidosNaFila,
    required this.marcar,
    required this.abrirCifra,
    required this.escolherCifra,
  });

  final ItemDoSetlist item;
  final bool salvando;
  final bool eProxima;
  // Cifra já consultada e sem link salvo: o ícone fica em destaque.
  final bool semCifra;
  final int pedidosNaFila;
  final ValueChanged<bool> marcar;
  final VoidCallback abrirCifra;
  final VoidCallback escolherCifra;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final tocada = item.tocada;
    final detalhes = [
      if (item.artista != null) item.artista!,
      if (item.tom != null) 'Tom ${item.tom}',
    ].join(' · ');
    return Container(
      color: eProxima ? CoresTocaEssa.roxo.withValues(alpha: .12) : null,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              checked: tocada,
              button: true,
              child: InkWell(
                onTap: salvando ? null : () => marcar(!tocada),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    EspacoTocaEssa.base,
                    EspacoTocaEssa.medio,
                    EspacoTocaEssa.pequeno,
                    EspacoTocaEssa.medio,
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tocada ? CoresTocaEssa.roxo : null,
                          border: Border.all(
                            color: tocada
                                ? CoresTocaEssa.roxo
                                : CoresTocaEssa.textoSecundario,
                            width: 2,
                          ),
                        ),
                        child: tocada
                            ? const Icon(Icons.check_rounded,
                                size: 18, color: CoresTocaEssa.texto)
                            : null,
                      ),
                      const SizedBox(width: EspacoTocaEssa.base),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (eProxima)
                              Text(
                                'Próxima',
                                style: texto.labelMedium
                                    ?.copyWith(color: CoresTocaEssa.roxoClaro),
                              ),
                            Text(
                              item.titulo,
                              style: texto.titleLarge?.copyWith(
                                color: tocada
                                    ? CoresTocaEssa.textoSecundario
                                    : null,
                                decoration:
                                    tocada ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            if (detalhes.isNotEmpty)
                              Text(
                                detalhes,
                                style: texto.bodyMedium?.copyWith(
                                    color: CoresTocaEssa.textoSecundario),
                              ),
                            if (pedidosNaFila > 0)
                              Text(
                                pedidosNaFila == 1
                                    ? '1 pedido na fila'
                                    : '$pedidosNaFila pedidos na fila',
                                style: texto.labelMedium
                                    ?.copyWith(color: CoresTocaEssa.roxoClaro),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: semCifra ? 'Música sem cifra' : 'Ver cifra',
            icon: Icon(Icons.menu_book_rounded,
                color:
                    semCifra ? CoresTocaEssa.atencao : CoresTocaEssa.roxoClaro),
            onPressed: abrirCifra,
          ),
          IconButton(
            tooltip: 'Escolher ou trocar cifra',
            icon: const Icon(Icons.link_rounded,
                color: CoresTocaEssa.textoSecundario),
            onPressed: escolherCifra,
          ),
          const SizedBox(width: EspacoTocaEssa.pequeno),
        ],
      ),
    );
  }
}

class _SelecionarRepertorioSheet extends StatelessWidget {
  const _SelecionarRepertorioSheet({required this.repertorios});
  final List<Repertorio> repertorios;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Selecionar repertório',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final rep in repertorios)
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              title: Text(rep.nome),
              subtitle: Text(
                '${rep.musicas.length} '
                '${rep.musicas.length == 1 ? 'música' : 'músicas'}',
                style: const TextStyle(color: CoresTocaEssa.textoSecundario),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => Navigator.pop(context, rep),
            ),
          const SizedBox(height: 16),
        ],
      );
}
