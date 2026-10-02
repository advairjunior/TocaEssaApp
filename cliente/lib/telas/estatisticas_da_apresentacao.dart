import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/baixar_arquivo.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_lista.dart';

part 'estatisticas_da_apresentacao_componentes.dart';
part 'estatisticas_da_apresentacao_acoes.dart';
part 'estatisticas_da_apresentacao_retrospectiva.dart';

class EstatisticasDaApresentacaoTela extends StatefulWidget {
  const EstatisticasDaApresentacaoTela({
    super.key,
    required this.api,
    required this.apresentacao,
    this.incorporada = false,
  });

  final ApiTocaEssa api;
  final Apresentacao apresentacao;
  final bool incorporada;

  @override
  State<EstatisticasDaApresentacaoTela> createState() =>
      _EstatisticasDaApresentacaoTelaState();
}

class _EstatisticasDaApresentacaoTelaState
    extends State<EstatisticasDaApresentacaoTela> with _EstatisticasAcoes {
  @override
  final _chaveCartao = GlobalKey();
  @override
  bool _gerandoCartao = false;
  @override
  bool _enviandoFoto = false;
  @override
  late Apresentacao _apresentacaoAtual;

  @override
  ApiTocaEssa get api => widget.api;
  @override
  Apresentacao get apresentacao => _apresentacaoAtual;

  @override
  void initState() {
    super.initState();
    _apresentacaoAtual = widget.apresentacao;
  }

  @override
  Widget build(BuildContext context) {
    final conteudo = ConteudoMobile(
      filho: FutureBuilder<EstatisticasDaApresentacao>(
        future: api.obterEstatisticasDaApresentacao(apresentacao.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 80),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.only(top: 64),
              child: Text(
                snapshot.error.toString(),
                textAlign: TextAlign.center,
              ),
            );
          }
          final dados = snapshot.data!;
          final texto = Theme.of(context).textTheme;
          final secundario =
              texto.bodyMedium?.copyWith(color: CoresTocaEssa.textoSecundario);
          const entreSecoes = SizedBox(height: EspacoTocaEssa.enorme);
          final maiorPedido = dados.musicasMaisPedidas.isEmpty
              ? 1
              : dados.musicasMaisPedidas
                  .map((m) => m.quantidade)
                  .reduce((a, b) => a > b ? a : b);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dentro do painel, nome e data já estão no topo.
              if (!widget.incorporada) ...[
                Text(apresentacao.nome, style: texto.headlineSmall),
                const SizedBox(height: EspacoTocaEssa.mini),
                Text(
                  '${formatarData(apresentacao.data)} · ${apresentacao.local}',
                  style: secundario,
                ),
                const SizedBox(height: EspacoTocaEssa.grande),
              ],
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: CoresTocaEssa.ouro, size: 36),
                  const SizedBox(width: EspacoTocaEssa.medio),
                  Text(
                    dados.mediaAvaliacoes?.toStringAsFixed(1) ?? '—',
                    style: texto.headlineMedium,
                  ),
                  const SizedBox(width: EspacoTocaEssa.medio),
                  Expanded(
                    child: Text(
                      dados.avaliados == 0
                          ? 'Ainda sem avaliações'
                          : '${dados.avaliados} '
                              '${dados.avaliados == 1 ? 'avaliação recebida' : 'avaliações recebidas'}',
                      style: secundario,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: EspacoTocaEssa.base),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: EspacoTocaEssa.base),
                decoration: BoxDecoration(
                  color: CoresTocaEssa.superficie,
                  borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
                  border: Border.all(color: CoresTocaEssa.borda),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      _NumeroDaFaixa(
                          valor: dados.totalPedidos, rotulo: 'pedidos'),
                      const VerticalDivider(width: 1),
                      _NumeroDaFaixa(valor: dados.tocados, rotulo: 'tocados'),
                      const VerticalDivider(width: 1),
                      _NumeroDaFaixa(
                          valor: dados.aguardando, rotulo: 'aguardando'),
                      const VerticalDivider(width: 1),
                      _NumeroDaFaixa(
                          valor: dados.recusados, rotulo: 'não atendidos'),
                    ],
                  ),
                ),
              ),
              entreSecoes,
              const TituloGrupo('Músicas mais pedidas'),
              if (dados.musicasMaisPedidas.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: EspacoTocaEssa.mini),
                  child: Text(
                    'Os destaques aparecem quando o público começar a pedir.',
                    style: secundario,
                  ),
                )
              else
                GrupoDeLinhas(
                  linhas: [
                    for (final (indice, musica)
                        in dados.musicasMaisPedidas.indexed)
                      _LinhaRanking(
                        posicao: indice + 1,
                        musica: musica,
                        proporcao: musica.quantidade / maiorPedido,
                      ),
                  ],
                ),
              if (apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos) ...[
                entreSecoes,
                const TituloGrupo('Galera da resenha'),
                FutureBuilder<List<ParticipanteDaResenha>>(
                  future: api
                      .listarParticipantesDaResenhaDoArtista(apresentacao.id),
                  builder: (context, participantesSnapshot) {
                    if (!participantesSnapshot.hasData &&
                        participantesSnapshot.connectionState !=
                            ConnectionState.done) {
                      return const Center(
                          child: Padding(
                        padding: EdgeInsets.all(EspacoTocaEssa.grande),
                        child: CircularProgressIndicator(),
                      ));
                    }
                    final participantes =
                        participantesSnapshot.data ?? const [];
                    if (participantes.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: EspacoTocaEssa.mini),
                        child: Text(
                          'A galera aparece depois dos primeiros pedidos.',
                          style: secundario,
                        ),
                      );
                    }
                    return GrupoDeLinhas(
                      linhas: [
                        for (final participante in participantes)
                          _LinhaParticipante(
                            participante: participante,
                            enderecoFoto:
                                api.enderecoArquivo(participante.fotoUrl),
                          ),
                      ],
                    );
                  },
                ),
                // A retrospectiva é para depois do show: fica no fim, sem
                // empurrar os números para baixo durante a apresentação.
                entreSecoes,
                const TituloGrupo('Retrospectiva'),
                _RetrospectivaDaResenha(
                  chaveCartao: _chaveCartao,
                  apresentacao: apresentacao,
                  dados: dados,
                  enderecoFoto:
                      api.enderecoArquivo(apresentacao.fotoRetrospectivaUrl),
                  enviandoFoto: _enviandoFoto,
                  escolherFoto: _escolherFotoDoEncontro,
                  gerandoImagem: _gerandoCartao,
                  baixarImagem: _baixarCartao,
                  copiar: () => _copiarRetrospectiva(context, dados),
                ),
              ],
              const SizedBox(height: EspacoTocaEssa.grande),
            ],
          );
        },
      ),
    );
    if (widget.incorporada) return conteudo;
    return Scaffold(
      appBar: AppBar(title: const Text('Estatísticas')),
      body: conteudo,
    );
  }
}
