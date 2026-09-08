import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'painel_do_artista.dart';

class AcessoDoArtista extends StatefulWidget {
  const AcessoDoArtista({super.key, required this.api});

  final ApiTocaEssa api;

  @override
  State<AcessoDoArtista> createState() => _AcessoDoArtistaState();
}

class _AcessoDoArtistaState extends State<AcessoDoArtista> {
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  ContaArtista? _conta;
  String? _token;
  bool _carregando = true;
  bool _autenticando = false;
  bool _criandoConta = false;

  @override
  void initState() {
    super.initState();
    _restaurarSessao();
  }

  Future<void> _restaurarSessao() async {
    final preferencias = await SharedPreferences.getInstance();
    final token = preferencias.getString('token_do_artista');
    if (token != null) {
      try {
        widget.api.definirTokenArtista(token);
        final conta = await widget.api.obterContaArtista(token);
        if (!mounted) return;
        setState(() {
          _token = token;
          _conta = conta;
        });
      } catch (_) {
        widget.api.definirTokenArtista(null);
        await preferencias.remove('token_do_artista');
      }
    }
    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _autenticar() async {
    if (_criandoConta && _nome.text.trim().length < 2) {
      mostrarErro(context, 'Informe seu nome.');
      return;
    }
    if (!_email.text.trim().contains('@')) {
      mostrarErro(context, 'Informe um e-mail válido.');
      return;
    }
    if (_senha.text.length < 6) {
      mostrarErro(context, 'A senha deve ter pelo menos 6 caracteres.');
      return;
    }
    setState(() => _autenticando = true);
    try {
      final sessao = _criandoConta
          ? await widget.api.criarContaArtista(
              _nome.text.trim(), _email.text.trim(), _senha.text)
          : await widget.api
              .entrarContaArtista(_email.text.trim(), _senha.text);
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setString('token_do_artista', sessao.token);
      widget.api.definirTokenArtista(sessao.token);
      if (!mounted) return;
      setState(() {
        _conta = sessao.conta;
        _token = sessao.token;
        _senha.clear();
      });
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _autenticando = false);
    }
  }

  Future<void> _sair() async {
    final token = _token;
    if (token != null) {
      try {
        await widget.api.sairContaArtista(token);
      } catch (_) {
        // A sessão local ainda é encerrada se a API estiver indisponível.
      }
    }
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.remove('token_do_artista');
    widget.api.definirTokenArtista(null);
    if (!mounted) return;
    setState(() {
      _conta = null;
      _token = null;
      _criandoConta = false;
    });
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_conta != null) {
      return PainelDoArtista(
        api: widget.api,
        conta: _conta!,
        sair: _sair,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Acesso do Artista')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.8),
            radius: 1.2,
            colors: [Color(0xFF24143C), CoresTocaEssa.fundo],
          ),
        ),
        child: ConteudoMobile(
          filho: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.mic_rounded,
                  size: 58, color: CoresTocaEssa.roxoClaro),
              const SizedBox(height: 14),
              Text(
                _criandoConta ? 'Crie seu acesso' : 'Entre no seu painel',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Seu Perfil Artístico, apresentações e pedidos protegidos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: CoresTocaEssa.textoSecundario),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_criandoConta) ...[
                        TextField(
                          controller: _nome,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Seu nome',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _senha,
                        obscureText: true,
                        enableSuggestions: false,
                        onSubmitted: (_) => _autenticar(),
                        decoration: const InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _autenticando ? null : _autenticar,
                        icon: Icon(_criandoConta
                            ? Icons.person_add_alt_1_rounded
                            : Icons.login_rounded),
                        label: Text(_autenticando
                            ? 'Aguarde...'
                            : _criandoConta
                                ? 'Criar conta e entrar'
                                : 'Entrar'),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _autenticando
                            ? null
                            : () =>
                                setState(() => _criandoConta = !_criandoConta),
                        child: Text(_criandoConta
                            ? 'Já tenho uma conta'
                            : 'Primeiro acesso? Criar conta'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
