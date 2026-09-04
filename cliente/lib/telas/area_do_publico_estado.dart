part of 'area_do_publico.dart';

class _AreaDoPublicoState extends State<AreaDoPublico> {
  late Future<Apresentacao?> _consulta;
  late Future<List<PedidoMusical>> _fila;
  final _musica = TextEditingController();
  final _artista = TextEditingController();
  final _nome = TextEditingController();
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
  bool _criandoConta = false;
  bool _mostrarTodosPedidos = false;
  int _abaSelecionada = 0;
  String? _pedidoSendoCancelado;
  String? _pedidoSendoAvaliado;
  String? _tokenPublico;
  PerfilPublico? _perfilPublico;
  EstatisticasDoPublico? _estatisticasPublico;
  TipoApresentacao? _tipoApresentacao;
  Timer? _atualizacaoAutomatica;

  int get _indicePerfil =>
      _tipoApresentacao == TipoApresentacao.resenhaEntreAmigos ? 3 : 2;

  String get _chavePedidos =>
      'pedidos_publico_${widget.codigoInicial.trim().toUpperCase()}';

  Iterable<PedidoMusical> get _pedidosExibidos =>
      _mostrarTodosPedidos ? _meusPedidos : _meusPedidos.take(3);

  @override
  void initState() {
    super.initState();
    _consulta = widget.api
        .obterApresentacaoPublica(widget.codigoInicial)
        .then((apresentacao) {
      _tipoApresentacao = apresentacao?.tipo;
      return apresentacao;
    });
    _fila = _consulta.then((apresentacao) => apresentacao == null
        ? <PedidoMusical>[]
        : widget.api.listarFilaPublica(widget.codigoInicial));
    _atualizacaoAutomatica = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _atualizarSilenciosamente(),
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
    _musica.dispose();
    _artista.dispose();
    _nome.dispose();
    _nomeCadastro.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _construirArea(context);
}
