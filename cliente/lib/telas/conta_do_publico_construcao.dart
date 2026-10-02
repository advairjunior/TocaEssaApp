part of 'conta_do_publico.dart';

extension _ConstrucaoContaPublico on _ContaDoPublicoState {
  bool get _noPerfil => _perfil != null && _aba == 1;

  Widget _construirConta(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_noPerfil ? 'Meu perfil' : 'Minhas resenhas'),
          leading: _noPerfil
              ? IconButton(
                  tooltip: 'Voltar às resenhas',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _alterar(() => _aba = 0),
                )
              : null,
          actions: [
            if (_perfil != null && !_noPerfil) ...[
              IconButton(
                tooltip: 'Atualizar',
                onPressed: _ocupado ? null : _carregar,
                icon: const Icon(Icons.refresh_rounded),
              ),
              Semantics(
                button: true,
                child: IconButton(
                  tooltip: 'Meu perfil',
                  onPressed: () => _alterar(() => _aba = 1),
                  icon: CircleAvatar(
                    radius: 15,
                    backgroundColor: CoresTocaEssa.roxo.withValues(alpha: .24),
                    foregroundColor: CoresTocaEssa.roxoClaro,
                    foregroundImage: _perfil!.fotoUrl == null
                        ? null
                        : NetworkImage(
                            widget.api.enderecoArquivo(_perfil!.fotoUrl)!),
                    child: const Icon(Icons.person_rounded, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: EspacoTocaEssa.mini),
            ],
          ],
        ),
        body: FundoTocaEssa(
          variante: VarianteFundoTocaEssa.atmosfera,
          intensidade: _perfil == null
              ? IntensidadeFundoTocaEssa.imersiva
              : IntensidadeFundoTocaEssa.suave,
          child: _ocupado && _perfil == null
              ? const Center(child: CircularProgressIndicator())
              : ConteudoMobile(
                  filho: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _erro != null
                        ? _construirErro()
                        : _perfil == null
                            ? _construirAcesso(context)
                            : _noPerfil
                                ? [
                                    PerfilPublicoAtivo(
                                      perfil: _perfil!,
                                      estatisticas: _estatisticas,
                                      enderecoFoto: widget.api
                                          .enderecoArquivo(_perfil!.fotoUrl),
                                      enviandoFoto: _ocupado,
                                      trocarFoto: _foto,
                                      sair: _sair,
                                    ),
                                  ]
                                : _construirResenhas(context),
                  ),
                ),
        ),
      );

  List<Widget> _construirErro() => [
        const EstadoVazio(
          icone: Icons.wifi_off_rounded,
          titulo: 'Não foi possível carregar',
          descricao: 'Confira sua conexão e tente de novo.',
        ),
        FilledButton(
          onPressed: _carregar,
          child: const Text('Tentar novamente'),
        ),
        TextButton(
          onPressed: _sair,
          child: const Text('Entrar com outra conta'),
        ),
      ];

