part of 'escala_do_louvor.dart';

/// Aba Pessoas: cantores, solistas e como escalar.
extension _PessoasDaEscala on _EscalaDoLouvorState {
  List<Widget> _construirPessoas(LouvorDoArtista louvor) {
    final explicacao = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: CoresTocaEssa.textoSecundario);
    final pontos = {
      for (final item in louvor.placar) item.nome: item.pontos,
    };
    final solos = {
      for (final item in louvor.placarDosSolos) item.nome: item.solos,
    };
    final configuracao = louvor.configuracao;
    final temAlguem = louvor.cantores.isNotEmpty || louvor.solistas.isNotEmpty;
    return [
      Row(
        children: [
          const Expanded(child: TituloGrupo('Quem canta no microfone')),
          if (temAlguem)
            TextButton(
              onPressed: _alternarEdicaoDePessoas,
              child: Text(_editandoPessoas ? 'Concluir' : 'Editar'),
            ),
        ],
      ),
      Wrap(
        spacing: EspacoTocaEssa.pequeno,
        runSpacing: EspacoTocaEssa.pequeno,
        children: [
          for (final nome in louvor.cantores)
            Chip(
              avatar: _Bolinha(corDoCantor(louvor.cantores, nome)),
              // "1 pt" já diz o que é o número.
              label: Text('$nome · ${_pontos(pontos[nome] ?? 0)}'),
              deleteButtonTooltipMessage: 'Tirar $nome',
              onDeleted: _editandoPessoas && !_salvando
                  ? () => _definirCantores([
                        for (final outro in louvor.cantores)
                          if (outro != nome) outro,
                      ])
                  : null,
            ),
          ActionChip(
            avatar: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Adicionar'),
            onPressed: _salvando ? null : _adicionarCantor,
          ),
        ],
      ),
      if (louvor.cantores.isEmpty) ...[
        const SizedBox(height: EspacoTocaEssa.pequeno),
        Text('Coloque quem vai cantar no microfone.', style: explicacao),
      ],
      const SizedBox(height: EspacoTocaEssa.grande),
      const TituloGrupo('Quem toca os solos'),
      Wrap(
        spacing: EspacoTocaEssa.pequeno,
        runSpacing: EspacoTocaEssa.pequeno,
        children: [
          for (final solista in louvor.solistas)
            Chip(
              avatar: const _Bolinha(corInstrumental),
              label: Text([
                solista.nome,
                if (solista.instrumento.isNotEmpty) solista.instrumento,
                _solos(solos[solista.nome] ?? 0),
              ].join(' · ')),
              deleteButtonTooltipMessage: 'Tirar ${solista.nome} dos solos',
              onDeleted: _editandoPessoas && !_salvando
                  ? () => _definirSolistas([
                        for (final outro in louvor.solistas)
                          if (outro.nome != solista.nome) outro,
                      ])
                  : null,
            ),
          ActionChip(
            avatar: const Icon(Icons.music_note_rounded, size: 18),
            label: const Text('Adicionar solista'),
            onPressed: _salvando ? null : _adicionarSolista,
          ),
        ],
      ),
      const SizedBox(height: EspacoTocaEssa.grande),
      const TituloGrupo('Como escalar'),
      Text('Cantores por hino', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: EspacoTocaEssa.pequeno),
      Wrap(
        spacing: EspacoTocaEssa.pequeno,
        runSpacing: EspacoTocaEssa.pequeno,
        children: [
          for (final maximo in const [null, 1, 2, 3, 4])
            ChoiceChip(
              label: Text(maximo == null ? 'Sem limite' : '$maximo'),
              selected: configuracao.maximoDeCantoresPorHino == maximo,
              onSelected: _salvando
                  ? null
                  : (_) => _definirConfiguracao(ConfiguracaoDaEscala(
                        maximoDeCantoresPorHino: maximo,
                        corosComTodos: configuracao.corosComTodos,
                      )),
            ),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Todos cantam os coros'),
        value: configuracao.corosComTodos,
        onChanged: _salvando
            ? null
            : (valor) => _definirConfiguracao(ConfiguracaoDaEscala(
                  maximoDeCantoresPorHino: configuracao.maximoDeCantoresPorHino,
                  corosComTodos: valor,
                )),
      ),
      const SizedBox(height: EspacoTocaEssa.grande),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => mostrarComoMarcarAsPartes(context),
          icon: const Icon(Icons.help_outline_rounded),
          label: const Text('Como marcar as partes'),
        ),
      ),
    ];
  }
}

String _pontos(int pontos) => pontos == 1 ? '1 pt' : '$pontos pts';

String _solos(int solos) => solos == 1 ? '1 solo' : '$solos solos';
