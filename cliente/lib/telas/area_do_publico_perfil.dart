// ignore_for_file: use_build_context_synchronously

part of 'area_do_publico.dart';

extension _PerfilAreaDoPublico on _AreaDoPublicoState {
  Future<void> _autenticarPublico() async {
    if (_email.text.trim().isEmpty ||
        _senha.text.isEmpty ||
        (_criandoConta && _nomeCadastro.text.trim().isEmpty)) {
      mostrarErro(_contexto, 'Preencha os dados para continuar.');
      return;
    }
    if (!_email.text.trim().contains('@')) {
      mostrarErro(_contexto, 'Informe um e-mail válido.');
      return;
    }
    if (_senha.text.length < 6) {
      mostrarErro(_contexto, 'A senha deve ter pelo menos 6 caracteres.');
      return;
    }
    if (_criandoConta && _nomeCadastro.text.trim().length < 2) {
      mostrarErro(_contexto, 'O nome deve ter pelo menos 2 caracteres.');
      return;
    }
    _mudarEstado(() => _autenticando = true);
    try {
      final sessao = _criandoConta
          ? await _api.criarContaPublica(
              _nomeCadastro.text.trim(), _email.text.trim(), _senha.text)
          : await _api.entrarContaPublica(_email.text.trim(), _senha.text);
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setString('token_do_publico', sessao.token);
      if (!_montado) return;
      _mudarEstado(() {
        _tokenPublico = sessao.token;
        _perfilPublico = sessao.perfil;
        _abaSelecionada = 0;
        _senha.clear();
      });
      try {
        if (_tipoApresentacao == TipoApresentacao.resenhaEntreAmigos) {
          await _api.registrarParticipacaoNaResenha(
            _codigoInicial,
            sessao.token,
          );
        }
        final pedidos =
            await _api.listarMeusPedidos(_codigoInicial, sessao.token);
        final estatisticas = await _obterEstatisticasPublico(sessao.token);
        final participantes =
            _tipoApresentacao == TipoApresentacao.resenhaEntreAmigos
                ? await _obterParticipantesDaResenha(sessao.token)
                : <ParticipanteDaResenha>[];
        if (!_montado) return;
        _mudarEstado(() {
          _meusPedidos = pedidos;
          _estatisticasPublico = estatisticas;
          _participantesDaResenha = participantes;
          _fila = _api.listarFilaPublica(
            _codigoInicial,
            token: sessao.token,
            identificadorAvaliador: _identificadorAvaliador,
          );
        });
      } catch (_) {
        if (_montado) {
          ScaffoldMessenger.of(_contexto).showSnackBar(const SnackBar(
            content: Text(
                'Perfil acessado. Os dados da apresentação serão atualizados em instantes.'),
          ));
        }
      }
    } catch (erro) {
      if (_montado) mostrarErro(_contexto, erro);
    } finally {
      if (_montado) _mudarEstado(() => _autenticando = false);
    }
  }

  Future<void> _sairDoPerfilPublico() async {
    final token = _tokenPublico;
    if (token != null) {
      try {
        await _api.sairContaPublica(token);
      } catch (_) {
        // A sessão local ainda é removida se o servidor estiver indisponível.
      }
    }
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.remove('token_do_publico');
    if (!_montado) return;
    _mudarEstado(() {
      _tokenPublico = null;
      _perfilPublico = null;
      _estatisticasPublico = null;
      _participantesDaResenha = [];
      _meusPedidos = [];
      if (_tipoApresentacao == TipoApresentacao.resenhaEntreAmigos) {
        _abaSelecionada = _indicePerfil;
      }
    });
  }

  Future<void> _selecionarFotoPublico() async {
    if (_tokenPublico == null) return;
    final arquivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 84,
    );
    if (arquivo == null || !_montado) return;
    _mudarEstado(() => _enviandoFotoPublico = true);
    try {
      final perfil = await _api.enviarFotoPerfilPublico(
        _tokenPublico!,
        await arquivo.readAsBytes(),
        arquivo.name,
      );
      if (_montado) _mudarEstado(() => _perfilPublico = perfil);
    } catch (erro) {
      if (_montado) mostrarErro(_contexto, erro);
    } finally {
      if (_montado) _mudarEstado(() => _enviandoFotoPublico = false);
    }
  }
}
