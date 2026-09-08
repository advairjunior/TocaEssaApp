// ignore_for_file: use_build_context_synchronously

part of 'area_do_publico.dart';

extension _PedidosAreaDoPublico on _AreaDoPublicoState {
  Future<void> _pedirMusica() async {
    if (_tipoPedido == TipoPedido.musica && _musica.text.trim().isEmpty) {
      mostrarErro(_contexto, 'Informe a música que deseja pedir.');
      return;
    }
    if (_tipoPedido == TipoPedido.alo && _destinatarioAlo.text.trim().isEmpty) {
      mostrarErro(_contexto, 'Informe para quem é o Alô.');
      return;
    }
    _mudarEstado(() => _enviando = true);
    try {
      final pedido = await _api.criarPedidoMusical(
        _codigoInicial,
        _tipoPedido == TipoPedido.musica ? _musica.text.trim() : '',
        _artista.text.trim(),
        _nome.text.trim(),
        token: _tokenPublico,
        formaParticipacao:
            _tipoApresentacao == TipoApresentacao.resenhaEntreAmigos
                ? _formaParticipacao
                : FormaParticipacaoPedido.pedidoNormal,
        tomPreferido: _tomPreferido.text.trim(),
        recado: _recado.text.trim(),
        tipo: _tipoPedido,
        destinatarioAlo: _destinatarioAlo.text.trim(),
      );
      if (!_montado) return;
      _musica.clear();
      _artista.clear();
      _tomPreferido.clear();
      _recado.clear();
      _destinatarioAlo.clear();
      _mudarEstado(
          () => _formaParticipacao = FormaParticipacaoPedido.pedidoNormal);
      await _salvarDadosDoPublico(pedido);
      if (!_montado) return;
      _mudarEstado(() {
        _meusPedidos = [pedido, ..._meusPedidos];
        _fila = _api.listarFilaPublica(
          _codigoInicial,
          token: _tokenPublico,
          identificadorAvaliador: _identificadorAvaliador,
        );
      });
      ScaffoldMessenger.of(_contexto).showSnackBar(
        SnackBar(
          content: Text(_tipoPedido == TipoPedido.alo
              ? 'Pedido de Alô enviado para o artista.'
              : 'Pedido Musical enviado para análise do artista.'),
        ),
      );
    } catch (erro) {
      if (_montado) mostrarErro(_contexto, erro);
    } finally {
      if (_montado) _mudarEstado(() => _enviando = false);
    }
  }

  Future<void> _atualizarMeusPedidos() async {
    try {
      final atualizados = await Future.wait(
          _meusPedidos.map((pedido) => _api.obterPedidoPublico(
                _codigoInicial,
                pedido.id,
                token: _tokenPublico,
              )));
      if (_montado) {
        _mudarEstado(() =>
            _meusPedidos = atualizados.whereType<PedidoMusical>().toList());
      }
    } catch (erro) {
      if (_montado) mostrarErro(_contexto, erro);
    }
  }

  Future<void> _cancelarPedido(PedidoMusical pedido) async {
    final confirmou = await showDialog<bool>(
          context: _contexto,
          builder: (contextoDialogo) => AlertDialog(
            title: const Text('Cancelar Pedido Musical?'),
            content: Text('O pedido “${pedido.musica}” será cancelado.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(contextoDialogo, false),
                child: const Text('Voltar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(contextoDialogo, true),
                child: const Text('Cancelar pedido'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmou || !_montado) return;
    _mudarEstado(() => _pedidoSendoCancelado = pedido.id);
    try {
      final cancelado = await _api.cancelarPedidoPublico(
        _codigoInicial,
        pedido.id,
        token: _tokenPublico,
      );
      if (!_montado) return;
      _mudarEstado(() => _meusPedidos = _meusPedidos
          .map((item) => item.id == cancelado.id ? cancelado : item)
          .toList());
      ScaffoldMessenger.of(_contexto).showSnackBar(
        const SnackBar(content: Text('Pedido Musical cancelado.')),
      );
    } catch (erro) {
      if (_montado) mostrarErro(_contexto, erro);
      await _atualizarMeusPedidos();
    } finally {
      if (_montado) _mudarEstado(() => _pedidoSendoCancelado = null);
    }
  }

  Future<void> _copiarCodigo(String codigo) async {
    await Clipboard.setData(ClipboardData(text: codigo));
    if (!_montado) return;
    ScaffoldMessenger.of(_contexto).showSnackBar(
      const SnackBar(content: Text('Código copiado.')),
    );
  }

  Future<void> _avaliarPedido(PedidoMusical pedido, int estrelas) async {
    _mudarEstado(() => _pedidoSendoAvaliado = pedido.id);
    try {
      final avaliado = await _api.avaliarPedidoPublico(
        _codigoInicial,
        pedido.id,
        estrelas,
        token: _tokenPublico,
        identificadorAvaliador: _identificadorAvaliador,
      );
      if (!_montado) return;
      _mudarEstado(() {
        _meusPedidos = _meusPedidos
            .map((item) => item.id == avaliado.id ? avaliado : item)
            .toList();
        _fila = _api.listarFilaPublica(
          _codigoInicial,
          token: _tokenPublico,
          identificadorAvaliador: _identificadorAvaliador,
        );
      });
      if (_tokenPublico != null) {
        final estatisticas = await _obterEstatisticasPublico(_tokenPublico!);
        if (_montado && estatisticas != null) {
          _mudarEstado(() => _estatisticasPublico = estatisticas);
        }
      }
      if (!_montado) return;
      ScaffoldMessenger.of(_contexto).showSnackBar(
        const SnackBar(content: Text('Obrigado pela avaliação!')),
      );
    } catch (erro) {
      if (_montado) mostrarErro(_contexto, erro);
    } finally {
      if (_montado) _mudarEstado(() => _pedidoSendoAvaliado = null);
    }
  }
}
