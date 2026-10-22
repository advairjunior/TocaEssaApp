part of 'painel_do_artista.dart';

extension _AcoesDoPerfilDoPainel on _PainelDoArtistaState {
  Future<void> _carregarGalera([String? apresentacaoId]) async {
    final id = apresentacaoId ?? _resenhaGaleraId;
    if (id == null || _carregandoGalera) return;
    _mudarEstado(() {
      _resenhaGaleraId = id;
      _carregandoGalera = true;
    });
    try {
      final participantes =
          await widget.api.listarParticipantesDaResenhaDoArtista(id);
      if (!mounted || _resenhaGaleraId != id) return;
      _mudarEstado(() => _galera = participantes);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) _mudarEstado(() => _carregandoGalera = false);
    }
  }

  Future<void> _salvarPerfil() async {
    if (_nomeArtistico.text.trim().isEmpty) {
      mostrarErro(context, 'Informe o nome artístico.');
      return;
    }
    _mudarEstado(() => _salvando = true);
    try {
      final configuracao = await widget.api.salvarPerfil(
        nomeArtistico: _nomeArtistico.text.trim(),
        bio: _bio.text.trim(),
        instagram: _instagram.text.trim(),
        exibirInstagram: _exibirInstagram,
        whatsapp: _whatsapp.text.trim(),
        exibirWhatsapp: _exibirWhatsapp,
        pixAtivo: _pixAtivo,
        pixChave: _pixChave.text.trim(),
        pixNomeBeneficiario: _pixNomeBeneficiario.text.trim(),
        pixCidadeBeneficiario: _pixCidadeBeneficiario.text.trim(),
        pixMensagem: _pixMensagem.text.trim(),
      );
      if (!mounted) return;
      _mudarEstado(() {
        _configuracaoPerfil = configuracao;
        _perfil = configuracao.perfil;
        // Adota os valores normalizados pela API para não sobrar "alteração".
        _restaurarPerfil();
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil artístico salvo.')));
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) _mudarEstado(() => _salvando = false);
    }
  }

  Future<void> _selecionarFoto() async {
    if (_perfil == null) {
      mostrarErro(
          context, 'Salve o Perfil Artístico antes de escolher a foto.');
      return;
    }
    final arquivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 82,
    );
    if (arquivo == null || !mounted) return;
    final bytes = await arquivo.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) mostrarErro(context, 'Escolha uma imagem de até 5 MB.');
      return;
    }
    _mudarEstado(() => _enviandoFoto = true);
    try {
      final perfil = await widget.api.enviarFotoPerfil(bytes, arquivo.name);
      if (!mounted) return;
      _mudarEstado(() {
        _perfil = perfil;
        _configuracaoPerfil = _configuracaoPerfil?.comPerfil(perfil);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto do Perfil Artístico atualizada.')),
      );
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) _mudarEstado(() => _enviandoFoto = false);
    }
  }

  Future<void> _novaApresentacao() async {
    final criada = await Navigator.push<Object>(
      context,
      MaterialPageRoute<Object>(
        builder: (_) => _FormularioApresentacao(
          salvar: (dados) async {
            final criada = await widget.api.criarApresentacao(
              dados.nome,
              dados.data,
              dados.local,
              dados.tipo,
            );
            if (dados.duracaoMinutos != null) {
              await widget.api.configurarRelogio(
                  criada.apresentacao.id, dados.duracaoMinutos,
                  pausa: dados.intervaloPausa);
            }
            return criada;
          },
        ),
      ),
    );
    if (!mounted || criada is! ApresentacaoCriada) return;
    _mudarEstado(() {
      _apresentacoes = [criada.apresentacao, ..._apresentacoes];
      _apresentacaoGestaoId = criada.apresentacao.id;
      _filtroApresentacoes = _FiltroApresentacoes.proximas;
    });
    await _mostrarCodigo(criada.apresentacao, recemCriada: true);
  }
}
