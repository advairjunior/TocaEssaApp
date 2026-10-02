part of 'area_do_publico.dart';

extension _PerfilPublicoDoArtista on _AreaDoPublicoState {
  Future<void> _abrirPerfilDoArtista(Apresentacao apresentacao) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: CoresTocaEssa.superficie,
      builder: (contextoModal) => _construirPerfilPublicoArtista(
        apresentacao,
        contextoModal: contextoModal,
      ),
    );
  }

  Widget _construirPerfilPublicoArtista(
    Apresentacao apresentacao, {
    BuildContext? contextoModal,
  }) {
    final perfil = apresentacao.perfilArtistico;
    return PerfilPublicoArtista(
      perfil: perfil,
      enderecoFoto: _api.enderecoArquivo(perfil.fotoUrl),
      emAba: contextoModal == null,
      apresentacao: apresentacao,
      copiarCodigo: () => _copiarCodigo(apresentacao.codigo),
      abrirInstagram: perfil.instagram == null
          ? null
          : () => abrirUrlExterna(Uri.https(
              'instagram.com', '/${_usuarioInstagram(perfil.instagram!)}')),
      abrirWhatsapp: perfil.whatsapp == null
          ? null
          : () => abrirUrlExterna(
              Uri.https('wa.me', '/${_somenteDigitos(perfil.whatsapp!)}')),
      apoiar: perfil.apoioPixDisponivel
          ? () {
              if (contextoModal != null) Navigator.pop(contextoModal);
              Future<void>.delayed(
                  Duration.zero, () => _abrirApoioPix(apresentacao));
            }
          : null,
    );
  }

  String _usuarioInstagram(String valor) => valor
      .trim()
      .replaceFirst(RegExp(r'^https?://(www\.)?instagram\.com/'), '')
      .replaceAll('@', '')
      .split('/')
      .first;

  String _somenteDigitos(String valor) =>
      valor.replaceAll(RegExp(r'[^0-9]'), '');
}

class PerfilPublicoArtista extends StatelessWidget {
  const PerfilPublicoArtista({
    super.key,
    required this.perfil,
    required this.enderecoFoto,
    required this.abrirInstagram,
    required this.abrirWhatsapp,
    required this.apoiar,
    this.apresentacao,
    this.copiarCodigo,
    this.emAba = false,
  });

