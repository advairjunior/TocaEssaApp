part of 'painel_do_artista.dart';

class _PontoAoVivo extends StatelessWidget {
  const _PontoAoVivo();

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: CoresTocaEssa.rosa,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x99FF4D9D), blurRadius: 8)],
        ),
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

  int _quantidade(StatusApresentacao status) =>
      apresentacoes.where((item) => item.status == status).length;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Flexible(
            child: AbaDeTexto(
              rotulo: 'Próximas',
              quantidade: _quantidade(StatusApresentacao.agendada),
              selecionada: selecionada == _FiltroApresentacoes.proximas,
              tocar: () => selecionar(_FiltroApresentacoes.proximas),
            ),
          ),
          const SizedBox(width: EspacoTocaEssa.base),
          Flexible(
            child: AbaDeTexto(
              rotulo: 'Histórico',
              quantidade: _quantidade(StatusApresentacao.encerrada),
              selecionada: selecionada == _FiltroApresentacoes.historico,
              tocar: () => selecionar(_FiltroApresentacoes.historico),
            ),
          ),
        ],
      );
}

class _ListaApresentacoes extends StatelessWidget {
  const _ListaApresentacoes({
    required this.apresentacoes,
    required this.jaPassou,
    required this.abrir,
  });

  final List<Apresentacao> apresentacoes;
  // Agendada com data passada: o artista esqueceu de encerrar.
  final bool Function(Apresentacao) jaPassou;
  final ValueChanged<Apresentacao> abrir;

  @override
  Widget build(BuildContext context) => GrupoDeLinhas(
        recuoDivisoria: 84,
        linhas: [
          for (final apresentacao in apresentacoes)
            LinhaComData(
              data: apresentacao.data,
              titulo: apresentacao.nome,
              aviso: jaPassou(apresentacao) ? 'Já passou' : null,
              subtitulo:
                  '${apresentacao.local} · ${apresentacao.tipo.rotuloCurto}',
              tocar: () => abrir(apresentacao),
            ),
        ],
      );
}

/// Resumo dos repertórios, que formam o acervo de onde saem as setlists, e,
/// com música no acervo, o atalho para tocar sem show.
class _LinhaDoAcervo extends StatelessWidget {
  const _LinhaDoAcervo({
    required this.repertorios,
    required this.abrir,
    required this.tocar,
  });

  final List<Repertorio>? repertorios;
  final VoidCallback abrir;
  final VoidCallback tocar;

  bool get _temMusica =>
      (repertorios ?? const <Repertorio>[]).any((r) => r.musicas.isNotEmpty);

  String get _resumo {
    final lista = repertorios ?? const [];
    if (lista.isEmpty) return 'Monte seu acervo de músicas';
    final musicas = lista.fold<int>(
        0, (soma, repertorio) => soma + repertorio.musicas.length);
    return [
      lista.length == 1 ? '1 repertório' : '${lista.length} repertórios',
      musicas == 1 ? '1 música' : '$musicas músicas',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) => GrupoDeLinhas(
        linhas: [
          _linha(context, Icons.queue_music_rounded, 'Meus repertórios',
              _resumo, abrir),
          if (_temMusica)
            _linha(context, Icons.play_arrow_rounded, 'Tocar e ensaiar',
                'Abra qualquer música, sem criar show', tocar),
        ],
      );

  Widget _linha(BuildContext context, IconData icone, String titulo,
      String detalhe, VoidCallback aoTocar) {
    final texto = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.all(EspacoTocaEssa.base),
          child: Row(
            children: [
              Icon(icone, color: CoresTocaEssa.roxoClaro),
              const SizedBox(width: EspacoTocaEssa.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: texto.titleMedium),
                    const SizedBox(height: 2),
                    Text(detalhe,
                        style: texto.bodyMedium
                            ?.copyWith(color: CoresTocaEssa.textoSecundario)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: CoresTocaEssa.textoSecundario),
            ],
          ),
        ),
      ),
    );
  }
}
