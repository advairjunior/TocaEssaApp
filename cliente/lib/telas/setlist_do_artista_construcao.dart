part of 'setlist_do_artista.dart';

extension _ConstrucaoDaSetlist on _SetlistDoArtistaState {
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
              aoMudar: (_) => _mudarEstado(() {}),
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
              onPressed: () => _mudarEstado(() {
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
