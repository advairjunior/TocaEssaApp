part of 'area_do_publico.dart';

class PerfilPublicoAtivo extends StatelessWidget {
  const PerfilPublicoAtivo({
    super.key,
    required this.perfil,
    required this.estatisticas,
    required this.enderecoFoto,
    required this.enviandoFoto,
    required this.trocarFoto,
    required this.sair,
    this.abrirResenhas,
  });

  final PerfilPublico perfil;
  final EstatisticasDoPublico? estatisticas;
  final String? enderecoFoto;
  final bool enviandoFoto;
  final VoidCallback trocarFoto;
  final VoidCallback sair;

  /// Atalho para o histórico de resenhas; omitido quando já se está nele.
  final VoidCallback? abrirResenhas;

  static const _meses = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', //
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
  ];

  Future<void> _copiarResumo(BuildContext context) async {
    final dados = estatisticas!;
    await Clipboard.setData(ClipboardData(
        text: '🎤 ${perfil.nome} no TocaEssa\n'
            '${dados.participacoes} participações · ${dados.pedidos} pedidos · '
            '${dados.pedidosTocados} tocados'));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Seu resumo foi copiado para compartilhar.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final secundario =
        texto.bodyMedium?.copyWith(color: CoresTocaEssa.textoSecundario);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox.square(
            dimension: 112,
            child: Stack(
              children: [
                FotoPerfilArtistico(
                  enderecoFoto: enderecoFoto,
                  tamanho: 112,
                  iconeFallback: Icons.person_rounded,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(
                    tooltip: 'Trocar foto',
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
        ),
        const SizedBox(height: EspacoTocaEssa.base),
        Text(perfil.nome,
            textAlign: TextAlign.center, style: texto.headlineSmall),
        const SizedBox(height: EspacoTocaEssa.mini),
        Text(
          'No TocaEssa desde ${_meses[perfil.criadoEm.month - 1]} '
          'de ${perfil.criadoEm.year}',
          textAlign: TextAlign.center,
          style: secundario,
        ),
        if (estatisticas != null) ...[
          ProgressoDoPublico(dados: estatisticas!),
          const SizedBox(height: EspacoTocaEssa.grande - 4),
          OutlinedButton.icon(
            onPressed: () => _copiarResumo(context),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Copiar meu resumo'),
          ),
        ] else ...[
          const SizedBox(height: EspacoTocaEssa.grande - 4),
          Text(
            'Seu histórico está temporariamente indisponível. '
            'Aguarde a atualização.',
            textAlign: TextAlign.center,
            style: secundario,
          ),
        ],
        const SizedBox(height: EspacoTocaEssa.enorme),
        const TituloGrupo('Conta'),
        GrupoDeLinhas(
          linhas: [
            if (abrirResenhas != null)
              Semantics(
                button: true,
                child: InkWell(
                  onTap: abrirResenhas,
                  child: Padding(
                    padding: const EdgeInsets.all(EspacoTocaEssa.base),
                    child: Row(
                      children: [
                        const Icon(Icons.history_rounded,
                            size: 20, color: CoresTocaEssa.roxoClaro),
                        const SizedBox(width: EspacoTocaEssa.base),
                        Expanded(
                          child:
                              Text('Minhas resenhas', style: texto.bodyLarge),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: CoresTocaEssa.textoSecundario),
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                EspacoTocaEssa.base,
                EspacoTocaEssa.pequeno,
                EspacoTocaEssa.pequeno,
                EspacoTocaEssa.pequeno,
              ),
              child: Row(
                children: [
                  const Icon(Icons.alternate_email_rounded,
                      size: 20, color: CoresTocaEssa.roxoClaro),
                  const SizedBox(width: EspacoTocaEssa.base),
                  Expanded(
                    child: Text(
                      perfil.email,
                      overflow: TextOverflow.ellipsis,
                      style: secundario,
                    ),
                  ),
                  TextButton(onPressed: sair, child: const Text('Sair')),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
