import 'package:flutter/material.dart';

import '../tema/tema_toca_essa.dart';

/// "b  Tom A (+2)  #" numa pílula só: bemol e sustenido descem e sobem meio
/// tom; tocar no tom mudado volta ao original.
class ControleDoTom extends StatelessWidget {
  const ControleDoTom({
    super.key,
    required this.tom,
    required this.original,
    required this.semitons,
    required this.mudarTom,
  });

  final String tom;
  final String? original;
  final int semitons;
  final ValueChanged<int> mudarTom;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    const cor = CoresTocaEssa.roxoClaro;
    Widget sinal(String simbolo, String dica, int passo) => IconButton(
          tooltip: dica,
          onPressed: () => mudarTom(passo),
          icon: Text(simbolo,
              style: texto.headlineSmall?.copyWith(color: cor, height: 1)),
        );
    final rotulo = Text(tom,
        style: texto.titleMedium
            ?.copyWith(color: cor, fontWeight: FontWeight.w700));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: cor.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
            border: Border.all(color: cor.withValues(alpha: .5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              sinal('b', 'Baixar meio tom', -1),
              semitons == 0
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: EspacoTocaEssa.pequeno),
                      child: rotulo,
                    )
                  : Tooltip(
                      message: 'Voltar ao tom original',
                      child: TextButton(
                        onPressed: () => mudarTom(-semitons),
                        child: rotulo,
                      ),
                    ),
              sinal('#', 'Subir meio tom', 1),
            ],
          ),
        ),
        if (semitons != 0 && original != null) ...[
          const SizedBox(height: EspacoTocaEssa.mini),
          Text('Toque no tom para voltar ao $original',
              style: texto.labelSmall
                  ?.copyWith(color: CoresTocaEssa.textoSecundario)),
        ],
      ],
    );
  }
}
