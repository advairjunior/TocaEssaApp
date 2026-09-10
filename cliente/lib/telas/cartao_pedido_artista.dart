import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';

class CartaoPedidoArtista extends StatelessWidget {
  const CartaoPedidoArtista({
    super.key,
    required this.pedido,
    required this.alterar,
    this.inicio,
    this.fim,
    this.somenteLeitura = false,
    this.abrirCifra,
    this.escolherCifra,
  });

  final PedidoMusical pedido;
  final ValueChanged<StatusPedidoMusical> alterar;
  final Widget? inicio;
  final Widget? fim;
  final bool somenteLeitura;
  final VoidCallback? abrirCifra;
  final VoidCallback? escolherCifra;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: CoresTocaEssa.roxoClaro.withValues(alpha: .16),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cabecalho(context),
              if (pedido.nomeSolicitante?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 15, color: CoresTocaEssa.textoSecundario),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Pedido por ${pedido.nomeSolicitante}',
                        style: const TextStyle(
                          color: CoresTocaEssa.textoSecundario,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (pedido.formaParticipacao !=
                  FormaParticipacaoPedido.pedidoNormal) ...[
                const SizedBox(height: 10),
                _detalhesDaParticipacao(),
              ],
              if (pedido.recado?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                _recado(),
              ],
              const SizedBox(height: 8),
              _status(),
              if (pedido.quantidadeAvaliacoes > 0) ...[
                const SizedBox(height: 8),
                _avaliacao(),
              ],
              if (_temRodape) ...[
                const SizedBox(height: 12),
                _rodape(),
              ],
            ],
          ),
        ),
      );

  bool get _temCifra => pedido.tipo == TipoPedido.musica && abrirCifra != null;

  bool get _temRodape => _temCifra || (!somenteLeitura && _acoes().isNotEmpty);

  Widget _rodape() {
    final acoes = somenteLeitura ? <Widget>[] : _acoes();
    if (acoes.length == 1) {
      return Row(
        children: [
          Expanded(child: acoes.single),
          if (_temCifra) ...[
            const SizedBox(width: 8),
            ..._atalhosDaCifra(),
          ],
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...acoes,
        if (_temCifra)
          OutlinedButton.icon(
            onPressed: abrirCifra,
            icon: const Icon(Icons.menu_book_rounded, size: 19),
            label: const Text('Abrir cifra'),
          ),
        if (_temCifra && escolherCifra != null)
          IconButton.outlined(
            tooltip: 'Escolher ou trocar cifra',
            onPressed: escolherCifra,
            icon: const Icon(Icons.link_rounded),
          ),
      ],
    );
  }

  List<Widget> _atalhosDaCifra() => [
        IconButton.filledTonal(
          tooltip: 'Abrir cifra',
          onPressed: abrirCifra,
          icon: const Icon(Icons.menu_book_rounded),
        ),
        if (escolherCifra != null) ...[
          const SizedBox(width: 6),
          IconButton.outlined(
            tooltip: 'Escolher ou trocar cifra',
            onPressed: escolherCifra,
            icon: const Icon(Icons.link_rounded),
          ),
        ],
      ];

  Widget _status() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: CoresTocaEssa.roxo.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          pedido.status.rotulo,
          style: const TextStyle(
            color: CoresTocaEssa.roxoClaro,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _cabecalho(BuildContext context) => Row(
        children: [
          if (inicio != null) ...[inicio!, const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    pedido.tipo == TipoPedido.alo
                        ? 'Alô para ${pedido.destinatarioAlo}'
                        : pedido.musica,
                    style: Theme.of(context).textTheme.titleMedium),
                if (pedido.artista?.isNotEmpty == true)
                  Text(
                    pedido.artista!,
                    style: const TextStyle(
                      color: CoresTocaEssa.textoSecundario,
                    ),
                  ),
              ],
            ),
          ),
          if (fim != null) fim!,
        ],
      );

  Widget _detalhesDaParticipacao() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          EtiquetaDetalhePedido(
            icone: pedido.formaParticipacao == FormaParticipacaoPedido.euCanto
                ? Icons.mic_rounded
                : Icons.groups_rounded,
            texto: pedido.formaParticipacao.rotulo,
            destaque: true,
          ),
          if (pedido.tomPreferido?.isNotEmpty == true)
            EtiquetaDetalhePedido(
              icone: Icons.tune_rounded,
              texto: 'Tom ${pedido.tomPreferido}',
            ),
        ],
      );

  Widget _recado() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CoresTocaEssa.roxo.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('“${pedido.recado}”'),
      );

  Widget _avaliacao() => Row(
        children: [
          const Icon(Icons.star_rounded, size: 20, color: Color(0xFFFFC857)),
          const SizedBox(width: 8),
          Text(
            '${pedido.mediaAvaliacoes?.toStringAsFixed(1)}/5 · '
            '${pedido.quantidadeAvaliacoes} '
            '${pedido.quantidadeAvaliacoes == 1 ? 'avaliação' : 'avaliações'}',
            style: const TextStyle(
              color: CoresTocaEssa.textoSecundario,
              fontSize: 12,
            ),
          ),
        ],
      );

  List<Widget> _acoes() => switch (pedido.status) {
        StatusPedidoMusical.aguardando => [
            FilledButton.tonal(
              onPressed: () => alterar(StatusPedidoMusical.aceito),
              child: Text(
                  pedido.tipo == TipoPedido.alo ? 'Aceitar Alô' : 'Aceitar'),
            ),
            TextButton(
              onPressed: () => alterar(StatusPedidoMusical.naoConhecemos),
              child: Text(pedido.tipo == TipoPedido.alo
                  ? 'Não enviar'
                  : 'Não conhecemos'),
            ),
            if (pedido.tipo == TipoPedido.musica)
              TextButton(
                onPressed: () =>
                    alterar(StatusPedidoMusical.aindaNaoSabemosTocar),
                child: const Text('Ainda não tocamos'),
              ),
          ],
        StatusPedidoMusical.aceito => [
            FilledButton(
              onPressed: () => alterar(pedido.tipo == TipoPedido.alo
                  ? StatusPedidoMusical.finalizado
                  : StatusPedidoMusical.tocandoAgora),
              child: Text(pedido.tipo == TipoPedido.alo
                  ? 'Marcar Alô como enviado'
                  : 'Tocar agora'),
            ),
          ],
        StatusPedidoMusical.tocandoAgora => [
            FilledButton(
              onPressed: () => alterar(StatusPedidoMusical.finalizado),
              child: const Text('Finalizar música'),
            ),
          ],
        _ => const [],
      };
}
