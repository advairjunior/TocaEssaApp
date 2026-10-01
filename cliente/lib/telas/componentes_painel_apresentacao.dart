part of 'painel_do_artista.dart';

/// Faixa abaixo do título com os controles principais do show.
class _BarraStatusApresentacao extends StatelessWidget
    implements PreferredSizeWidget {
  const _BarraStatusApresentacao({
    required this.apresentacao,
    required this.salvando,
    required this.alterarPedidos,
    required this.alterarStatus,
  });

  final Apresentacao apresentacao;
  final bool salvando;
  final VoidCallback alterarPedidos;
  final ValueChanged<StatusApresentacao> alterarStatus;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final agendada = apresentacao.status == StatusApresentacao.agendada;
    final estilo =
        (agendada ? FilledButton.styleFrom : OutlinedButton.styleFrom)(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: EspacoTocaEssa.base),
    );
    final acao = salvando
        ? null
        : () => alterarStatus(agendada
            ? StatusApresentacao.emAndamento
            : StatusApresentacao.encerrada);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        EspacoTocaEssa.base,
        0,
        EspacoTocaEssa.base,
        EspacoTocaEssa.pequeno,
      ),
      child: Row(
        children: [
          Tooltip(
            message: 'Receber pedidos',
            child: Switch(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              value: apresentacao.pedidosAbertos,
              onChanged: salvando ? null : (_) => alterarPedidos(),
            ),
          ),
          const SizedBox(width: EspacoTocaEssa.pequeno),
          Expanded(
            child: Text(
              apresentacao.pedidosAbertos
                  ? 'Recebendo pedidos'
                  : 'Pedidos pausados',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: CoresTocaEssa.textoSecundario),
            ),
          ),
          const SizedBox(width: EspacoTocaEssa.pequeno),
          agendada
              ? FilledButton(
                  style: estilo,
                  onPressed: acao,
                  child: const Text('Iniciar'),
                )
              : OutlinedButton(
                  style: estilo,
                  onPressed: acao,
                  child: const Text('Encerrar'),
                ),
        ],
      ),
    );
  }
}

/// Título da apresentação com o status logo abaixo do nome.
class _TituloApresentacao extends StatelessWidget {
  const _TituloApresentacao({required this.apresentacao});
  final Apresentacao apresentacao;

  @override
  Widget build(BuildContext context) {
    final (rotulo, cor) = switch (apresentacao.status) {
      StatusApresentacao.emAndamento => ('Ao vivo', CoresTocaEssa.rosa),
      StatusApresentacao.agendada => ('Agendada', CoresTocaEssa.roxoClaro),
      StatusApresentacao.encerrada => (
          'Encerrada',
          CoresTocaEssa.textoSecundario
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(apresentacao.nome, overflow: TextOverflow.ellipsis),
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
            ),
            const SizedBox(width: EspacoTocaEssa.pequeno - 2),
            Flexible(
              child: Text(
                rotulo,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: cor),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TituloGrupo extends StatelessWidget {
  const _TituloGrupo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(
          left: EspacoTocaEssa.mini,
          bottom: EspacoTocaEssa.pequeno,
        ),
        child: Text(
          texto,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: CoresTocaEssa.roxoClaro,
                letterSpacing: .4,
              ),
        ),
      );
}

/// Lista agrupada em uma única superfície, com divisórias finas.
class _GrupoDeLinhas extends StatelessWidget {
  const _GrupoDeLinhas({required this.linhas});
  final List<Widget> linhas;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: CoresTocaEssa.superficie,
          borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
          border: Border.all(color: CoresTocaEssa.borda),
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              for (final (indice, linha) in linhas.indexed) ...[
                if (indice > 0)
                  const Divider(height: 1, indent: 52, endIndent: 16),
                linha,
              ],
            ],
          ),
        ),
      );
}

class _LinhaDetalhe extends StatelessWidget {
  const _LinhaDetalhe({
    required this.icone,
    required this.rotulo,
    required this.valor,
    this.destaque = false,
    this.tocar,
  });

  final IconData icone;
  final String rotulo;
  final String valor;
  final bool destaque;
  final VoidCallback? tocar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return InkWell(
      onTap: tocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: EspacoTocaEssa.base,
          vertical: EspacoTocaEssa.base - 2,
        ),
        child: Row(
          children: [
            Icon(icone, size: 20, color: CoresTocaEssa.roxoClaro),
            const SizedBox(width: EspacoTocaEssa.base),
            Text(
              rotulo,
              style: texto.bodyMedium
                  ?.copyWith(color: CoresTocaEssa.textoSecundario),
            ),
            const SizedBox(width: EspacoTocaEssa.base),
            Expanded(
              child: Text(
                valor,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: destaque
                    ? texto.titleMedium?.copyWith(
                        color: CoresTocaEssa.roxoClaro,
                        letterSpacing: 2,
                      )
                    : texto.bodyLarge,
              ),
            ),
            if (tocar != null) ...[
              const SizedBox(width: EspacoTocaEssa.mini),
              const Icon(Icons.chevron_right_rounded,
                  color: CoresTocaEssa.textoSecundario),
            ],
          ],
        ),
      ),
    );
  }
}
