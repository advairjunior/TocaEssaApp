part of 'painel_do_artista.dart';

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
