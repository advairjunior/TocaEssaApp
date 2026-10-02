part of 'conta_do_publico.dart';

/// Três números que resumem a trajetória do público nas resenhas.
class _ResumoDasResenhas extends StatelessWidget {
  const _ResumoDasResenhas({required this.estatisticas});
  final EstatisticasDoPublico estatisticas;

  @override
  Widget build(BuildContext context) {
    String plural(int valor, String singular, String varios) =>
        valor == 1 ? singular : varios;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: EspacoTocaEssa.base),
      decoration: BoxDecoration(
        color: CoresTocaEssa.superficie,
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
        border: Border.all(color: CoresTocaEssa.borda),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _NumeroDoResumo(
              valor: estatisticas.participacoes,
              rotulo: plural(estatisticas.participacoes, 'resenha', 'resenhas'),
            ),
            const VerticalDivider(width: 1),
            _NumeroDoResumo(
              valor: estatisticas.pedidos,
              rotulo: plural(estatisticas.pedidos, 'pedido', 'pedidos'),
            ),
            const VerticalDivider(width: 1),
            _NumeroDoResumo(
              valor: estatisticas.pedidosTocados,
              rotulo: plural(estatisticas.pedidosTocados, 'tocada', 'tocadas'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumeroDoResumo extends StatelessWidget {
  const _NumeroDoResumo({required this.valor, required this.rotulo});
  final int valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text('$valor', style: texto.headlineSmall),
          Text(
            rotulo,
            style: texto.labelMedium
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
        ],
      ),
    );
  }
}

/// Destaque da resenha que está acontecendo agora, com volta direta a ela.
class _CartaoResenhaAoVivo extends StatelessWidget {
  const _CartaoResenhaAoVivo({required this.apresentacao, required this.abrir});
  final Apresentacao apresentacao;
  final VoidCallback abrir;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(EspacoTocaEssa.grande - 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CoresTocaEssa.destaqueFundo, CoresTocaEssa.superficie],
        ),
        border: Border.all(color: CoresTocaEssa.destaqueBorda),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33784DFF),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: CoresTocaEssa.rosa,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x99FF4D9D), blurRadius: 8)
                  ],
                ),
              ),
              const SizedBox(width: EspacoTocaEssa.pequeno),
              Text(
                'Ao vivo agora',
                style: texto.labelLarge
                    ?.copyWith(color: CoresTocaEssa.rosa, letterSpacing: .4),
              ),
            ],
          ),
          const SizedBox(height: EspacoTocaEssa.medio),
          Text(apresentacao.nome, style: texto.headlineSmall),
          const SizedBox(height: EspacoTocaEssa.mini),
          Text(
            '${apresentacao.perfilArtistico.nomeArtistico} · '
            '${apresentacao.local}',
            style: texto.bodyMedium
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
          const SizedBox(height: EspacoTocaEssa.grande - 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: abrir,
              icon: const Icon(Icons.graphic_eq_rounded),
              label: const Text('Voltar para a resenha'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha do histórico: capa (foto do encontro ou do artista), nome, artista
/// e local, e a data com o tipo do encontro.
class _LinhaMemoria extends StatelessWidget {
  const _LinhaMemoria({
    required this.apresentacao,
    required this.enderecoCapa,
    required this.tocar,
  });

  final Apresentacao apresentacao;
  final String? enderecoCapa;
  final VoidCallback tocar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final resenha = apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: tocar,
        child: Padding(
          padding: const EdgeInsets.all(EspacoTocaEssa.medio),
          child: Row(
            children: [
              _CapaDaMemoria(
                endereco: enderecoCapa,
                icone: resenha ? Icons.groups_rounded : Icons.mic_rounded,
              ),
              const SizedBox(width: EspacoTocaEssa.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apresentacao.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texto.titleMedium,
                    ),
                    Text(
                      '${apresentacao.perfilArtistico.nomeArtistico} · '
                      '${apresentacao.local}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texto.bodyMedium
                          ?.copyWith(color: CoresTocaEssa.textoSecundario),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatarDiaEMes(apresentacao.data)} · '
                      '${resenha ? 'Resenha' : 'Show'}',
                      style: texto.labelMedium?.copyWith(
                        color: CoresTocaEssa.roxoClaro,
                        letterSpacing: .2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: EspacoTocaEssa.mini),
              const Icon(Icons.chevron_right_rounded,
                  color: CoresTocaEssa.textoSecundario),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapaDaMemoria extends StatelessWidget {
  const _CapaDaMemoria({required this.endereco, required this.icone});
  final String? endereco;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final semFoto = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CoresTocaEssa.destaqueFundo,
            CoresTocaEssa.superficieElevada
          ],
        ),
      ),
      child: Center(
        child: Icon(icone, size: 26, color: CoresTocaEssa.roxoClaro),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
      child: SizedBox.square(
        dimension: 60,
        child: endereco == null
            ? semFoto
            : Image.network(
                endereco!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => semFoto,
              ),
      ),
    );
  }
}
