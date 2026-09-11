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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(apresentacao.nome,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                '${formatarData(apresentacao.data)} · ${apresentacao.local}',
                style: const TextStyle(color: CoresTocaEssa.textoSecundario),
              ),
              if (apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos) ...[
                const SizedBox(height: 20),
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
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2B1748), CoresTocaEssa.superficie],
                  ),
                  border: Border.all(color: const Color(0xFF503778)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFFFC857), size: 42),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dados.mediaAvaliacoes?.toStringAsFixed(1) ?? '—',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(
                            dados.avaliados == 0
                                ? 'Ainda sem avaliações'
                                : '${dados.avaliados} ${dados.avaliados == 1 ? 'avaliação recebida' : 'avaliações recebidas'}',
                            style: const TextStyle(
                              color: CoresTocaEssa.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, limites) {
                final largura = (limites.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _NumeroEstatistica(
                        largura: largura,
                        numero: dados.totalPedidos,
                        rotulo: 'Pedidos'),
                    _NumeroEstatistica(
                        largura: largura,
                        numero: dados.tocados,
                        rotulo: 'Tocados'),
                    _NumeroEstatistica(
                        largura: largura,
                        numero: dados.aguardando,
                        rotulo: 'Aguardando'),
                    _NumeroEstatistica(
                        largura: largura,
                        numero: dados.recusados,
                        rotulo: 'Não atendidos'),
                  ],
                );
              }),
              const SizedBox(height: 28),
              Text('Músicas mais pedidas',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              if (dados.musicasMaisPedidas.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Os destaques aparecerão quando o público começar a pedir.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                for (var indice = 0;
                    indice < dados.musicasMaisPedidas.length;
                    indice++) ...[
                  _MusicaDoRanking(
                    posicao: indice + 1,
                    musica: dados.musicasMaisPedidas[indice],
                  ),
                  const SizedBox(height: 8),
                ],
              if (apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos) ...[
                const SizedBox(height: 24),
                Text('Galera da resenha',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                const Text(
                  'Participantes que enviaram pedidos nesta Resenha.',
                  style: TextStyle(
                      color: CoresTocaEssa.textoSecundario, fontSize: 12),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<ParticipanteDaResenha>>(
                  future: api
                      .listarParticipantesDaResenhaDoArtista(apresentacao.id),
                  builder: (context, participantesSnapshot) {
                    if (!participantesSnapshot.hasData &&
                        participantesSnapshot.connectionState !=
                            ConnectionState.done) {
                      return const Center(
                          child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ));
                    }
                    final participantes =
                        participantesSnapshot.data ?? const [];
                    if (participantes.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text(
                            'A galera aparecerá depois dos primeiros pedidos.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final participante in participantes) ...[
                          _CartaoParticipante(
                            participante: participante,
                            enderecoFoto:
                                api.enderecoArquivo(participante.fotoUrl),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 24),
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
