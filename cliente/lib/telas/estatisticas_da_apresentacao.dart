import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../dominio/modelos.dart';
import '../dominio/retrospectiva_do_artista.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/baixar_arquivo.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_lista.dart';
import 'componentes_memoria.dart';

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
  late final Future<(EstatisticasDaApresentacao, List<ParticipanteDaResenha>)>
      _carga = _carregar();

  @override
  ApiTocaEssa get api => widget.api;
  @override
  Apresentacao get apresentacao => _apresentacaoAtual;

  bool get _resenha => apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos;

  @override
  void initState() {
    super.initState();
    _apresentacaoAtual = widget.apresentacao;
  }

  // Números e galera chegam juntos: o cartão da resenha usa os dois. Sem a
  // galera, os números continuam aparecendo.
  Future<(EstatisticasDaApresentacao, List<ParticipanteDaResenha>)>
      _carregar() async {
    final estatisticas = api.obterEstatisticasDaApresentacao(apresentacao.id);
    final participantes = _resenha
        ? api
            .listarParticipantesDaResenhaDoArtista(apresentacao.id)
            .catchError((_) => <ParticipanteDaResenha>[])
        : Future.value(<ParticipanteDaResenha>[]);
    return (await estatisticas, await participantes);
  }

  @override
  Widget build(BuildContext context) {
    final conteudo = ConteudoMobile(
      filho: FutureBuilder(
        future: _carga,
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
          final (dados, participantes) = snapshot.data!;
          final texto = Theme.of(context).textTheme;
          final secundario =
              texto.bodyMedium?.copyWith(color: CoresTocaEssa.textoSecundario);
          const entreSecoes = SizedBox(height: EspacoTocaEssa.enorme);
          final maiorPedido = dados.musicasMaisPedidas.isEmpty
              ? 1
              : dados.musicasMaisPedidas
                  .map((m) => m.quantidade)
                  .reduce((a, b) => a > b ? a : b);
          final retrospectiva = [
            const TituloGrupo('Retrospectiva'),
            _RetrospectivaDoArtista(
              chaveCartao: _chaveCartao,
              apresentacao: apresentacao,
              dados: dados,
              participantes: participantes,
              enderecoFoto: api.enderecoArquivo(
                  apresentacao.fotoRetrospectivaUrl ??
                      apresentacao.perfilArtistico.fotoUrl),
              temFotoPropria: apresentacao.fotoRetrospectivaUrl != null,
              enviandoFoto: _enviandoFoto,
              escolherFoto: _escolherFotoDoEncontro,
              gerandoImagem: _gerandoCartao,
              baixarImagem: _baixarCartao,
              copiar: () => _copiarRetrospectiva(context, dados, participantes),
            ),
          ];
          // Depois do show, a retrospectiva é o que importa: vai para o topo.
          // Durante o show, fica no fim sem empurrar os números para baixo.
          final encerrada = apresentacao.status == StatusApresentacao.encerrada;
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
              if (encerrada) ...[...retrospectiva, entreSecoes],
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
              if (_resenha) ...[
                entreSecoes,
                const TituloGrupo('Galera da resenha'),
                if (participantes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: EspacoTocaEssa.mini),
                    child: Text(
                      'A galera aparece depois dos primeiros pedidos.',
                      style: secundario,
                    ),
                  )
                else
                  GrupoDeLinhas(
                    linhas: [
                      for (final participante in participantes)
                        _LinhaParticipante(
                          participante: participante,
                          enderecoFoto:
                              api.enderecoArquivo(participante.fotoUrl),
                        ),
                    ],
                  ),
              ],
              if (!encerrada) ...[entreSecoes, ...retrospectiva],
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
