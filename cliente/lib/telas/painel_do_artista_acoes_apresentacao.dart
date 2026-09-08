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
              title: const Text('Encerrar Apresentação?'),
              content: const Text(
                'Novos Pedidos Musicais serão encerrados. A fila e o histórico continuarão disponíveis.',
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
        _filtroApresentacoes = switch (status) {
          StatusApresentacao.agendada => _FiltroApresentacoes.agendadas,
          StatusApresentacao.emAndamento => _FiltroApresentacoes.aoVivo,
          StatusApresentacao.encerrada => _FiltroApresentacoes.historico,
        };
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
    final atualizada = await Navigator.push<Apresentacao>(
      context,
      MaterialPageRoute<Apresentacao>(
        builder: (_) => _EditarApresentacao(
          api: widget.api,
          apresentacao: apresentacao,
        ),
      ),
    );
    if (!mounted || atualizada == null) return;
    _mudarEstado(() => _apresentacoes = _apresentacoes
        .map((item) => item.id == atualizada.id ? atualizada : item)
        .toList());
  }

  Future<void> _excluirApresentacao(Apresentacao apresentacao) async {
    final confirmou = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir Apresentação?'),
            content: Text(
              '“${apresentacao.nome}” e todos os seus Pedidos Musicais serão excluídos.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
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
          ),
        ),
      );
}
