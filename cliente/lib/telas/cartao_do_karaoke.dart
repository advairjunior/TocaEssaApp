import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_memoria.dart';
import 'foto_do_cartao.dart';

part 'cartao_do_karaoke_conteudo.dart';

/// Cartão 9:16 do karaokê: a foto ocupa tudo, a marca e o nome em cima e
/// os números embaixo.
class CartaoDoKaraoke extends StatelessWidget {
  const CartaoDoKaraoke({
    super.key,
    required this.conteudo,
    required this.enderecoFoto,
    this.foto,
    this.fundo,
  });

  final ConteudoDoCartaoDoKaraoke conteudo;

  /// Foto do encontro, quando não há foto própria.
  final String? enderecoFoto;
  final Uint8List? foto;

  /// Substitui a foto, como a prévia da câmera do app.
  final Widget? fundo;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 9 / 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: ColoredBox(
            color: const Color(0xFF100B18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                fundo ??
                    FotoDoCartao(
                      endereco: enderecoFoto,
                      imagem: foto == null ? null : MemoryImage(foto!),
                    ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      // Faixa do meio transparente: a foto precisa aparecer.
                      colors: [
                        Color(0xB308050D),
                        Color(0x0008050D),
                        Color(0x0008050D),
                        Color(0xF208050D),
                      ],
                      stops: [0, .3, .5, .92],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(color: Colors.white),
                    child: _TextosDoCartao(conteudo),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _TextosDoCartao extends StatelessWidget {
  const _TextosDoCartao(this.conteudo);
  final ConteudoDoCartaoDoKaraoke conteudo;

  @override
  Widget build(BuildContext context) {
    final destaque = conteudo.destaque;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset('assets/marca/toca_essa_icone.png',
                width: 28,
                height: 28,
                errorBuilder: (_, __, ___) =>
                    const SizedBox.square(dimension: 28)),
            const SizedBox(width: 8),
            const Text('TocaEssa',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const Spacer(),
            const Icon(Icons.mic_external_on_rounded,
                color: CoresTocaEssa.rosa, size: 22),
          ],
        ),
        const SizedBox(height: 18),
        if (conteudo.selo case final selo?) _SeloDaVoz(selo),
        Text(conteudo.titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        Text(conteudo.subtitulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFD8CFDF))),
        const Spacer(),
        if (destaque != null) ...[
          Text(destaque.$1.toUpperCase(),
              style: const TextStyle(
                  color: CoresTocaEssa.roxoClaro,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(destaque.$2,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xBB100B18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF665578)),
          ),
          child: Row(
            children: [
              for (final (valor, rotulo) in conteudo.numeros)
                Expanded(
                  child: Column(
                    children: [
                      Text(valor,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      Text(rotulo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11,
                              color: CoresTocaEssa.textoSecundario)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SeloDaVoz extends StatelessWidget {
  const _SeloDaVoz(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0x33000000),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: CoresTocaEssa.ouro),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded,
                size: 16, color: CoresTocaEssa.ouro),
            const SizedBox(width: 6),
            Text(texto.toUpperCase(),
                style: const TextStyle(
                    color: CoresTocaEssa.ouro,
                    fontSize: 12,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

/// O cartão na tela, com o botão de compartilhar e a foto própria.
class CompartilharCartaoDoKaraoke extends StatefulWidget {
  const CompartilharCartaoDoKaraoke({
    super.key,
    required this.titulo,
    required this.conteudo,
    required this.enderecoFoto,
    required this.nomeDoArquivo,
  });

  final String titulo;
  final ConteudoDoCartaoDoKaraoke conteudo;
  final String? enderecoFoto;
  final String nomeDoArquivo;

  @override
  State<CompartilharCartaoDoKaraoke> createState() =>
      _CompartilharCartaoDoKaraokeState();
}

class _CompartilharCartaoDoKaraokeState
    extends State<CompartilharCartaoDoKaraoke> {
  final _chave = GlobalKey();
  Uint8List? _foto;
  bool _gerando = false;

  Future<void> _escolherFoto() async {
    final foto = await escolherFotoDoCartao(context,
        cartao: (_, fundo) => CartaoDoKaraoke(
            conteudo: widget.conteudo, enderecoFoto: null, fundo: fundo));
    if (foto != null && mounted) setState(() => _foto = foto);
  }

  Future<void> _compartilhar() async {
    setState(() => _gerando = true);
    try {
      await compartilharCartaoComoImagem(_chave, widget.nomeDoArquivo);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: EspacoTocaEssa.grande),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.titulo, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: EspacoTocaEssa.mini),
            Text('Um cartão no formato de story: tire uma selfie com a galera.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: CoresTocaEssa.textoSecundario)),
            const SizedBox(height: EspacoTocaEssa.base),
            RepaintBoundary(
              key: _chave,
              child: CartaoDoKaraoke(
                  conteudo: widget.conteudo,
                  enderecoFoto: widget.enderecoFoto,
                  foto: _foto),
            ),
            const SizedBox(height: EspacoTocaEssa.base),
            FilledButton.icon(
              onPressed: _gerando ? null : _compartilhar,
              icon: const Icon(Icons.ios_share_rounded),
              label:
                  Text(_gerando ? 'Gerando imagem...' : 'Compartilhar imagem'),
            ),
            TextButton.icon(
              onPressed: _escolherFoto,
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: Text(_foto == null ? 'Tirar uma selfie' : 'Trocar a foto'),
            ),
          ],
        ),
      );
}
