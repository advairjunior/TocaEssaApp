part of 'leitor_de_cifras.dart';

class _SemCifra extends StatelessWidget {
  const _SemCifra({
    required this.vocabulario,
    required this.link,
    required this.colar,
    required this.abrirNoSite,
  });

  final Vocabulario vocabulario;
  final String? link;
  // Nulo no celular do músico convidado: a cifra é do dono.
  final VoidCallback? colar;
  final ValueChanged<String> abrirNoSite;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(EspacoTocaEssa.grande),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_note_rounded,
                  size: 48, color: CoresTocaEssa.textoSecundario),
              const SizedBox(height: EspacoTocaEssa.medio),
              Text('Sem ${vocabulario.cifra} no app',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: EspacoTocaEssa.base),
              if (colar != null)
                FilledButton.icon(
                  onPressed: colar,
                  icon: const Icon(Icons.content_paste_rounded),
                  label: Text('Colar ${vocabulario.cifra}'),
                ),
              if (link case final endereco?) ...[
                const SizedBox(height: EspacoTocaEssa.pequeno),
                OutlinedButton.icon(
                  onPressed: () => abrirNoSite(endereco),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir no site'),
                ),
              ],
            ],
          ),
        ),
      );
}

/// Sempre visível: setas que só trocam a cifra e Tocar no meio. Fora do
/// show (sem [tocar]), o meio diz em que música da lista se está.
class _BarraDoLeitor extends StatelessWidget {
  const _BarraDoLeitor({
    required this.vocabulario,
    required this.temAnterior,
    required this.temProxima,
    required this.tocando,
    required this.salvando,
    required this.depois,
    required this.anterior,
    required this.proxima,
    required this.tocar,
    required this.posicao,
  });

  final Vocabulario vocabulario;
  final bool temAnterior;
  final bool temProxima;
  final bool tocando;
  final bool salvando;
  final String? depois;
  final VoidCallback anterior;
  final VoidCallback proxima;
  final VoidCallback? tocar;
  // "3 de 25"
  final String posicao;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            EspacoTocaEssa.pequeno,
            EspacoTocaEssa.pequeno,
            EspacoTocaEssa.pequeno,
            EspacoTocaEssa.pequeno,
          ),
          decoration: const BoxDecoration(
            color: CoresTocaEssa.superficie,
            border: Border(top: BorderSide(color: CoresTocaEssa.borda)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: vocabulario.anterior,
                    iconSize: 32,
                    onPressed: temAnterior ? anterior : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  const SizedBox(width: EspacoTocaEssa.pequeno),
                  Expanded(
                    child: tocar == null
                        ? Text(posicao,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium)
                        : FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 52),
                              backgroundColor:
                                  tocando ? CoresTocaEssa.sucesso : null,
                              disabledBackgroundColor: tocando
                                  ? CoresTocaEssa.sucesso.withValues(alpha: .25)
                                  : null,
                            ),
                            onPressed: tocando || salvando ? null : tocar,
                            child: Text(tocando ? 'Tocando ✓' : 'Tocar'),
                          ),
                  ),
                  const SizedBox(width: EspacoTocaEssa.pequeno),
                  IconButton.filledTonal(
                    tooltip: vocabulario.proxima,
                    iconSize: 32,
                    onPressed: temProxima ? proxima : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: EspacoTocaEssa.mini),
              Text(
                depois == null
                    ? tocar == null
                        ? 'Fim da lista'
                        : 'Fim da ${vocabulario.setlist}'
                    : 'Depois: $depois',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: CoresTocaEssa.textoSecundario),
              ),
            ],
          ),
        ),
      );
}
