part of 'area_do_publico.dart';

extension _SessaoAreaDoPublico on _AreaDoPublicoState {
  Future<void> _restaurarDadosDoPublico() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      final nomeSalvo = preferencias.getString('nome_do_publico') ?? '';
      _identificadorAvaliador =
          preferencias.getString('identificador_avaliador') ??
              _identificadorAvaliador;
      await preferencias.setString(
          'identificador_avaliador', _identificadorAvaliador);
      if (_montado) {
        _mudarEstado(() {
          _fila = _consulta.then((item) => item == null
              ? <PedidoMusical>[]
              : _api.listarFilaPublica(
                  _codigoInicial,
                  identificadorAvaliador: _identificadorAvaliador,
                ));
        });
      }
      if (_nome.text.isEmpty) _nome.text = nomeSalvo;
      final apresentacao = await _consulta;
      if (apresentacao == null) return;

      final pedidosIdentificados = <PedidoMusical>[];
      final token = preferencias.getString('token_do_publico');
      if (token != null) {
        PerfilPublico? perfil;
        try {
          perfil = await _api.obterPerfilPublico(token);
        } catch (_) {
          await preferencias.remove('token_do_publico');
        }
        if (perfil != null) {
          if (_montado) {
            _mudarEstado(() {
              _tokenPublico = token;
              _perfilPublico = perfil;
            });
          }
          try {
            if (apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos) {
              await _api.registrarParticipacaoNaResenha(
                _codigoInicial,
                token,
              );
            }
            final pedidos = await _api.listarMeusPedidos(_codigoInicial, token);
            final estatisticas = await _obterEstatisticasPublico(token);
            final participantes =
                apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos
                    ? await _obterParticipantesDaResenha(token)
                    : <ParticipanteDaResenha>[];
            pedidosIdentificados.addAll(pedidos);
            if (!_montado) return;
            _mudarEstado(() {
              _estatisticasPublico = estatisticas;
              _participantesDaResenha = participantes;
              _fila = _api.listarFilaPublica(
                _codigoInicial,
                token: token,
                identificadorAvaliador: _identificadorAvaliador,
              );
            });
          } catch (_) {
            // A sessão permanece ativa e os dados tentam atualizar novamente.
          }
        }
      }

      if (apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos) {
        if (_montado) {
          _mudarEstado(() {
            _meusPedidos = pedidosIdentificados;
            if (_perfilPublico == null) _abaSelecionada = _indicePerfil;
          });
        }
        return;
      }

      final ids = preferencias.getStringList(_chavePedidos) ?? const [];
      if (ids.isEmpty) {
        if (_montado && pedidosIdentificados.isNotEmpty) {
          _mudarEstado(() => _meusPedidos = pedidosIdentificados);
        }
        return;
      }
      final pedidos = await Future.wait(
          ids.map((id) => _api.obterPedidoPublico(_codigoInicial, id)));
      if (!_montado) return;
      final restaurados = pedidos.whereType<PedidoMusical>().toList();
      _mudarEstado(() {
        final idsIdentificados =
            pedidosIdentificados.map((pedido) => pedido.id).toSet();
        _meusPedidos = [
          ...pedidosIdentificados,
          ...restaurados
              .where((pedido) => !idsIdentificados.contains(pedido.id)),
        ];
      });
      await preferencias.setStringList(
        _chavePedidos,
        restaurados.map((pedido) => pedido.id).toList(),
      );
    } catch (_) {
      // O pedido continua funcionando mesmo se o armazenamento local falhar.
    } finally {
      if (_montado) _mudarEstado(() => _carregandoSessao = false);
    }
  }

  Future<void> _salvarDadosDoPublico(PedidoMusical pedido) async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString('nome_do_publico', _nome.text.trim());
    final ids = preferencias.getStringList(_chavePedidos) ?? <String>[];
    ids.remove(pedido.id);
    ids.insert(0, pedido.id);
    await preferencias.setStringList(_chavePedidos, ids.take(50).toList());
  }

  Future<EstatisticasDoPublico?> _obterEstatisticasPublico(String token) async {
    try {
      return await _api.obterEstatisticasDoPublico(token);
    } catch (_) {
      return null;
    }
  }

  Future<List<ParticipanteDaResenha>> _obterParticipantesDaResenha(
      String token) async {
    try {
      return await _api.listarParticipantesDaResenhaPublica(
        _codigoInicial,
        token,
      );
    } catch (_) {
      return _participantesDaResenha;
    }
  }

  Future<void> _atualizarSilenciosamente() async {
    if (_atualizando || !_montado) return;
    _atualizando = true;
    try {
      final apresentacao = await _api.obterApresentacaoPublica(_codigoInicial);
      if (apresentacao == null) {
        if (_montado) {
          _mudarEstado(() {
            _consulta = Future.value(null);
            _fila = Future.value(<PedidoMusical>[]);
          });
        }
        return;
      }
      final fila = await _api.listarFilaPublica(
        _codigoInicial,
        token: _tokenPublico,
        identificadorAvaliador: _identificadorAvaliador,
      );
      final meusPedidos = _tokenPublico != null
          ? await _api.listarMeusPedidos(_codigoInicial, _tokenPublico!)
          : await Future.wait(_meusPedidos.map(
              (pedido) => _api.obterPedidoPublico(_codigoInicial, pedido.id)));
      final estatisticas = _tokenPublico != null
          ? await _obterEstatisticasPublico(_tokenPublico!)
          : null;
      final participantes = _tokenPublico != null &&
              apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos
          ? await _obterParticipantesDaResenha(_tokenPublico!)
          : <ParticipanteDaResenha>[];
      if (!_montado) return;
      _mudarEstado(() {
        _consulta = Future.value(apresentacao);
        _tipoApresentacao = apresentacao.tipo;
        _fila = Future.value(fila);
        _meusPedidos = meusPedidos.whereType<PedidoMusical>().toList();
        if (estatisticas != null) _estatisticasPublico = estatisticas;
        _participantesDaResenha = participantes;
      });
    } catch (_) {
      // A próxima atualização tenta novamente sem interromper a apresentação.
    } finally {
      _atualizando = false;
    }
  }
}
