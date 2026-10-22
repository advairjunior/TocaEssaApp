import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_lista.dart';
import 'componentes_movimento.dart';

/// Monta a setlist do show escolhendo músicas do acervo: navega pelos
/// repertórios, marca músicas (ou todas de um repertório), busca em tudo e
/// adiciona no fim da setlist. Também recebe música avulsa.
/// Fecha devolvendo `true` quando a setlist mudou.
class MontarSetlist extends StatefulWidget {
  const MontarSetlist({
    super.key,
    required this.api,
    required this.apresentacaoId,
    required this.naSetlist,
    this.vocabulario = Vocabulario.musical,
  });

  final ApiTocaEssa api;
  final String apresentacaoId;
  final List<ItemDoSetlist> naSetlist;
  final Vocabulario vocabulario;

  @override
  State<MontarSetlist> createState() => _MontarSetlistState();
}

class _MontarSetlistState extends State<MontarSetlist> {
  Vocabulario get _v => widget.vocabulario;
  final _busca = TextEditingController();
  List<Repertorio>? _repertorios;
  String? _repertorioId;
  RelogioDoShow? _relogio;
  late List<ItemDoSetlist> _naSetlist = [...widget.naSetlist];
  // Em ordem de escolha, que é a ordem em que entram na setlist.
  final _selecionadas = <MusicaDoRepertorio>[];
  bool _salvando = false;
  bool _mudou = false;

  @override
  void initState() {
    super.initState();
    _busca.addListener(() => setState(() {}));
    _carregar();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final repertorios = await widget.api.listarRepertorios();
      if (!mounted) return;
      setState(() {
        _repertorios = repertorios;
        _repertorioId = repertorios.firstOrNull?.id;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _repertorios = const []);
      mostrarErro(context, erro);
    }
    try {
      final relogio = await widget.api.obterRelogio(widget.apresentacaoId);
      if (mounted) setState(() => _relogio = relogio);
    } catch (_) {
      // Sem relógio, o rodapé mostra só a quantidade.
    }
  }

  bool _estaNaSetlist(MusicaDoRepertorio musica) => _naSetlist.any((item) =>
      mesmaMusica(item.titulo, item.artista, musica.titulo, musica.artista));

  bool _selecionada(MusicaDoRepertorio musica) =>
      _selecionadas.any((escolhida) => escolhida.id == musica.id);

  // Pelo id: o acervo é recarregado depois de salvar uma avulsa.
  void _alternar(MusicaDoRepertorio musica) => setState(() {
        if (_selecionada(musica)) {
          _selecionadas.removeWhere((escolhida) => escolhida.id == musica.id);
        } else {
          _selecionadas.add(musica);
        }
      });

  /// Músicas na tela: da busca em todo o acervo ou do repertório escolhido.
  List<(MusicaDoRepertorio, String?)> _visiveis() {
    final repertorios = _repertorios ?? const <Repertorio>[];
    final termo = normalizarMusica(_busca.text);
    if (termo.isNotEmpty) {
      return [
        for (final repertorio in repertorios)
          for (final musica in repertorio.musicas)
            if (combinaComBusca(termo, [musica.titulo, musica.artista]))
              (musica, repertorio.nome),
      ];
    }
    final atual = repertorios.where((r) => r.id == _repertorioId).firstOrNull;
    return [for (final musica in atual?.musicas ?? const []) (musica, null)];
  }

  void _selecionarTodas(List<MusicaDoRepertorio> musicas) => setState(() {
        final livres =
            musicas.where((musica) => !_estaNaSetlist(musica)).toList();
        if (livres.every(_selecionada)) {
          final ids = {for (final musica in livres) musica.id};
          _selecionadas.removeWhere((escolhida) => ids.contains(escolhida.id));
        } else {
          _selecionadas.addAll(livres.where((musica) => !_selecionada(musica)));
        }
      });

