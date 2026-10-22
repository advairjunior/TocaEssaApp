part of 'painel_do_artista.dart';

extension _ConstrucaoPerfilDoArtista on _PainelDoArtistaState {
  Widget _construirTelaPerfil(BuildContext context) {
    final paddingBottom = MediaQuery.paddingOf(context).bottom;
    // Botão sempre no lugar (sem pular o layout); habilita só com alterações.
    final podeSalvar = !_salvando && (_perfil == null || _perfilAlterado);

    return Column(
      children: [
        Expanded(
          child: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    EspacoTocaEssa.grande - 4,
                    EspacoTocaEssa.grande,
                    EspacoTocaEssa.grande - 4,
                    EspacoTocaEssa.grande,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _conteudoPerfil(context),
                  ),
                ),
              ),
            ),
          ),
        ),
        OcultoComTecladoAberto(
          child: Align(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  EspacoTocaEssa.grande - 4,
                  EspacoTocaEssa.pequeno,
                  EspacoTocaEssa.grande - 4,
                  EspacoTocaEssa.base + paddingBottom,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: podeSalvar ? _salvarPerfil : null,
                    child: Text(
                      _salvando
                          ? 'Salvando...'
                          : _perfil == null
                              ? 'Criar perfil artístico'
                              : 'Salvar alterações',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _conteudoPerfil(BuildContext context) {
    const entreSecoes = SizedBox(height: EspacoTocaEssa.enorme);
    const entreCampos = SizedBox(height: EspacoTocaEssa.base + 4);
    return [
      _PreviaDoPerfil(
        nome: _nomeArtistico.text.trim(),
        bio: _bio.text.trim(),
        enderecoFoto: _api.enderecoArquivo(_perfil?.fotoUrl),
        temFoto: _perfil?.fotoUrl != null,
        perfilSalvo: _perfil != null,
        enviandoFoto: _enviandoFoto,
        trocarFoto: _selecionarFoto,
      ),
      entreSecoes,
      const TituloGrupo('Identidade artística'),
      CampoTexto(
        rotulo: 'Nome artístico',
        controlador: _nomeArtistico,
        dica: 'Como o público te conhece',
        capitalizacao: TextCapitalization.words,
        acaoTeclado: TextInputAction.next,
      ),
      entreCampos,
      CampoTexto(
        rotulo: 'Apresentação breve',
        controlador: _bio,
        dica: 'Opcional. Ex.: Voz e violão, MPB e pop rock',
        capitalizacao: TextCapitalization.sentences,
        linhas: 3,
      ),
      entreSecoes,
      const TituloGrupo('Contatos públicos'),
      CampoTexto(
        rotulo: 'Instagram',
        controlador: _instagram,
        dica: '@seuperfil',
        acaoTeclado: TextInputAction.next,
      ),
      _InterruptorDoPerfil(
        titulo: 'Exibir Instagram ao público',
        valor: _exibirInstagram,
        alterar: (valor) => _mudarEstado(() => _exibirInstagram = valor),
      ),
      const SizedBox(height: EspacoTocaEssa.pequeno),
      CampoTexto(
        rotulo: 'WhatsApp profissional',
        controlador: _whatsapp,
        dica: '5511999999999',
        teclado: TextInputType.phone,
      ),
      _InterruptorDoPerfil(
        titulo: 'Exibir WhatsApp ao público',
        valor: _exibirWhatsapp,
        alterar: (valor) => _mudarEstado(() => _exibirWhatsapp = valor),
      ),
      entreSecoes,
      const TituloGrupo('Apoio via Pix'),
      _InterruptorDoPerfil(
        titulo: 'Aceitar contribuições',
        descricao: 'Voluntária, sem confirmação automática.',
        valor: _pixAtivo,
        alterar: (valor) => _mudarEstado(() => _pixAtivo = valor),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: _pixAtivo
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: EspacoTocaEssa.medio),
                  CampoTexto(
                    rotulo: 'Chave Pix',
                    controlador: _pixChave,
                    ajuda: 'Prefira uma chave aleatória. Celular com +55 e DDD',
                  ),
                  entreCampos,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: CampoTexto(
                          rotulo: 'Beneficiário',
                          controlador: _pixNomeBeneficiario,
                          comprimentoMaximo: 25,
                          capitalizacao: TextCapitalization.characters,
                        ),
                      ),
                      const SizedBox(width: EspacoTocaEssa.medio),
                      Expanded(
                        flex: 2,
                        child: CampoTexto(
                          rotulo: 'Cidade',
                          controlador: _pixCidadeBeneficiario,
                          comprimentoMaximo: 15,
                          capitalizacao: TextCapitalization.characters,
                        ),
                      ),
                    ],
                  ),
                  entreCampos,
                  CampoTexto(
                    rotulo: 'Mensagem de agradecimento',
                    controlador: _pixMensagem,
                    dica: 'Opcional',
                    ajuda: 'Exibida ao público depois de gerar o Pix',
                    comprimentoMaximo: 72,
                  ),
                ],
              )
            : const SizedBox(width: double.infinity),
      ),
      entreSecoes,
      _ProgressoDoArtista(apresentacoes: _apresentacoes),
      entreSecoes,
      const TituloGrupo('Conta'),
      GrupoDeLinhas(
        linhas: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              EspacoTocaEssa.base,
              EspacoTocaEssa.medio,
              EspacoTocaEssa.pequeno,
              EspacoTocaEssa.medio,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_conta.nome,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        _conta.email,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: CoresTocaEssa.textoSecundario),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _salvando ? null : _sair,
                  child: const Text('Sair'),
                ),
              ],
            ),
          ),
          LinhaInstalarApp(),
        ],
      ),
    ];
  }
}
