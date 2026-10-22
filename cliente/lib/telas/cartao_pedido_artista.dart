import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../tema/tema_toca_essa.dart';
part 'cartao_pedido_artista_partes.dart';

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
    this.aSeguir = false,
    this.alternarASeguir,
    this.foraDoAcervo,
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

  /// Marcado para entrar na barra Próxima da setlist e do leitor de cifras.
  final bool aSeguir;
  final VoidCallback? alternarASeguir;

  /// Música que não está em nenhum repertório: o selo leva a um deles.
  final VoidCallback? foraDoAcervo;

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
        aSeguir: aSeguir,
        alternarASeguir: alternarASeguir,
        foraDoAcervo: foraDoAcervo,
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
    this.aSeguir = false,
    this.alternarASeguir,
    this.foraDoAcervo,
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

  /// Marcado para entrar na barra Próxima da setlist e do leitor de cifras.
  final bool aSeguir;
  final VoidCallback? alternarASeguir;

  /// Música que não está em nenhum repertório: o selo leva a um deles.
  final VoidCallback? foraDoAcervo;

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
              if (foraDoAcervo != null && pedido.tipo == TipoPedido.musica) ...[
                const SizedBox(height: EspacoTocaEssa.pequeno),
                ActionChip(
                  tooltip: 'Adicionar ao repertório',
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.library_add_rounded, size: 16),
                  label: const Text('Fora do acervo'),
                  onPressed: foraDoAcervo,
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
}
