part of 'area_do_publico.dart';

extension _ConstrucaoAreaDoPublico on _AreaDoPublicoState {
  Widget _construirArea(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Área do Público'), actions: [
          IconButton(
              tooltip: 'Minha conta e histórico',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => Navigator.pushNamed(context, '/minha-conta')),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _abaSelecionada,
          onDestinationSelected: (indice) {
            if (indice != _indicePerfil &&
                _tipoApresentacao == TipoApresentacao.resenhaEntreAmigos &&
                _perfilPublico == null) {
              mostrarErro(
                  context, 'Entre no seu perfil para participar da resenha.');
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
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Perfil',
            ),
          ],
        ),
        body: ConteudoMobile(
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
                  if (_abaSelecionada == 0)
                    _CabecalhoCompactoPedido(
                      apresentacao: apresentacao,
                      enderecoFoto: _api.enderecoArquivo(
                        apresentacao.perfilArtistico.fotoUrl,
                      ),
                    )
                  else if (_abaSelecionada != _indicePerfil)
                    _CartaoApresentacaoPublica(
                      apresentacao: apresentacao,
                      enderecoFoto: _api.enderecoArquivo(
                        apresentacao.perfilArtistico.fotoUrl,
                      ),
                      copiarCodigo: () => _copiarCodigo(apresentacao.codigo),
                    ),
                  ..._construirConteudoDaAba(apresentacao, context),
                ],
              );
            },
          ),
        ),
      );

  List<Widget> _construirConteudoDaAba(
      Apresentacao apresentacao, BuildContext context) {
    if (_abaSelecionada == _indicePerfil) {
      return _construirAbaPerfil(apresentacao, context);
    }
    if (_abaSelecionada == 0) return _construirAbaPedir(apresentacao, context);
    if (_abaSelecionada == 1) return _construirAbaFila(context);
    return _construirAbaGalera();
  }

  List<Widget> _construirAbaPerfil(
          Apresentacao apresentacao, BuildContext context) =>
      [
        const SizedBox(height: 20),
        Text(
          'Perfil do Público',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
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
            const Text('Sua conta e sua trajetória em todas as apresentações.'),
            const SizedBox(height: 12),
            PerfilPublicoAtivo(
              perfil: _perfilPublico!,
              estatisticas: _estatisticasPublico,
              enderecoFoto: _api.enderecoArquivo(_perfilPublico!.fotoUrl),
              enviandoFoto: _enviandoFotoPublico,
              trocarFoto: _selecionarFotoPublico,
              sair: _sairDoPerfilPublico,
            ),
          ] else ...[
            _CabecalhoCompactoPedido(
              apresentacao: apresentacao,
              enderecoFoto:
                  _api.enderecoArquivo(apresentacao.perfilArtistico.fotoUrl),
            ),
            const SizedBox(height: 16),
            const Text('Sua participação apenas neste encontro.'),
            const SizedBox(height: 12),
            if (_minhaParticipacaoNaResenha == null)
              const Text(
                  'Sua participação está sendo atualizada. Aguarde um instante.')
            else ...[
              _CartaoPessoaDaResenha(
                participante: _minhaParticipacaoNaResenha!,
                souEu: true,
                enderecoFoto: _api.enderecoArquivo(_perfilPublico!.fotoUrl),
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
