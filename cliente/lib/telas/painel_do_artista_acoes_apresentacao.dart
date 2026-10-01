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
    if (status == StatusApresentacao.encerrada) {
      final confirmou = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Encerrar apresentação?'),
              content: const Text(
                'O público deixa de enviar pedidos. A fila e o histórico continuam disponíveis.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Encerrar'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmou || !mounted) return;
    }

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
    final atualizada = await Navigator.push<Object>(
      context,
      MaterialPageRoute<Object>(
        builder: (_) => _FormularioApresentacao(
          apresentacao: apresentacao,
          salvar: (dados) => widget.api.editarApresentacao(
            apresentacao.id,
            dados.nome,
            dados.data,
            dados.local,
            dados.tipo,
          ),
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

  String _linkPublico(String codigo) {
    final base = Uri.base;
    final origem = base.scheme == 'http' || base.scheme == 'https'
        ? base.origin
        : 'http://localhost:5173';
    return '$origem/#/publico/$codigo';
  }

  Future<void> _mostrarCodigo(Apresentacao apresentacao) =>
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => _CodigoDaApresentacao(
            apresentacao: apresentacao,
            linkPublico: _linkPublico(apresentacao.codigo),
            enderecoFoto:
                _api.enderecoArquivo(apresentacao.perfilArtistico.fotoUrl),
          ),
        ),
      );
}
