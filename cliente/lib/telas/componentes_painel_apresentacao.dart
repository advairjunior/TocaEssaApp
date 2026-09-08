part of 'painel_do_artista.dart';

class _EstadoVazioApresentacoes extends StatelessWidget {
  const _EstadoVazioApresentacoes({required this.filtro});
  final _FiltroApresentacoes filtro;

  @override
  Widget build(BuildContext context) {
    final (icone, titulo, descricao) = switch (filtro) {
      _FiltroApresentacoes.aoVivo => (
          Icons.graphic_eq_rounded,
          'Nada ao vivo agora',
          'Quando você iniciar uma apresentação, ela aparecerá aqui.'
        ),
      _FiltroApresentacoes.agendadas => (
          Icons.event_outlined,
          'Nenhuma apresentação agendada',
          'Use a aba Criar para preparar seu próximo evento.'
        ),
      _FiltroApresentacoes.historico => (
          Icons.history_rounded,
          'Seu histórico está vazio',
          'As apresentações encerradas ficarão guardadas aqui.'
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: _decoracaoPainel(),
      child: Column(
        children: [
          Icon(icone, size: 38, color: CoresTocaEssa.roxoClaro),
          const SizedBox(height: 12),
          Text(titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(
            descricao,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CoresTocaEssa.textoSecundario,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoApresentacaoArtista extends StatelessWidget {
  const _CartaoApresentacaoArtista({
    required this.apresentacao,
    required this.salvando,
    required this.mostrarCodigo,
    required this.alterarStatus,
    required this.alterarPedidos,
    required this.selecionarOpcao,
  });

  final Apresentacao apresentacao;
  final bool salvando;
  final VoidCallback mostrarCodigo;
  final ValueChanged<StatusApresentacao> alterarStatus;
  final VoidCallback alterarPedidos;
  final ValueChanged<String> selecionarOpcao;

  @override
  Widget build(BuildContext context) {
    final emAndamento = apresentacao.status == StatusApresentacao.emAndamento;
    final encerrada = apresentacao.status == StatusApresentacao.encerrada;
    void executarAcao(String acao) {
      switch (acao) {
        case 'codigo':
          mostrarCodigo();
        case 'pedidos':
          alterarPedidos();
        case 'iniciar':
          alterarStatus(StatusApresentacao.emAndamento);
        case 'encerrar':
          alterarStatus(StatusApresentacao.encerrada);
        default:
          selecionarOpcao(acao);
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _decoracaoPainel(destaque: emAndamento),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apresentacao.nome,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 15),
                        const SizedBox(width: 6),
                        Text(formatarData(apresentacao.data)),
                        const SizedBox(width: 12),
                        const Icon(Icons.location_on_outlined, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            apresentacao.local,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opções da Apresentação',
                onSelected: executarAcao,
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'codigo',
                    child: ListTile(
                      leading: Icon(Icons.qr_code_2_rounded),
                      title: Text('Código e link'),
                    ),
                  ),
                  if (!encerrada)
                    PopupMenuItem(
                      value: 'pedidos',
                      child: ListTile(
                        leading: Icon(apresentacao.pedidosAbertos
                            ? Icons.lock_outline_rounded
                            : Icons.lock_open_rounded),
                        title: Text(apresentacao.pedidosAbertos
                            ? 'Encerrar pedidos'
                            : 'Reabrir pedidos'),
                      ),
                    ),
                  if (emAndamento)
                    const PopupMenuItem(
                      value: 'encerrar',
                      child: ListTile(
                        leading: Icon(Icons.stop_circle_outlined),
                        title: Text('Encerrar Apresentação'),
                      ),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'editar',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Editar'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'excluir',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Excluir'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _EtiquetaPainel(
                texto:
                    '${apresentacao.tipo.rotulo} · ${apresentacao.status.rotulo}',
                destaque: emAndamento,
              ),
              _EtiquetaPainel(
                texto: apresentacao.pedidosAbertos
                    ? 'Pedidos abertos'
                    : 'Pedidos fechados',
                icone: apresentacao.pedidosAbertos
                    ? Icons.lock_open_rounded
                    : Icons.lock_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: mostrarCodigo,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: CoresTocaEssa.fundo.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tag_rounded,
                      size: 18, color: CoresTocaEssa.roxoClaro),
                  const SizedBox(width: 8),
                  const Text(
                    'Código público',
                    style: TextStyle(
                      color: CoresTocaEssa.textoSecundario,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    apresentacao.codigo,
                    style: const TextStyle(
                      color: CoresTocaEssa.roxoClaro,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.qr_code_2_rounded,
                      size: 20, color: CoresTocaEssa.roxoClaro),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!emAndamento && !encerrada) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: salvando
                  ? null
                  : () => alterarStatus(StatusApresentacao.emAndamento),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Iniciar Apresentação'),
            ),
          ],
        ],
      ),
    );
  }
}

class _EtiquetaPainel extends StatelessWidget {
  const _EtiquetaPainel({
    required this.texto,
    this.icone,
    this.destaque = false,
  });

  final String texto;
  final IconData? icone;
  final bool destaque;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: destaque
              ? CoresTocaEssa.roxo.withValues(alpha: 0.24)
              : CoresTocaEssa.superficieElevada,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: destaque
                ? CoresTocaEssa.roxo.withValues(alpha: 0.6)
                : CoresTocaEssa.borda,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[
              Icon(icone, size: 14, color: CoresTocaEssa.roxoClaro),
              const SizedBox(width: 5),
            ],
            Text(
              texto,
              style: TextStyle(
                color: destaque
                    ? CoresTocaEssa.roxoClaro
                    : CoresTocaEssa.textoSecundario,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}
