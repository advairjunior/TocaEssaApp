part of 'componentes_formulario.dart';

/// Código em caixas, uma por caractere: aceita letras e números, sempre em
/// maiúsculas, e avisa quando todas as caixas estão preenchidas.
class CampoCodigo extends StatefulWidget {
  const CampoCodigo({
    super.key,
    required this.controlador,
    this.aoCompletar,
    this.tamanho = 6,
    this.rotulo = 'Código da apresentação',
  });

  final TextEditingController controlador;
  final ValueChanged<String>? aoCompletar;
  final int tamanho;
  final String rotulo;

  @override
  State<CampoCodigo> createState() => _CampoCodigoState();
}

class _CampoCodigoState extends State<CampoCodigo> {
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    _foco.addListener(_redesenhar);
    widget.controlador.addListener(_redesenhar);
  }

  @override
  void dispose() {
    widget.controlador.removeListener(_redesenhar);
    _foco.dispose();
    super.dispose();
  }

  void _redesenhar() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final texto = widget.controlador.text;
    final atual = texto.length.clamp(0, widget.tamanho - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: RotuloCampo(widget.rotulo)),
        Stack(
          children: [
            // As caixas são só desenho: o campo abaixo já anuncia o valor, e
            // mudar a árvore de acessibilidade a cada letra derruba o foco no
            // Flutter Web com leitor de tela.
            ExcludeSemantics(
              child: Row(
                children: [
                  for (var indice = 0; indice < widget.tamanho; indice++) ...[
                    if (indice > 0)
                      const SizedBox(width: EspacoTocaEssa.pequeno),
                    Expanded(
                      child: _CaixaDoCodigo(
                        caractere: indice < texto.length ? texto[indice] : null,
                        ativa: _foco.hasFocus && indice == atual,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // O campo real fica invisível sobre as caixas: recebe o toque,
            // o teclado, a colagem e a leitura por leitores de tela.
            Positioned.fill(
              child: Semantics(
                label: widget.rotulo,
                child: TextField(
                  controller: widget.controlador,
                  focusNode: _foco,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  keyboardType: TextInputType.visiblePassword,
                  style: const TextStyle(color: Colors.transparent),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                    _Maiusculas(),
                    LengthLimitingTextInputFormatter(widget.tamanho),
                  ],
                  decoration: const InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                  ),
                  onChanged: (valor) {
                    if (valor.length == widget.tamanho) {
                      widget.aoCompletar?.call(valor);
                    }
                  },
                  onSubmitted: (valor) {
                    if (valor.length == widget.tamanho) {
                      widget.aoCompletar?.call(valor);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CaixaDoCodigo extends StatelessWidget {
  const _CaixaDoCodigo({required this.caractere, required this.ativa});

  final String? caractere;
  final bool ativa;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: CoresTocaEssa.superficieElevada,
          borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
          border: Border.all(
            color: ativa ? CoresTocaEssa.roxoClaro : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          caractere ?? '',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      );
}

class _Maiusculas extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue novo,
  ) =>
      novo.copyWith(text: novo.text.toUpperCase());
}
