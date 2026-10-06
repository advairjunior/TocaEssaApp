import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Envolve o conteúdo da alça (o ícone) com os gestos de reordenar.
typedef ConstrutorDaAlca = Widget Function(Widget conteudo);

/// Lista que o artista reordena arrastando a alça, segurando a linha ou
/// tocando na alça e escolhendo para onde mover.
///
/// Usa só arrastar vertical e toque longo, os mesmos gestos da rolagem.
/// A lista reordenável do Flutter depende de um reconhecedor de "arrasto
/// múltiplo" que não respondia no Safari do iPhone.
class ListaReordenavel extends StatefulWidget {
  const ListaReordenavel({
    super.key,
    required this.quantidade,
    required this.chaveDoItem,
    required this.construirItem,
    required this.aoReordenar,
    this.segurarParaArrastar = false,
    this.habilitada = true,
  });

  final int quantidade;
  final Key Function(int indice) chaveDoItem;

  /// Monta o item do [indice]; [alca] envolve o ícone de arrastar.
  final Widget Function(BuildContext context, int indice, ConstrutorDaAlca alca)
      construirItem;

  /// Avisado ao soltar, com a posição final já ajustada.
  final void Function(int de, int para) aoReordenar;

  /// Segurar a linha inteira também começa a arrastar.
  final bool segurarParaArrastar;
  final bool habilitada;

  @override
  State<ListaReordenavel> createState() => _ListaReordenavelState();
}

class _ListaReordenavelState extends State<ListaReordenavel> {
  final _chavesDeMedida = <Key, GlobalKey>{};

  /// Ordem visível durante o arrasto, em índices originais.
  List<int>? _ordem;
  int? _origem;
  double _deslocamento = 0;
  Offset _ultimoPontoDoToque = Offset.zero;

  int? get _posicaoArrastada => _ordem?.indexOf(_origem!);

  GlobalKey _chaveDeMedida(int indice) => _chavesDeMedida.putIfAbsent(
      widget.chaveDoItem(indice), () => GlobalKey());

  double _altura(int indice) =>
      _chaveDeMedida(indice).currentContext?.size?.height ?? 0;

  void _iniciar(int indice) {
    if (!widget.habilitada || _ordem != null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _ordem = List.generate(widget.quantidade, (i) => i);
      _origem = indice;
      _deslocamento = 0;
    });
  }

  // Troca de lugar com o vizinho assim que o item passa da metade dele.
  void _mover(double dy) {
    final ordem = _ordem;
    if (ordem == null) return;
    setState(() {
      _deslocamento += dy;
      var posicao = _posicaoArrastada!;
      while (posicao < ordem.length - 1) {
        final vizinho = _altura(ordem[posicao + 1]);
        if (_deslocamento <= vizinho / 2) break;
        ordem.insert(posicao + 1, ordem.removeAt(posicao));
        _deslocamento -= vizinho;
        posicao++;
      }
      while (posicao > 0) {
        final vizinho = _altura(ordem[posicao - 1]);
        if (_deslocamento >= -vizinho / 2) break;
        ordem.insert(posicao - 1, ordem.removeAt(posicao));
        _deslocamento += vizinho;
        posicao--;
      }
    });
  }

  void _terminar() {
    final origem = _origem;
    final destino = _posicaoArrastada;
    setState(() {
      _ordem = null;
      _origem = null;
      _deslocamento = 0;
    });
    if (origem != null && destino != null && origem != destino) {
      widget.aoReordenar(origem, destino);
    }
  }

  Future<void> _oferecerMover(BuildContext contexto, int indice) async {
    if (!widget.habilitada) return;
    final caixa = contexto.findRenderObject()! as RenderBox;
    final sobreposicao =
        Overlay.of(contexto).context.findRenderObject()! as RenderBox;
    final posicao = RelativeRect.fromRect(
      Rect.fromPoints(
        caixa.localToGlobal(Offset.zero, ancestor: sobreposicao),
        caixa.localToGlobal(caixa.size.bottomRight(Offset.zero),
            ancestor: sobreposicao),
      ),
      Offset.zero & sobreposicao.size,
    );
    final ultimo = widget.quantidade - 1;
    final destino = await showMenu<int>(
      context: contexto,
      position: posicao,
      items: [
        if (indice > 0) ...[
          const PopupMenuItem(value: 0, child: Text('Mover para o topo')),
          PopupMenuItem(
              value: indice - 1, child: const Text('Mover para cima')),
        ],
        if (indice < ultimo)
          PopupMenuItem(
              value: indice + 1, child: const Text('Mover para baixo')),
      ],
    );
    if (destino != null && destino != indice && mounted) {
      widget.aoReordenar(indice, destino);
    }
  }

  Widget _alca(int indice, Widget conteudo) => Builder(
        builder: (contexto) => Semantics(
          label: 'Arrastar para reordenar',
          button: true,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onTap: () => _oferecerMover(contexto, indice),
            onVerticalDragStart: (_) => _iniciar(indice),
            onVerticalDragUpdate: (detalhes) => _mover(detalhes.delta.dy),
            onVerticalDragEnd: (_) => _terminar(),
            onVerticalDragCancel: _terminar,
            child: conteudo,
          ),
        ),
      );

  Widget _segurarLinha(int indice, Widget item) => GestureDetector(
        onLongPressStart: (detalhes) {
          _ultimoPontoDoToque = detalhes.globalPosition;
          _iniciar(indice);
        },
        onLongPressMoveUpdate: (detalhes) {
          _mover(detalhes.globalPosition.dy - _ultimoPontoDoToque.dy);
          _ultimoPontoDoToque = detalhes.globalPosition;
        },
        onLongPressEnd: (_) => _terminar(),
        onLongPressCancel: () {
          if (_ordem != null) _terminar();
        },
        child: item,
      );

  @override
  Widget build(BuildContext context) {
    final ordem = _ordem ?? List.generate(widget.quantidade, (i) => i);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final indice in ordem)
          KeyedSubtree(
            key: widget.chaveDoItem(indice),
            child: _itemNaPosicao(context, indice),
          ),
      ],
    );
  }

  Widget _itemNaPosicao(BuildContext context, int indice) {
    Widget item = KeyedSubtree(
      key: _chaveDeMedida(indice),
      child: widget.construirItem(
          context, indice, (conteudo) => _alca(indice, conteudo)),
    );
    if (widget.segurarParaArrastar && widget.habilitada) {
      item = _segurarLinha(indice, item);
    }
    // O item arrastado acompanha o dedo, levemente destacado. A estrutura é
    // a mesma para todos: trocar de widget no meio do gesto o cancelaria.
    final arrastado = indice == _origem;
    return Transform.translate(
      offset: Offset(0, arrastado ? _deslocamento : 0),
      child: AnimatedScale(
        scale: arrastado ? 1.02 : 1,
        duration: const Duration(milliseconds: 120),
        child: item,
      ),
    );
  }
}
