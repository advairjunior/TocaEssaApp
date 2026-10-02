part of 'area_do_publico.dart';

extension _ConstrucaoAreaDoPublico on _AreaDoPublicoState {
  Widget _construirArea(BuildContext context) {
    final intensidadeDoFundo = _abaSelecionada == 1 ||
            (_tipoApresentacao == TipoApresentacao.resenhaEntreAmigos &&
                _abaSelecionada == 2)
        ? IntensidadeFundoTocaEssa.cabecalho
        : IntensidadeFundoTocaEssa.suave;
    final noPerfil = _abaSelecionada == _indicePerfil;
    // Na resenha sem perfil não há abas para onde voltar: a seta sai da tela.
    final podeVoltarAsAbas = noPerfil &&
        !(_tipoApresentacao == TipoApresentacao.resenhaEntreAmigos &&
            _perfilPublico == null);
    return Scaffold(
      appBar: AppBar(
          leading: podeVoltarAsAbas
              ? IconButton(
                  tooltip: 'Voltar às abas',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () =>
                      _mudarEstado(() => _abaSelecionada = _abaAntesDoPerfil),
                )
              : null,
          title: FutureBuilder<Apresentacao?>(
            future: _consulta,
            builder: (context, snapshot) => snapshot.data == null
                ? const Text('TocaEssa')
                : _TituloDoShow(apresentacao: snapshot.data!),
          ),
          actions: [
            IconButton(
              tooltip: 'Copiar código',
              icon: const Icon(Icons.share_rounded),
              onPressed: () =>
                  _copiarCodigo(widget.codigoInicial.trim().toUpperCase()),
            ),
            if (!noPerfil)
              Semantics(
                button: true,
                child: IconButton(
                  tooltip: 'Meu perfil',
                  onPressed: () => _mudarEstado(() {
                    _abaAntesDoPerfil = _abaSelecionada;
                    _abaSelecionada = _indicePerfil;
                  }),
                  icon: CircleAvatar(
                    radius: 15,
                    backgroundColor: CoresTocaEssa.roxo.withValues(alpha: .24),
                    foregroundColor: CoresTocaEssa.roxoClaro,
                    foregroundImage: _perfilPublico?.fotoUrl == null
                        ? null
                        : NetworkImage(
                            _api.enderecoArquivo(_perfilPublico!.fotoUrl)!),
                    child: const Icon(Icons.person_rounded, size: 18),
                  ),
                ),
              ),
            const SizedBox(width: EspacoTocaEssa.mini),
          ]),
      bottomNavigationBar: noPerfil
          ? null
          : OcultoComTecladoAberto(
              child: NavigationBar(
                selectedIndex: _abaSelecionada,
                onDestinationSelected: (indice) {
                  if (indice != _indicePerfil &&
                      indice != _indiceArtista &&
                      _tipoApresentacao ==
                          TipoApresentacao.resenhaEntreAmigos &&
                      _perfilPublico == null) {
                    mostrarErro(context,
                        'Entre no seu perfil para participar da resenha.');
                    _mudarEstado(() => _abaSelecionada = _indicePerfil);
                    return;
                  }
                  _mudarEstado(() => _abaSelecionada = indice);
                },
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.music_note_outlined),
                    selectedIcon: Icon(Icons.music_note_rounded),
                    label: 'Pedir',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.queue_music_outlined),
                    selectedIcon: Icon(Icons.queue_music_rounded),
                    label: 'Fila',
                  ),
                  if (_tipoApresentacao == TipoApresentacao.resenhaEntreAmigos)
                    const NavigationDestination(
                      icon: Icon(Icons.groups_outlined),
                      selectedIcon: Icon(Icons.groups_rounded),
                      label: 'Galera',
                    ),
                  const NavigationDestination(
                    icon: Icon(Icons.mic_external_on_outlined),
                    selectedIcon: Icon(Icons.mic_external_on_rounded),
                    label: 'Artista',
                  ),
                ],
              ),
            ),
      body: FundoTocaEssa(
        variante: VarianteFundoTocaEssa.atmosfera,
        intensidade: intensidadeDoFundo,
        child: ConteudoMobile(
          filho: FutureBuilder<Apresentacao?>(
            future: _consulta,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _MensagemPublica(
                  icone: Icons.wifi_off_rounded,
                  titulo: 'Não foi possível conectar',
                  descricao: snapshot.error.toString(),
                );
              }
              final apresentacao = snapshot.data;
              if (apresentacao == null) {
                return const _MensagemPublica(
                  icone: Icons.search_off_rounded,
                  titulo: 'Código não encontrado',
                  descricao:
                      'Confira o código com o artista e tente novamente.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  ..._construirConteudoDaAba(apresentacao, context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _construirConteudoDaAba(
      Apresentacao apresentacao, BuildContext context) {
    if (_abaSelecionada == _indicePerfil) {
      return _construirAbaPerfil(apresentacao, context);
    }
    if (_abaSelecionada == _indiceArtista) {
      return [
        const SizedBox(height: EspacoTocaEssa.pequeno),
        _construirPerfilPublicoArtista(apresentacao),
      ];
    }
    if (_abaSelecionada == 0) return _construirAbaPedir(apresentacao, context);
    if (_abaSelecionada == 1) return _construirAbaFila(context);
    return _construirAbaGalera();
  }

  List<Widget> _construirAbaPerfil(
          Apresentacao apresentacao, BuildContext context) =>
      [
        const SizedBox(height: EspacoTocaEssa.pequeno),
        if (_carregandoSessao)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_perfilPublico == null)
          _AcessoPerfilPublico(
            obrigatorio:
                apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos,
            criandoConta: _criandoConta,
            autenticando: _autenticando,
            nome: _nomeCadastro,
            email: _email,
            senha: _senha,
            alternarModo: () =>
                _mudarEstado(() => _criandoConta = !_criandoConta),
            autenticar: _autenticarPublico,
            continuarComoConvidado:
                apresentacao.tipo == TipoApresentacao.publica
                    ? () => _mudarEstado(() => _abaSelecionada = 0)
                    : null,
          )
        else ...[
          if (apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    label: Text('Perfil geral'),
                    icon: Icon(Icons.person_outline)),
                ButtonSegment(
                    value: true,
                    label: Text('Nesta resenha'),
                    icon: Icon(Icons.celebration_outlined)),
              ],
              selected: {_perfilDaResenha},
              onSelectionChanged: (valores) =>
                  _mudarEstado(() => _perfilDaResenha = valores.single),
            ),
            const SizedBox(height: 16),
          ],
          if (!_perfilDaResenha ||
              apresentacao.tipo == TipoApresentacao.publica) ...[
            PerfilPublicoAtivo(
              perfil: _perfilPublico!,
              estatisticas: _estatisticasPublico,
              enderecoFoto: _api.enderecoArquivo(_perfilPublico!.fotoUrl),
              enviandoFoto: _enviandoFotoPublico,
              trocarFoto: _selecionarFotoPublico,
              sair: _sairDoPerfilPublico,
              abrirResenhas: () => Navigator.pushNamed(context, '/minha-conta'),
            ),
          ] else ...[
            _CabecalhoCompactoPedido(
              apresentacao: apresentacao,
              enderecoFoto:
                  _api.enderecoArquivo(apresentacao.perfilArtistico.fotoUrl),
              abrirPerfil: () => _abrirPerfilDoArtista(apresentacao),
            ),
            const SizedBox(height: 16),
            const Text('Sua participação apenas neste encontro.'),
            const SizedBox(height: 12),
            if (_minhaParticipacaoNaResenha == null)
              const Text(
                  'Sua participação está sendo atualizada. Aguarde um instante.')
            else ...[
              GrupoDeLinhas(
                linhas: [
                  _LinhaPessoaDaResenha(
                    participante: _minhaParticipacaoNaResenha!,
                    souEu: true,
                    enderecoFoto: _api.enderecoArquivo(_perfilPublico!.fotoUrl),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ..._construirRetrospectivaDoPublico(
                apresentacao,
                _minhaParticipacaoNaResenha!,
              ),
            ],
          ],
        ],
      ];
}
