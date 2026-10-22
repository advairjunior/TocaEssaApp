part of 'escala_do_louvor.dart';

extension _ConstrucaoDaEscala on _EscalaDoLouvorState {
  List<Widget> _construirHinos(LouvorDoArtista louvor) {
    final texto = Theme.of(context).textTheme;
    final filtro = _filtro;
    // O hino de agora é o último tocado, como no roteiro.
    final agora = louvor.hinos.where((hino) => hino.tocado).lastOrNull?.itemId;
    if (louvor.hinos.isEmpty) {
      return const [
        EstadoVazio(
          icone: Icons.library_music_outlined,
          titulo: 'Nenhum hino ainda',
          descricao: 'Monte a lista de hinos na aba Hinos, embaixo.',
        ),
      ];
    }
    return [
      _ResumoDaEscala(
        louvor: louvor,
        // Só quando há o que escalar: hino sem letra não tem partes.
        temOQueEscalar: louvor.hinos.any((hino) => hino.partes.isNotEmpty),
        escalarTodos: _salvando ? null : _escalarTodos,
        temEscala: louvor.hinos
            .any((hino) => hino.partes.any((parte) => parte.definida)),
        limparEscala: _salvando ? null : _limparEscala,
      ),
      const SizedBox(height: EspacoTocaEssa.medio),
      if (louvor.participantes.isNotEmpty) ...[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                showCheckmark: false,
                label: const Text('Todos'),
                selected: filtro == null,
                onSelected: (_) => _mudarEstado(() => _filtro = null),
              ),
              for (final nome in louvor.participantes) ...[
                const SizedBox(width: EspacoTocaEssa.pequeno),
                ChoiceChip(
                  showCheckmark: false,
                  avatar: _Bolinha(corDaPessoa(louvor.participantes, nome)),
                  label: Text(nome),
                  selected: filtro == nome,
                  onSelected: (_) => _mudarEstado(() => _filtro = nome),
                ),
              ],
            ],
          ),
        ),
        if (filtro != null) ...[
          const SizedBox(height: EspacoTocaEssa.pequeno),
          Text(_EscalaDoLouvorState._resumoDaPessoa(louvor, filtro),
              style: texto.titleSmall?.copyWith(color: CoresTocaEssa.ouro)),
        ],
        const SizedBox(height: EspacoTocaEssa.medio),
      ],
      for (final (indice, hino) in louvor.hinos.indexed) ...[
        _CartaoDoHino(
          ordem: indice + 1,
          hino: hino,
          cantores: louvor.cantores,
          filtro: filtro,
          aberto: _abertos.contains(hino.itemId),
          ehAgora: hino.itemId == agora,
          alternar: () => _mudarEstado(() => _abertos.contains(hino.itemId)
              ? _abertos.remove(hino.itemId)
              : _abertos.add(hino.itemId)),
          escolherParte: _salvando
              ? null
              : (indice, rotulo) => _escolherParte(hino, indice, rotulo),
          colarLetra: _salvando ? null : () => _colarLetra(hino),
          escalar: _salvando
              ? null
              : () => _salvar(
                  () => widget.api.escalarHinoDoLouvor(_id, hino.itemId)),
        ),
        const SizedBox(height: EspacoTocaEssa.medio),
      ],
    ];
  }
}
