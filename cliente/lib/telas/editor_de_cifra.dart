import 'package:flutter/material.dart';

import '../dominio/ajustar_cifra.dart';
import '../dominio/transpor_cifra.dart';
import '../tema/tema_toca_essa.dart';
import 'como_marcar_hinos.dart';

const _tamanhoDaLetra = 15.0;
// Largura de uma letra da JetBrains Mono em relação ao tamanho da fonte.
const _larguraDaLetra = .6;
const _margem = EspacoTocaEssa.base;

/// Tela cheia para colar ou corrigir a cifra; responde o texto já ajustado
/// ou nulo se cancelar.
Future<String?> pedirCifraEmTexto(
  BuildContext context, {
  required String titulo,
  String? texto,
  String oQue = 'Cifra',
}) =>
    Navigator.of(context).push<String>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          _EditorDeCifra(titulo: titulo, texto: texto ?? '', oQue: oQue),
    ));

class _EditorDeCifra extends StatefulWidget {
  const _EditorDeCifra(
      {required this.titulo, required this.texto, required this.oQue});

  final String titulo;
  final String texto;
  // "Cifra" ou, no louvor, "Letra".
  final String oQue;

  @override
  State<_EditorDeCifra> createState() => _EditorDeCifraState();
}

class _EditorDeCifraState extends State<_EditorDeCifra> {
  late final _texto = TextEditingController(text: widget.texto)
    ..addListener(() => setState(() {}));
  var _conferindo = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Cancelar',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('${widget.oQue} de ${widget.titulo}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            // Só na letra do louvor: o que cada marcação faz.
            if (widget.oQue == 'Letra')
              IconButton(
                tooltip: 'Como marcar as partes',
                icon: const Icon(Icons.help_outline_rounded),
                onPressed: () => mostrarComoMarcarAsPartes(context),
              ),
            Padding(
              padding: const EdgeInsets.only(right: EspacoTocaEssa.pequeno),
              child: FilledButton(
                onPressed: () =>
                    Navigator.pop(context, ajustarCifraColada(_texto.text)),
                child: const Text('Salvar'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    _margem, EspacoTocaEssa.pequeno, _margem, 0),
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                        value: false,
                        icon: Icon(Icons.edit_outlined),
                        label: Text('Editar')),
                    ButtonSegment(
                        value: true,
                        icon: Icon(Icons.fact_check_outlined),
                        label: Text('Conferir')),
                  ],
                  selected: {_conferindo},
                  onSelectionChanged: (escolha) {
                    FocusScope.of(context).unfocus();
                    setState(() => _conferindo = escolha.single);
                  },
                ),
              ),
              Expanded(
                child: _conferindo
                    ? _Conferencia(texto: ajustarCifraColada(_texto.text))
                    : _CampoSemQuebra(controlador: _texto),
              ),
            ],
          ),
        ),
      );
}

double _larguraDoTexto(Iterable<String> linhas, double minima) {
  final maior = linhas.fold<int>(
      0, (maior, linha) => linha.length > maior ? linha.length : maior);
  final largura = maior * _tamanhoDaLetra * _larguraDaLetra + _margem * 3;
  return largura > minima ? largura : minima;
}

const _estiloDaCifra = TextStyle(
  fontFamily: 'JetBrainsMono',
  fontSize: _tamanhoDaLetra,
  height: 1.35,
);

/// Campo sem quebra de linha: a linha comprida rola para o lado, para o
/// acorde ficar sempre em cima da sílaba enquanto se edita.
class _CampoSemQuebra extends StatelessWidget {
  const _CampoSemQuebra({required this.controlador});

  final TextEditingController controlador;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, limites) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width:
                _larguraDoTexto(controlador.text.split('\n'), limites.maxWidth),
            height: limites.maxHeight,
            child: TextField(
              controller: controlador,
              autofocus: controlador.text.isEmpty,
              expands: true,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              autocorrect: false,
              enableSuggestions: false,
              style: _estiloDaCifra.copyWith(color: CoresTocaEssa.texto),
              decoration: const InputDecoration(
                hintText: 'Cole aqui a letra com os acordes',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.all(_margem),
              ),
            ),
          ),
        ),
      );
}

/// A cifra como o app entendeu: acordes reconhecidos em roxo e aviso nas
/// linhas que parecem de acordes mas têm algo que o app não entendeu.
class _Conferencia extends StatelessWidget {
  const _Conferencia({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final linhas = texto.split('\n');
    final problemas =
        linhas.where((linha) => acordesNaoReconhecidos(linha).isNotEmpty);
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              _margem, EspacoTocaEssa.medio, _margem, 0),
          child: Text(
            switch (problemas.length) {
              0 => 'Acordes em roxo mudam de tom.',
              1 => '1 linha para conferir',
              final n => '$n linhas para conferir',
            },
            style: textos.bodyMedium?.copyWith(
                color: problemas.isEmpty
                    ? CoresTocaEssa.textoSecundario
                    : CoresTocaEssa.atencao),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, limites) => SingleChildScrollView(
              padding: const EdgeInsets.all(_margem),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: limites.maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final linha in linhas) ..._linha(linha, textos),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _linha(String linha, TextTheme textos) {
    if (linha.trim().isEmpty) {
      return const [SizedBox(height: _tamanhoDaLetra * .9)];
    }
    final estranhas = acordesNaoReconhecidos(linha);
    return [
      Text(linha,
          softWrap: false,
          style: _estiloDaCifra.copyWith(
            color: linhaDeAcordes(linha)
                ? CoresTocaEssa.roxoClaro
                : estranhas.isEmpty
                    ? CoresTocaEssa.texto
                    : CoresTocaEssa.atencao,
          )),
      if (estranhas.isNotEmpty)
        Text('Não entendi: ${estranhas.join(', ')}',
            style: textos.bodySmall?.copyWith(color: CoresTocaEssa.atencao)),
    ];
  }
}
