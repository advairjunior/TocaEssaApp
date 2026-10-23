part of 'escala_do_louvor.dart';

/// Resposta da escolha de uma parte: [cantores] nulo volta à escala.
class _Escolha {
  const _Escolha(this.cantores);
  final List<String>? cantores;
}

class _EscolhaDaParte extends StatefulWidget {
  const _EscolhaDaParte({
    required this.titulo,
    required this.cantores,
    required this.atuais,
    required this.contagem,
    required this.solo,
    this.coral = false,
    this.mudarCoral,
  });

  final String titulo;
  final List<String> cantores;
  final List<String> atuais;
  // "3 pts" ou "1 solo" por nome.
  final Map<String, String> contagem;
  final bool solo;
  final bool coral;
  // Grava na hora, sem mexer em quem canta; nulo no solo.
  final ValueChanged<bool>? mudarCoral;

  @override
  State<_EscolhaDaParte> createState() => _EscolhaDaParteState();
}

class _EscolhaDaParteState extends State<_EscolhaDaParte> {
  late final _selecionados = {...widget.atuais};
  late var _coral = widget.coral;

  void _responder(List<String>? cantores) =>
      Navigator.of(context).pop(_Escolha(cantores));

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              EspacoTocaEssa.base, 0, EspacoTocaEssa.base, EspacoTocaEssa.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.titulo,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: EspacoTocaEssa.medio),
              Wrap(
                spacing: EspacoTocaEssa.pequeno,
                runSpacing: EspacoTocaEssa.pequeno,
                children: [
                  for (final nome in widget.cantores)
                    FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(nome),
                          if (widget.contagem[nome] case final conta?) ...[
                            const SizedBox(width: EspacoTocaEssa.pequeno),
                            Text(conta,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color: CoresTocaEssa.textoSecundario)),
                          ],
                        ],
                      ),
                      selected: _selecionados.contains(nome),
                      onSelected: (marcado) => setState(() => marcado
                          ? _selecionados.add(nome)
                          : _selecionados.remove(nome)),
                    ),
                ],
              ),
              if (widget.mudarCoral case final mudarCoral?)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Coral canta junto'),
                  value: _coral,
                  onChanged: (valor) {
                    setState(() => _coral = valor);
                    mudarCoral(valor);
                  },
                ),
              const SizedBox(height: EspacoTocaEssa.grande),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _responder(const []),
                      child: Text(widget.solo ? 'Banda toda' : 'Todos cantam'),
                    ),
                  ),
                  const SizedBox(width: EspacoTocaEssa.pequeno),
                  Expanded(
                    child: FilledButton(
                      onPressed: _selecionados.isEmpty
                          ? null
                          : () => _responder([
                                for (final nome in widget.cantores)
                                  if (_selecionados.contains(nome)) nome,
                              ]),
                      child: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: EspacoTocaEssa.pequeno),
              TextButton(
                onPressed: () => _responder(null),
                child: const Text('Deixar sem escala'),
              ),
            ],
          ),
        ),
      );
}

/// Confirmação do "Escalar todos os hinos": todos os hinos com letra vêm
/// marcados; responde os ids marcados, na ordem da lista.
class _HinosAEscalar extends StatefulWidget {
  const _HinosAEscalar({required this.hinos});

  final List<HinoDoLouvor> hinos;

  @override
  State<_HinosAEscalar> createState() => _HinosAEscalarState();
}

class _HinosAEscalarState extends State<_HinosAEscalar> {
  late final _marcados = {for (final hino in widget.hinos) hino.itemId};

  @override
  Widget build(BuildContext context) {
    final todos = _marcados.length == widget.hinos.length;
    return AlertDialog(
      title: const Text('Escalar quais hinos?'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Os marcados são refeitos na ordem da lista, inclusive o que '
              'foi trocado à mão. Os outros ficam como estão.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: CoresTocaEssa.textoSecundario),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Todos'),
              value: todos,
              onChanged: (_) => setState(() {
                if (todos) {
                  _marcados.clear();
                } else {
                  _marcados.addAll(widget.hinos.map((hino) => hino.itemId));
                }
              }),
            ),
            const Divider(height: 1),
            for (final hino in widget.hinos)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(hino.titulo),
                value: _marcados.contains(hino.itemId),
                onChanged: (marcado) => setState(() => marcado == true
                    ? _marcados.add(hino.itemId)
                    : _marcados.remove(hino.itemId)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _marcados.isEmpty
              ? null
              : () => Navigator.of(context).pop([
                    for (final hino in widget.hinos)
                      if (_marcados.contains(hino.itemId)) hino.itemId,
                  ]),
          child: Text('Escalar (${_marcados.length})'),
        ),
      ],
    );
  }
}

class _NovoCantor extends StatefulWidget {
  const _NovoCantor();

  @override
  State<_NovoCantor> createState() => _NovoCantorState();
}

class _NovoCantorState extends State<_NovoCantor> {
  final _nome = TextEditingController();

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  void _confirmar() => Navigator.of(context).pop(_nome.text);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Quem vai cantar?'),
        content: TextField(
          controller: _nome,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nome'),
          onSubmitted: (_) => _confirmar(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(onPressed: _confirmar, child: const Text('Adicionar')),
        ],
      );
}

class _NovoSolista extends StatefulWidget {
  const _NovoSolista();

  @override
  State<_NovoSolista> createState() => _NovoSolistaState();
}

class _NovoSolistaState extends State<_NovoSolista> {
  final _nome = TextEditingController();
  final _instrumento = TextEditingController();

  @override
  void dispose() {
    _nome.dispose();
    _instrumento.dispose();
    super.dispose();
  }

  void _confirmar() => Navigator.of(context).pop(
      Solista(nome: _nome.text.trim(), instrumento: _instrumento.text.trim()));

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Quem toca os solos?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nome,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: _instrumento,
              decoration: const InputDecoration(
                  labelText: 'Instrumento', hintText: 'sax tenor'),
              onSubmitted: (_) => _confirmar(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(onPressed: _confirmar, child: const Text('Adicionar')),
        ],
      );
}
