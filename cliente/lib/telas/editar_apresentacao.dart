part of 'painel_do_artista.dart';

class _EditarApresentacao extends StatefulWidget {
  const _EditarApresentacao({
    required this.api,
    required this.apresentacao,
  });

  final ApiTocaEssa api;
  final Apresentacao apresentacao;

  @override
  State<_EditarApresentacao> createState() => _EditarApresentacaoState();
}

class _EditarApresentacaoState extends State<_EditarApresentacao> {
  late final TextEditingController _nome;
  late final TextEditingController _local;
  late DateTime _data;
  late TipoApresentacao _tipo;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(text: widget.apresentacao.nome);
    _local = TextEditingController(text: widget.apresentacao.local);
    _data = widget.apresentacao.data;
    _tipo = widget.apresentacao.tipo;
  }

  @override
  void dispose() {
    _nome.dispose();
    _local.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (escolhida != null && mounted) setState(() => _data = escolhida);
  }

  Future<void> _salvar() async {
    if (_nome.text.trim().isEmpty || _local.text.trim().isEmpty) {
      mostrarErro(context, 'Informe o nome e o local da Apresentação.');
      return;
    }
    setState(() => _salvando = true);
    try {
      final atualizada = await widget.api.editarApresentacao(
        widget.apresentacao.id,
        _nome.text.trim(),
        _data,
        _local.text.trim(),
        _tipo,
      );
      if (mounted) Navigator.pop(context, atualizada);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Editar Apresentação')),
        body: ConteudoMobile(
          filho: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  DropdownButtonFormField<TipoApresentacao>(
                    value: _tipo,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Apresentação',
                    ),
                    items: TipoApresentacao.values
                        .map((tipo) => DropdownMenuItem(
                              value: tipo,
                              child: Text(tipo.rotulo),
                            ))
                        .toList(),
                    onChanged: (tipo) {
                      if (tipo != null) setState(() => _tipo = tipo);
                    },
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _tipo.descricao,
                      style: const TextStyle(
                        color: CoresTocaEssa.textoSecundario,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nome,
                    decoration: const InputDecoration(
                      labelText: 'Nome da apresentação',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _local,
                    decoration: const InputDecoration(labelText: 'Local'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    leading: const Icon(Icons.calendar_today_rounded),
                    title: const Text('Data'),
                    subtitle: Text(formatarData(_data)),
                    onTap: _escolherData,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _salvando ? null : _salvar,
                      child: Text(_salvando ? 'Salvando...' : 'Salvar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