  List<Widget> _construirAcesso(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    const entreCampos = SizedBox(height: EspacoTocaEssa.base + 4);
    return [
      const SizedBox(height: EspacoTocaEssa.base),
      Text(
        _cadastro ? 'Crie seu perfil' : 'Entre na sua conta',
        style: texto.headlineSmall,
      ),
      const SizedBox(height: EspacoTocaEssa.mini),
      Text(
        'Reencontre suas resenhas, músicas e conquistas sem precisar '
        'guardar códigos.',
        style: texto.bodyMedium?.copyWith(color: CoresTocaEssa.textoSecundario),
      ),
      const SizedBox(height: EspacoTocaEssa.grande),
      if (_cadastro) ...[
        CampoTexto(
          rotulo: 'Seu nome',
          controlador: _nome,
          capitalizacao: TextCapitalization.words,
          acaoTeclado: TextInputAction.next,
        ),
        entreCampos,
      ],
      CampoTexto(
        rotulo: 'E-mail',
        controlador: _email,
        dica: 'voce@exemplo.com',
        teclado: TextInputType.emailAddress,
        acaoTeclado: TextInputAction.next,
      ),
      entreCampos,
      CampoTexto(
        rotulo: 'Senha',
        controlador: _senha,
        oculto: true,
        aoEnviar: (_) => _entrar(),
      ),
      const SizedBox(height: EspacoTocaEssa.grande),
      FilledButton(
        onPressed: _ocupado ? null : _entrar,
        child: Text(_cadastro ? 'Criar conta' : 'Entrar'),
      ),
      const SizedBox(height: EspacoTocaEssa.pequeno),
      TextButton(
        onPressed: () => _alterar(() => _cadastro = !_cadastro),
        child: Text(_cadastro ? 'Já tenho conta' : 'Criar meu perfil'),
      ),
      TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: CoresTocaEssa.textoSecundario,
        ),
        onPressed: () => Navigator.pushNamed(context, '/'),
        icon: const Icon(Icons.tag_rounded, size: 18),
        label: const Text('Entrar com um código'),
      ),
    ];
  }

  List<Widget> _construirResenhas(BuildContext context) {
    List<Apresentacao> comStatus(StatusApresentacao status) =>
        _apresentacoes.where((a) => a.status == status).toList()
          ..sort((a, b) => b.data.compareTo(a.data));
    final aoVivo = comStatus(StatusApresentacao.emAndamento);
    final filtradas = comStatus(_filtro);
    LinhaComData linha(Apresentacao apresentacao) => LinhaComData(
          data: apresentacao.data,
          titulo: apresentacao.nome,
          subtitulo:
              '${apresentacao.local} · ${apresentacao.perfilArtistico.nomeArtistico}',
          tocar: () => _abrir(apresentacao),
        );
    return [
      if (aoVivo.isNotEmpty) ...[
        const TituloGrupo('Acontecendo agora'),
        GrupoDeLinhas(
          recuoDivisoria: 84,
          linhas: [for (final apresentacao in aoVivo) linha(apresentacao)],
        ),
        const SizedBox(height: EspacoTocaEssa.grande),
      ],
      Row(
        children: [
          Flexible(
            child: AbaDeTexto(
              rotulo: 'Próximas',
              quantidade: comStatus(StatusApresentacao.agendada).length,
              selecionada: _filtro == StatusApresentacao.agendada,
              tocar: () =>
                  _alterar(() => _filtro = StatusApresentacao.agendada),
            ),
          ),
          const SizedBox(width: EspacoTocaEssa.base),
          Flexible(
            child: AbaDeTexto(
              rotulo: 'Histórico',
              quantidade: comStatus(StatusApresentacao.encerrada).length,
              selecionada: _filtro == StatusApresentacao.encerrada,
              tocar: () =>
                  _alterar(() => _filtro = StatusApresentacao.encerrada),
            ),
          ),
        ],
      ),
      const SizedBox(height: EspacoTocaEssa.base),
      if (filtradas.isEmpty)
        _filtro == StatusApresentacao.agendada
            ? const EstadoVazio(
                icone: Icons.event_outlined,
                titulo: 'Nenhum encontro agendado',
                descricao: 'Quando você entrar em uma resenha marcada, '
                    'ela aparece aqui.',
              )
            : const EstadoVazio(
                icone: Icons.history_rounded,
                titulo: 'Histórico vazio',
                descricao: 'Os encontros que já aconteceram ficam guardados '
                    'aqui, com fila, galera e retrospectiva.',
              )
      else
        GrupoDeLinhas(
          recuoDivisoria: 84,
          linhas: [for (final apresentacao in filtradas) linha(apresentacao)],
        ),
      const SizedBox(height: EspacoTocaEssa.grande),
      TextButton.icon(
        onPressed: () async {
          await Navigator.pushNamed(context, '/');
          if (mounted) await _carregar();
        },
        icon: const Icon(Icons.tag_rounded, size: 18),
        label: const Text('Entrar em outra apresentação'),
      ),
    ];
  }
}
