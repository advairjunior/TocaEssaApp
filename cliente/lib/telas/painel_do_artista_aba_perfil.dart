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
        ],
      ),
    ];
  }
}

/// Mostra o perfil como o público verá, atualizado enquanto se digita.
class _PreviaDoPerfil extends StatelessWidget {
  const _PreviaDoPerfil({
    required this.nome,
    required this.bio,
    required this.enderecoFoto,
    required this.temFoto,
    required this.perfilSalvo,
    required this.enviandoFoto,
    required this.trocarFoto,
  });

  final String nome;
  final String bio;
  final String? enderecoFoto;
  final bool temFoto;
  final bool perfilSalvo;
  final bool enviandoFoto;
  final VoidCallback trocarFoto;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final secundario = texto.bodyMedium?.copyWith(
      color: CoresTocaEssa.textoSecundario,
    );
    return Column(
      children: [
        Text(
          'Como o público vê',
          style: texto.labelMedium?.copyWith(
            color: CoresTocaEssa.textoSecundario,
            letterSpacing: .4,
          ),
        ),
        const SizedBox(height: EspacoTocaEssa.base),
        SizedBox.square(
          dimension: 112,
          child: Stack(
            children: [
              FotoPerfilArtistico(enderecoFoto: enderecoFoto, tamanho: 112),
              if (perfilSalvo)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(
                    tooltip: temFoto ? 'Trocar foto' : 'Adicionar foto',
                    onPressed: enviandoFoto ? null : trocarFoto,
                    style: IconButton.styleFrom(
                      backgroundColor: CoresTocaEssa.roxo,
                      side: const BorderSide(
                        color: CoresTocaEssa.fundo,
                        width: 3,
                      ),
                    ),
                    icon: enviandoFoto
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: CoresTocaEssa.texto,
                            ),
                          )
                        : const Icon(Icons.photo_camera_rounded, size: 20),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: EspacoTocaEssa.base),
        Text(
          nome.isEmpty ? 'Seu nome artístico' : nome,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: texto.headlineSmall,
        ),
        const SizedBox(height: EspacoTocaEssa.mini),
        Text(
          bio.isEmpty ? 'Adicione uma breve apresentação.' : bio,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: secundario,
        ),
        if (!perfilSalvo) ...[
          const SizedBox(height: EspacoTocaEssa.pequeno),
          Text(
            'Salve o perfil para adicionar uma foto.',
            textAlign: TextAlign.center,
            style: texto.labelMedium
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
        ],
      ],
    );
  }
}

class _InterruptorDoPerfil extends StatelessWidget {
  const _InterruptorDoPerfil({
    required this.titulo,
    required this.valor,
    required this.alterar,
    this.descricao,
  });

  final String titulo;
  final String? descricao;
  final bool valor;
  final ValueChanged<bool> alterar;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: EspacoTocaEssa.mini),
        title: Text(titulo, style: Theme.of(context).textTheme.bodyLarge),
        subtitle: descricao == null
            ? null
            : Text(
                descricao!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: CoresTocaEssa.textoSecundario),
              ),
        value: valor,
        onChanged: alterar,
      );
}
