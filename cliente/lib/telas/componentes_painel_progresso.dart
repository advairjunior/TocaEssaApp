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
        const _TituloSecaoPainel(
          icone: Icons.insights_rounded,
          titulo: 'Estatísticas',
          descricao: 'Seu progresso no TocaEssa',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _ResumoDoArtista(
                valor: apresentacoes.length, rotulo: 'apresentações'),
            const SizedBox(width: 10),
            _ResumoDoArtista(valor: aoVivo, rotulo: 'ao vivo'),
            const SizedBox(width: 10),
            _ResumoDoArtista(valor: encerradas, rotulo: 'realizadas'),
          ],
        ),
        const SizedBox(height: 28),
        const _TituloSecaoPainel(
          icone: Icons.emoji_events_rounded,
          titulo: 'Conquistas',
          descricao: 'Marcos da sua jornada musical',
        ),
        const SizedBox(height: 12),
        _ConquistaDoArtista(
          icone: Icons.mic_external_on_rounded,
          titulo: 'Primeiro palco',
          descricao: 'Crie sua primeira Apresentação',
          desbloqueada: apresentacoes.isNotEmpty,
        ),
        const SizedBox(height: 10),
        _ConquistaDoArtista(
          icone: Icons.waves_rounded,
          titulo: 'Som ao vivo',
          descricao: 'Inicie uma Apresentação',
          desbloqueada: aoVivo > 0 || encerradas > 0,
        ),
      ],
    );
  }
}

class _ResumoDoArtista extends StatelessWidget {
  const _ResumoDoArtista({required this.valor, required this.rotulo});

  final int valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          decoration: _decoracaoPainel(),
          child: Column(
            children: [
              Text('$valor', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(rotulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: CoresTocaEssa.textoSecundario, fontSize: 11)),
            ],
          ),
        ),
      );
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
  Widget build(BuildContext context) => Opacity(
        opacity: desbloqueada ? 1 : .45,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _decoracaoPainel(destaque: desbloqueada),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF352064),
                foregroundColor: CoresTocaEssa.roxoClaro,
                child: Icon(desbloqueada ? icone : Icons.lock_outline_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(descricao,
                        style: const TextStyle(
                            color: CoresTocaEssa.textoSecundario,
                            fontSize: 12)),
                  ],
                ),
              ),
              if (desbloqueada)
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF54D98C)),
            ],
          ),
        ),
      );
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

class _TituloSecaoPainel extends StatelessWidget {
  const _TituloSecaoPainel({
    required this.icone,
    required this.titulo,
    required this.descricao,
  });

  final IconData icone;
  final String titulo;
  final String descricao;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: CoresTocaEssa.roxo.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icone, color: CoresTocaEssa.roxoClaro, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: Theme.of(context).textTheme.titleLarge),
                Text(
                  descricao,
                  style: const TextStyle(
                    color: CoresTocaEssa.textoSecundario,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _AbasApresentacoes extends StatelessWidget {
  const _AbasApresentacoes({
    required this.selecionada,
    required this.apresentacoes,
    required this.selecionar,
  });

  final _FiltroApresentacoes selecionada;
  final List<Apresentacao> apresentacoes;
  final ValueChanged<_FiltroApresentacoes> selecionar;

  int _quantidade(_FiltroApresentacoes filtro) => apresentacoes
      .where((item) => switch (filtro) {
            _FiltroApresentacoes.aoVivo =>
              item.status == StatusApresentacao.emAndamento,
            _FiltroApresentacoes.agendadas =>
              item.status == StatusApresentacao.agendada,
            _FiltroApresentacoes.historico =>
              item.status == StatusApresentacao.encerrada,
          })
      .length;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: CoresTocaEssa.superficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CoresTocaEssa.borda),
        ),
        child: Row(
          children: [
            _AbaApresentacao(
              rotulo: 'Ao vivo',
              quantidade: _quantidade(_FiltroApresentacoes.aoVivo),
              selecionada: selecionada == _FiltroApresentacoes.aoVivo,
              tocar: () => selecionar(_FiltroApresentacoes.aoVivo),
            ),
            _AbaApresentacao(
              rotulo: 'Agendadas',
              quantidade: _quantidade(_FiltroApresentacoes.agendadas),
              selecionada: selecionada == _FiltroApresentacoes.agendadas,
              tocar: () => selecionar(_FiltroApresentacoes.agendadas),
            ),
            _AbaApresentacao(
              rotulo: 'Histórico',
              quantidade: _quantidade(_FiltroApresentacoes.historico),
              selecionada: selecionada == _FiltroApresentacoes.historico,
              tocar: () => selecionar(_FiltroApresentacoes.historico),
            ),
          ],
        ),
      );
}

class _AbaApresentacao extends StatelessWidget {
  const _AbaApresentacao({
    required this.rotulo,
    required this.quantidade,
    required this.selecionada,
    required this.tocar,
  });

  final String rotulo;
  final int quantidade;
  final bool selecionada;
  final VoidCallback tocar;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: tocar,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            decoration: BoxDecoration(
              color: selecionada ? CoresTocaEssa.roxo : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    rotulo,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selecionada
                          ? Colors.white
                          : CoresTocaEssa.textoSecundario,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: selecionada
                        ? Colors.white.withValues(alpha: .18)
                        : CoresTocaEssa.superficieElevada,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$quantidade',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selecionada
                          ? Colors.white
                          : CoresTocaEssa.textoSecundario,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
