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
  PerfilArtistico? _perfil;
  ConfiguracaoPerfilArtistico? _configuracaoPerfil;
  bool _exibirInstagram = false;
  bool _exibirWhatsapp = false;
  bool _pixAtivo = false;
  List<Apresentacao> _apresentacoes = [];
  List<ParticipanteDaResenha> _galera = [];
  bool _carregando = true;
  bool _salvando = false;
  bool _enviandoFoto = false;
  bool _carregandoGalera = false;
  _AbaPainel _aba = _AbaPainel.inicio;
  String? _resenhaGaleraId;
  String? _apresentacaoGestaoId;
  _FiltroApresentacoes _filtroApresentacoes = _FiltroApresentacoes.proximas;

  bool get _dentroDaApresentacao => _abasDaApresentacao.contains(_aba);

  List<Apresentacao> _comStatus(StatusApresentacao status) => _apresentacoes
      .where((apresentacao) => apresentacao.status == status)
      .toList()
    ..sort((a, b) => b.data.compareTo(a.data));

  List<Apresentacao> get _apresentacoesAoVivo =>
      _comStatus(StatusApresentacao.emAndamento);

  List<Apresentacao> get _apresentacoesFiltradas =>
      _comStatus(switch (_filtroApresentacoes) {
        _FiltroApresentacoes.proximas => StatusApresentacao.agendada,
        _FiltroApresentacoes.historico => StatusApresentacao.encerrada,
      });

  _FiltroApresentacoes _filtroInicial(List<Apresentacao> apresentacoes) {
    final temProximas =
        apresentacoes.any((item) => item.status == StatusApresentacao.agendada);
    final temHistorico = apresentacoes
        .any((item) => item.status == StatusApresentacao.encerrada);
    return !temProximas && temHistorico
        ? _FiltroApresentacoes.historico
        : _FiltroApresentacoes.proximas;
  }

  @override
  void initState() {
    super.initState();
    // Redesenha a prévia e o botão de salvar a cada tecla.
    for (final campo in _camposDoPerfil) {
      campo.addListener(_aoEditarPerfil);
    }
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
        _apresentacaoGestaoId =
            _escolherApresentacaoDaGestao(apresentacoes)?.id;
        _filtroApresentacoes = _filtroInicial(apresentacoes);
        _carregando = false;
        _restaurarPerfil();
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _carregando = false);
      mostrarErro(context, erro);
    }
  }

  List<TextEditingController> get _camposDoPerfil => [
        _nomeArtistico,
        _bio,
        _instagram,
        _whatsapp,
        _pixChave,
        _pixNomeBeneficiario,
        _pixCidadeBeneficiario,
        _pixMensagem,
      ];

  void _aoEditarPerfil() {
    if (mounted) setState(() {});
  }

  /// Volta os campos do perfil aos valores salvos.
  void _restaurarPerfil() {
    final configuracao = _configuracaoPerfil;
    _nomeArtistico.text = configuracao?.perfil.nomeArtistico ?? '';
    _bio.text = configuracao?.perfil.bio ?? '';
    _instagram.text = configuracao?.instagram ?? '';
    _whatsapp.text = configuracao?.whatsapp ?? '';
    _pixChave.text = configuracao?.pixChave ?? '';
    _pixNomeBeneficiario.text = configuracao?.pixNomeBeneficiario ?? '';
    _pixCidadeBeneficiario.text = configuracao?.pixCidadeBeneficiario ?? '';
    _pixMensagem.text = configuracao?.pixMensagem ?? '';
    _exibirInstagram = configuracao?.exibirInstagram ?? false;
    _exibirWhatsapp = configuracao?.exibirWhatsapp ?? false;
    _pixAtivo = configuracao?.pixAtivo ?? false;
  }

  bool get _perfilAlterado {
    final configuracao = _configuracaoPerfil;
    if (configuracao == null) {
      return _camposDoPerfil.any((campo) => campo.text.trim().isNotEmpty);
    }
    bool difere(TextEditingController campo, String? salvo) =>
        campo.text.trim() != (salvo ?? '').trim();
    return difere(_nomeArtistico, configuracao.perfil.nomeArtistico) ||
        difere(_bio, configuracao.perfil.bio) ||
        difere(_instagram, configuracao.instagram) ||
        difere(_whatsapp, configuracao.whatsapp) ||
        difere(_pixChave, configuracao.pixChave) ||
        difere(_pixNomeBeneficiario, configuracao.pixNomeBeneficiario) ||
        difere(_pixCidadeBeneficiario, configuracao.pixCidadeBeneficiario) ||
        difere(_pixMensagem, configuracao.pixMensagem) ||
        _exibirInstagram != configuracao.exibirInstagram ||
        _exibirWhatsapp != configuracao.exibirWhatsapp ||
        _pixAtivo != configuracao.pixAtivo;
  }

  /// Sai do perfil; com alterações pendentes, pergunta antes de descartar.
  Future<void> _sairDoPerfil() async {
    if (_perfilAlterado) {
      final descartar = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Descartar alterações?'),
              content: const Text(
                'As mudanças no seu perfil artístico ainda não foram salvas.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Continuar editando'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Descartar'),
                ),
              ],
            ),
          ) ??
          false;
      if (!descartar || !mounted) return;
      _restaurarPerfil();
    }
    _voltarAoInicio();
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

  Future<void> _selecionarAba(_AbaPainel aba) async {
    setState(() => _aba = aba);
    final apresentacao = _apresentacaoDaGestao;
    if (aba == _AbaPainel.mais &&
        apresentacao?.tipo == TipoApresentacao.resenhaEntreAmigos) {
      await _carregarGalera(apresentacao!.id);
    }
  }

  void _abrirApresentacao(Apresentacao apresentacao, {_AbaPainel? aba}) {
    setState(() {
      _apresentacaoGestaoId = apresentacao.id;
      _resenhaGaleraId = apresentacao.id;
      _galera = [];
    });
    _selecionarAba(aba ??
        switch (apresentacao.status) {
          StatusApresentacao.encerrada => _AbaPainel.estatisticas,
          StatusApresentacao.agendada => _AbaPainel.mais,
          StatusApresentacao.emAndamento => _AbaPainel.fila,
        });
  }

  void _voltarAoInicio() => setState(() => _aba = _AbaPainel.inicio);

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
        // Adota os valores normalizados pela API para não sobrar "alteração".
        _restaurarPerfil();
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil artístico salvo.')));
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

  Future<void> _novaApresentacao() async {
    final criada = await Navigator.push<Object>(
      context,
      MaterialPageRoute<Object>(
        builder: (_) => _FormularioApresentacao(
          salvar: (dados) => widget.api.criarApresentacao(
            dados.nome,
            dados.data,
            dados.local,
            dados.tipo,
          ),
        ),
      ),
    );
    if (!mounted || criada is! ApresentacaoCriada) return;
    setState(() {
      _apresentacoes = [criada.apresentacao, ..._apresentacoes];
      _apresentacaoGestaoId = criada.apresentacao.id;
      _filtroApresentacoes = _FiltroApresentacoes.proximas;
    });
    await _mostrarCodigo(criada.apresentacao, recemCriada: true);
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
    super.dispose();
  }

  ApiTocaEssa get _api => widget.api;
  ContaArtista get _conta => widget.conta;
  VoidCallback get _sair => widget.sair;
  void _mudarEstado(VoidCallback acao) => setState(acao);

  @override
  Widget build(BuildContext context) => _construirPainel(context);
}
