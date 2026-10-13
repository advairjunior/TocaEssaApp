import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/abrir_url_externa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_lista.dart';
import 'componentes_palco.dart';
import 'modo_palco.dart';
import 'acoes_do_palco.dart';
import 'colar_cifras.dart';
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
  });

  final ApiTocaEssa api;
  final Apresentacao apresentacao;
  final bool incorporada;
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
  )..addListener(_redesenhar);
  bool _carregando = true;
  bool _editando = false;
  // Só antes do show: horas contratadas e ritmo médio para estimar a setlist.
  RelogioDoShow? _relogio;

  @override
  void initState() {
    super.initState();
    _carregar();
    if (widget.apresentacao.status == StatusApresentacao.agendada) {
      _carregarRelogio();
    }
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
    _sequencia.dispose();
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
            child: const Text('Colar ou corrigir cifra'),
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
        titulo: item.titulo, texto: _sequencia.cifraDe(musica)?.texto);
    if (texto == null || !mounted) return;
    try {
      await _sequencia.salvarCifraEmTexto(musica, texto);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  /// Ao voltar do modo palco, o setlist e os pedidos podem ter mudado.
  Future<void> _abrirModoPalco() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ModoPalco(
        api: widget.api,
        apresentacao: widget.apresentacao,
        abrirUrl: widget.abrirUrl,
        prepararAbertura: widget.prepararAbertura,
      ),
    ));
    if (mounted) await _carregar();
  }

  Future<void> _montar() async {
    final mudou = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => MontarSetlist(
        api: widget.api,
        apresentacaoId: widget.apresentacao.id,
        naSetlist: _sequencia.itens,
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

  Future<void> _limpar() async {
    final confirmou = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Limpar a setlist?'),
            content: const Text(
                'Todas as músicas saem da setlist, inclusive as já tocadas.'),
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
      return const Center(child: CircularProgressIndicator());
    }
    if (_sequencia.itens.isEmpty) {
      return _construirVazio();
    }
    final proxima = _sequencia.proxima;
    return Column(
      children: [
        Expanded(child: _construirLista(context, proxima?.item)),
        if (proxima != null || ultimaComecada != null)
          BarraProximaMusica(
            titulo: proxima?.titulo,
            detalhe: _sequencia.detalheDaProxima,
            salvando: _sequencia.salvando,
            tocar: tocarProxima,
            comecou: ultimaComecada?.titulo,
            desfazer: desfazerUltima,
          ),
      ],
    );
  }

  Widget _construirLista(BuildContext context, ItemDoSetlist? proxima) {
    final pedidosNaFila = _sequencia.pedidosNaFila;
    return ConteudoMobile(
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _abrirModoPalco,
                  icon: const Icon(Icons.mic_rounded),
                  label: const Text('Modo palco'),
                ),
              ),
              const SizedBox(width: EspacoTocaEssa.pequeno),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: abrirLeitorDoShow,
                  icon: const Icon(Icons.auto_stories_rounded),
                  label: const Text('Leitor'),
                ),
              ),
            ],
          ),
          const SizedBox(height: EspacoTocaEssa.base),
          _construirProgresso(context),
          if (_relogio case final relogio?
              when _sequencia.musicasNaSequencia > 0) ...[
            const SizedBox(height: EspacoTocaEssa.base),
            _DuracaoEstimada(
              relogio: relogio,
              musicas: _sequencia.musicasNaSequencia,
            ),
          ],
          if (_sequencia.semCifra.isNotEmpty) ...[
            const SizedBox(height: EspacoTocaEssa.base),
            _AvisoSemCifra(
              quantidade: _sequencia.semCifra.length,
              colar: _colarCifras,
            ),
          ],
          const SizedBox(height: EspacoTocaEssa.base + 4),
          if (_editando)
            ..._construirEdicao()
          else
            SlidableAutoCloseBehavior(
              child: GrupoDeLinhas(
                recuoDivisoria: 60,
                linhas: [
                  for (final item in _sequencia.itens)
                    _LinhaSetlist(
                      item: item,
                      salvando: _sequencia.salvando,
                      eProxima: item.id == proxima?.id,
                      semCifra: _sequencia
                          .estaSemCifra(MusicaDoPalco.doSetlist(item)),
                      pedidosNaFila:
                          pedidosNaFila[item.titulo.toLowerCase().trim()] ?? 0,
                      marcar: (tocada) => _marcar(item, tocada),
                      abrirLeitor: () =>
                          abrirLeitor(MusicaDoPalco.doSetlist(item)),
                      acoesDaCifra: () => _acoesDaCifra(item),
                      remover: () => _remover(item),
                    ),
                ],
              ),
            ),
          const SizedBox(height: EspacoTocaEssa.base),
        ],
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
          remover: () => _remover(itens[indice]),
          alca: alca,
        ),
      ),
      const SizedBox(height: EspacoTocaEssa.base),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _limpar,
          style: TextButton.styleFrom(foregroundColor: CoresTocaEssa.rosa),
          icon: const Icon(Icons.delete_sweep_outlined),
          label: const Text('Limpar setlist'),
        ),
      ),
    ];
  }

  Widget _construirProgresso(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final total = _sequencia.itens.length;
    final restantes = total - _sequencia.tocadas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_sequencia.tocadas} de $total tocadas',
                      style: texto.titleMedium),
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
              onPressed: _editando ? null : _montar,
              icon: const Icon(Icons.playlist_add_rounded, size: 18),
              label: const Text('Montar'),
            ),
            TextButton(
              onPressed: () => setState(() => _editando = !_editando),
              child: Text(_editando ? 'Concluir' : 'Editar'),
            ),
          ],
        ),
        const SizedBox(height: EspacoTocaEssa.pequeno),
        LinearProgressIndicator(
          value: total > 0 ? _sequencia.tocadas / total : 0,
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
                titulo: 'Setlist vazia',
                descricao: 'Monte a setlist com músicas dos seus repertórios '
                    'ou avulsas.',
              ),
              FilledButton.icon(
                onPressed: _montar,
                icon: const Icon(Icons.playlist_add_rounded),
                label: const Text('Montar setlist'),
              ),
            ],
          ),
        ),
      );
}

