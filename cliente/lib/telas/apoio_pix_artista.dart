part of 'area_do_publico.dart';

extension _ApoioPixDoArtista on _AreaDoPublicoState {
  Future<void> _abrirApoioPix(Apresentacao apresentacao) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: CoresTocaEssa.superficie,
        builder: (_) => ApoioPixArtista(
          carregar: (valor) => _api.obterApoioPix(apresentacao.codigo, valor),
        ),
      );
}

class ApoioPixArtista extends StatefulWidget {
  const ApoioPixArtista({super.key, required this.carregar});

  final Future<ApoioPix> Function(double valor) carregar;

  @override
  State<ApoioPixArtista> createState() => _ApoioPixArtistaState();
}

class _ApoioPixArtistaState extends State<ApoioPixArtista> {
  final _outroValor = TextEditingController();
  ApoioPix? _apoio;
  double? _valorEscolhido;
  bool _carregando = false;
  String? _erro;

  @override
  void dispose() {
    _outroValor.dispose();
    super.dispose();
  }

  Future<void> _selecionar(double valor) async {
    setState(() {
      _carregando = true;
      _valorEscolhido = valor;
      _erro = null;
    });
    try {
      final apoio = await widget.carregar(valor);
      if (mounted) setState(() => _apoio = apoio);
    } catch (erro) {
      if (mounted) setState(() => _erro = erro.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _usarOutroValor() async {
    final valor = double.tryParse(_outroValor.text.replaceAll(',', '.'));
    if (valor == null || valor < 1 || valor > 1000) {
      setState(() => _erro = 'Informe um valor entre R\$ 1 e R\$ 1.000.');
      return;
    }
    await _selecionar(valor);
  }

  @override
  // O recuo do teclado fica fora da rolagem: assim a área rolável termina
  // acima do teclado e o campo focado é rolado para onde pode ser visto.
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.favorite_rounded,
                  size: 42, color: CoresTocaEssa.roxoClaro),
              const SizedBox(height: 10),
              Text('Apoiar o artista',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              const Text(
                'Escolha um valor para gerar o Pix.',
                textAlign: TextAlign.center,
                style: TextStyle(color: CoresTocaEssa.textoSecundario),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  for (final valor in const [5.0, 10.0, 20.0]) ...[
                    Expanded(
                      child: ChoiceChip(
                        selected: _valorEscolhido == valor,
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(
                            vertical: EspacoTocaEssa.pequeno),
                        labelStyle: Theme.of(context).textTheme.titleMedium,
                        side: BorderSide(
                          color: _valorEscolhido == valor
                              ? CoresTocaEssa.roxoClaro
                              : CoresTocaEssa.borda,
                        ),
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(
                            'R\$ ${valor.toInt()}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        onSelected:
                            _carregando ? null : (_) => _selecionar(valor),
                      ),
                    ),
                    if (valor != 20)
                      const SizedBox(width: EspacoTocaEssa.pequeno),
                  ],
                ],
              ),
              const SizedBox(height: EspacoTocaEssa.medio),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _outroValor,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: decoracaoCampoTocaEssa(dica: 'Outro valor'),
                    ),
                  ),
                  const SizedBox(width: EspacoTocaEssa.pequeno),
                  IconButton.filled(
                    tooltip: 'Gerar Pix com outro valor',
                    onPressed: _carregando ? null : _usarOutroValor,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
              ),
              if (_carregando) ...[
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Text(_erro!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: CoresTocaEssa.rosa)),
              ],
              if (_apoio != null) ...[
                const SizedBox(height: EspacoTocaEssa.grande),
                Text(
                  'Pix de R\$ ${_apoio!.valor.toStringAsFixed(2).replaceAll('.', ',')}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: EspacoTocaEssa.medio),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(EspacoTocaEssa.medio),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
                    ),
                    child: QrImageView(
                      data: _apoio!.pixCopiaECola,
                      size: 210,
                    ),
                  ),
                ),
                const SizedBox(height: EspacoTocaEssa.medio),
                Text(_apoio!.mensagem,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: EspacoTocaEssa.base),
                FilledButton.icon(
                  onPressed: () async {
                    final mensageiro = ScaffoldMessenger.of(context);
                    await Clipboard.setData(
                        ClipboardData(text: _apoio!.pixCopiaECola));
                    if (mounted) {
                      mensageiro.showSnackBar(
                          const SnackBar(content: Text('Código Pix copiado.')));
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copiar código Pix'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'A contribuição é voluntária e não garante que um pedido seja aceito ou tocado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: CoresTocaEssa.textoSecundario, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      );
}
