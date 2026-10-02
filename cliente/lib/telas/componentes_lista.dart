import 'package:flutter/material.dart';

import '../tema/tema_toca_essa.dart';

/// Título curto de uma seção, em destaque discreto.
class TituloGrupo extends StatelessWidget {
  const TituloGrupo(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(
          left: EspacoTocaEssa.mini,
          bottom: EspacoTocaEssa.pequeno,
        ),
        child: Text(
          texto,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: CoresTocaEssa.roxoClaro,
                letterSpacing: .4,
              ),
        ),
      );
}

/// Lista agrupada em uma única superfície, com divisórias finas.
class GrupoDeLinhas extends StatelessWidget {
  const GrupoDeLinhas({super.key, required this.linhas});
  final List<Widget> linhas;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: CoresTocaEssa.superficie,
          borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
          border: Border.all(color: CoresTocaEssa.borda),
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              for (final (indice, linha) in linhas.indexed) ...[
                if (indice > 0)
                  const Divider(height: 1, indent: 52, endIndent: 16),
                linha,
              ],
            ],
          ),
        ),
      );
}