  Future<void> _adicionar() async {
    setState(() => _salvando = true);
    try {
      await widget.api.adicionarMusicasAoSetlist(
          widget.apresentacaoId, [for (final m in _selecionadas) m.id]);
      if (mounted) Navigator.pop(context, true);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _adicionarAvulsa() async {
    final avulsa = await showDialog<_MusicaAvulsa>(
      context: context,
      builder: (_) => _DialogoMusicaAvulsa(
          vocabulario: _v, repertorios: _repertorios ?? const <Repertorio>[]),
    );
    if (avulsa == null || !mounted) return;
    try {
      final setlist = await widget.api.adicionarMusicaAvulsa(
        widget.apresentacaoId,
        titulo: avulsa.titulo,
        artista: avulsa.artista,
        tom: avulsa.tom,
        repertorioId: avulsa.repertorioId,
      );
      if (!mounted) return;
      setState(() {
        _naSetlist = setlist;
        _mudou = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${avulsa.titulo} entrou na ${_v.setlist}.')));
      // Salva no acervo: a música nova aparece no repertório escolhido.
      if (avulsa.repertorioId != null) await _carregarRepertorios();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _carregarRepertorios() async {
    try {
      final repertorios = await widget.api.listarRepertorios();
      if (mounted) setState(() => _repertorios = repertorios);
    } catch (_) {
      // A lista antiga continua valendo.
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (saiu, _) {
          if (!saiu) Navigator.pop(context, _mudou);
        },
        child: Scaffold(
          appBar: AppBar(title: Text('Montar ${_v.setlist}')),
          body: _repertorios == null
              ? const EsqueletoDeLista()
              : _construirCorpo(context),
          bottomNavigationBar: _construirRodape(context),
        ),
      );

  Widget _construirCorpo(BuildContext context) {
    final repertorios = _repertorios!;
    final visiveis = _visiveis();
    final buscando = _busca.text.trim().isNotEmpty;
    return ConteudoMobile(
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CampoDeBusca(controlador: _busca, dica: 'Buscar no acervo'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _adicionarAvulsa,
              icon: const Icon(Icons.add_rounded),
              label: Text(_v.avulsa),
            ),
          ),
          if (repertorios.isEmpty)
            const EstadoVazio(
              icone: Icons.library_music_outlined,
              titulo: 'Nenhum repertório no acervo',
              descricao: 'Crie repertórios em Repertórios, no menu da sua '
                  'conta, ou adicione músicas avulsas.',
            )
          else ...[
            if (!buscando) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final repertorio in repertorios)
                      Padding(
                        padding: const EdgeInsets.only(
                            right: EspacoTocaEssa.pequeno),
                        child: ChoiceChip(
                          label: Text(repertorio.nome),
                          selected: repertorio.id == _repertorioId,
                          onSelected: (_) =>
                              setState(() => _repertorioId = repertorio.id),
                        ),
                      ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      _selecionarTodas([for (final (m, _) in visiveis) m]),
                  child: Text(visiveis
                              .map((v) => v.$1)
                              .where((m) => !_estaNaSetlist(m))
                              .every(_selecionada) &&
                          visiveis.isNotEmpty
                      ? 'Desmarcar todas'
                      : 'Selecionar todas'),
                ),
              ),
            ],
            for (final (musica, repertorio) in visiveis)
              _LinhaDoAcervo(
                musica: musica,
                repertorio: repertorio,
                naSetlist: _estaNaSetlist(musica),
                setlist: _v.setlist,
                selecionada: _selecionada(musica),
                alternar: () => _alternar(musica),
              ),
            if (visiveis.isEmpty)
              Padding(
                padding: const EdgeInsets.all(EspacoTocaEssa.grande),
                child: Text(
                  buscando
                      ? 'Nenhuma música encontrada no acervo.'
                      : 'Este repertório ainda não tem músicas.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: CoresTocaEssa.textoSecundario),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _construirRodape(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final total = _naSetlist.length + _selecionadas.length;
    // O tempo conta cada música do pout-pourri.
    final musicas = [
      for (final item in _naSetlist) item.titulo,
      for (final musica in _selecionadas) musica.titulo,
    ].fold(0, (soma, titulo) => soma + musicasNoTitulo(titulo));
    final estimada = _relogio?.duracaoEstimada(musicas) ??
        RelogioDoShow.ritmoPadrao * musicas;
    final contrato =
        _relogio == null ? null : compararComContrato(_relogio!, estimada);
    final resumo = '${_selecionadas.isEmpty ? '' : '+${_selecionadas.length} '
            '${_selecionadas.length == 1 ? 'selecionada' : 'selecionadas'} · '}'
        '$total ${total == 1 ? _v.musica : _v.musicas} ≈ '
        '${formatarTempoDoShow(estimada)}';
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          EspacoTocaEssa.base,
          EspacoTocaEssa.medio,
          EspacoTocaEssa.base,
          EspacoTocaEssa.medio,
        ),
        decoration: const BoxDecoration(
          color: CoresTocaEssa.superficie,
          border: Border(top: BorderSide(color: CoresTocaEssa.borda)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(resumo, style: texto.titleSmall),
            if (contrato != null)
              Text(contrato,
                  style: texto.bodySmall
                      ?.copyWith(color: CoresTocaEssa.textoSecundario)),
            const SizedBox(height: EspacoTocaEssa.pequeno),
            FilledButton.icon(
              onPressed: _selecionadas.isEmpty || _salvando ? null : _adicionar,
              icon: const Icon(Icons.playlist_add_rounded),
              label: Text('Adicionar à ${_v.setlist}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaDoAcervo extends StatelessWidget {
  const _LinhaDoAcervo({
    required this.musica,
    required this.repertorio,
    required this.naSetlist,
    required this.setlist,
    required this.selecionada,
    required this.alternar,
  });

  final MusicaDoRepertorio musica;
  // Na busca, de qual repertório a música é.
  final String? repertorio;
  final bool naSetlist;
  // "setlist" ou, no louvor, "lista de hinos".
  final String setlist;
  final bool selecionada;
  final VoidCallback alternar;

  @override
  Widget build(BuildContext context) {
    final detalhes = [
      if (musica.artista != null) musica.artista!,
      if (repertorio != null) repertorio!,
    ].join(' · ');
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: naSetlist || selecionada,
      onChanged: naSetlist ? null : (_) => alternar(),
      title: Text(musica.titulo),
      subtitle: detalhes.isEmpty && !naSetlist
          ? null
          : Text(
              naSetlist ? 'na $setlist' : detalhes,
              style: TextStyle(
                color: naSetlist
                    ? CoresTocaEssa.sucesso
                    : CoresTocaEssa.textoSecundario,
              ),
            ),
    );
  }
}

typedef _MusicaAvulsa = ({
  String titulo,
  String? artista,
  String? tom,
  String? repertorioId,
});

class _DialogoMusicaAvulsa extends StatefulWidget {
  const _DialogoMusicaAvulsa(
      {required this.vocabulario, required this.repertorios});
  final Vocabulario vocabulario;
  final List<Repertorio> repertorios;

  @override
  State<_DialogoMusicaAvulsa> createState() => _DialogoMusicaAvulsaState();
}

class _DialogoMusicaAvulsaState extends State<_DialogoMusicaAvulsa> {
  final _titulo = TextEditingController();
  final _artista = TextEditingController();
  final _tom = TextEditingController();
  String? _repertorioId;

  @override
  void dispose() {
    _titulo.dispose();
    _artista.dispose();
    _tom.dispose();
    super.dispose();
  }

  void _confirmar() {
    final titulo = _titulo.text.trim();
    if (titulo.isEmpty) {
      mostrarErro(context, 'Informe o título da música.');
      return;
    }
    String? opcional(TextEditingController campo) =>
        campo.text.trim().isEmpty ? null : campo.text.trim();
    Navigator.pop<_MusicaAvulsa>(context, (
      titulo: titulo,
      artista: opcional(_artista),
      tom: opcional(_tom),
      repertorioId: _repertorioId,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.vocabulario.avulsa),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titulo,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              TextField(
                controller: _artista,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Cantor ou banda'),
              ),
              TextField(
                controller: _tom,
                decoration: const InputDecoration(labelText: 'Tom'),
              ),
              if (widget.repertorios.isNotEmpty) ...[
                const SizedBox(height: EspacoTocaEssa.base),
                const Text('Salvar também em',
                    style: TextStyle(color: CoresTocaEssa.textoSecundario)),
                const SizedBox(height: EspacoTocaEssa.pequeno),
                Wrap(
                  spacing: EspacoTocaEssa.pequeno,
                  runSpacing: EspacoTocaEssa.pequeno,
                  children: [
                    ChoiceChip(
                      label: Text('Só nesta ${widget.vocabulario.setlist}'),
                      selected: _repertorioId == null,
                      onSelected: (_) => setState(() => _repertorioId = null),
                    ),
                    for (final repertorio in widget.repertorios)
                      ChoiceChip(
                        label: Text(repertorio.nome),
                        selected: _repertorioId == repertorio.id,
                        onSelected: (_) =>
                            setState(() => _repertorioId = repertorio.id),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(onPressed: _confirmar, child: const Text('Adicionar')),
        ],
      );
}
