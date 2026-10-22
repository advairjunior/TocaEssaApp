part of 'leitor_de_cifras.dart';

extension _AcoesDoLeitor on _LeitorDeCifrasState {
  Future<void> _escolherQuemSou() async {
    final cantores = _louvor?.participantes ?? const <String>[];
    final nome = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (contexto) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              EspacoTocaEssa.base, 0, EspacoTocaEssa.base, EspacoTocaEssa.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Quem é você?',
                  style: Theme.of(contexto).textTheme.titleMedium),
              const SizedBox(height: EspacoTocaEssa.medio),
              Wrap(
                spacing: EspacoTocaEssa.pequeno,
                runSpacing: EspacoTocaEssa.pequeno,
                children: [
                  for (final cantor in cantores)
                    ChoiceChip(
                      showCheckmark: false,
                      // A cor da faixa da pessoa, como no roteiro.
                      avatar: Center(
                        widthFactor: 1,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: corDaPessoa(
                                _louvor?.participantes ?? const [], cantor),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      label: Text(cantor),
                      selected: cantor == _quemSou,
                      onSelected: (_) => Navigator.of(contexto).pop(cantor),
                    ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.of(contexto).pop(''),
                child: const Text('Só tocar'),
              ),
            ],
          ),
        ),
      ),
    );
    if (nome == null) return;
    try {
      await _preferencias?.setString(_chaveQuemSou, nome);
    } catch (_) {
      // A escolha só não fica guardada para a próxima vez.
    }
    if (mounted) _mudarEstado(() {});
  }

  KeyEventResult _teclado(FocusNode _, KeyEvent evento) {
    if (evento is! KeyDownEvent) return KeyEventResult.ignored;
    final tecla = evento.logicalKey;
    if (tecla == LogicalKeyboardKey.arrowRight ||
        tecla == LogicalKeyboardKey.pageDown) {
      _irPara(1);
      return KeyEventResult.handled;
    }
    if (tecla == LogicalKeyboardKey.arrowLeft ||
        tecla == LogicalKeyboardKey.pageUp) {
      _irPara(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _tocar() async {
    try {
      await _sequencia.comecar(_pagina);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _editarCifra(String? textoAtual) async {
    final texto = await pedirCifraEmTexto(context,
        titulo: _pagina.titulo,
        texto: textoAtual,
        oQue: _sequencia.vocabulario.cifraMaiuscula);
    if (texto == null || !mounted) return;
    try {
      await _sequencia.salvarCifraEmTexto(_pagina, texto);
      // A letra nova muda as partes do hino.
      if (_noLouvor) await _carregarLouvor();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _abrirNoSite(String url) async {
    try {
      await widget.abrirUrl(Uri.parse(url));
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }
}
