part of 'gerenciar_repertorios.dart';

Future<String?> _pedirNome(
  BuildContext context, {
  required String titulo,
  required String rotulo,
  String? inicial,
}) async {
  final valores = await _abrirFormulario(
    context,
    titulo: titulo,
    rotuloConfirmar: inicial == null ? 'Criar' : 'Salvar',
    campos: [
      _CampoDoFormulario(
        rotulo: rotulo,
        inicial: inicial,
        dica: 'Ex.: Barzinho, Casamento',
        obrigatorio: true,
        capitalizacao: TextCapitalization.words,
      ),
    ],
  );
  return valores?.first;
}

Future<(String titulo, String? artista, String? tom)?> _pedirMusica(
  BuildContext context, {
  String? tituloInicial,
  String? artistaInicial,
  String? tomInicial,
}) async {
  final editando = tituloInicial != null;
  final valores = await _abrirFormulario(
    context,
    titulo: editando ? 'Editar música' : 'Adicionar música',
    rotuloConfirmar: editando ? 'Salvar' : 'Adicionar',
    campos: [
      _CampoDoFormulario(
        rotulo: 'Música',
        inicial: tituloInicial,
        dica: 'Nome da música',
        obrigatorio: true,
        capitalizacao: TextCapitalization.words,
      ),
      _CampoDoFormulario(
        rotulo: 'Artista',
        inicial: artistaInicial,
        dica: 'Opcional',
        capitalizacao: TextCapitalization.words,
      ),
      _CampoDoFormulario(
        rotulo: 'Tom preferido',
        inicial: tomInicial,
        dica: 'Opcional. Ex.: Lá, Mi, Ré menor',
        capitalizacao: TextCapitalization.sentences,
      ),
    ],
  );
  if (valores == null) return null;
  final [titulo, artista, tom] = valores;
  return (titulo, artista.isEmpty ? null : artista, tom.isEmpty ? null : tom);
}

class _CampoDoFormulario {
  const _CampoDoFormulario({
    required this.rotulo,
    this.inicial,
    this.dica,
    this.obrigatorio = false,
    this.capitalizacao = TextCapitalization.none,
  });

  final String rotulo;
  final String? inicial;
  final String? dica;
  final bool obrigatorio;
  final TextCapitalization capitalizacao;
}

/// Formulário em tela cheia: campos no topo e confirmação na barra superior,
/// onde o teclado virtual nunca cobre os botões. Devolve os textos aparados.
Future<List<String>?> _abrirFormulario(
  BuildContext context, {
  required String titulo,
  required String rotuloConfirmar,
  required List<_CampoDoFormulario> campos,
}) =>
    Navigator.of(context).push<List<String>>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _FormularioEmTelaCheia(
        titulo: titulo,
        rotuloConfirmar: rotuloConfirmar,
        campos: campos,
      ),
    ));

class _FormularioEmTelaCheia extends StatefulWidget {
  const _FormularioEmTelaCheia({
    required this.titulo,
    required this.rotuloConfirmar,
    required this.campos,
  });

  final String titulo;
  final String rotuloConfirmar;
  final List<_CampoDoFormulario> campos;

  @override
  State<_FormularioEmTelaCheia> createState() => _FormularioEmTelaCheiaState();
}

class _FormularioEmTelaCheiaState extends State<_FormularioEmTelaCheia> {
  late final List<TextEditingController> _controles = [
    for (final campo in widget.campos)
      TextEditingController(text: campo.inicial ?? ''),
  ];

  @override
  void dispose() {
    for (final controle in _controles) {
      controle.dispose();
    }
    super.dispose();
  }

  void _confirmar() {
    final valores = [for (final c in _controles) c.text.trim()];
    for (var i = 0; i < widget.campos.length; i++) {
      if (widget.campos[i].obrigatorio && valores[i].isEmpty) return;
    }
    Navigator.pop(context, valores);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Fechar',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.titulo),
          actions: [
            TextButton(
              onPressed: _confirmar,
              child: Text(widget.rotuloConfirmar),
            ),
            const SizedBox(width: EspacoTocaEssa.pequeno),
          ],
        ),
        body: ConteudoMobile(
          filho: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < widget.campos.length; i++) ...[
                if (i > 0) const SizedBox(height: EspacoTocaEssa.base + 4),
                CampoTexto(
                  rotulo: widget.campos[i].rotulo,
                  controlador: _controles[i],
                  dica: widget.campos[i].dica,
                  focoAutomatico: i == 0,
                  capitalizacao: widget.campos[i].capitalizacao,
                  acaoTeclado: i == widget.campos.length - 1
                      ? TextInputAction.done
                      : TextInputAction.next,
                  aoEnviar: i == widget.campos.length - 1
                      ? (_) => _confirmar()
                      : null,
                ),
              ],
            ],
          ),
        ),
      );
}
