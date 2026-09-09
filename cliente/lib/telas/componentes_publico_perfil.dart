part of 'area_do_publico.dart';

class _PerfilPublicoAtivo extends StatelessWidget {
  const _PerfilPublicoAtivo(
      {required this.perfil,
      required this.estatisticas,
      required this.enderecoFoto,
      required this.enviandoFoto,
      required this.trocarFoto,
      required this.sair});
  final PerfilPublico perfil;
  final EstatisticasDoPublico? estatisticas;
  final String? enderecoFoto;
  final bool enviandoFoto;
  final VoidCallback trocarFoto;
  final VoidCallback sair;

  @override
  Widget build(BuildContext context) {
    const meses = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro'
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: CoresTocaEssa.superficie,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: CoresTocaEssa.borda)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
            child: Stack(children: [
          Padding(
              padding: const EdgeInsets.all(6),
              child: FotoPerfilArtistico(
                  enderecoFoto: enderecoFoto,
                  tamanho: 96,
                  iconeFallback: Icons.person_rounded)),
          Positioned(
              right: 0,
              bottom: 0,
              child: IconButton.filled(
                  tooltip: 'Trocar foto',
                  onPressed: enviandoFoto ? null : trocarFoto,
                  icon: Icon(enviandoFoto
                      ? Icons.hourglass_top
                      : Icons.photo_camera_outlined))),
        ])),
        const SizedBox(height: 12),
        Text(perfil.nome,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
            'Membro desde ${meses[perfil.criadoEm.month - 1]} de ${perfil.criadoEm.year}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
        if (estatisticas != null) ...[
          ProgressoDoPublico(dados: estatisticas!),
          const SizedBox(height: 20),
          OutlinedButton.icon(
              onPressed: () async {
                final dados = estatisticas!;
                await Clipboard.setData(ClipboardData(
                    text:
                        '🎤 ${perfil.nome} no TocaEssa\n${dados.participacoes} participações · ${dados.pedidos} pedidos · ${dados.pedidosTocados} tocados'));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('Seu resumo foi copiado para compartilhar.')));
                }
              },
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Copiar meu resumo')),
        ] else ...[
          const SizedBox(height: 20),
          const Text(
              'Seu histórico está temporariamente indisponível. Aguarde a atualização.'),
        ],
        const SizedBox(height: 16),
        const Divider(),
        Text(perfil.email,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
        TextButton(onPressed: sair, child: const Text('Sair')),
      ]),
    );
  }
}
