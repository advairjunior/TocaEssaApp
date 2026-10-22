part of 'gerenciar_repertorios.dart';

extension _AcoesDoDetalhe on _DetalheRepertorioState {
  Future<void> _renomearRepertorio() async {
    final nome = await _pedirNome(
      context,
      titulo: 'Renomear repertório',
      rotulo: 'Nome do repertório',
      inicial: _nome,
    );
    if (nome == null || nome == _nome || !mounted) return;
    _mudarEstado(() => _salvando = true);
    try {
      final renomeado =
          await widget.api.renomearRepertorio(widget.repertorio.id, nome);
      if (!mounted) return;
      _mudarEstado(() => _nome = renomeado.nome);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) _mudarEstado(() => _salvando = false);
    }
  }

  Future<void> _adicionarMusica() async {
    final resultado = await _pedirMusica(context);
    if (resultado == null || !mounted) return;
    _mudarEstado(() => _salvando = true);
    try {
      final nova = await widget.api.adicionarMusicaAoRepertorio(
        widget.repertorio.id,
        resultado.$1,
        resultado.$2,
        tom: resultado.$3,
      );
      if (!mounted) return;
      _mudarEstado(() => _musicas = [..._musicas, nova]);
      // A música nova só oferece a cifra depois de conhecer a situação dela.
      await _carregarCifras();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) _mudarEstado(() => _salvando = false);
    }
  }

  Future<void> _editarMusica(MusicaDoRepertorio musica) async {
    final resultado = await _pedirMusica(
      context,
      tituloInicial: musica.titulo,
      artistaInicial: musica.artista,
      tomInicial: musica.tom,
    );
    if (resultado == null || !mounted) return;
    _mudarEstado(() => _salvando = true);
    try {
      final editada = await widget.api.editarMusicaDoRepertorio(
        widget.repertorio.id,
        musica.id,
        resultado.$1,
        artista: resultado.$2,
        tom: resultado.$3,
      );
      if (!mounted) return;
      _mudarEstado(() => _musicas =
          _musicas.map((m) => m.id == editada.id ? editada : m).toList());
      // Com outro nome, a música pode ter outra cifra.
      await _carregarCifras();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) _mudarEstado(() => _salvando = false);
    }
  }

  Future<void> _removerMusica(MusicaDoRepertorio musica) async {
    _mudarEstado(() => _salvando = true);
    try {
      await widget.api
          .removerMusicaDoRepertorio(widget.repertorio.id, musica.id);
      if (!mounted) return;
      _mudarEstado(
          () => _musicas = _musicas.where((m) => m.id != musica.id).toList());
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) _mudarEstado(() => _salvando = false);
    }
  }

  Future<void> _reordenar(int indiceAntigo, int indiceNovo) async {
    if (_salvando) return;
    if (indiceNovo == indiceAntigo) return;
    final anteriores = _musicas;
    final reordenadas = [..._musicas];
    reordenadas.insert(indiceNovo, reordenadas.removeAt(indiceAntigo));
    _mudarEstado(() {
      _musicas = reordenadas;
      _salvando = true;
    });
    try {
      final salvo = await widget.api.reordenarMusicasDoRepertorio(
        widget.repertorio.id,
        [for (final musica in reordenadas) musica.id],
      );
      if (!mounted) return;
      _mudarEstado(() => _musicas = salvo.musicas);
    } catch (erro) {
      if (!mounted) return;
      _mudarEstado(() => _musicas = anteriores);
      mostrarErro(context, erro);
    } finally {
      if (mounted) _mudarEstado(() => _salvando = false);
    }
  }

  Future<void> _excluirRepertorio() async {
    final rep = widget.repertorio;
    final confirmou = await showDialog<bool>(
          context: context,
          builder: (contexto) => AlertDialog(
            title: const Text('Excluir repertório?'),
            content: Text(
                '"$_nome" e suas ${_musicas.length} músicas serão removidos.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(contexto, false),
                  child: const Text('Cancelar')),
              FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CoresTocaEssa.rosa,
                  ),
                  onPressed: () => Navigator.pop(contexto, true),
                  child: const Text('Excluir')),
            ],
          ),
        ) ??
        false;
    if (!confirmou || !mounted) return;
    try {
      await widget.api.excluirRepertorio(rep.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$_nome" excluído.')),
      );
      Navigator.pop(context);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }
}
