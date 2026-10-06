import 'package:flutter/material.dart';

import '../tema/tema_toca_essa.dart';

/// Quantas pessoas estão no evento pelo app e quantas já pediram música.
/// Ao vivo, dá uma dica quando os números sugerem que algo não está bem.
class PublicoNoApp extends StatelessWidget {
  const PublicoNoApp({
    super.key,
    required this.pessoas,
    required this.pediram,
    this.mostrarDica = true,
  });

  final int pessoas;
  final int pediram;
  final bool mostrarDica;

  // A partir de quantas pessoas sem nenhum pedido vale desconfiar do app.
  static const _pessoasSemPedidoParaDica = 5;

  String get _resumo {
    if (pessoas == 0) return 'Ninguém abriu o evento pelo app ainda';
    final quem = pessoas == 1 ? '1 pessoa' : '$pessoas pessoas';
    final pedidos = switch (pediram) {
      0 => 'ninguém pediu ainda',
      1 => '1 pediu música',
      _ => '$pediram pediram música',
    };
    return '$quem no app · $pedidos';
  }

  String? get _dica {
    if (!mostrarDica) return null;
    if (pessoas == 0) return 'Mostre o QR Code para a galera entrar.';
    if (pessoas >= _pessoasSemPedidoParaDica && pediram == 0) {
      return 'Vale perguntar à galera se o app está funcionando.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final dica = _dica;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.groups_rounded,
              size: 20, color: CoresTocaEssa.roxoClaro),
        ),
        const SizedBox(width: EspacoTocaEssa.pequeno),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_resumo, style: texto.titleSmall),
              if (dica != null)
                Text(
                  dica,
                  style: texto.bodySmall
                      ?.copyWith(color: CoresTocaEssa.textoSecundario),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
