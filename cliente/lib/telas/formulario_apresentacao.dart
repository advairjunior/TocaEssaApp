part of 'painel_do_artista.dart';

typedef _DadosApresentacao = ({
  String nome,
  String local,
  DateTime data,
  TipoApresentacao tipo,
});

/// Cria ou edita uma apresentação. Fecha devolvendo o que [salvar] retornar.
class _FormularioApresentacao extends StatefulWidget {
  const _FormularioApresentacao({required this.salvar, this.apresentacao});

  final Apresentacao? apresentacao;
  final Future<Object> Function(_DadosApresentacao dados) salvar;

  @override
  State<_FormularioApresentacao> createState() =>
      _FormularioApresentacaoState();
}

class _FormularioApresentacaoState extends State<_FormularioApresentacao> {
  late final _nome = TextEditingController(text: widget.apresentacao?.nome);
  late final _local = TextEditingController(text: widget.apresentacao?.local);
  late DateTime _data = widget.apresentacao?.data ?? DateTime.now();
  late TipoApresentacao _tipo =
      widget.apresentacao?.tipo ?? TipoApresentacao.publica;
  bool _salvando = false;

  bool get _editando => widget.apresentacao != null;

  @override
  void dispose() {
    _nome.dispose();
    _local.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final ontem = DateTime.now().subtract(const Duration(days: 1));
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: _editando || _data.isBefore(ontem) ? DateTime(2000) : ontem,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (escolhida != null && mounted) setState(() => _data = escolhida);
  }

  Future<void> _salvar() async {
    if (_nome.text.trim().isEmpty || _local.text.trim().isEmpty) {
      mostrarErro(context, 'Informe o nome e o local da apresentação.');
      return;
    }
    setState(() => _salvando = true);
    try {
      final resultado = await widget.salvar((
        nome: _nome.text.trim(),
        local: _local.text.trim(),
        data: _data,
        tipo: _tipo,
      ));
      if (mounted) Navigator.pop(context, resultado);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_editando ? 'Editar apresentação' : 'Nova apresentação'),
        ),
        body: ConteudoMobile(
          filho: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RotuloCampo('Tipo'),
              SeletorOpcoes<TipoApresentacao>(
                selecionado: _tipo,
                aoSelecionar: (tipo) => setState(() => _tipo = tipo),
                opcoes: const [
                  OpcaoSeletor(
                    valor: TipoApresentacao.publica,
                    titulo: 'Pública',
                    descricao: 'Qualquer pessoa entra pelo código.',
                    icone: Icons.public_rounded,
                  ),
                  OpcaoSeletor(
                    valor: TipoApresentacao.resenhaEntreAmigos,
                    titulo: 'Resenha',
                    descricao: 'Entre amigos, com perfil e histórico.',
                    icone: Icons.celebration_rounded,
                  ),
                ],
              ),
              const SizedBox(height: EspacoTocaEssa.grande),
              CampoTexto(
                rotulo: 'Nome da apresentação',
                controlador: _nome,
                dica: 'Ex.: Noite acústica',
                capitalizacao: TextCapitalization.sentences,
                acaoTeclado: TextInputAction.next,
              ),
              const SizedBox(height: EspacoTocaEssa.base + 4),
              CampoTexto(
                rotulo: 'Local',
                controlador: _local,
                dica: 'Ex.: Bar do Zé',
                capitalizacao: TextCapitalization.words,
                acaoTeclado: TextInputAction.done,
              ),
              const SizedBox(height: EspacoTocaEssa.base + 4),
              CampoData(rotulo: 'Data', data: _data, tocar: _escolherData),
              const SizedBox(height: EspacoTocaEssa.enorme),
              FilledButton(
                onPressed: _salvando ? null : _salvar,
                child: Text(_salvando
                    ? 'Salvando...'
                    : _editando
                        ? 'Salvar'
                        : 'Criar apresentação'),
              ),
            ],
          ),
        ),
      );
}
