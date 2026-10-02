import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../tema/tema_toca_essa.dart';

class CartaoGrupoPedidoArtista extends StatelessWidget {
  const CartaoGrupoPedidoArtista({
    super.key,
    required this.grupo,
    required this.alterar,
    this.inicio,
    this.fim,
    this.somenteLeitura = false,
    this.eoPrimeiroDaFila = false,
    this.abrirCifra,
    this.escolherCifra,
    this.destaque = false,
  });

  final GrupoPedidoMusical grupo;
  final ValueChanged<StatusPedidoMusical> alterar;
  final Widget? inicio;
  final Widget? fim;
  final bool somenteLeitura;
  final bool eoPrimeiroDaFila;
  final VoidCallback? abrirCifra;
  final VoidCallback? escolherCifra;

  /// Realça a música que está tocando agora.
  final bool destaque;

  @override
  Widget build(BuildContext context) => CartaoPedidoArtista(
        pedido: grupo.comoPedidoMusical(),
        alterar: alterar,
        inicio: inicio,
        fim: fim,
        somenteLeitura: somenteLeitura,
        eoPrimeiroDaFila: eoPrimeiroDaFila,
        abrirCifra: abrirCifra,
        escolherCifra: escolherCifra,
        destaque: destaque,
      );
}

class CartaoPedidoArtista extends StatelessWidget {
  const CartaoPedidoArtista({
    super.key,
    required this.pedido,
    required this.alterar,
    this.inicio,
    this.fim,
    this.somenteLeitura = false,
    this.eoPrimeiroDaFila = false,
    this.abrirCifra,
    this.escolherCifra,
    this.destaque = false,
  });

  final PedidoMusical pedido;
  final ValueChanged<StatusPedidoMusical> alterar;
  final Widget? inicio;
  final Widget? fim;
  final bool somenteLeitura;
  final bool eoPrimeiroDaFila;
  final VoidCallback? abrirCifra;
  final VoidCallback? escolherCifra;

  /// Realça a música que está tocando agora.
  final bool destaque;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
          color: destaque
              ? null
              : pedido.quantidadePedidos > 1
                  ? CoresTocaEssa.roxo.withValues(alpha: .1)
                  : CoresTocaEssa.superficie,
          gradient: destaque
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    CoresTocaEssa.destaqueFundo,
                    CoresTocaEssa.superficie
                  ],
                )
              : null,
          border: Border.all(
            color: destaque
                ? CoresTocaEssa.destaqueBorda
                : pedido.quantidadePedidos > 1
                    ? CoresTocaEssa.roxoClaro.withValues(alpha: .4)
                    : CoresTocaEssa.borda,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(EspacoTocaEssa.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eoPrimeiroDaFila &&
                  pedido.status == StatusPedidoMusical.aceito) ...[
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: CoresTocaEssa.sucesso,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'PRÓXIMA A TOCAR',
                      style: TextStyle(
                        color: CoresTocaEssa.sucesso,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              _cabecalho(context),
              if (_textoDosSolicitantes != null) ...[
                const SizedBox(height: EspacoTocaEssa.mini),
                Text(
                  _textoDosSolicitantes!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: CoresTocaEssa.textoSecundario),
                ),
              ],
              if (_detalhesDaParticipacao != null) ...[
                const SizedBox(height: EspacoTocaEssa.mini),
                Text(
                  _detalhesDaParticipacao!,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: CoresTocaEssa.roxoClaro),
                ),
              ],
              if (pedido.recado?.isNotEmpty == true) ...[
                const SizedBox(height: EspacoTocaEssa.pequeno),
                _recado(context),
              ],
              // Nas seções o status já está implícito; no histórico ele diz
              // como cada pedido terminou.
              if (somenteLeitura) ...[
                const SizedBox(height: EspacoTocaEssa.pequeno),
                Text(
                  pedido.status.rotulo,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: CoresTocaEssa.roxoClaro),
                ),
              ],
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

  String? get _textoDosSolicitantes {
    final nomes = pedido.solicitantes;
    if (nomes.isEmpty) {
      return pedido.nomeSolicitante?.isNotEmpty == true
          ? 'Pedido por ${pedido.nomeSolicitante}'
          : null;
    }
    if (nomes.length == 1) return 'Pedido por ${nomes.first}';
    if (nomes.length == 2) return 'Pedido por ${nomes[0]} e ${nomes[1]}';
    return 'Pedido por ${nomes[0]}, ${nomes[1]} e mais ${nomes.length - 2}';
  }

  bool get _temRodape => _temCifra || (!somenteLeitura && _acoes().isNotEmpty);

  /// Ação principal e atalhos da cifra numa linha; as alternativas (recusas)
  /// ficam abaixo, discretas.
  Widget _rodape() {
    final acoes = somenteLeitura ? <Widget>[] : _acoes();
    final principal = acoes.isEmpty ? null : acoes.first;
    final alternativas = acoes.skip(1).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (principal != null)
              Expanded(child: principal)
            else
              const Spacer(),
            if (_temCifra) ...[
              const SizedBox(width: EspacoTocaEssa.pequeno),
              ..._atalhosDaCifra(),
            ],
          ],
        ),
        if (alternativas.isNotEmpty) ...[
          const SizedBox(height: EspacoTocaEssa.mini),
          // Cada rótulo fica inteiro; se não couberem lado a lado, descem.
          Wrap(children: alternativas),
        ],
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
                    style: Theme.of(context).textTheme.titleLarge),
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
          if (pedido.quantidadePedidos > 1) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: CoresTocaEssa.roxoClaro.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${pedido.quantidadePedidos} pedidos',
                style: const TextStyle(
                  color: CoresTocaEssa.roxoClaro,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          if (fim != null) fim!,
        ],
      );

  /// Ex.: "Eu canto · Tom G"; nulo quando é um pedido comum.
  String? get _detalhesDaParticipacao {
    final partes = [
      if (pedido.formaParticipacao != FormaParticipacaoPedido.pedidoNormal)
        pedido.formaParticipacao.rotulo,
      if (pedido.tomPreferido?.isNotEmpty == true) 'Tom ${pedido.tomPreferido}',
    ];
    return partes.isEmpty ? null : partes.join(' · ');
  }

  Widget _recado(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.only(left: EspacoTocaEssa.medio),
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: CoresTocaEssa.roxoClaro, width: 2),
          ),
        ),
        child: Text(
          '“${pedido.recado}”',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontStyle: FontStyle.italic),
        ),
      );

  Widget _avaliacao() => Row(
        children: [
          const Icon(Icons.star_rounded, size: 20, color: CoresTocaEssa.ouro),
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
