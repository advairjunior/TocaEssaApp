part of 'noite_de_karaoke_dono.dart';

enum _Correcao { passar, tirar, devolver }

class _ModoDaNoite extends StatelessWidget {
  const _ModoDaNoite({required this.modo, required this.mudar});

  final ModoDasMusicas modo;
  final ValueChanged<ModoDasMusicas>? mudar;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<ModoDasMusicas>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ModoDasMusicas.livre,
                icon: Icon(Icons.queue_music_rounded),
                label: Text('Livre'),
              ),
              ButtonSegment(
                value: ModoDasMusicas.roleta,
                icon: Icon(Icons.casino_outlined),
                label: Text('Roleta'),
              ),
            ],
            selected: {modo},
            onSelectionChanged: mudar == null
                ? null
                : (escolhido) {
                    if (escolhido.first != modo) mudar!(escolhido.first);
                  },
          ),
          const SizedBox(height: EspacoTocaEssa.pequeno),
          Text(
            modo.descricao,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
        ],
      );
}

/// De onde a galera escolhe (ou a roleta sorteia) a música.
class _LinhaDaPlaylist extends StatelessWidget {
  const _LinhaDaPlaylist({required this.repertorio, required this.escolher});

  final Repertorio? repertorio;
  final VoidCallback? escolher;

  @override
  Widget build(BuildContext context) {
    final escolhido = repertorio;
    return GrupoDeLinhas(linhas: [
      ListTile(
        leading: const Icon(Icons.smart_display_outlined,
            color: CoresTocaEssa.roxoClaro),
        title: Text(escolhido == null
            ? 'Escolher a playlist'
            : '${escolhido.nome} · ${_quantasMusicas(escolhido)}'),
        subtitle: const Text('Playlist da noite'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: escolher,
      ),
    ]);
  }
}

class _LinhaDaPessoa extends StatelessWidget {
  const _LinhaDaPessoa({
    super.key,
    required this.pessoa,
    required this.posicao,
    required this.corrigir,
  });

  final PessoaDoKaraoke pessoa;
  final int? posicao;
  final ValueChanged<_Correcao>? corrigir;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: SizedBox(
          width: 28,
          child: Center(
            child: posicao == null
                ? const Icon(Icons.person_outline_rounded,
                    color: CoresTocaEssa.textoSecundario)
                : Text('$posicaoº',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: CoresTocaEssa.roxoClaro)),
          ),
        ),
        title: Text(pessoa.nome),
        trailing: PopupMenuButton<_Correcao>(
          tooltip: 'Opções de ${pessoa.nome}',
          enabled: corrigir != null,
          onSelected: corrigir,
          itemBuilder: (_) => const [
            PopupMenuItem(value: _Correcao.passar, child: Text('Passar a vez')),
            PopupMenuItem(
                value: _Correcao.tirar, child: Text('Tirar da ordem')),
          ],
        ),
      );
}

class _LinhaForaDaOrdem extends StatelessWidget {
  const _LinhaForaDaOrdem({required this.pessoa, required this.devolver});

  final PessoaDoKaraoke pessoa;
  final VoidCallback? devolver;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.person_off_outlined,
            color: CoresTocaEssa.textoSecundario),
        title: Text(pessoa.nome),
        trailing:
            TextButton(onPressed: devolver, child: const Text('Devolver')),
      );
}
