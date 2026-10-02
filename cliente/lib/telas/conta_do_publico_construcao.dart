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
    List<EncontroDoPublico> comStatus(StatusApresentacao status) =>
        _encontros.where((e) => e.apresentacao.status == status).toList()
          ..sort((a, b) => b.apresentacao.data.compareTo(a.apresentacao.data));
    final aoVivo = [
      for (final e in comStatus(StatusApresentacao.emAndamento)) e.apresentacao
    ];
    // Próximas da mais perto para a mais distante; histórico ao contrário.
    final proximas = [
      for (final e in comStatus(StatusApresentacao.agendada).reversed)
        e.apresentacao
    ];
    final historico = comStatus(StatusApresentacao.encerrada);
    final anos = {for (final e in historico) e.apresentacao.data.year};
    Future<void> entrarComCodigo() async {
      await Navigator.pushNamed(context, '/');
      if (mounted) await _carregar();
    }

    if (_encontros.isEmpty) {
      return [
        const EstadoVazio(
          icone: Icons.queue_music_rounded,
          titulo: 'Sua primeira resenha te espera',
          descricao: 'Entre com o código do artista e o encontro fica '
              'guardado aqui, com a fila, a galera e sua retrospectiva.',
        ),
        FilledButton.icon(
          onPressed: entrarComCodigo,
          icon: const Icon(Icons.tag_rounded),
          label: const Text('Entrar com um código'),
        ),
      ];
    }
    return [
      if (_estatisticas != null) ...[
        _ResumoDasResenhas(estatisticas: _estatisticas!),
        const SizedBox(height: EspacoTocaEssa.grande),
      ],
      for (final apresentacao in aoVivo) ...[
        _CartaoResenhaAoVivo(
          apresentacao: apresentacao,
          abrir: () => _abrir(apresentacao),
        ),
        const SizedBox(height: EspacoTocaEssa.grande),
      ],
      if (proximas.isNotEmpty) ...[
        const TituloGrupo('Próximas'),
        GrupoDeLinhas(
          recuoDivisoria: 84,
          linhas: [
            for (final apresentacao in proximas)
              LinhaComData(
                data: apresentacao.data,
                titulo: apresentacao.nome,
                subtitulo: '${apresentacao.perfilArtistico.nomeArtistico} · '
                    '${apresentacao.local}',
                tocar: () => _abrir(apresentacao),
              ),
          ],
        ),
        const SizedBox(height: EspacoTocaEssa.grande),
      ],
      for (final ano in anos) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: TituloGrupo('$ano')),
            TextButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => RetrospectivaDoAno(
                    ano: ano,
                    nome: _perfil!.nome,
                    encontros: [
                      for (final e in historico)
                        if (e.apresentacao.data.year == ano) e
                    ],
                  ),
                ),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text('Meu $ano'),
            ),
          ],
        ),
        GrupoDeLinhas(
          recuoDivisoria: 88,
          linhas: [
            for (final encontro
                in historico.where((e) => e.apresentacao.data.year == ano))
              _LinhaMemoria(
                encontro: encontro,
                fotoNova: _temFotoNova(encontro.apresentacao),
                enderecoCapa: widget.api.enderecoArquivo(
                  encontro.apresentacao.fotoRetrospectivaUrl ??
                      encontro.apresentacao.perfilArtistico.fotoUrl,
                ),
                enderecoFoto: widget.api.enderecoArquivo,
                tocar: () => _abrir(encontro.apresentacao),
              ),
          ],
        ),
        const SizedBox(height: EspacoTocaEssa.grande),
      ],
      OutlinedButton.icon(
        onPressed: entrarComCodigo,
        icon: const Icon(Icons.tag_rounded, size: 18),
        label: const Text('Entrar com um código'),
      ),
    ];
  }
}
