part of 'painel_do_artista.dart';

extension _AcoesDeApresentacaoDoArtista on _PainelDoArtistaState {
  Future<void> _alterarPedidos(Apresentacao apresentacao) async {
    try {
      final atualizada = await widget.api.alterarPedidosDaApresentacao(
        apresentacao.id,
        !apresentacao.pedidosAbertos,
      );
      if (!mounted) return;
      _mudarEstado(() => _apresentacoes = _apresentacoes
          .map((item) => item.id == atualizada.id ? atualizada : item)
          .toList());
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _alterarStatusApresentacao(
    Apresentacao apresentacao,
    StatusApresentacao status,
  ) async {
    // Encerrar é a última chance de pegar a galera junta: sem selfie ainda,
    // o aviso oferece tirar uma antes de encerrar.
    if (status == StatusApresentacao.encerrada &&
        apresentacao.fotoRetrospectivaUrl == null) {
      final selfieGuardada = await _lembrarDaSelfie(apresentacao);
      if (selfieGuardada == null || !mounted) return;
      await _mudarStatus(apresentacao, status);
      return;
    }
    final confirmacao = switch (status) {
      StatusApresentacao.emAndamento => (
          'Iniciar apresentação?',
          'O público passa a ver a apresentação como ao vivo. '
              'Se foi sem querer, dá para voltar para agendada na aba Mais.',
          'Iniciar',
        ),
      StatusApresentacao.encerrada => (
          'Encerrar apresentação?',
          'O público deixa de enviar pedidos. A fila e o histórico continuam disponíveis.',
          'Encerrar',
        ),
      StatusApresentacao.agendada => null,
    };
    if (confirmacao case (final titulo, final descricao, final rotulo)) {
      final confirmou = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(titulo),
              content: Text(descricao),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(rotulo),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmou || !mounted) return;
    }
    await _mudarStatus(apresentacao, status);
  }

  /// Pergunta da selfie ao encerrar. Devolve nulo quando o artista desiste
  /// (cancelou ou fechou a câmera), falso quando encerra sem foto e
  /// verdadeiro quando a selfie foi guardada na retrospectiva.
  Future<bool?> _lembrarDaSelfie(Apresentacao apresentacao) async {
    final tirarSelfie = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Encerrar apresentação?'),
        content: const Text(
            '📸 Antes da galera ir embora, tire uma selfie com o público '
            'para o cartão da retrospectiva.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Encerrar sem foto'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tirar selfie'),
          ),
        ],
      ),
    );
    if (tirarSelfie != true || !mounted) return tirarSelfie;
    final foto = await escolherFotoDoCartao(
      context,
      cartao: (_, fundo) => cartaoDaSelfie(apresentacao, fundo),
    );
    if (foto == null || !mounted) return null;
    _mudarEstado(() => _salvando = true);
    try {
      await widget.api.enviarFotoRetrospectiva(
        apresentacao.id,
        foto,
        foto.first == 0x89
            ? 'foto-retrospectiva.png'
            : 'foto-retrospectiva.jpg',
      );
      return true;
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
      return null;
    } finally {
      if (mounted) _mudarEstado(() => _salvando = false);
    }
  }

  Future<void> _mudarStatus(
    Apresentacao apresentacao,
    StatusApresentacao status,
  ) async {
    _mudarEstado(() => _salvando = true);
    try {
      final atualizada =
          await widget.api.alterarStatusApresentacao(apresentacao.id, status);
      if (!mounted) return;
      _mudarEstado(() {
        _apresentacoes = _apresentacoes
            .map((item) => item.id == atualizada.id ? atualizada : item)
            .toList();
        _filtroApresentacoes = status == StatusApresentacao.encerrada
            ? _FiltroApresentacoes.historico
            : _FiltroApresentacoes.proximas;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apresentação ${status.rotulo.toLowerCase()}.')),
      );
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) _mudarEstado(() => _salvando = false);
    }
  }

  Future<void> _editarApresentacao(Apresentacao apresentacao) async {
    final RelogioDoShow relogio;
    try {
      relogio = await widget.api.obterRelogio(apresentacao.id);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
      return;
    }
    if (!mounted) return;
    final atualizada = await Navigator.push<Object>(
      context,
      MaterialPageRoute<Object>(
        builder: (_) => _FormularioApresentacao(
          apresentacao: apresentacao,
          relogio: relogio,
          salvar: (dados) async {
            final editada = await widget.api.editarApresentacao(
              apresentacao.id,
              dados.nome,
              dados.data,
              dados.local,
              dados.tipo,
            );
            if (dados.duracaoMinutos != relogio.duracaoContratadaMinutos ||
                dados.intervaloPausa != relogio.intervaloPausaRelogio) {
              await widget.api.configurarRelogio(
                  apresentacao.id, dados.duracaoMinutos,
                  pausa: dados.intervaloPausa);
            }
            return editada;
          },
        ),
      ),
    );
    if (!mounted || atualizada is! Apresentacao) return;
    _mudarEstado(() => _apresentacoes = _apresentacoes
        .map((item) => item.id == atualizada.id ? atualizada : item)
        .toList());
  }

  Future<void> _excluirApresentacao(Apresentacao apresentacao) async {
    final confirmou = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir apresentação?'),
            content: Text(
              '“${apresentacao.nome}” e todos os pedidos dela serão excluídos. Não é possível desfazer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: CoresTocaEssa.rosa,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmou || !mounted) return;
    _mudarEstado(() => _salvando = true);
    try {
      await widget.api.excluirApresentacao(apresentacao.id);
      if (!mounted) return;
      _mudarEstado(() {
        _apresentacoes.removeWhere((item) => item.id == apresentacao.id);
        if (_dentroDaApresentacao && _apresentacaoGestaoId == apresentacao.id) {
          _aba = _AbaPainel.inicio;
        }
        if (_apresentacaoGestaoId == apresentacao.id) {
          _apresentacaoGestaoId =
              _escolherApresentacaoDaGestao(_apresentacoes)?.id;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apresentação excluída.')),
      );
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) _mudarEstado(() => _salvando = false);
    }
  }

  Future<void> _mostrarCodigo(
    Apresentacao apresentacao, {
    bool recemCriada = false,
  }) =>
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => _CodigoDaApresentacao(
            apresentacao: apresentacao,
            recemCriada: recemCriada,
            linkPublico: linkPublicoDoShow(apresentacao.codigo),
            enderecoFoto:
                _api.enderecoArquivo(apresentacao.perfilArtistico.fotoUrl),
          ),
        ),
      );
}
