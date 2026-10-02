import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/baixar_arquivo.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'fundo_toca_essa.dart';

/// Números e destaques de um ano de encontros do público.
class ResumoDoAno {
  const ResumoDoAno({
    required this.encontros,
    required this.pedidos,
    required this.tocadas,
    required this.artistas,
    this.musicaDoAno,
    this.parceriaDoAno,
  });

  final int encontros;
  final int pedidos;
  final int tocadas;
  final List<String> artistas;
  final String? musicaDoAno;
  final String? parceriaDoAno;

  factory ResumoDoAno.de(List<EncontroDoPublico> encontros) {
    // Músicas somadas sem diferenciar maiúsculas; empate fica com a que
    // apareceu primeiro.
    final musicas = <String, (String, int)>{};
    final parcerias = <String, (String, int)>{};
    final artistas = <String>[];
    for (final encontro in encontros) {
      for (final musica in encontro.minhasMusicas) {
        final chave = musica.musica.trim().toLowerCase();
        final (nome, total) = musicas[chave] ?? (musica.musica.trim(), 0);
        musicas[chave] = (nome, total + musica.quantidade);
      }
      for (final pessoa in encontro.companhia) {
        final (nome, total) = parcerias[pessoa.publicoId] ?? (pessoa.nome, 0);
        parcerias[pessoa.publicoId] = (nome, total + 1);
      }
      final artista = encontro.apresentacao.perfilArtistico.nomeArtistico;
      if (!artistas.contains(artista)) artistas.add(artista);
    }
    String? maisFrequente(Map<String, (String, int)> contagem) {
      String? escolhido;
      var maior = 0;
      for (final (nome, total) in contagem.values) {
        if (total > maior) {
          escolhido = nome;
          maior = total;
        }
      }
      return escolhido;
    }

    return ResumoDoAno(
      encontros: encontros.length,
      pedidos: encontros.fold(0, (soma, e) => soma + e.pedidos),
      tocadas: encontros.fold(0, (soma, e) => soma + e.pedidosTocados),
      artistas: artistas,
      musicaDoAno: maisFrequente(musicas),
      parceriaDoAno: maisFrequente(parcerias),
    );
  }
}

/// Retrospectiva de um ano inteiro, pronta para virar imagem e ser
/// compartilhada.
class RetrospectivaDoAno extends StatefulWidget {
  const RetrospectivaDoAno({
    super.key,
    required this.ano,
    required this.nome,
    required this.encontros,
  });

  final int ano;
  final String nome;
  final List<EncontroDoPublico> encontros;

  @override
  State<RetrospectivaDoAno> createState() => _RetrospectivaDoAnoState();
}

class _RetrospectivaDoAnoState extends State<RetrospectivaDoAno> {
  final _chaveCartao = GlobalKey();
  bool _gerando = false;

  Future<void> _salvar() async {
    setState(() => _gerando = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final limite = _chaveCartao.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (limite == null) throw StateError('Não foi possível gerar a imagem.');
      final proporcao = (1080 / limite.size.width).clamp(1.0, 4.0).toDouble();
      final imagem = await limite.toImage(pixelRatio: proporcao);
      final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
      if (dados == null) throw StateError('Não foi possível gerar a imagem.');
      baixarArquivo(
          dados.buffer.asUint8List(), 'tocaessa-meu-${widget.ano}.png');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sua retrospectiva do ano foi salva.')),
      );
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumo = ResumoDoAno.de(widget.encontros);
    return Scaffold(
      appBar: AppBar(title: Text('Meu ${widget.ano}')),
      body: FundoTocaEssa(
        variante: VarianteFundoTocaEssa.atmosfera,
        intensidade: IntensidadeFundoTocaEssa.suave,
        child: ConteudoMobile(
          filho: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RepaintBoundary(
                key: _chaveCartao,
                child: _CartaoDoAno(
                  ano: widget.ano,
                  nome: widget.nome,
                  resumo: resumo,
                ),
              ),
              const SizedBox(height: EspacoTocaEssa.base),
              FilledButton.icon(
                onPressed: _gerando ? null : _salvar,
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(_gerando
                    ? 'Gerando imagem...'
                    : 'Salvar imagem para compartilhar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaoDoAno extends StatelessWidget {
  const _CartaoDoAno({
    required this.ano,
    required this.nome,
    required this.resumo,
  });

  final int ano;
  final String nome;
  final ResumoDoAno resumo;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 9 / 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF3A1C6E),
                  CoresTocaEssa.destaqueFundo,
                  Color(0xFF100B18),
                ],
                stops: [0, .45, 1],
              ),
            ),
            child: Stack(
              children: [
                const Positioned(
                  right: -40,
                  top: 120,
                  child: Icon(Icons.graphic_eq_rounded,
                      size: 260, color: Color(0x14FFFFFF)),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset('assets/marca/toca_essa_icone.png',
                              width: 30, height: 30),
                          const SizedBox(width: 8),
                          const Text('TocaEssa',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text('Meu $ano',
                          style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              height: 1.1)),
                      Text(nome,
                          style: const TextStyle(
                              fontSize: 18, color: Color(0xFFD8CFDF))),
                      const Spacer(),
                      if (resumo.musicaDoAno != null)
                        _Destaque(
                            rotulo: 'MÚSICA DO ANO',
                            valor: resumo.musicaDoAno!),
                      if (resumo.parceriaDoAno != null)
                        _Destaque(
                            rotulo: 'PARCERIA DO ANO',
                            valor: resumo.parceriaDoAno!),
                      if (resumo.artistas.isNotEmpty)
                        _Destaque(
                          rotulo: 'QUEM ME FEZ CANTAR',
                          valor: resumo.artistas.take(3).join(' · '),
                          tamanho: 16,
                        ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xBB100B18),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF665578)),
                        ),
                        child: Row(
                          children: [
                            _Numero(
                                valor: resumo.encontros,
                                rotulo: resumo.encontros == 1
                                    ? 'encontro'
                                    : 'encontros'),
                            _Numero(
                                valor: resumo.pedidos,
                                rotulo:
                                    resumo.pedidos == 1 ? 'pedido' : 'pedidos'),
                            _Numero(
                                valor: resumo.tocadas,
                                rotulo:
                                    resumo.tocadas == 1 ? 'tocada' : 'tocadas'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Destaque extends StatelessWidget {
  const _Destaque({
    required this.rotulo,
    required this.valor,
    this.tamanho = 22,
  });

  final String rotulo;
  final String valor;
  final double tamanho;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotulo,
                style: const TextStyle(
                    color: CoresTocaEssa.roxoClaro,
                    fontSize: 11,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(valor,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: tamanho, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _Numero extends StatelessWidget {
  const _Numero({required this.valor, required this.rotulo});
  final int valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text('$valor',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            Text(rotulo,
                style: const TextStyle(
                    fontSize: 11, color: CoresTocaEssa.textoSecundario)),
          ],
        ),
      );
}
