import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import 'area_do_publico.dart';
import 'componentes.dart';

part 'conta_do_publico_construcao.dart';

class ContaDoPublico extends StatefulWidget {
  const ContaDoPublico({super.key, required this.api});
  final ApiTocaEssa api;
  @override
  State<ContaDoPublico> createState() => _ContaDoPublicoState();
}

class _ContaDoPublicoState extends State<ContaDoPublico> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _nome = TextEditingController();
  String? _token;
  PerfilPublico? _perfil;
  EstatisticasDoPublico? _estatisticas;
  List<Apresentacao> _apresentacoes = [];
  bool _ocupado = true;
  bool _cadastro = false;
  int _aba = 0;
  StatusApresentacao _filtro = StatusApresentacao.emAndamento;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final preferencias = await SharedPreferences.getInstance();
      _token = preferencias.getString('token_do_publico');
      if (_token == null) {
        if (mounted) {
          setState(() {
            _perfil = null;
            _apresentacoes = [];
            _estatisticas = null;
          });
        }
      } else {
        final perfil = await widget.api.obterPerfilPublico(_token!);
        final estatisticas =
            await widget.api.obterEstatisticasDoPublico(_token!);
        final apresentacoes =
            await widget.api.listarApresentacoesDoPublico(_token!);
        if (!mounted) return;
        setState(() {
          _perfil = perfil;
          _estatisticas = estatisticas;
          _apresentacoes = apresentacoes;
          if (!apresentacoes.any((a) => a.status == _filtro) &&
              apresentacoes.isNotEmpty) {
            _filtro = apresentacoes.first.status;
          }
        });
      }
    } catch (erro) {
      if (mounted) setState(() => _erro = erro.toString());
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _entrar() async {
    if (!_email.text.contains('@') ||
        _senha.text.length < 6 ||
        (_cadastro && _nome.text.trim().length < 2)) {
      mostrarErro(context,
          'Informe um e-mail válido, senha com pelo menos 6 caracteres e seu nome no cadastro.');
      return;
    }
    setState(() => _ocupado = true);
    try {
      final sessao = _cadastro
          ? await widget.api.criarContaPublica(
              _nome.text.trim(), _email.text.trim(), _senha.text)
          : await widget.api
              .entrarContaPublica(_email.text.trim(), _senha.text);
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setString('token_do_publico', sessao.token);
      _senha.clear();
      if (mounted) await _carregar();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _sair() async {
    if (_token != null) {
      try {
        await widget.api.sairContaPublica(_token!);
      } catch (_) {}
    }
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.remove('token_do_publico');
    if (!mounted) return;
    setState(() {
      _token = null;
      _perfil = null;
      _estatisticas = null;
      _apresentacoes = [];
      _erro = null;
      _aba = 0;
    });
  }

  Future<void> _foto() async {
    final arquivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 84);
    if (arquivo == null || !mounted || _token == null) return;
    setState(() => _ocupado = true);
    try {
      final perfil = await widget.api.enviarFotoPerfilPublico(
          _token!, await arquivo.readAsBytes(), arquivo.name);
      if (mounted) setState(() => _perfil = perfil);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _abrir(Apresentacao apresentacao) async {
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => AreaDoPublico(
                api: widget.api,
                codigoInicial: apresentacao.codigo,
                revisitar:
                    apresentacao.status == StatusApresentacao.encerrada)));
    if (mounted) await _carregar();
  }

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    _nome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _construirConta(context);
  void _alterar(VoidCallback acao) => setState(acao);
}
