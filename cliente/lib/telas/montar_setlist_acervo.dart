part of 'montar_setlist.dart';

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
