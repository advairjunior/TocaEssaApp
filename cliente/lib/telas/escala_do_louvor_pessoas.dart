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
            _ChipDaPessoa(
              cor: corDoCantor(louvor.cantores, nome),
              // "1 pt" já diz o que é o número.
              texto: '$nome · ${_pontos(pontos[nome] ?? 0)}',
              fora: configuracao.cantoresFora.contains(nome),
              alternar: _salvando
                  ? null
                  : () => _definirConfiguracao(configuracao.copiarCom(
                      cantoresFora:
                          _alternado(configuracao.cantoresFora, nome))),
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
            _ChipDaPessoa(
              cor: corDaPessoa(louvor.participantes, solista.nome),
              texto: [
                solista.nome,
                if (solista.instrumento.isNotEmpty) solista.instrumento,
                _solos(solos[solista.nome] ?? 0),
              ].join(' · '),
              fora: configuracao.solistasFora.contains(solista.nome),
              alternar: _salvando
                  ? null
                  : () => _definirConfiguracao(configuracao.copiarCom(
                      solistasFora:
                          _alternado(configuracao.solistasFora, solista.nome))),
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
                  : (_) => _definirConfiguracao(configuracao.copiarCom(
                      maximoDeCantoresPorHino: () => maximo)),
            ),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Todos cantam os coros'),
        value: configuracao.corosComTodos,
        onChanged: _salvando
            ? null
            : (valor) => _definirConfiguracao(
                configuracao.copiarCom(corosComTodos: valor)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Coral canta nos refrões'),
        subtitle: const Text('Quem não está no microfone canta junto.'),
        value: configuracao.coralNosRefroes,
        onChanged: _salvando
            ? null
            : (valor) => _definirConfiguracao(
                configuracao.copiarCom(coralNosRefroes: valor)),
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

/// Lista com [nome] tirado, se estava, ou posto, se não estava.
List<String> _alternado(List<String> nomes, String nome) => nomes.contains(nome)
    ? [
        for (final outro in nomes)
          if (outro != nome) outro
      ]
    : [...nomes, nome];

/// Nome na aba Pessoas: tocar tira ou põe a pessoa no automático; quem está
/// fora fica apagado, com "fora" depois dos pontos: escalada à mão, ainda
/// conta o que canta. O × de tirar da lista só aparece no Editar.
class _ChipDaPessoa extends StatelessWidget {
  const _ChipDaPessoa({
    required this.cor,
    required this.texto,
    required this.fora,
    required this.alternar,
    required this.deleteButtonTooltipMessage,
    required this.onDeleted,
  });

  final Color cor;
  final String texto;
  final bool fora;
  final VoidCallback? alternar;
  final String deleteButtonTooltipMessage;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) => InputChip(
        avatar: Opacity(opacity: fora ? .35 : 1, child: _Bolinha(cor)),
        label: Text(fora ? '$texto · fora' : texto),
        labelStyle:
            fora ? const TextStyle(color: CoresTocaEssa.textoSecundario) : null,
        tooltip: fora ? 'Voltar ao automático' : 'Tirar do automático',
        // Sem onPressed o chip ficaria cinza, com cara de desativado.
        onPressed: alternar ?? () {},
        deleteButtonTooltipMessage: deleteButtonTooltipMessage,
        onDeleted: onDeleted,
      );
}
