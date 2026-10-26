import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'componentes_memoria.dart';

/// Foto mais larga que alta: a do grupo enviada da galeria, que no cartão em
/// pé perderia as laterais.
bool fotoDeitada(Size tamanho) => tamanho.width > tamanho.height;

/// A foto da retrospectiva no cartão 9:16. Em pé (a selfie da hora) ocupa
/// tudo; deitada aparece inteira, com ela mesma desfocada preenchendo o
/// resto, como nos Stories. Sem foto, o fundo de palco.
class FotoDoCartao extends StatefulWidget {
  const FotoDoCartao({super.key, required this.endereco, this.imagem});

  final String? endereco;

  /// No lugar do endereço, para os testes.
  final ImageProvider? imagem;

  @override
  State<FotoDoCartao> createState() => _FotoDoCartaoState();
}

class _FotoDoCartaoState extends State<FotoDoCartao> {
  ImageStream? _fluxo;
  late final ImageStreamListener _ouvinte =
      ImageStreamListener(_aoCarregar, onError: (_, __) {});
  Size? _tamanho;

  ImageProvider? get _imagem =>
      widget.imagem ??
      (widget.endereco == null ? null : NetworkImage(widget.endereco!));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ouvir();
  }

  @override
  void didUpdateWidget(FotoDoCartao anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.endereco != widget.endereco ||
        anterior.imagem != widget.imagem) {
      _tamanho = null;
      _ouvir();
    }
  }

  void _ouvir() {
    final fluxo = _imagem?.resolve(createLocalImageConfiguration(context));
    if (fluxo?.key == _fluxo?.key) return;
    _fluxo?.removeListener(_ouvinte);
    _fluxo = fluxo?..addListener(_ouvinte);
  }

  void _aoCarregar(ImageInfo info, bool _) {
    final tamanho =
        Size(info.image.width.toDouble(), info.image.height.toDouble());
    if (mounted && tamanho != _tamanho) setState(() => _tamanho = tamanho);
  }

  @override
  void dispose() {
    _fluxo?.removeListener(_ouvinte);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagem = _imagem;
    if (imagem == null) return const CapaDaNoite(endereco: null);
    final tamanho = _tamanho;
    if (tamanho == null || !fotoDeitada(tamanho)) {
      return _foto(imagem, BoxFit.cover);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: _foto(imagem, BoxFit.cover),
        ),
        const ColoredBox(color: Color(0x40000000)),
        // Um pouco acima do meio: embaixo ficam o nome e os números.
        Align(
          alignment: const Alignment(0, -.25),
          child: _foto(imagem, BoxFit.contain, preencher: false),
        ),
      ],
    );
  }

  Widget _foto(ImageProvider imagem, BoxFit ajuste, {bool preencher = true}) =>
      Image(
        image: imagem,
        fit: ajuste,
        width: preencher ? double.infinity : null,
        height: preencher ? double.infinity : null,
        errorBuilder: (_, __, ___) => const CapaDaNoite(endereco: null),
      );
}
