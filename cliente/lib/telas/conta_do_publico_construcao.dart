part of 'conta_do_publico.dart';

extension _ConstrucaoContaPublico on _ContaDoPublicoState {
  bool get _noPerfil => _perfil != null && _aba == 1;

  // Sem conta, a tela fala a língua do início: foto do palco e marca.
  bool get _semConta => _perfil == null && _erro == null;

  Widget _construirConta(BuildContext context) => Scaffold(
        body: FundoTocaEssa(
          variante: _semConta && _token == null
              ? VarianteFundoTocaEssa.palco
              : VarianteFundoTocaEssa.atmosfera,
          intensidade: _semConta
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
                                    _cabecalhoDoPerfil(context),
                                    const SizedBox(height: EspacoTocaEssa.base),
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

  Widget _cabecalhoDoPerfil(BuildContext context) => Row(
        children: [
          BotaoVoltarRedondo(
            dica: 'Voltar às resenhas',
            tocar: () => _alterar(() => _aba = 0),
          ),
          const SizedBox(width: EspacoTocaEssa.medio),
          Text('Meu perfil', style: Theme.of(context).textTheme.titleLarge),
        ],
      );

  List<Widget> _construirErro() => [
        const Align(
          alignment: Alignment.centerLeft,
          child: BotaoVoltarRedondo(),
        ),
        const SizedBox(height: EspacoTocaEssa.enorme),
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
    const entreCampos = SizedBox(height: EspacoTocaEssa.base);
    return [
      const Align(
        alignment: Alignment.centerLeft,
        child: BotaoVoltarRedondo(),
      ),
      const SizedBox(height: EspacoTocaEssa.base),
      Image.asset(
        'assets/marca/toca_essa_horizontal.png',
        height: 64,
        fit: BoxFit.contain,
        semanticLabel: 'TocaEssa',
      ),
      const SizedBox(height: EspacoTocaEssa.grande),
      Text(
        'Suas noites, guardadas.',
        textAlign: TextAlign.center,
        style: texto.headlineMedium?.copyWith(fontSize: 28, letterSpacing: -.4),
      ),
      const SizedBox(height: EspacoTocaEssa.pequeno),
      Text(
        'As músicas que você pediu, quem estava com você e a foto de cada '
        'resenha — sem precisar guardar códigos.',
        textAlign: TextAlign.center,
        style: texto.bodyMedium?.copyWith(color: CoresTocaEssa.textoSecundario),
      ),
      const SizedBox(height: EspacoTocaEssa.enorme),
      _PainelDeVidro(
        filho: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _cadastro ? 'Crie seu perfil' : 'Entre na sua conta',
              style: texto.titleMedium,
            ),
            const SizedBox(height: EspacoTocaEssa.base),
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
          ],
        ),
      ),
      const SizedBox(height: EspacoTocaEssa.base),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _cadastro ? 'Já tem conta?' : 'Primeira vez aqui?',
            style: texto.bodyMedium
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
          TextButton(
            onPressed: () => _alterar(() => _cadastro = !_cadastro),
            child: Text(_cadastro ? 'Já tenho conta' : 'Criar meu perfil'),
          ),
        ],
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

    final cabecalho = [
      Row(
        children: [
          const BotaoVoltarRedondo(),
          const Spacer(),
          _BotaoMeuPerfil(
            enderecoFoto: widget.api.enderecoArquivo(_perfil!.fotoUrl),
            tocar: () => _alterar(() => _aba = 1),
          ),
        ],
      ),
      const SizedBox(height: EspacoTocaEssa.grande),
      const Text(
        'Minhas resenhas',
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w600,
          height: 1.1,
          letterSpacing: -.6,
        ),
      ),
    ];

    if (_encontros.isEmpty) {
      return [
        ...cabecalho,
        const SizedBox(height: EspacoTocaEssa.enorme),
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
    var indiceMemoria = 0;
    return [
      ...cabecalho,
      if (_estatisticas != null) ...[
        const SizedBox(height: EspacoTocaEssa.medio),
        _ResumoDasResenhas(estatisticas: _estatisticas!),
      ],
      const SizedBox(height: EspacoTocaEssa.enorme),
      for (final apresentacao in aoVivo) ...[
        _CartaoResenhaAoVivo(
          apresentacao: apresentacao,
          enderecoCapa:
              widget.api.enderecoArquivo(apresentacao.perfilArtistico.fotoUrl),
          abrir: () => _abrir(apresentacao),
        ),
        const SizedBox(height: EspacoTocaEssa.enorme),
      ],
      if (proximas.isNotEmpty) ...[
        Text('Próximas', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: EspacoTocaEssa.pequeno),
        for (final apresentacao in proximas)
          _LinhaProxima(
            apresentacao: apresentacao,
            tocar: () => _abrir(apresentacao),
          ),
        const SizedBox(height: EspacoTocaEssa.enorme),
      ],
      for (final ano in anos) ...[
        _CabecalhoDoAno(
          ano: ano,
          abrirRetrospectiva: () => Navigator.push<void>(
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
        ),
        const SizedBox(height: EspacoTocaEssa.base),
        for (final encontro
            in historico.where((e) => e.apresentacao.data.year == ano)) ...[
          _CartaoMemoria(
            key: ValueKey('memoria-${encontro.apresentacao.id}'),
            encontro: encontro,
            fotoNova: _temFotoNova(encontro.apresentacao),
            enderecoCapa: widget.api.enderecoArquivo(
              encontro.apresentacao.fotoRetrospectivaUrl ??
                  encontro.apresentacao.perfilArtistico.fotoUrl,
            ),
            // Alterna os fundos de palco para que noites sem foto não
            // fiquem todas iguais.
            fundoAlternativo: (indiceMemoria++).isEven
                ? 'assets/fundos/bastidores.png'
                : 'assets/fundos/inicio_palco.png',
            enderecoFoto: widget.api.enderecoArquivo,
            tocar: () => _abrirMemoria(encontro),
          ),
          const SizedBox(height: EspacoTocaEssa.base),
        ],
        const SizedBox(height: EspacoTocaEssa.base),
      ],
      Center(
        child: TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: CoresTocaEssa.textoSecundario,
          ),
          onPressed: entrarComCodigo,
          icon: const Icon(Icons.tag_rounded, size: 18),
          label: const Text('Entrar com um código'),
        ),
      ),
    ];
  }
}
