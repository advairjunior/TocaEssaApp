import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tema/tema_toca_essa.dart';

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

/// Campo de texto com rótulo acima, sem ícone e sem borda aparente.
class CampoTexto extends StatelessWidget {
  const CampoTexto({
    super.key,
    required this.rotulo,
    required this.controlador,
    this.dica,
    this.ajuda,
    this.teclado,
    this.capitalizacao = TextCapitalization.none,
    this.acaoTeclado,
    this.aoEnviar,
    this.linhas = 1,
    this.comprimentoMaximo,
    this.oculto = false,
    this.focoAutomatico = false,
  });

  final String rotulo;
  final TextEditingController controlador;
  final String? dica;
  final String? ajuda;
  final TextInputType? teclado;
  final TextCapitalization capitalizacao;
  final TextInputAction? acaoTeclado;
  final ValueChanged<String>? aoEnviar;
  final int linhas;
  final int? comprimentoMaximo;

  /// Esconde o texto digitado, como em senhas.
  final bool oculto;

  /// Abre o teclado neste campo assim que a tela aparece.
  final bool focoAutomatico;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RotuloCampo(rotulo),
          TextField(
            controller: controlador,
            autofocus: focoAutomatico,
            keyboardType: teclado,
            textCapitalization: capitalizacao,
            textInputAction: acaoTeclado,
            onSubmitted: aoEnviar,
            minLines: 1,
            maxLines: oculto ? 1 : linhas,
            obscureText: oculto,
            autocorrect: !oculto,
            enableSuggestions: !oculto,
            maxLength: comprimentoMaximo,
            decoration: decoracaoCampoTocaEssa(dica: dica, ajuda: ajuda),
          ),
        ],
      );
}

InputDecoration decoracaoCampoTocaEssa({String? dica, String? ajuda}) {
  OutlineInputBorder borda(Color cor, [double largura = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
        borderSide: BorderSide(color: cor, width: largura),
      );
  return InputDecoration(
    hintText: dica,
    helperText: ajuda,
    helperMaxLines: 3,
    helperStyle: const TextStyle(color: CoresTocaEssa.textoSecundario),
    counterText: '',
    filled: true,
    fillColor: CoresTocaEssa.superficieElevada,
    border: borda(Colors.transparent),
    enabledBorder: borda(Colors.transparent),
    focusedBorder: borda(CoresTocaEssa.roxoClaro, 1.5),
  );
}

class RotuloCampo extends StatelessWidget {
  const RotuloCampo(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(
          left: EspacoTocaEssa.mini,
          bottom: EspacoTocaEssa.pequeno,
        ),
        child: Text(
          texto,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: CoresTocaEssa.textoSecundario),
        ),
      );
}

class OpcaoSeletor<T> {
  const OpcaoSeletor({
    required this.valor,
    required this.titulo,
    required this.descricao,
    required this.icone,
  });

  final T valor;
  final String titulo;
  final String descricao;
  final IconData icone;
}

/// Cartões lado a lado para escolher entre poucas opções.
class SeletorOpcoes<T> extends StatelessWidget {
  const SeletorOpcoes({
    super.key,
    required this.opcoes,
    required this.selecionado,
    required this.aoSelecionar,
  });

  final List<OpcaoSeletor<T>> opcoes;
  final T selecionado;
  final ValueChanged<T> aoSelecionar;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (indice, opcao) in opcoes.indexed) ...[
              if (indice > 0) const SizedBox(width: EspacoTocaEssa.medio),
              Expanded(
                child: _CartaoOpcao(
                  opcao: opcao,
                  selecionada: opcao.valor == selecionado,
                  tocar: () => aoSelecionar(opcao.valor),
                ),
              ),
            ],
          ],
        ),
      );
}

class _CartaoOpcao<T> extends StatelessWidget {
  const _CartaoOpcao({
    required this.opcao,
    required this.selecionada,
    required this.tocar,
  });

  final OpcaoSeletor<T> opcao;
  final bool selecionada;
  final VoidCallback tocar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selecionada,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: tocar,
          borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(EspacoTocaEssa.base),
            decoration: BoxDecoration(
              color: selecionada
                  ? CoresTocaEssa.roxo.withValues(alpha: .16)
                  : CoresTocaEssa.superficieElevada,
              borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
              border: Border.all(
                color:
                    selecionada ? CoresTocaEssa.roxoClaro : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      opcao.icone,
                      color: selecionada
                          ? CoresTocaEssa.roxoClaro
                          : CoresTocaEssa.textoSecundario,
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: selecionada ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: CoresTocaEssa.roxoClaro,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: EspacoTocaEssa.medio),
                Text(opcao.titulo, style: texto.titleMedium),
                const SizedBox(height: EspacoTocaEssa.mini),
                Text(
                  opcao.descricao,
                  style: texto.bodySmall
                      ?.copyWith(color: CoresTocaEssa.textoSecundario),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de data que abre o calendário ao toque.
class CampoData extends StatelessWidget {
  const CampoData({
    super.key,
    required this.rotulo,
    required this.data,
    required this.tocar,
  });

  final String rotulo;
  final DateTime data;
  final VoidCallback tocar;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RotuloCampo(rotulo),
          Material(
            color: CoresTocaEssa.superficieElevada,
            borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
            child: InkWell(
              onTap: tocar,
              borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: EspacoTocaEssa.base,
                  vertical: 17,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatarDataPorExtenso(data),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: CoresTocaEssa.roxoClaro,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
}

const mesesAbreviados = [
  'JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', //
  'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ',
];

const _meses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', //
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

const _diasDaSemana = [
  'segunda',
  'terça',
  'quarta',
  'quinta',
  'sexta',
  'sábado',
  'domingo',
];

/// Ex.: "sábado, 5 de setembro"; o ano aparece só quando não é o atual.
String formatarDataPorExtenso(DateTime data) {
  final ano = data.year == DateTime.now().year ? '' : ' de ${data.year}';
  return '${_diasDaSemana[data.weekday - 1]}, ${data.day} de '
      '${_meses[data.month - 1]}$ano';
}