  final PerfilArtistico perfil;
  final String? enderecoFoto;
  final VoidCallback? abrirInstagram;
  final VoidCallback? abrirWhatsapp;
  final VoidCallback? apoiar;
  final Apresentacao? apresentacao;
  final VoidCallback? copiarCodigo;
  final bool emAba;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final secundario =
        texto.bodyLarge?.copyWith(color: CoresTocaEssa.textoSecundario);
    const entreSecoes = SizedBox(height: EspacoTocaEssa.enorme);
    final instagram = perfil.instagram?.trim().replaceAll('@', '');
    final conteudo = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!emAba) ...[
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: CoresTocaEssa.borda,
                borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
              ),
            ),
          ),
          const SizedBox(height: EspacoTocaEssa.grande - 4),
        ],
        FotoPerfilArtistico(enderecoFoto: enderecoFoto, tamanho: 112),
        const SizedBox(height: EspacoTocaEssa.base),
        Text(
          perfil.nomeArtistico,
          textAlign: TextAlign.center,
          style: texto.headlineSmall,
        ),
        entreSecoes,
        const TituloGrupo('Sobre o artista'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: EspacoTocaEssa.mini),
          child: Text(
            perfil.bio?.trim().isNotEmpty == true
                ? perfil.bio!
                : 'Este artista ainda não escreveu uma apresentação.',
            style: secundario,
          ),
        ),
        if (apresentacao != null) ...[
          entreSecoes,
          const TituloGrupo('Esta apresentação'),
          GrupoDeLinhas(
            linhas: [
              _LinhaDoArtista(
                icone: Icons.calendar_today_rounded,
                rotulo: 'Data',
                valor: formatarData(apresentacao!.data),
              ),
              _LinhaDoArtista(
                icone: Icons.location_on_outlined,
                rotulo: 'Local',
                valor: apresentacao!.local,
              ),
              _LinhaDoArtista(
                icone: Icons.tag_rounded,
                rotulo: 'Código',
                valor: apresentacao!.codigo,
                acao: Icons.copy_rounded,
                tocar: copiarCodigo,
              ),
            ],
          ),
        ],
        if (abrirInstagram != null || abrirWhatsapp != null) ...[
          entreSecoes,
          const TituloGrupo('Contatos'),
          GrupoDeLinhas(
            linhas: [
              if (abrirInstagram != null)
                _LinhaDoArtista(
                  icone: Icons.alternate_email_rounded,
                  rotulo: 'Instagram',
                  valor: '@$instagram',
                  acao: Icons.open_in_new_rounded,
                  tocar: abrirInstagram,
                ),
              if (abrirWhatsapp != null)
                _LinhaDoArtista(
                  icone: Icons.chat_outlined,
                  rotulo: 'WhatsApp',
                  valor: 'Conversar',
                  acao: Icons.open_in_new_rounded,
                  tocar: abrirWhatsapp,
                ),
            ],
          ),
        ],
        if (apoiar != null) ...[
          entreSecoes,
          _ConviteApoio(apoiar: apoiar!),
        ],
        const SizedBox(height: EspacoTocaEssa.base),
      ],
    );
    if (emAba) return conteudo;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        EspacoTocaEssa.grande,
        EspacoTocaEssa.base,
        EspacoTocaEssa.grande,
        EspacoTocaEssa.enorme,
      ),
      child: conteudo,
    );
  }
}

class _LinhaDoArtista extends StatelessWidget {
  const _LinhaDoArtista({
    required this.icone,
    required this.rotulo,
    required this.valor,
    this.acao,
    this.tocar,
  });

  final IconData icone;
  final String rotulo;
  final String valor;
  final IconData? acao;
  final VoidCallback? tocar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Semantics(
      button: tocar != null,
      child: InkWell(
        onTap: tocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: EspacoTocaEssa.base,
            vertical: EspacoTocaEssa.base - 2,
          ),
          child: Row(
            children: [
              Icon(icone, size: 20, color: CoresTocaEssa.roxoClaro),
              const SizedBox(width: EspacoTocaEssa.base),
              Text(
                rotulo,
                style: texto.bodyMedium
                    ?.copyWith(color: CoresTocaEssa.textoSecundario),
              ),
              const SizedBox(width: EspacoTocaEssa.base),
              Expanded(
                child: Text(
                  valor,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: texto.bodyLarge,
                ),
              ),
              if (acao != null) ...[
                const SizedBox(width: EspacoTocaEssa.pequeno),
                Icon(acao, size: 18, color: CoresTocaEssa.textoSecundario),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ConviteApoio extends StatelessWidget {
  const _ConviteApoio({required this.apoiar});
  final VoidCallback apoiar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(EspacoTocaEssa.grande - 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A1640), CoresTocaEssa.superficie],
        ),
        border: Border.all(color: CoresTocaEssa.rosa.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.favorite_rounded, color: CoresTocaEssa.rosa),
          const SizedBox(height: EspacoTocaEssa.medio),
          Text('Gostou do show?', style: texto.titleLarge),
          const SizedBox(height: EspacoTocaEssa.mini),
          Text(
            'Mande um Pix. É voluntário e vai direto para quem está no palco.',
            style: texto.bodyMedium
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
          const SizedBox(height: EspacoTocaEssa.base + 4),
          FilledButton.icon(
            onPressed: apoiar,
            icon: const Icon(Icons.favorite_rounded),
            label: const Text('Apoiar o artista'),
          ),
        ],
      ),
    );
  }
}
