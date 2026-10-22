import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/abrir_url_externa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_lista.dart';
import 'componentes_movimento.dart';
import 'componentes_palco.dart';
import '../infraestrutura/assinatura_tempo_real.dart';
import 'acoes_do_palco.dart';
import 'colar_cifras.dart';
import 'escolher_para_repertorio.dart';
import 'leitor_de_cifras.dart';
import 'lista_reordenavel.dart';
import 'montar_setlist.dart';
import 'sequencia_do_palco.dart';

class SetlistDoArtista extends StatefulWidget {
  const SetlistDoArtista({
    super.key,
    required this.api,
    required this.apresentacao,
    this.incorporada = false,
    this.abrirUrl = abrirNaAbaDaCifra,
    this.prepararAbertura = prepararAberturaNaAbaDaCifra,
    this.abrirFila,
  });

  final ApiTocaEssa api;
  final Apresentacao apresentacao;
  final bool incorporada;
  // Selo de pedidos novos leva à aba Fila do painel.
  final VoidCallback? abrirFila;
  final Future<void> Function(Uri url) abrirUrl;
  final FinalizarAberturaExterna Function() prepararAbertura;

  @override
  State<SetlistDoArtista> createState() => _SetlistDoArtistaState();
}

class _SetlistDoArtistaState extends State<SetlistDoArtista>
    with AcoesDoPalco<SetlistDoArtista> {
  @override
  SequenciaDoPalco get sequencia => _sequencia;
  @override
  ApiTocaEssa get api => widget.api;
  @override
  Future<void> Function(Uri url) get abrirUrl => widget.abrirUrl;
  @override
  FinalizarAberturaExterna Function() get prepararAbertura =>
      widget.prepararAbertura;

  late final SequenciaDoPalco _sequencia = SequenciaDoPalco(
    api: widget.api,
    apresentacaoId: widget.apresentacao.id,
    codigo: widget.apresentacao.codigo,
    vocabulario: _v,
  )..addListener(_redesenhar);
  Vocabulario get _v => widget.apresentacao.tipo.vocabulario;
  bool _carregando = true;
  bool _editando = false;
  // Busca pelo título ou cantor; com muitas músicas, rolar cansa.
  final _busca = TextEditingController();
  static const _musicasParaBuscar = 10;
  // Acervo do artista, para avisar o que está fora dele.
  List<Repertorio>? _repertorios;
  // Só antes do show: horas contratadas e ritmo médio para estimar a setlist.
  RelogioDoShow? _relogio;

  AssinaturaTempoReal? _tempoReal;
  Timer? _atualizacaoAutomatica;

  @override
  void initState() {
    super.initState();
    _carregar();
    _carregarRelogio();
    _carregarRepertorios();
    // Acompanha o que os outros aparelhos da banda fazem no show.
    _tempoReal = AssinaturaTempoReal(
      widget.api.enderecoTempoReal(widget.apresentacao.codigo),
      _sequencia.recarregar,
    );
    _atualizacaoAutomatica = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sequencia.recarregar(),
    );
  }

  Future<void> _carregarRelogio() async {
    try {
      final relogio = await widget.api.obterRelogio(widget.apresentacao.id);
      if (mounted) setState(() => _relogio = relogio);
    } catch (_) {
      // Sem a estimativa, a setlist segue normal.
    }
  }

  @override
  void dispose() {
    _tempoReal?.encerrar();
    _atualizacaoAutomatica?.cancel();
    _sequencia.dispose();
    _busca.dispose();
    super.dispose();
  }

  void _redesenhar() {
    if (mounted) setState(() {});
  }

  Future<void> _carregar() async {
    try {
      await _sequencia.carregar();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _marcar(ItemDoSetlist item, bool tocada) async {
    try {
      await _sequencia.marcar(item, tocada);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  /// Colar e próxima nas músicas que faltam tocar sem cifra no app.
  Future<void> _colarCifras() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ColarCifras(
        api: widget.api,
        abrirUrl: widget.abrirUrl,
        musicas: [
          for (final item in _sequencia.semCifra)
            if (_sequencia.cifraDe(MusicaDoPalco.doSetlist(item))
                case final consulta?)
              (
                titulo: item.titulo,
                artista: item.artista,
                url: consulta.cifra?.url,
                urlPesquisa: consulta.urlPesquisa,
              ),
        ],
      ),
    ));
    if (mounted) await _sequencia.buscarCifras();
  }

  /// Ações da cifra: colar no app primeiro, o link do site como reserva.
  Future<void> _acoesDaCifra(ItemDoSetlist item) async {
    final musica = MusicaDoPalco.doSetlist(item);
    final escolha = await showCupertinoModalPopup<String>(
      context: context,
      builder: (contexto) => CupertinoActionSheet(
        title: Text(item.titulo),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(contexto, 'colar'),
            child: Text('Colar ou corrigir ${_v.cifra}'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(contexto, 'link'),
            child: const Text('Link do site'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(contexto),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (!mounted) return;
    if (escolha == 'link') return escolherCifra(musica);
    if (escolha != 'colar') return;
    final texto = await pedirCifraEmTexto(context,
        titulo: item.titulo,
        texto: _sequencia.cifraDe(musica)?.texto,
        oQue: _v.cifraMaiuscula);
    if (texto == null || !mounted) return;
    try {
      await _sequencia.salvarCifraEmTexto(musica, texto);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _montar() async {
    final mudou = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => MontarSetlist(
        api: widget.api,
        apresentacaoId: widget.apresentacao.id,
        naSetlist: _sequencia.itens,
        vocabulario: _v,
      ),
    ));
    if (mudou == true && mounted) await _carregar();
  }

  Future<void> _remover(ItemDoSetlist item) async {
    try {
      _sequencia.reorganizarItens(await widget.api
          .removerItemDoSetlist(widget.apresentacao.id, item.id));
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  /// Só as que faltam mudam de lugar; as tocadas ficam onde estão.
  Future<void> _reordenar(int de, int para) async {
    final antes = _sequencia.itens;
    final nova = [...antes];
    nova.insert(para, nova.removeAt(de));
    _sequencia.reorganizarItens(nova);
    try {
      _sequencia.reorganizarItens(
          await widget.api.reordenarSetlist(widget.apresentacao.id, [
        for (final item in nova)
          if (!item.tocada) item.id
      ]));
    } catch (erro) {
      _sequencia.reorganizarItens(antes);
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _carregarRepertorios() async {
    try {
      final repertorios = await widget.api.listarRepertorios();
      if (mounted) setState(() => _repertorios = repertorios);
    } catch (_) {
      // Sem o acervo, a setlist segue sem o aviso de fora do repertório.
    }
  }

  /// Música que não está em nenhum repertório; nada é marcado enquanto o
  /// acervo não chega.
  bool _foraDoRepertorio(ItemDoSetlist item) =>
      _repertorios?.every((repertorio) => !repertorio.musicas.any((musica) =>
          mesmaMusica(
              musica.titulo, musica.artista, item.titulo, item.artista))) ??
      false;

  /// Leva [itens] (toda a setlist, se nulo) com todas marcadas: guardar o
  /// show como repertório é o mais comum.
  Future<void> _levarAoRepertorio([List<ItemDoSetlist>? itens]) async {
    final data = widget.apresentacao.data;
    await escolherParaRepertorio(
      context,
      api: widget.api,
      titulo: 'Adicionar ao repertório',
      vocabulario: _v,
      nomeSugerido: '${widget.apresentacao.nome} · '
          '${data.day.toString().padLeft(2, '0')}/'
          '${data.month.toString().padLeft(2, '0')}',
      opcoes: [
        for (final item in itens ?? _sequencia.itens)
          OpcaoParaRepertorio(musica: (
            titulo: item.titulo,
            artista: item.artista,
            tom: item.tom,
          )),
      ],
    );
    if (mounted) await _carregarRepertorios();
  }

  Future<void> _limpar() async {
    final confirmou = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Limpar a ${_v.setlist}?'),
            content: Text(_v.todasSaemDaSetlist),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: CoresTocaEssa.rosa),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Limpar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmou || !mounted) return;
    try {
      await widget.api.limparSetlist(widget.apresentacao.id);
      _sequencia.reorganizarItens(const []);
      if (mounted) setState(() => _editando = false);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
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
      return const EsqueletoDeLista();
    }
    if (_sequencia.itens.isEmpty) {
      return _construirVazio();
    }
    final proxima = _sequencia.proxima;
    final temBarra = proxima != null || ultimaComecada != null;
    // A lista passa por trás da barra translúcida, como no iPhone.
    return Stack(
      children: [
        Positioned.fill(
          child: _construirLista(context, proxima?.item, temBarra: temBarra),
        ),
        if (temBarra)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BarraProximaMusica(
              titulo: proxima?.titulo,
              detalhe: _sequencia.detalheDaProxima,
              salvando: _sequencia.salvando,
              tocar: tocarProxima,
              comecou: ultimaComecada?.titulo,
              desfazer: desfazerUltima,
            ),
          ),
      ],
    );
  }

  bool get _mostraBusca =>
      !_editando && _sequencia.itens.length >= _musicasParaBuscar;

  String get _termo => _mostraBusca ? normalizarMusica(_busca.text) : '';

  bool _achada(ItemDoSetlist item) =>
      combinaComBusca(_termo, [item.titulo, item.artista]);

  void _limparBusca() => setState(_busca.clear);

  Widget _construirLista(BuildContext context, ItemDoSetlist? proxima,
      {required bool temBarra}) {
    final pedidosNaFila = _sequencia.pedidosNaFila;
    final buscando = _termo.isNotEmpty;
    final itens = _sequencia.itens;
    final foraDoRepertorio = itens.where(_foraDoRepertorio).toList();
    return ConteudoMobile(
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _construirProgresso(context),
          _construirAvisos(foraDoRepertorio),
          const SizedBox(height: EspacoTocaEssa.base + 4),
          if (_mostraBusca) ...[
            CampoDeBusca(
              controlador: _busca,
              dica: _v.buscar,
              aoMudar: (_) => setState(() {}),
            ),
            const SizedBox(height: EspacoTocaEssa.base),
          ],
          if (_editando)
            ..._construirEdicao()
          else if (buscando && !itens.any(_achada))
            _SemResultado(
              texto: '${_v.nenhuma} com "${_busca.text.trim()}"',
              limpar: _limparBusca,
            )
          else
            SlidableAutoCloseBehavior(
              child: GrupoDeLinhas(
                recuoDivisoria: 60,
                linhas: [
                  for (final (indice, item) in itens.indexed)
                    if (!buscando || _achada(item))
                      _LinhaSetlist(
                        item: item,
                        // Achada pela busca, mostra onde está na ordem.
                        posicao: buscando ? indice + 1 : null,
                        foraDoRepertorio: foraDoRepertorio.contains(item),
                        vocabulario: _v,
                        salvando: _sequencia.salvando,
                        eProxima: item.id == proxima?.id,
                        semCifra: _sequencia
                            .estaSemCifra(MusicaDoPalco.doSetlist(item)),
                        pedidosNaFila:
                            pedidosNaFila[item.titulo.toLowerCase().trim()] ??
                                0,
                        marcar: (tocada) => _marcar(item, tocada),
                        abrirLeitor: () =>
                            abrirLeitor(MusicaDoPalco.doSetlist(item)),
                        acoesDaCifra: () => _acoesDaCifra(item),
                        remover: () => _remover(item),
                      ),
                ],
              ),
            ),
          // Espaço para o fim da lista rolar acima da barra Próxima.
          SizedBox(height: temBarra ? 150 : EspacoTocaEssa.base),
        ],
      ),
    );
  }

  /// Pedidos novos, músicas sem cifra e fora do repertório em chips numa
  /// faixa só: empilhados, empurravam a primeira música para o meio da tela.
  Widget _construirAvisos(List<ItemDoSetlist> foraDoRepertorio) {
    final abrirFila = widget.abrirFila;
    final novos = _sequencia.pedidosNovos.length;
    final semCifra = _sequencia.semCifra.length;
    final avisos = [
      if (abrirFila != null && novos > 0)
        _ChipDeAviso(
          icone: Icons.queue_music_rounded,
          cor: CoresTocaEssa.roxoClaro,
          texto: novos == 1 ? '1 pedido novo' : '$novos pedidos novos',
          dica: 'Abrir a fila',
          seta: true,
          tocar: abrirFila,
        ),
      if (semCifra > 0)
        _ChipDeAviso(
          icone: Icons.error_outline_rounded,
          cor: CoresTocaEssa.atencao,
          texto: '$semCifra sem ${_v.cifra}',
          dica: 'Colar as ${_v.cifra}s',
          tocar: _colarCifras,
        ),
      if (foraDoRepertorio.isNotEmpty)
        _ChipDeAviso(
          icone: Icons.library_add_rounded,
          cor: CoresTocaEssa.roxoClaro,
          texto: '${foraDoRepertorio.length} fora do repertório',
          dica: 'Adicionar ao repertório',
          tocar: () => _levarAoRepertorio(foraDoRepertorio),
        ),
    ];
    if (avisos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: EspacoTocaEssa.medio),
      child: Wrap(
        key: const ValueKey('avisos-da-setlist'),
        spacing: EspacoTocaEssa.pequeno,
        runSpacing: EspacoTocaEssa.pequeno,
        children: avisos,
      ),
    );
  }

  /// Edição: as que faltam podem ser arrastadas ou removidas; as tocadas
  /// ficam no lugar.
  List<Widget> _construirEdicao() {
    final itens = _sequencia.itens;
    return [
      ListaReordenavel(
        quantidade: itens.length,
        chaveDoItem: (indice) => ValueKey(itens[indice].id),
        habilitada: !_sequencia.salvando,
        aoReordenar: _reordenar,
        construirItem: (context, indice, alca) => _LinhaEmEdicao(
          item: itens[indice],
          vocabulario: _v,
          remover: () => _remover(itens[indice]),
          alca: alca,
        ),
      ),
    ];
  }

  /// Ritmo para estimar o que falta: o medido no show, o médio do artista
  /// ou, sem histórico, 3 minutos por música.
  Duration get _ritmo {
    final relogio = _relogio;
    if (relogio == null) return RelogioDoShow.ritmoPadrao;
    return relogio.iniciadaEm != null
        ? relogio.ritmo(DateTime.now())
        : relogio.ritmoAntesDeMedir;
  }

  /// "1 de 3 tocadas · faltam ~6 min de músicas" numa linha (sem nada
  /// tocado, "~24 min de músicas": quanto a lista leva); antes do show, embaixo da
  /// barra, o ritmo usado e a comparação com as horas contratadas.
  Widget _construirProgresso(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final total = _sequencia.itens.length;
    final faltam = _sequencia.musicasNaSequencia;
    final completa = total - _sequencia.tocadas == 0;
    final secundario =
        texto.bodyMedium?.copyWith(color: CoresTocaEssa.textoSecundario);
    final legenda = _legendaAntesDoShow();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              // Uma frase só: ao quebrar, o "·" não sobra no começo da linha.
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '${_sequencia.tocadas} de $total ${_v.tocadas}',
                      style: texto.titleMedium),
                  // Estimativa da lista, com ou sem horas contratadas:
                  // antes de começar, quanto ela leva; depois, o que resta.
                  TextSpan(
                    text: switch ((completa, _sequencia.tocadas)) {
                      (true, _) => ' · ${_v.setlist} completa',
                      (_, 0) => ' · ~${formatarTempoDoShow(_ritmo * faltam)} '
                          'de ${_v.musicas}',
                      _ => ' · faltam ~${formatarTempoDoShow(_ritmo * faltam)} '
                          'de ${_v.musicas}',
                    },
                    style: secundario,
                  ),
                ]),
              ),
            ),
            TextButton(
              // Arrastar numa lista filtrada confundiria a ordem.
              onPressed: () => setState(() {
                _editando = !_editando;
                _busca.clear();
              }),
              child: Text(_editando ? 'Concluir' : 'Editar'),
            ),
            IconButton(
              tooltip: 'Montar ${_v.setlist}',
              onPressed: _editando ? null : _montar,
              icon: const Icon(Icons.add_rounded),
            ),
            // Salvar no repertório e limpar, à vista e longe de um toque
            // acidental.
            PopupMenuButton<VoidCallback>(
              tooltip: 'Mais opções',
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (acao) => acao(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _levarAoRepertorio,
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.library_add_rounded),
                    title: Text('Adicionar ao repertório'),
                  ),
                ),
                PopupMenuItem(
                  value: _limpar,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_sweep_outlined,
                        color: CoresTocaEssa.rosa),
                    title: Text('Limpar ${_v.setlist}',
                        style: const TextStyle(color: CoresTocaEssa.rosa)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: EspacoTocaEssa.pequeno),
        LinearProgressIndicator(
          value: total > 0 ? _sequencia.tocadas / total : 0,
          minHeight: 6,
          borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
          color: completa ? CoresTocaEssa.sucesso : null,
        ),
        if (legenda != null) ...[
          const SizedBox(height: EspacoTocaEssa.pequeno),
          Text(legenda,
              style: texto.bodySmall
                  ?.copyWith(color: CoresTocaEssa.textoSecundario)),
        ],
      ],
    );
  }

  /// Só antes do show: ao vivo, o tempo do contrato está na faixa do
  /// cronômetro acima das abas.
  String? _legendaAntesDoShow() {
    final relogio = _relogio;
    if (widget.apresentacao.status != StatusApresentacao.agendada ||
        relogio == null) {
      return null;
    }
    final ritmo = formatarRitmo(relogio.ritmoAntesDeMedir);
    final contrato = compararComContrato(
        relogio, relogio.duracaoEstimada(_sequencia.musicasNaSequencia));
    return [
      relogio.temRitmoMedio
          ? 'seu ritmo médio: $ritmo por ${_v.musica}'
          : 'estimativa: $ritmo por ${_v.musica}',
      if (contrato != null) contrato,
    ].join(' · ');
  }

  Widget _construirVazio() => Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EstadoVazio(
                icone: Icons.playlist_play_rounded,
                titulo: _v.setlistVazia,
                descricao: _v.convitePraMontar,
              ),
              FilledButton.icon(
                onPressed: _montar,
                icon: const Icon(Icons.playlist_add_rounded),
                label: Text('Montar ${_v.setlist}'),
              ),
            ],
          ),
        ),
      );
}

