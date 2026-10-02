part of 'painel_do_artista.dart';

class _ProgressoDoArtista extends StatelessWidget {
  const _ProgressoDoArtista({required this.apresentacoes});

  final List<Apresentacao> apresentacoes;

  @override
  Widget build(BuildContext context) {
    final aoVivo = apresentacoes
        .where((item) => item.status == StatusApresentacao.emAndamento)
        .length;
    final encerradas = apresentacoes
        .where((item) => item.status == StatusApresentacao.encerrada)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloGrupo('Sua jornada'),
        Container(
          padding: const EdgeInsets.symmetric(vertical: EspacoTocaEssa.base),
          decoration: BoxDecoration(
            color: CoresTocaEssa.superficie,
            borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
            border: Border.all(color: CoresTocaEssa.borda),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                _NumeroDaJornada(
                    valor: apresentacoes.length, rotulo: 'apresentações'),
                const VerticalDivider(width: 1),
                _NumeroDaJornada(valor: aoVivo, rotulo: 'ao vivo'),
                const VerticalDivider(width: 1),
                _NumeroDaJornada(valor: encerradas, rotulo: 'realizadas'),
              ],
            ),
          ),
        ),
        const SizedBox(height: EspacoTocaEssa.base),
        Padding(
          padding: const EdgeInsets.only(
            left: EspacoTocaEssa.mini,
            bottom: EspacoTocaEssa.pequeno,
          ),
          child: Text(
            'Conquistas',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
        ),
        GrupoDeLinhas(
          linhas: [
            _ConquistaDoArtista(
              icone: Icons.mic_external_on_rounded,
              titulo: 'Primeiro palco',
              descricao: 'Crie sua primeira apresentação',
              desbloqueada: apresentacoes.isNotEmpty,
            ),
            _ConquistaDoArtista(
              icone: Icons.waves_rounded,
              titulo: 'Som ao vivo',
              descricao: 'Inicie uma apresentação',
              desbloqueada: aoVivo > 0 || encerradas > 0,
            ),
          ],
        ),
      ],
    );
  }
}

class _NumeroDaJornada extends StatelessWidget {
  const _NumeroDaJornada({required this.valor, required this.rotulo});

  final int valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text('$valor', style: texto.headlineSmall),
          const SizedBox(height: 2),
          Text(
            rotulo,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: texto.labelMedium
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
        ],
      ),
    );
  }
}

class _ConquistaDoArtista extends StatelessWidget {
  const _ConquistaDoArtista({
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.desbloqueada,
  });

  final IconData icone;
  final String titulo;
  final String descricao;
  final bool desbloqueada;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Opacity(
      opacity: desbloqueada ? 1 : .5,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: EspacoTocaEssa.base,
          vertical: EspacoTocaEssa.medio,
        ),
        child: Row(
          children: [
            Icon(
              desbloqueada ? icone : Icons.lock_outline_rounded,
              size: 20,
              color: CoresTocaEssa.roxoClaro,
            ),
            const SizedBox(width: EspacoTocaEssa.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: texto.titleMedium),
                  Text(
                    descricao,
                    style: texto.bodyMedium
                        ?.copyWith(color: CoresTocaEssa.textoSecundario),
                  ),
                ],
              ),
            ),
            if (desbloqueada)
              const Icon(Icons.check_circle_rounded,
                  size: 20, color: Color(0xFF54D98C)),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _decoracaoPainel({bool destaque = false}) => BoxDecoration(
      color: CoresTocaEssa.superficie,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: destaque ? const Color(0xFF4A3470) : CoresTocaEssa.borda,
      ),
      boxShadow: destaque
          ? const [
              BoxShadow(
                color: Color(0x26784DFF),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ]
          : null,
    );
