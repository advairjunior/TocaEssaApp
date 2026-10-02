import 'package:flutter/material.dart';

import '../tema/tema_toca_essa.dart';
import 'componentes_formulario.dart';

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
  const GrupoDeLinhas({
    super.key,
    required this.linhas,
    this.recuoDivisoria = 52,
  });
  final List<Widget> linhas;

  /// Recuo à esquerda das divisórias, para alinhar ao texto das linhas.
  final double recuoDivisoria;

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
                  Divider(
                    height: 1,
                    indent: recuoDivisoria,
                    endIndent: 16,
                  ),
                linha,
              ],
            ],
          ),
        ),
      );
}

/// Mensagem para listas vazias: ícone, título e uma frase de orientação.
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.descricao,
  });

  final IconData icone;
  final String titulo;
  final String descricao;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: EspacoTocaEssa.grande,
        vertical: EspacoTocaEssa.enorme + 8,
      ),
      child: Column(
        children: [
          Icon(icone, size: 40, color: CoresTocaEssa.roxoClaro),
          const SizedBox(height: EspacoTocaEssa.base),
          Text(titulo, textAlign: TextAlign.center, style: texto.titleLarge),
          const SizedBox(height: EspacoTocaEssa.pequeno),
          Text(
            descricao,
            textAlign: TextAlign.center,
            style: texto.bodyMedium
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
        ],
      ),
    );
  }
}

/// Aba em texto com contador e sublinhado curto quando selecionada.
class AbaDeTexto extends StatelessWidget {
  const AbaDeTexto({
    super.key,
    required this.rotulo,
    required this.quantidade,
    required this.selecionada,
    required this.tocar,
  });

  final String rotulo;
  final int quantidade;
  final bool selecionada;
  final VoidCallback tocar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final cor =
        selecionada ? CoresTocaEssa.texto : CoresTocaEssa.textoSecundario;
    return Semantics(
      selected: selecionada,
      button: true,
      child: InkWell(
        onTap: tocar,
        borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: EspacoTocaEssa.mini,
            vertical: EspacoTocaEssa.pequeno,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      rotulo,
                      overflow: TextOverflow.ellipsis,
                      style: texto.titleMedium?.copyWith(color: cor),
                    ),
                  ),
                  const SizedBox(width: EspacoTocaEssa.pequeno - 2),
                  Text(
                    '$quantidade',
                    style: texto.labelLarge
                        ?.copyWith(color: CoresTocaEssa.textoSecundario),
                  ),
                ],
              ),
              const SizedBox(height: EspacoTocaEssa.pequeno - 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 3,
                width: selecionada ? 28 : 0,
                decoration: BoxDecoration(
                  color: CoresTocaEssa.roxoClaro,
                  borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linha de lista com a data em bloco (mês e dia), título e subtítulo.
class LinhaComData extends StatelessWidget {
  const LinhaComData({
    super.key,
    required this.data,
    required this.titulo,
    required this.subtitulo,
    required this.tocar,
  });

  final DateTime data;
  final String titulo;
  final String subtitulo;
  final VoidCallback tocar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: tocar,
        child: Padding(
          padding: const EdgeInsets.all(EspacoTocaEssa.base),
          child: Row(
            children: [
              _BlocoData(data: data),
              const SizedBox(width: EspacoTocaEssa.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texto.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texto.bodyMedium
                          ?.copyWith(color: CoresTocaEssa.textoSecundario),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: EspacoTocaEssa.mini),
              const Icon(Icons.chevron_right_rounded,
                  color: CoresTocaEssa.textoSecundario),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlocoData extends StatelessWidget {
  const _BlocoData({required this.data});
  final DateTime data;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: EspacoTocaEssa.pequeno),
      decoration: BoxDecoration(
        color: CoresTocaEssa.roxo.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
      ),
      child: Column(
        children: [
          Text(
            mesesAbreviados[data.month - 1],
            style: texto.labelMedium?.copyWith(
              color: CoresTocaEssa.roxoClaro,
              letterSpacing: 1,
            ),
          ),
          Text(data.day.toString().padLeft(2, '0'), style: texto.titleLarge),
        ],
      ),
    );
  }
}