/// Avisa, antes do show, quantas músicas que faltam tocar estão sem cifra,
/// para o artista não precisar escolher cifra no meio da apresentação.
class _AvisoSemCifra extends StatelessWidget {
  const _AvisoSemCifra({required this.quantidade, required this.colar});

  final int quantidade;
  final VoidCallback colar;

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
          TextButton(onPressed: colar, child: const Text('Colar')),
        ],
      ),
    );
  }
}

/// Antes do show: quanto a sequência deve durar no ritmo médio do artista
/// (ou 3 min por música sem histórico) e como fica perto do contratado.
class _DuracaoEstimada extends StatelessWidget {
  const _DuracaoEstimada({required this.relogio, required this.musicas});

  final RelogioDoShow relogio;
  final int musicas;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final estimada = relogio.duracaoEstimada(musicas);
    final ritmo = formatarRitmo(relogio.ritmoAntesDeMedir);
    final contrato = compararComContrato(relogio, estimada);
    final secundario =
        texto.bodySmall?.copyWith(color: CoresTocaEssa.textoSecundario);
    return Container(
      padding: const EdgeInsets.all(EspacoTocaEssa.medio),
      decoration: BoxDecoration(
        color: CoresTocaEssa.superficie,
        borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
        border: Border.all(color: CoresTocaEssa.borda),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: CoresTocaEssa.roxoClaro),
          const SizedBox(width: EspacoTocaEssa.medio),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${musicas == 1 ? '1 música' : '$musicas músicas'} ≈ '
                  '${formatarTempoDoShow(estimada)}',
                  style: texto.titleSmall,
                ),
                Text(
                  relogio.temRitmoMedio
                      ? 'seu ritmo médio: $ritmo por música'
                      : 'estimativa: $ritmo por música',
                  style: secundario,
                ),
                if (contrato != null) Text(contrato, style: secundario),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha da setlist em edição: só a que falta tocar tem alça e remover.
class _LinhaEmEdicao extends StatelessWidget {
  const _LinhaEmEdicao({
    required this.item,
    required this.remover,
    required this.alca,
  });

  final ItemDoSetlist item;
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
              tooltip: 'Remover da setlist',
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
            label: 'Cifra',
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
        color: eProxima
            ? CoresTocaEssa.roxo.withValues(alpha: .12)
            : Colors.transparent,
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
                        color: CoresTocaEssa.roxo.withValues(alpha: .25),
                        borderRadius:
                            BorderRadius.circular(RaioTocaEssa.pilula),
                      ),
                      child: Text('$pedidosNaFila',
                          style: texto.labelMedium
                              ?.copyWith(color: CoresTocaEssa.roxoClaro)),
                    ),
                  ),
                  const SizedBox(width: EspacoTocaEssa.pequeno),
                ],
                Tooltip(
                  message: semCifra ? 'Sem cifra no app' : 'Cifra no app',
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
