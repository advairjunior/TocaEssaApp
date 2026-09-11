import 'package:flutter/material.dart';

import '../tema/tema_toca_essa.dart';

enum VarianteFundoTocaEssa { palco, bastidores, atmosfera }

enum IntensidadeFundoTocaEssa { imersiva, suave, cabecalho }

class FundoTocaEssa extends StatelessWidget {
  const FundoTocaEssa({
    super.key,
    required this.child,
    required this.variante,
    this.intensidade = IntensidadeFundoTocaEssa.suave,
  });

  final Widget child;
  final VarianteFundoTocaEssa variante;
  final IntensidadeFundoTocaEssa intensidade;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, limites) {
          final cabecalho = intensidade == IntensidadeFundoTocaEssa.cabecalho;
          final alinhamento =
              variante == VarianteFundoTocaEssa.palco && limites.maxWidth < 700
                  ? const Alignment(-.72, -.15)
                  : Alignment.topCenter;

          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -.85),
                    radius: 1.15,
                    colors: [Color(0xFF24143C), CoresTocaEssa.fundo],
                    stops: [0, .72],
                  ),
                ),
              ),
              _composicaoVisual(
                cabecalho: cabecalho,
                imagem: Image.asset(
                  _caminhoDaImagem(variante),
                  fit: BoxFit.cover,
                  alignment: alinhamento,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.expand(),
                ),
                contraste: DecoratedBox(
                  decoration: BoxDecoration(gradient: _gradienteContraste),
                ),
              ),
              child,
            ],
          );
        },
      );

  Widget _composicaoVisual({
    required bool cabecalho,
    required Widget imagem,
    required Widget contraste,
  }) {
    final composicao = Stack(
      fit: StackFit.expand,
      children: [imagem, contraste],
    );

    return cabecalho
        ? Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: double.infinity,
              height: 280,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (limites) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: [0, .65, 1],
                ).createShader(limites),
                child: composicao,
              ),
            ),
          )
        : Positioned.fill(child: composicao);
  }

  String _caminhoDaImagem(VarianteFundoTocaEssa variante) => switch (variante) {
        VarianteFundoTocaEssa.palco => 'assets/fundos/inicio_palco.png',
        VarianteFundoTocaEssa.bastidores => 'assets/fundos/bastidores.png',
        VarianteFundoTocaEssa.atmosfera => 'assets/fundos/atmosfera.png',
      };

  Gradient get _gradienteContraste => switch (intensidade) {
        IntensidadeFundoTocaEssa.imersiva => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Color(0x1A0A0610),
              Color(0x8008050D),
            ],
            stops: [0, .58, 1],
          ),
        IntensidadeFundoTocaEssa.suave => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x1408050D),
              Color(0x6608050D),
              Color(0xB308050D),
            ],
            stops: [0, .58, 1],
          ),
        IntensidadeFundoTocaEssa.cabecalho => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x8008050D), Colors.transparent],
          ),
      };
}
