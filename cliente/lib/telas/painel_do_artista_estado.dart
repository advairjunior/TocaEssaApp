part of 'painel_do_artista.dart';

class _PainelDoArtistaState extends State<PainelDoArtista> {
  final _nomeArtistico = TextEditingController();
  final _bio = TextEditingController();
  final _nomeApresentacao = TextEditingController();
  final _local = TextEditingController();
  PerfilArtistico? _perfil;
  List<Apresentacao> _apresentacoes = [];
  DateTime _data = DateTime.now();
  TipoApresentacao _tipo = TipoApresentacao.publica;
  bool _carregando = true;
  bool _salvando = false;
  bool _enviandoFoto = false;
  int _abaSelecionada = 0;
  _FiltroApresentacoes _filtroApresentacoes = _FiltroApresentacoes.aoVivo;

  List<Apresentacao> get _apresentacoesFiltradas => _apresentacoes
      .where((apresentacao) => switch (_filtroApresentacoes) {
            _FiltroApresentacoes.aoVivo =>
              apresentacao.status == StatusApresentacao.emAndamento,
            _FiltroApresentacoes.agendadas =>
              apresentacao.status == StatusApresentacao.agendada,
            _FiltroApresentacoes.historico =>
              apresentacao.status == StatusApresentacao.encerrada,
          })
      .toList();

  _FiltroApresentacoes _filtroInicial(List<Apresentacao> apresentacoes) {
    if (apresentacoes
        .any((item) => item.status == StatusApresentacao.emAndamento)) {
      return _FiltroApresentacoes.aoVivo;
    }
    if (apresentacoes
        .any((item) => item.status == StatusApresentacao.agendada)) {
      return _FiltroApresentacoes.agendadas;
    }
    return _FiltroApresentacoes.historico;
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final resultados = await Future.wait<dynamic>([
        widget.api.obterPerfil(),
        widget.api.listarApresentacoes(),
      ]);
      if (!mounted) return;
      final perfil = resultados[0] as PerfilArtistico?;
      final apresentacoes = resultados[1] as List<Apresentacao>;
      setState(() {
        _perfil = perfil;
        _apresentacoes = apresentacoes;
        _filtroApresentacoes = _filtroInicial(apresentacoes);
        _carregando = false;
        _nomeArtistico.text = perfil?.nomeArtistico ?? '';
        _bio.text = perfil?.bio ?? '';
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _carregando = false);
      mostrarErro(context, erro);
    }
  }

