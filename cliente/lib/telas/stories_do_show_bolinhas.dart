part of 'stories_do_show.dart';

/// Círculo de 64 px da fileira, com o rótulo embaixo.
class _BolinhaComRotulo extends StatelessWidget {
  const _BolinhaComRotulo({
    required this.anel,
    required this.miolo,
    required this.rotulo,
    required this.destaque,
    this.aoTocar,
    this.selo,
  });

  /// Gradiente do anel; nulo deixa só uma borda discreta.
  final Gradient? anel;
  final Widget miolo;
  final String rotulo;
  final bool destaque;
  final VoidCallback? aoTocar;
  final Widget? selo;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: anel,
                        border: anel == null
                            ? Border.all(color: CoresTocaEssa.borda, width: 2)
                            : null,
                      ),
                      child: miolo,
                    ),
                    if (selo != null) selo!,
                  ],
                ),
              ),
              const SizedBox(height: EspacoTocaEssa.mini),
              Text(
                rotulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: destaque
                        ? CoresTocaEssa.texto
                        : CoresTocaEssa.textoSecundario),
              ),
            ],
          ),
        ),
      );
}

const _anelNovo =
    LinearGradient(colors: [CoresTocaEssa.roxo, CoresTocaEssa.rosa]);

/// Miolo redondo das bolinhas.
Widget _miolo(Widget filho, {Color cor = CoresTocaEssa.superficieElevada}) =>
    Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cor,
        border: Border.all(color: CoresTocaEssa.fundo, width: 2),
      ),
      alignment: Alignment.center,
      child: filho,
    );

/// Bolinha de uma pessoa: anel roxo enquanto tem story não visto neste
/// aparelho.
class BolinhaDeStory extends StatelessWidget {
  const BolinhaDeStory({
    super.key,
    required this.grupo,
    required this.novo,
    required this.aoTocar,
  });

  final GrupoDeStories grupo;
  final bool novo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => _BolinhaComRotulo(
        anel: novo ? _anelNovo : null,
        destaque: novo,
        rotulo: grupo.nome,
        aoTocar: aoTocar,
        miolo: grupo.doArtista
            ? _miolo(
                const Icon(Icons.mic_rounded,
                    color: CoresTocaEssa.ouro, size: 26),
                cor: CoresTocaEssa.destaqueFundo)
            : _miolo(grupo.chave == '#publico'
                ? const Icon(Icons.person_rounded,
                    color: CoresTocaEssa.textoSecundario)
                : Text(grupo.nome.characters.first.toUpperCase(),
                    style: Theme.of(context).textTheme.titleLarge)),
        selo: grupo.temEscondido
            ? const Positioned(
                right: -2,
                bottom: -2,
                child: Tooltip(
                  message: 'Escondido por denúncias',
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: CoresTocaEssa.perigo,
                    child: Icon(Icons.visibility_off_rounded,
                        size: 13, color: CoresTocaEssa.fundo),
                  ),
                ),
              )
            : null,
      );
}
