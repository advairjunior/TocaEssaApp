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
  // Acervo resumido no início; nulo enquanto não chega.
  List<Repertorio>? _repertorios;
  List<ParticipanteDaResenha> _galera = [];
  bool _carregando = true;
  bool _salvando = false;
  bool _enviandoFoto = false;
  bool _carregandoGalera = false;
  _AbaPainel _aba = _AbaPainel.inicio;
  String? _resenhaGaleraId;
  String? _apresentacaoGestaoId;
  _FiltroApresentacoes _filtroApresentacoes = _FiltroApresentacoes.proximas;

  // Início e perfil ficam fora; toda outra aba é de uma apresentação aberta.
  bool get _dentroDaApresentacao =>
      _aba != _AbaPainel.inicio && _aba != _AbaPainel.perfil;

  List<Apresentacao> _comStatus(
    StatusApresentacao status, {
    bool maisProximaPrimeiro = false,
  }) =>
      _apresentacoes
          .where((apresentacao) => apresentacao.status == status)
          .toList()
        ..sort((a, b) => maisProximaPrimeiro
            ? a.data.compareTo(b.data)
            : b.data.compareTo(a.data));

  bool _jaPassou(Apresentacao apresentacao) {
    final hoje = DateTime.now();
    return apresentacao.status == StatusApresentacao.agendada &&
        apresentacao.data.isBefore(DateTime(hoje.year, hoje.month, hoje.day));
  }

  List<Apresentacao> get _apresentacoesAoVivo =>
      _comStatus(StatusApresentacao.emAndamento);

  List<Apresentacao> get _apresentacoesFiltradas =>
      switch (_filtroApresentacoes) {
        // As que já passaram sem encerrar vão para o fim: não podem
        // esconder o próximo show de verdade.
        _FiltroApresentacoes.proximas => [
            ..._comStatus(StatusApresentacao.agendada,
                    maisProximaPrimeiro: true)
                .where((apresentacao) => !_jaPassou(apresentacao)),
            ..._comStatus(StatusApresentacao.agendada,
                    maisProximaPrimeiro: true)
                .where(_jaPassou),
          ],
        _FiltroApresentacoes.historico =>
          _comStatus(StatusApresentacao.encerrada),
      };

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
    _carregarRepertorios();
  }

  Future<void> _carregarRepertorios() async {
    try {
      final repertorios = await widget.api.listarRepertorios();
      if (mounted) setState(() => _repertorios = repertorios);
    } catch (_) {
      // Sem o resumo, o acervo continua a um toque no menu da conta.
    }
  }

  Future<void> _abrirRepertorios() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
          builder: (_) => GerenciarRepertorios(api: widget.api)),
    );
    if (mounted) await _carregarRepertorios();
  }

  /// Tocar e ensaiar as músicas do acervo sem criar um show.
  Future<void> _tocarMusicas() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => TocarMusicas(api: widget.api)),
    );
    if (mounted) await _carregarRepertorios();
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
      await _voltarOndeParou();
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

  /// Ao recarregar a página no meio do show, reabre a apresentação e a aba
  /// onde o artista estava. Show encerrado ou ausente abre o início.
  Future<void> _voltarOndeParou() async {
    final preferencias = await SharedPreferences.getInstance();
    final id = preferencias.getString(_chaveApresentacaoAberta);
    final aba = _AbaPainel.values
        .where((aba) => aba.name == preferencias.getString(_chaveAbaAberta))
        .firstOrNull;
    if (!mounted || aba == null) return;
    final apresentacao = _apresentacoes
        .where((item) =>
            item.id == id && item.status == StatusApresentacao.emAndamento)
        .firstOrNull;
    if (apresentacao != null && _abasDe(apresentacao).contains(aba)) {
      _abrirApresentacao(apresentacao, aba: aba);
    }
  }

  Future<void> _lembrarOndeParou() async {
    final preferencias = await SharedPreferences.getInstance();
    final id = _apresentacaoGestaoId;
    if (_dentroDaApresentacao && id != null) {
      await preferencias.setString(_chaveApresentacaoAberta, id);
      await preferencias.setString(_chaveAbaAberta, _aba.name);
    } else {
      await preferencias.remove(_chaveApresentacaoAberta);
      await preferencias.remove(_chaveAbaAberta);
    }
  }

  Future<void> _selecionarAba(_AbaPainel aba) async {
    setState(() => _aba = aba);
    _lembrarOndeParou();
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
        switch ((apresentacao.tipo, apresentacao.status)) {
          (TipoApresentacao.louvor, StatusApresentacao.agendada) =>
            _AbaPainel.escala,
          (TipoApresentacao.louvor, _) => _AbaPainel.setlist,
          (TipoApresentacao.karaoke, _) => _AbaPainel.karaoke,
          (_, StatusApresentacao.encerrada) => _AbaPainel.estatisticas,
          (_, StatusApresentacao.agendada) => _AbaPainel.mais,
          (_, StatusApresentacao.emAndamento) => _AbaPainel.fila,
        });
  }

  void _voltarAoInicio() {
    setState(() => _aba = _AbaPainel.inicio);
    _lembrarOndeParou();
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