  Future<void> _salvarPerfil() async {
    if (_nomeArtistico.text.trim().isEmpty) {
      mostrarErro(context, 'Informe o nome artístico.');
      return;
    }
    setState(() => _salvando = true);
    try {
      final perfil = await widget.api
          .salvarPerfil(_nomeArtistico.text.trim(), _bio.text.trim());
      if (!mounted) return;
      setState(() => _perfil = perfil);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil Artístico salvo.')));
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _selecionarFoto() async {
    if (_perfil == null) {
      mostrarErro(
          context, 'Salve o Perfil Artístico antes de escolher a foto.');
      return;
    }
    final arquivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 82,
    );
    if (arquivo == null || !mounted) return;
    final bytes = await arquivo.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) mostrarErro(context, 'Escolha uma imagem de até 5 MB.');
      return;
    }
    setState(() => _enviandoFoto = true);
    try {
      final perfil = await widget.api.enviarFotoPerfil(bytes, arquivo.name);
      if (!mounted) return;
      setState(() => _perfil = perfil);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto do Perfil Artístico atualizada.')),
      );
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _enviandoFoto = false);
    }
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  Future<void> _criarApresentacao() async {
    if (_nomeApresentacao.text.trim().isEmpty || _local.text.trim().isEmpty) {
      mostrarErro(context, 'Informe o nome e o local da Apresentação.');
      return;
    }
    setState(() => _salvando = true);
    try {
      final criada = await widget.api.criarApresentacao(
        _nomeApresentacao.text.trim(),
        _data,
        _local.text.trim(),
        _tipo,
      );
      if (!mounted) return;
      setState(() {
        _apresentacoes = [criada.apresentacao, ..._apresentacoes];
        _abaSelecionada = 0;
        _filtroApresentacoes = _FiltroApresentacoes.agendadas;
      });
      _nomeApresentacao.clear();
      _local.clear();
      await _mostrarCodigo(criada.apresentacao);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _alterarPedidos(Apresentacao apresentacao) async {
    try {
      final atualizada = await widget.api.alterarPedidosDaApresentacao(
        apresentacao.id,
        !apresentacao.pedidosAbertos,
      );
      if (!mounted) return;
      setState(() => _apresentacoes = _apresentacoes
          .map((item) => item.id == atualizada.id ? atualizada : item)
          .toList());
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _alterarStatusApresentacao(
    Apresentacao apresentacao,
    StatusApresentacao status,
  ) async {
    if (status == StatusApresentacao.encerrada) {
      final confirmou = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Encerrar Apresentação?'),
              content: const Text(
                'Novos Pedidos Musicais serão encerrados. A fila e o histórico continuarão disponíveis.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Encerrar'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmou || !mounted) return;
    }

    setState(() => _salvando = true);
    try {
      final atualizada =
          await widget.api.alterarStatusApresentacao(apresentacao.id, status);
      if (!mounted) return;
      setState(() {
        _apresentacoes = _apresentacoes
            .map((item) => item.id == atualizada.id ? atualizada : item)
            .toList();
        _filtroApresentacoes = switch (status) {
          StatusApresentacao.agendada => _FiltroApresentacoes.agendadas,
          StatusApresentacao.emAndamento => _FiltroApresentacoes.aoVivo,
          StatusApresentacao.encerrada => _FiltroApresentacoes.historico,
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apresentação ${status.rotulo.toLowerCase()}.')),
      );
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _editarApresentacao(Apresentacao apresentacao) async {
    final atualizada = await Navigator.push<Apresentacao>(
      context,
      MaterialPageRoute<Apresentacao>(
        builder: (_) => _EditarApresentacao(
          api: widget.api,
          apresentacao: apresentacao,
        ),
      ),
    );
    if (!mounted || atualizada == null) return;
    setState(() => _apresentacoes = _apresentacoes
        .map((item) => item.id == atualizada.id ? atualizada : item)
        .toList());
  }

  Future<void> _excluirApresentacao(Apresentacao apresentacao) async {
    final confirmou = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir Apresentação?'),
            content: Text(
              '“${apresentacao.nome}” e todos os seus Pedidos Musicais serão excluídos.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmou || !mounted) return;
    setState(() => _salvando = true);
    try {
      await widget.api.excluirApresentacao(apresentacao.id);
      if (!mounted) return;
      setState(() =>
          _apresentacoes.removeWhere((item) => item.id == apresentacao.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apresentação excluída.')),
      );
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  String _linkPublico(String codigo) {
    final base = Uri.base;
    final origem = base.scheme == 'http' || base.scheme == 'https'
        ? base.origin
        : 'http://localhost:5173';
    return '$origem/#/publico/$codigo';
  }

  Future<void> _mostrarCodigo(Apresentacao apresentacao) =>
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => _CodigoDaApresentacao(
            apresentacao: apresentacao,
            linkPublico: _linkPublico(apresentacao.codigo),
          ),
        ),
      );

  @override
  void dispose() {
    _nomeArtistico.dispose();
    _bio.dispose();
    _nomeApresentacao.dispose();
    _local.dispose();
    super.dispose();
  }

  ApiTocaEssa get _api => widget.api;
  ContaArtista get _conta => widget.conta;
  VoidCallback get _sair => widget.sair;
  bool get _montado => mounted;
  void _mudarEstado(VoidCallback acao) => setState(acao);

  @override
  Widget build(BuildContext context) => _construirPainel(context);
}