/// Aviso compacto do topo da setlist: o chip inteiro é o atalho ("2 sem
/// cifra" leva a colar; "1 pedido novo ›" leva à fila).
class _ChipDeAviso extends StatelessWidget {
  const _ChipDeAviso({
    required this.icone,
    required this.cor,
    required this.texto,
    required this.dica,
    required this.tocar,
    this.seta = false,
  });

  final IconData icone;
  final Color cor;
  final String texto;
  final String dica;
  final VoidCallback tocar;
  final bool seta;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: dica,
        child: Material(
          color: cor.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
          child: InkWell(
            borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
            onTap: tocar,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: EspacoTocaEssa.medio,
                vertical: EspacoTocaEssa.pequeno,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icone, size: 18, color: cor),
                  const SizedBox(width: EspacoTocaEssa.pequeno - 2),
                  Text(texto, style: Theme.of(context).textTheme.labelLarge),
                  if (seta)
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: CoresTocaEssa.textoSecundario),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Linha da setlist em edição: só a que falta tocar tem alça e remover.
class _LinhaEmEdicao extends StatelessWidget {
  const _LinhaEmEdicao({
    required this.item,
    required this.vocabulario,
    required this.remover,
    required this.alca,
  });

  final ItemDoSetlist item;
  final Vocabulario vocabulario;
  final VoidCallback remover;
  final ConstrutorDaAlca alca;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final detalhes = [
      if (item.artista != null) item.artista!,
      if (item.tom != null) 'Tom ${item.tom}',
    ].join(' · ');
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CoresTocaEssa.borda)),
      ),
      padding: const EdgeInsets.only(left: EspacoTocaEssa.pequeno),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: EspacoTocaEssa.medio),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.titulo,
                    style: texto.titleMedium?.copyWith(
                      color: item.tocada
                          ? CoresTocaEssa.textoSecundario
                          : CoresTocaEssa.texto,
                    ),
                  ),
                  if (detalhes.isNotEmpty)
                    Text(detalhes,
                        style: texto.bodySmall
                            ?.copyWith(color: CoresTocaEssa.textoSecundario)),
                ],
              ),
            ),
          ),
          if (item.tocada)
            const Padding(
              padding: EdgeInsets.all(EspacoTocaEssa.medio),
              child: Icon(Icons.check_rounded, color: CoresTocaEssa.sucesso),
            )
          else ...[
            IconButton(
              tooltip: 'Remover da ${vocabulario.setlist}',
              icon: const Icon(Icons.remove_circle_outline_rounded,
                  color: CoresTocaEssa.textoSecundario, size: 20),
              onPressed: remover,
            ),
            alca(
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: EspacoTocaEssa.pequeno,
                  vertical: EspacoTocaEssa.medio,
                ),
                child: Icon(Icons.drag_handle_rounded,
                    color: CoresTocaEssa.textoSecundario),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Uma música do setlist, no jeito do iPhone: tocar na música abre a cifra;
/// o círculo marca como tocada; deslizar para a esquerda mostra Cifra e
/// Remover (música já tocada não sai).
class _LinhaSetlist extends StatelessWidget {
  const _LinhaSetlist({
    required this.item,
    this.posicao,
    this.foraDoRepertorio = false,
    required this.vocabulario,
    required this.salvando,
    required this.eProxima,
    required this.semCifra,
    required this.pedidosNaFila,
    required this.marcar,
    required this.abrirLeitor,
    required this.acoesDaCifra,
    required this.remover,
  });

  final ItemDoSetlist item;
  // "Nº 12" quando a linha aparece pela busca.
  final int? posicao;
  // Não está em nenhum repertório do artista.
  final bool foraDoRepertorio;
  final Vocabulario vocabulario;
  final bool salvando;
  final bool eProxima;
  // Cifra já consultada e sem cifra colada no app.
  final bool semCifra;
  final int pedidosNaFila;
  final ValueChanged<bool> marcar;
  final VoidCallback abrirLeitor;
  final VoidCallback acoesDaCifra;
  final VoidCallback remover;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final tocada = item.tocada;
    final detalhes = [
      if (posicao != null) 'Nº $posicao',
      if (item.artista != null) item.artista!,
      if (item.tom != null) 'Tom ${item.tom}',
    ].join(' · ');
    return Slidable(
      key: ValueKey(item.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: tocada ? .25 : .5,
        children: [
          SlidableAction(
            onPressed: (_) => acoesDaCifra(),
            backgroundColor: CoresTocaEssa.roxo,
            foregroundColor: CoresTocaEssa.texto,
            icon: Icons.menu_book_rounded,
            label: vocabulario.cifraMaiuscula,
          ),
          if (!tocada)
            SlidableAction(
              onPressed: (_) => remover(),
              backgroundColor: CoresTocaEssa.rosa,
              foregroundColor: CoresTocaEssa.texto,
              icon: Icons.remove_circle_outline_rounded,
              label: 'Remover',
            ),
        ],
      ),
      child: Material(
        // A próxima se destaca só pelo rótulo, sem fundo colorido.
        color: Colors.transparent,
        child: InkWell(
          onTap: abrirLeitor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              EspacoTocaEssa.pequeno,
              EspacoTocaEssa.medio,
              EspacoTocaEssa.base,
              EspacoTocaEssa.medio,
            ),
            child: Row(
              children: [
                _CirculoDeTocada(
                  tocada: tocada,
                  marcar: salvando ? null : () => marcar(!tocada),
                ),
                const SizedBox(width: EspacoTocaEssa.pequeno),
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
                        style: texto.titleMedium?.copyWith(
                          color: tocada ? CoresTocaEssa.textoSecundario : null,
                          decoration:
                              tocada ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (detalhes.isNotEmpty)
                        Text(
                          detalhes,
                          style: texto.bodySmall
                              ?.copyWith(color: CoresTocaEssa.textoSecundario),
                        ),
                    ],
                  ),
                ),
                if (pedidosNaFila > 0) ...[
                  Tooltip(
                    message: pedidosNaFila == 1
                        ? '1 pedido na fila'
                        : '$pedidosNaFila pedidos na fila',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: EspacoTocaEssa.pequeno, vertical: 2),
                      decoration: BoxDecoration(
                        color: CoresTocaEssa.superficieElevada,
                        borderRadius:
                            BorderRadius.circular(RaioTocaEssa.pilula),
                      ),
                      child: Text('$pedidosNaFila',
                          style: texto.labelMedium
                              ?.copyWith(color: CoresTocaEssa.textoSecundario)),
                    ),
                  ),
                  const SizedBox(width: EspacoTocaEssa.pequeno),
                ],
                if (foraDoRepertorio) ...[
                  const Tooltip(
                    message: 'Fora do repertório',
                    child: Icon(Icons.library_add_outlined,
                        size: 16, color: CoresTocaEssa.textoSecundario),
                  ),
                  const SizedBox(width: EspacoTocaEssa.pequeno),
                ],
                Tooltip(
                  message: semCifra
                      ? 'Sem ${vocabulario.cifra} no app'
                      : '${vocabulario.cifraMaiuscula} no app',
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: semCifra ? null : CoresTocaEssa.sucesso,
                      border: Border.all(
                        color: semCifra
                            ? CoresTocaEssa.atencao
                            : CoresTocaEssa.sucesso,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: EspacoTocaEssa.pequeno),
                const Icon(Icons.chevron_right_rounded,
                    color: CoresTocaEssa.textoSecundario),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Busca sem nenhuma música achada, com o atalho para limpar.
class _SemResultado extends StatelessWidget {
  const _SemResultado({required this.texto, required this.limpar});

  final String texto;
  final VoidCallback limpar;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: EspacoTocaEssa.medio),
        child: Column(
          children: [
            Text(texto,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: CoresTocaEssa.textoSecundario)),
            TextButton(onPressed: limpar, child: const Text('Limpar busca')),
          ],
        ),
      );
}

/// Círculo de marcar como tocada, alvo separado de abrir a cifra.
class _CirculoDeTocada extends StatelessWidget {
  const _CirculoDeTocada({required this.tocada, required this.marcar});

  final bool tocada;
  final VoidCallback? marcar;

  @override
  // Nó próprio de acessibilidade: a linha inteira abre a cifra.
  Widget build(BuildContext context) => Semantics(
        container: true,
        checked: tocada,
        button: true,
        child: Tooltip(
          message: tocada ? 'Desmarcar' : 'Marcar como tocada',
          child: InkResponse(
            onTap: marcar,
            radius: 22,
            child: Padding(
              padding: const EdgeInsets.all(EspacoTocaEssa.pequeno),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 26,
                height: 26,
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
                        size: 16, color: CoresTocaEssa.texto)
                    : null,
              ),
            ),
          ),
        ),
      );
}
