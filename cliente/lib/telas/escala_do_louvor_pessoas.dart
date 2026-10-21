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
    return [
      const TituloGrupo('Quem canta no microfone'),
      Wrap(
        spacing: EspacoTocaEssa.pequeno,
        runSpacing: EspacoTocaEssa.pequeno,
        children: [
          for (final nome in louvor.cantores)
            InputChip(
              avatar: _Bolinha(corDoCantor(louvor.cantores, nome)),
              label: Text('$nome · ${pontos[nome] ?? 0}'),
              deleteButtonTooltipMessage: 'Tirar $nome',
              onDeleted: _salvando
                  ? null
                  : () => _definirCantores([
                        for (final outro in louvor.cantores)
                          if (outro != nome) outro,
                      ]),
            ),
          ActionChip(
            avatar: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Adicionar'),
            onPressed: _salvando ? null : _adicionarCantor,
          ),
        ],
      ),
      const SizedBox(height: EspacoTocaEssa.pequeno),
      Text(
        louvor.cantores.isEmpty
            ? 'Coloque quem vai cantar no microfone. Em cada hino, '
                '"Escalar automático" divide as partes entre eles.'
            : 'O número é de pontos: estrofe vale 1 e coro vale 2.',
        style: explicacao,
      ),
      const SizedBox(height: EspacoTocaEssa.grande),
      const TituloGrupo('Quem toca os solos'),
      Wrap(
        spacing: EspacoTocaEssa.pequeno,
        runSpacing: EspacoTocaEssa.pequeno,
        children: [
          for (final solista in louvor.solistas)
            InputChip(
              avatar: const _Bolinha(corInstrumental),
              label: Text([
                solista.nome,
                if (solista.instrumento.isNotEmpty) solista.instrumento,
                '${solos[solista.nome] ?? 0}',
              ].join(' · ')),
              deleteButtonTooltipMessage: 'Tirar ${solista.nome} dos solos',
              onDeleted: _salvando
                  ? null
                  : () => _definirSolistas([
                        for (final outro in louvor.solistas)
                          if (outro.nome != solista.nome) outro,
                      ]),
            ),
          ActionChip(
            avatar: const Icon(Icons.music_note_rounded, size: 18),
            label: const Text('Adicionar solista'),
            onPressed: _salvando ? null : _adicionarSolista,
          ),
        ],
      ),
      const SizedBox(height: EspacoTocaEssa.pequeno),
      Text(
        'O app dá cada "(Solo sax)" para quem toca o instrumento, '
        'revezando quando tem mais de um. O número é de solos.',
        style: explicacao,
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
      Text(
        'Vale para os próximos "Escalar".',
        style: explicacao,
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
