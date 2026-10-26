part of 'estatisticas_da_apresentacao.dart';

/// No louvor não há pedidos nem notas: a retrospectiva é a selfie com o
/// nome, o lugar, a data e quem conduziu.
String _textoDoLouvor(Apresentacao apresentacao) => [
      'Retrospectiva do louvor',
      apresentacao.nome,
      '${apresentacao.local} · ${formatarData(apresentacao.data)}',
      'com ${apresentacao.perfilArtistico.nomeArtistico}',
    ].join('\n');

class _ConteudoDoLouvor extends StatelessWidget {
  const _ConteudoDoLouvor({required this.apresentacao});
  final Apresentacao apresentacao;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _RotuloDoCartao('Retrospectiva do louvor'),
          const SizedBox(height: 2),
          Text(
            apresentacao.nome,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w700, height: 1.1),
          ),
          const SizedBox(height: 4),
          Text(
            '${apresentacao.local} · ${formatarData(apresentacao.data)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Text(
            'com ${apresentacao.perfilArtistico.nomeArtistico}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      );
}
