part of 'memoria_da_resenha.dart';

/// O que foi seu naquela noite: a música, os números e quem estava junto.
class _SuaNoite extends StatelessWidget {
  const _SuaNoite({
    super.key,
    required this.encontro,
    required this.enderecoFoto,
  });

  final EncontroDoPublico encontro;
  final String? Function(String?) enderecoFoto;

  @override
  Widget build(BuildContext context) {
    final musicas = encontro.minhasMusicas;
    final secundario = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: CoresTocaEssa.textoSecundario);
    String plural(int valor, String singular, String varios) =>
        valor == 1 ? singular : varios;
    final outras = switch (musicas.length) {
      0 || 1 => null,
      2 => 'também pediu ${musicas[1].musica}',
      _ => 'também pediu ${musicas[1].musica} e mais ${musicas.length - 2}',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (musicas.isNotEmpty) ...[
          const RotuloVersalete('SUA MÚSICA DA NOITE'),
          const SizedBox(height: EspacoTocaEssa.pequeno),
          Text(
            musicas.first.musica,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          if (outras != null) ...[
            const SizedBox(height: EspacoTocaEssa.mini),
            Text(outras, style: secundario),
          ],
          const SizedBox(height: EspacoTocaEssa.grande + 4),
        ],
        Row(
          children: [
            _NumeroGrande(
              valor: encontro.pedidos,
              rotulo: plural(encontro.pedidos, 'pedido', 'pedidos'),
            ),
            Container(
              width: 1,
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              color: CoresTocaEssa.borda,
            ),
            _NumeroGrande(
              valor: encontro.pedidosTocados,
              rotulo: plural(encontro.pedidosTocados, 'tocada', 'tocadas'),
            ),
          ],
        ),
        if (encontro.companhia.isNotEmpty) ...[
          const SizedBox(height: 36),
          const RotuloVersalete('QUEM ESTAVA COM VOCÊ'),
          const SizedBox(height: EspacoTocaEssa.base),
          Wrap(
            spacing: 18,
            runSpacing: 16,
            children: [
              for (final pessoa in encontro.companhia)
                SizedBox(
                  width: 56,
                  child: Column(
                    children: [
                      RostoDoPublico(
                        nome: pessoa.nome,
                        endereco: enderecoFoto(pessoa.fotoUrl),
                        tamanho: 52,
                        contorno: CoresTocaEssa.destaqueBorda,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        pessoa.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CoresTocaEssa.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _NumeroGrande extends StatelessWidget {
  const _NumeroGrande({required this.valor, required this.rotulo});
  final int valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$valor',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            rotulo,
            style: const TextStyle(
              fontSize: 14,
              color: CoresTocaEssa.textoSecundario,
            ),
          ),
        ],
      );
}

/// Cartão 9:16 que vira imagem: a foto aparece de verdade, com o texto só
/// nas faixas de cima e de baixo.
class _CartaoDaNoite extends StatelessWidget {
  const _CartaoDaNoite({
    required this.encontro,
    required this.nome,
    required this.minhaFoto,
    required this.enderecoFoto,
    this.fundo,
  });

  final EncontroDoPublico encontro;
  final String nome;
  final Uint8List? minhaFoto;
  final String? enderecoFoto;

  /// Substitui a foto, como a prévia da câmera do app.
  final Widget? fundo;

  @override
  Widget build(BuildContext context) {
    final apresentacao = encontro.apresentacao;
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao + 4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (fundo != null)
              fundo!
            else if (minhaFoto != null)
              Image.memory(minhaFoto!, fit: BoxFit.cover)
            else
              CapaDaNoite(endereco: enderecoFoto),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xB308050D),
                    Color(0x0008050D),
                    Color(0x0008050D),
                    Color(0xF208050D),
                  ],
                  stops: [0, .3, .5, .92],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/marca/toca_essa_icone.png',
                          width: 28, height: 28),
                      const SizedBox(width: 8),
                      const Text('TocaEssa',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '${apresentacao.nome} · ${formatarData(apresentacao.data)}',
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFFD8CFDF)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nome,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                  if (encontro.companhia.isNotEmpty)
                    Text(
                      textoDaCompanhia(encontro.companhia),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFFD8CFDF)),
                    ),
                  if (encontro.minhasMusicas.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const RotuloVersalete('MINHA MÚSICA'),
                    const SizedBox(height: 2),
                    Text(
                      encontro.minhasMusicas.first.musica,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    '${encontro.pedidos} '
                    '${encontro.pedidos == 1 ? 'pedido' : 'pedidos'}  ·  '
                    '${encontro.pedidosTocados} '
                    '${encontro.pedidosTocados == 1 ? 'tocada' : 'tocadas'}  ·  '
                    '${apresentacao.perfilArtistico.nomeArtistico}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: CoresTocaEssa.textoSecundario),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaAbrirResenha extends StatelessWidget {
  const _LinhaAbrirResenha({required this.tocar});
  final VoidCallback tocar;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: InkWell(
          onTap: tocar,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              children: [
                const Icon(Icons.queue_music_rounded,
                    color: CoresTocaEssa.roxoClaro),
                const SizedBox(width: EspacoTocaEssa.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Abrir a resenha completa',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Text(
                        'Fila, galera e perfil do artista',
                        style: TextStyle(
                          fontSize: 13,
                          color: CoresTocaEssa.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: CoresTocaEssa.textoSecundario),
              ],
            ),
          ),
        ),
      );
}
