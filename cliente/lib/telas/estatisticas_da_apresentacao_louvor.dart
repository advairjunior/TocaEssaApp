part of 'estatisticas_da_apresentacao.dart';

/// Quem canta e depois quem toca, na ordem da escala; quem faz os dois
/// aparece uma vez só (sem diferença de acento ou maiúscula).
List<String> nomesDaRetrospectivaDoLouvor(
    List<String> cantores, List<Solista> solistas) {
  final vistos = <String>{};
  return [
    for (final nome in [...cantores, ...solistas.map((s) => s.nome)])
      if (nome.trim().isNotEmpty && vistos.add(normalizarMusica(nome)))
        nome.trim(),
  ];
}

/// "com Ana, João e Bia"; sem ninguém na escala, quem criou o louvor.
String _comQuem(Apresentacao apresentacao, List<String> nomes) {
  if (nomes.isEmpty) return 'com ${apresentacao.perfilArtistico.nomeArtistico}';
  if (nomes.length == 1) return 'com ${nomes.single}';
  final inicio = nomes.sublist(0, nomes.length - 1).join(', ');
  return 'com $inicio e ${nomes.last}';
}

/// No louvor não há pedidos nem notas: a retrospectiva é a selfie com o
/// nome, o lugar, a data e quem cantou e tocou.
String _textoDoLouvor(Apresentacao apresentacao, List<String> nomes) => [
      'Retrospectiva do louvor',
      apresentacao.nome,
      '${apresentacao.local} · ${formatarData(apresentacao.data)}',
      _comQuem(apresentacao, nomes),
    ].join('\n');

class _ConteudoDoLouvor extends StatelessWidget {
  const _ConteudoDoLouvor({required this.apresentacao, required this.nomes});
  final Apresentacao apresentacao;
  final List<String> nomes;

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
            _comQuem(apresentacao, nomes),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, height: 1.3),
          ),
        ],
      );
}
