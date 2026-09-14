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
    this.emAba = false,
  });

  final PerfilArtistico perfil;
  final String? enderecoFoto;
  final VoidCallback? abrirInstagram;
  final VoidCallback? abrirWhatsapp;
  final VoidCallback? apoiar;
  final bool emAba;

  @override
  Widget build(BuildContext context) {
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
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        FotoPerfilArtistico(
          enderecoFoto: enderecoFoto,
          tamanho: 104,
        ),
        const SizedBox(height: 14),
        Text(
          perfil.nomeArtistico,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 22),
        Text('Sobre o artista', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          perfil.bio?.trim().isNotEmpty == true
              ? perfil.bio!
              : 'Este artista ainda não adicionou uma apresentação.',
          style: const TextStyle(color: CoresTocaEssa.textoSecundario),
        ),
        if (abrirInstagram != null || abrirWhatsapp != null) ...[
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (abrirInstagram != null)
                OutlinedButton.icon(
                  onPressed: abrirInstagram,
                  icon: const Icon(Icons.alternate_email_rounded),
                  label: const Text('Instagram'),
                ),
              if (abrirWhatsapp != null)
                OutlinedButton.icon(
                  onPressed: abrirWhatsapp,
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
            ],
          ),
        ],
        if (apoiar != null) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: apoiar,
            icon: const Icon(Icons.favorite_rounded),
            label: const Text('Apoiar o artista'),
          ),
        ],
      ],
    );
    if (emAba) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
          child: conteudo,
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: conteudo,
    );
  }
}
