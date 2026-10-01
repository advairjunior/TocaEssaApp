part of 'painel_do_artista.dart';

class _PainelDoArtistaState extends State<PainelDoArtista> {
  final _nomeArtistico = TextEditingController();
  final _bio = TextEditingController();
  final _instagram = TextEditingController();
  final _whatsapp = TextEditingController();
  final _pixChave = TextEditingController();
  final _pixNomeBeneficiario = TextEditingController();
  final _pixCidadeBeneficiario = TextEditingController();
  final _pixMensagem = TextEditingController();
  final _nomeApresentacao = TextEditingController();
  final _local = TextEditingController();
  PerfilArtistico? _perfil;
  ConfiguracaoPerfilArtistico? _configuracaoPerfil;
  bool _exibirInstagram = false;
  bool _exibirWhatsapp = false;
  bool _pixAtivo = false;
  List<Apresentacao> _apresentacoes = [];
  List<ParticipanteDaResenha> _galera = [];
  DateTime _data = DateTime.now();
  TipoApresentacao _tipo = TipoApresentacao.publica;
  bool _carregando = true;
  bool _salvando = false;
  bool _enviandoFoto = false;
  bool _carregandoGalera = false;
  int _abaSelecionada = 0;
  bool _dentroDaApresentacao = false;
  String? _resenhaGaleraId;
  String? _apresentacaoGestaoId;
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
      .toList()
    ..sort((a, b) => b.data.compareTo(a.data));

  List<Apresentacao> get _resenhas => _apresentacoes
      .where((item) => item.tipo == TipoApresentacao.resenhaEntreAmigos)
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
      final configuracao = resultados[0] as ConfiguracaoPerfilArtistico?;
      final perfil = configuracao?.perfil;
      final apresentacoes = resultados[1] as List<Apresentacao>;
      setState(() {
        _perfil = perfil;
        _configuracaoPerfil = configuracao;
        _apresentacoes = apresentacoes;
        _resenhaGaleraId = _escolherResenhaDaGalera(apresentacoes)?.id;
        _apresentacaoGestaoId =
            _escolherApresentacaoDaGestao(apresentacoes)?.id;
        _filtroApresentacoes = _filtroInicial(apresentacoes);
        _carregando = false;
        _nomeArtistico.text = perfil?.nomeArtistico ?? '';
        _bio.text = perfil?.bio ?? '';
        _instagram.text = configuracao?.instagram ?? '';
        _whatsapp.text = configuracao?.whatsapp ?? '';
        _pixChave.text = configuracao?.pixChave ?? '';
        _pixNomeBeneficiario.text = configuracao?.pixNomeBeneficiario ?? '';
        _pixCidadeBeneficiario.text = configuracao?.pixCidadeBeneficiario ?? '';
        _pixMensagem.text = configuracao?.pixMensagem ?? '';
        _exibirInstagram = configuracao?.exibirInstagram ?? false;
        _exibirWhatsapp = configuracao?.exibirWhatsapp ?? false;
        _pixAtivo = configuracao?.pixAtivo ?? false;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _carregando = false);
      mostrarErro(context, erro);
    }
  }

  Apresentacao? _escolherResenhaDaGalera(List<Apresentacao> apresentacoes) {
    final resenhas = apresentacoes
        .where((item) => item.tipo == TipoApresentacao.resenhaEntreAmigos)
        .toList();
    if (resenhas.isEmpty) return null;
    return resenhas.firstWhere(
      (item) => item.status == StatusApresentacao.emAndamento,
      orElse: () => resenhas.first,
    );
  }

  Apresentacao? _escolherApresentacaoDaGestao(
    List<Apresentacao> apresentacoes,
  ) {
    if (apresentacoes.isEmpty) return null;
    for (final status in [
      StatusApresentacao.emAndamento,
      StatusApresentacao.agendada,
      StatusApresentacao.encerrada,
    ]) {
      for (final apresentacao in apresentacoes) {
        if (apresentacao.status == status) return apresentacao;
      }
    }
    return apresentacoes.first;
  }

  Apresentacao? get _apresentacaoDaGestao {
    if (_apresentacoes.isEmpty) return null;
    for (final apresentacao in _apresentacoes) {
      if (apresentacao.id == _apresentacaoGestaoId) return apresentacao;
    }
    return _escolherApresentacaoDaGestao(_apresentacoes);
  }

  Future<void> _selecionarAba(int indice) async {
    setState(() => _abaSelecionada = indice);
    if (indice == 4) await _carregarGalera();
  }

  void _abrirApresentacao(Apresentacao apresentacao) {
    setState(() {
      _apresentacaoGestaoId = apresentacao.id;
      _resenhaGaleraId = apresentacao.id;
      _galera = [];
      _dentroDaApresentacao = true;
      _abaSelecionada = switch (apresentacao.status) {
        StatusApresentacao.encerrada => 3,
        StatusApresentacao.agendada => 6,
        StatusApresentacao.emAndamento => 1,
      };
    });
  }

  void _voltarParaApresentacoes() => setState(() {
        _dentroDaApresentacao = false;
        _abaSelecionada = 0;
      });

  Future<void> _carregarGalera([String? apresentacaoId]) async {
    final id = apresentacaoId ?? _resenhaGaleraId;
    if (id == null || _carregandoGalera) return;
    setState(() {
      _resenhaGaleraId = id;
      _carregandoGalera = true;
    });
    try {
      final participantes =
          await widget.api.listarParticipantesDaResenhaDoArtista(id);
      if (!mounted || _resenhaGaleraId != id) return;
      setState(() => _galera = participantes);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _carregandoGalera = false);
    }
  }

  Future<void> _salvarPerfil() async {
    if (_nomeArtistico.text.trim().isEmpty) {
      mostrarErro(context, 'Informe o nome artístico.');
      return;
    }
    setState(() => _salvando = true);
    try {
      final configuracao = await widget.api.salvarPerfil(
        nomeArtistico: _nomeArtistico.text.trim(),
        bio: _bio.text.trim(),
        instagram: _instagram.text.trim(),
        exibirInstagram: _exibirInstagram,
        whatsapp: _whatsapp.text.trim(),
        exibirWhatsapp: _exibirWhatsapp,
        pixAtivo: _pixAtivo,
        pixChave: _pixChave.text.trim(),
        pixNomeBeneficiario: _pixNomeBeneficiario.text.trim(),
        pixCidadeBeneficiario: _pixCidadeBeneficiario.text.trim(),
        pixMensagem: _pixMensagem.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _configuracaoPerfil = configuracao;
        _perfil = configuracao.perfil;
      });
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
      setState(() {
        _perfil = perfil;
        _configuracaoPerfil = _configuracaoPerfil?.comPerfil(perfil);
      });
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
        _apresentacaoGestaoId = criada.apresentacao.id;
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

  @override
  void dispose() {
    _nomeArtistico.dispose();
    _bio.dispose();
    _instagram.dispose();
    _whatsapp.dispose();
    _pixChave.dispose();
    _pixNomeBeneficiario.dispose();
    _pixCidadeBeneficiario.dispose();
    _pixMensagem.dispose();
    _nomeApresentacao.dispose();
    _local.dispose();
    super.dispose();
  }

  ApiTocaEssa get _api => widget.api;
  ContaArtista get _conta => widget.conta;
  VoidCallback get _sair => widget.sair;
  void _mudarEstado(VoidCallback acao) => setState(acao);

  @override
  Widget build(BuildContext context) => _construirPainel(context);
}
