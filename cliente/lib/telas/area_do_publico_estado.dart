part of 'area_do_publico.dart';

class _AreaDoPublicoState extends State<AreaDoPublico> {
  late Future<Apresentacao?> _consulta;
  late Future<List<PedidoMusical>> _fila;
  final _musica = TextEditingController();
  final _artista = TextEditingController();
  final _nome = TextEditingController();
  final _tomPreferido = TextEditingController();
  final _recado = TextEditingController();
  final _destinatarioAlo = TextEditingController();
  final _nomeCadastro = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  List<PedidoMusical> _meusPedidos = [];
  List<ParticipanteDaResenha> _participantesDaResenha = [];
  bool _enviando = false;
  bool _atualizando = false;
  bool _carregandoSessao = true;
  bool _autenticando = false;
  bool _enviandoFotoPublico = false;
  bool _gerandoRetrospectiva = false;
  bool _criandoConta = false;
  bool _mostrarTodosPedidos = false;
  bool _mostrarDetalhesPedido = false;
  FormaParticipacaoPedido _formaParticipacao =
      FormaParticipacaoPedido.pedidoNormal;
  TipoPedido _tipoPedido = TipoPedido.musica;
  int _abaSelecionada = 0;
  bool _perfilDaResenha = false;
  String? _pedidoSendoCancelado;
  String? _pedidoSendoAvaliado;
  String? _tokenPublico;
  String _identificadorAvaliador =
      '${DateTime.now().microsecondsSinceEpoch}-${DateTime.now().millisecondsSinceEpoch}';
  Uint8List? _fotoRetrospectivaPublico;
  final _chaveRetrospectivaPublico = GlobalKey();
  PerfilPublico? _perfilPublico;
  EstatisticasDoPublico? _estatisticasPublico;
  TipoApresentacao? _tipoApresentacao;
  Timer? _atualizacaoAutomatica;
  AssinaturaTempoReal? _tempoReal;

  int get _indicePerfil =>
      _tipoApresentacao == TipoApresentacao.resenhaEntreAmigos ? 3 : 2;

  String get _chavePedidos =>
      'pedidos_publico_${widget.codigoInicial.trim().toUpperCase()}';

  Iterable<PedidoMusical> get _pedidosExibidos =>
      _mostrarTodosPedidos ? _meusPedidos : _meusPedidos.take(2);

  ParticipanteDaResenha? get _minhaParticipacaoNaResenha {
    final id = _perfilPublico?.id;
    if (id == null) return null;
    for (final participante in _participantesDaResenha) {
      if (participante.publicoId == id) return participante;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.revisitar) _abaSelecionada = 1;
    _consulta = widget.api
        .obterApresentacaoPublica(widget.codigoInicial)
        .then((apresentacao) {
      _tipoApresentacao = apresentacao?.tipo;
      return apresentacao;
    });
    _fila = _consulta.then((apresentacao) => apresentacao == null
        ? <PedidoMusical>[]
        : widget.api.listarFilaPublica(widget.codigoInicial,
            identificadorAvaliador: _identificadorAvaliador));
    _atualizacaoAutomatica = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _atualizarSilenciosamente(),
    );
    _tempoReal = AssinaturaTempoReal(
      widget.api.enderecoTempoReal(widget.codigoInicial),
      _atualizarSilenciosamente,
    );
    _restaurarDadosDoPublico();
  }

  ApiTocaEssa get _api => widget.api;
  String get _codigoInicial => widget.codigoInicial;
  bool get _montado => mounted;
  BuildContext get _contexto => context;
  void _mudarEstado(VoidCallback acao) => setState(acao);

  @override
  void dispose() {
    _atualizacaoAutomatica?.cancel();
    _tempoReal?.encerrar();
    _musica.dispose();
    _artista.dispose();
    _nome.dispose();
    _tomPreferido.dispose();
    _recado.dispose();
    _destinatarioAlo.dispose();
    _nomeCadastro.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _construirArea(context);
}
