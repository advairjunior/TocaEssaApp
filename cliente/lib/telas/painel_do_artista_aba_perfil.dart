part of 'painel_do_artista.dart';

extension _ConstrucaoPerfilDoArtista on _PainelDoArtistaState {
  Widget _construirTelaPerfil(BuildContext context) {
    final paddingBottom = MediaQuery.paddingOf(context).bottom;
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
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
                padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + paddingBottom),
                child: FilledButton(
                  onPressed: _salvando ? null : _salvarPerfil,
                  child: Text(
                    _perfil == null
                        ? 'Criar Perfil Artístico'
                        : 'Salvar alterações',
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _conteudoPerfil(BuildContext context) => [
        _construirPreviewPerfil(context),
        const SizedBox(height: 16),
        _construirCardIdentidade(),
        const SizedBox(height: 16),
        _construirCardContatos(),
        const SizedBox(height: 16),
        _construirCardPix(),
        const SizedBox(height: 16),
        _construirCardRepertorios(context),
        const SizedBox(height: 16),
        _ProgressoDoArtista(apresentacoes: _apresentacoes),
        const SizedBox(height: 16),
        _construirCardConta(context),
        const SizedBox(height: 8),
      ];

  Widget _construirPreviewPerfil(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: _decoracaoPainel(destaque: true),
        child: Row(
          children: [
            FotoPerfilArtistico(
              enderecoFoto: _api.enderecoArquivo(_perfil?.fotoUrl),
              tamanho: 80,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nomeArtistico.text.trim().isEmpty
                        ? 'Seu nome artístico'
                        : _nomeArtistico.text.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _bio.text.trim().isEmpty
                        ? 'Adicione uma breve apresentação.'
                        : _bio.text.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CoresTocaEssa.textoSecundario,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_perfil != null)
                    TextButton.icon(
                      onPressed: _enviandoFoto ? null : _selecionarFoto,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.photo_camera_outlined, size: 16),
                      label: Text(
                        _enviandoFoto
                            ? 'Enviando...'
                            : _perfil?.fotoUrl == null
                                ? 'Adicionar foto'
                                : 'Trocar foto',
                        style: const TextStyle(fontSize: 13),
                      ),
                    )
                  else
                    const Text(
                      'Salve o perfil para adicionar uma foto.',
                      style: TextStyle(
                        color: CoresTocaEssa.textoSecundario,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _construirCardIdentidade() => Container(
        padding: const EdgeInsets.all(20),
        decoration: _decoracaoPainel(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CabecalhoSecaoPerfil(
              Icons.badge_outlined,
              'Identidade artística',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nomeArtistico,
              decoration: const InputDecoration(
                labelText: 'Nome artístico',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bio,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Apresentação breve (opcional)',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Icon(Icons.notes_rounded),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _construirCardContatos() => Container(
        padding: const EdgeInsets.all(20),
        decoration: _decoracaoPainel(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CabecalhoSecaoPerfil(
              Icons.public_rounded,
              'Contatos públicos',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _instagram,
              decoration: const InputDecoration(
                labelText: 'Instagram',
                hintText: '@seuperfil',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exibir Instagram ao público'),
              value: _exibirInstagram,
              onChanged: (v) => _mudarEstado(() => _exibirInstagram = v),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _whatsapp,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp profissional',
                hintText: '5511999999999',
                prefixIcon: Icon(Icons.chat_outlined),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exibir WhatsApp ao público'),
              value: _exibirWhatsapp,
              onChanged: (v) => _mudarEstado(() => _exibirWhatsapp = v),
            ),
          ],
        ),
      );

  Widget _construirCardPix() => Container(
        padding: const EdgeInsets.all(20),
        decoration: _decoracaoPainel(destaque: _pixAtivo),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CabecalhoSecaoPerfil(
              Icons.pix_rounded,
              'Apoio via Pix',
            ),
            const SizedBox(height: 4),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aceitar contribuições'),
              subtitle: const Text(
                'Voluntária, sem confirmação automática.',
                style: TextStyle(
                  color: CoresTocaEssa.textoSecundario,
                  fontSize: 12,
                ),
              ),
              value: _pixAtivo,
              onChanged: (v) => _mudarEstado(() => _pixAtivo = v),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _pixAtivo
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(height: 24),
                        TextField(
                          controller: _pixChave,
                          decoration: const InputDecoration(
                            labelText: 'Chave Pix',
                            prefixIcon: Icon(Icons.key_rounded),
                            helperText: 'Prefira uma chave aleatória',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _pixNomeBeneficiario,
                                maxLength: 25,
                                decoration: const InputDecoration(
                                  labelText: 'Nome do beneficiário',
                                  prefixIcon:
                                      Icon(Icons.person_outline_rounded),
                                  counterText: '',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _pixCidadeBeneficiario,
                                maxLength: 15,
                                decoration: const InputDecoration(
                                  labelText: 'Cidade',
                                  prefixIcon:
                                      Icon(Icons.location_city_outlined),
                                  counterText: '',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _pixMensagem,
                          maxLength: 72,
                          decoration: const InputDecoration(
                            labelText: 'Mensagem de agradecimento (opcional)',
                            prefixIcon: Icon(Icons.favorite_border_rounded),
                            helperText: 'Exibida ao público após gerar o Pix',
                            counterText: '',
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );

  Widget _construirCardRepertorios(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: _decoracaoPainel(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CabecalhoSecaoPerfil(
              Icons.queue_music_rounded,
              'Repertórios',
            ),
            const SizedBox(height: 6),
            const Text(
              'Crie listas de músicas para usar nos seus shows.',
              style: TextStyle(
                  color: CoresTocaEssa.textoSecundario, fontSize: 13),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => GerenciarRepertorios(api: _api),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Gerenciar repertórios'),
            ),
          ],
        ),
      );

  Widget _construirCardConta(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _decoracaoPainel(),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFF352064),
              foregroundColor: CoresTocaEssa.roxoClaro,
              child: Icon(Icons.person_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_conta.nome,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    _conta.email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CoresTocaEssa.textoSecundario,
                      fontSize: 12,
                    ),
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
      );
}

class _CabecalhoSecaoPerfil extends StatelessWidget {
  const _CabecalhoSecaoPerfil(this.icone, this.titulo);
  final IconData icone;
  final String titulo;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icone, size: 15, color: CoresTocaEssa.roxoClaro),
          const SizedBox(width: 7),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: CoresTocaEssa.roxoClaro,
              letterSpacing: 0.8,
            ),
          ),
        ],
      );
}
