part of 'painel_do_artista.dart';

class _MenuDaConta extends StatelessWidget {
  const _MenuDaConta({
    required this.enderecoFoto,
    required this.abrirPerfil,
    required this.abrirRepertorios,
    required this.abrirNovidades,
    required this.irParaTelaInicial,
    required this.sair,
  });

  final String? enderecoFoto;
  final VoidCallback abrirPerfil;
  final VoidCallback abrirRepertorios;
  final VoidCallback abrirNovidades;
  // Tela de entrada do app, por exemplo para entrar num show como público.
  final VoidCallback irParaTelaInicial;
  final VoidCallback sair;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: _construirMenu(),
      );

  Widget _construirMenu() => PopupMenuButton<VoidCallback>(
        tooltip: 'Minha conta',
        onSelected: (acao) => acao(),
        position: PopupMenuPosition.under,
        itemBuilder: (_) => [
          PopupMenuItem(
            value: abrirPerfil,
            child: const _ItemMenu(Icons.badge_outlined, 'Perfil artístico'),
          ),
          PopupMenuItem(
            value: abrirRepertorios,
            child: const _ItemMenu(Icons.queue_music_rounded, 'Repertórios'),
          ),
          PopupMenuItem(
            value: abrirNovidades,
            child: const _ItemMenu(Icons.auto_awesome_rounded, 'Novidades'),
          ),
          PopupMenuItem(
            value: irParaTelaInicial,
            child: const _ItemMenu(Icons.home_outlined, 'Tela inicial'),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: sair,
            child: const _ItemMenu(Icons.logout_rounded, 'Sair'),
          ),
        ],
        child: CircleAvatar(
          radius: 18,
          backgroundColor: CoresTocaEssa.roxo.withValues(alpha: .24),
          foregroundColor: CoresTocaEssa.roxoClaro,
          foregroundImage:
              enderecoFoto == null ? null : NetworkImage(enderecoFoto!),
          child: const Icon(Icons.person_rounded, size: 20),
        ),
      );
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu(this.icone, this.texto);
  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 20, color: CoresTocaEssa.roxoClaro),
          const SizedBox(width: EspacoTocaEssa.medio),
          Flexible(child: Text(texto, overflow: TextOverflow.ellipsis)),
        ],
      );
}

class _ConviteCriarPerfil extends StatelessWidget {
  const _ConviteCriarPerfil({required this.criar});
  final VoidCallback criar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(EspacoTocaEssa.grande),
      decoration: _decoracaoPainel(destaque: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mic_external_on_rounded,
              size: 32, color: CoresTocaEssa.roxoClaro),
          const SizedBox(height: EspacoTocaEssa.base),
          Text('Comece pelo seu perfil', style: texto.headlineSmall),
          const SizedBox(height: EspacoTocaEssa.pequeno),
          Text(
            'É ele que o público vê ao entrar no seu show. '
            'Depois disso, você já pode criar sua primeira apresentação.',
            style: texto.bodyMedium
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
          const SizedBox(height: EspacoTocaEssa.grande),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: criar,
              child: const Text('Criar perfil artístico'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoAoVivo extends StatelessWidget {
  const _CartaoAoVivo({
    required this.apresentacao,
    required this.salvando,
    required this.abrir,
    required this.abrirFila,
    required this.mostrarCodigo,
    required this.encerrar,
  });

  final Apresentacao apresentacao;
  final bool salvando;
  final VoidCallback abrir;
  final VoidCallback abrirFila;
  final VoidCallback mostrarCodigo;
  final VoidCallback encerrar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final louvor = apresentacao.tipo == TipoApresentacao.louvor;
    final raio = BorderRadius.circular(24);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: abrir,
        borderRadius: raio,
        child: Ink(
          padding: const EdgeInsets.all(EspacoTocaEssa.grande - 4),
          decoration: BoxDecoration(
            borderRadius: raio,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [CoresTocaEssa.destaqueFundo, CoresTocaEssa.superficie],
            ),
            border: Border.all(color: CoresTocaEssa.destaqueBorda),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33784DFF),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _PontoAoVivo(),
                  const SizedBox(width: EspacoTocaEssa.pequeno),
                  Expanded(
                    child: Text(
                      'Ao vivo agora',
                      overflow: TextOverflow.ellipsis,
                      style: texto.labelLarge?.copyWith(
                        color: CoresTocaEssa.rosa,
                        letterSpacing: .4,
                      ),
                    ),
                  ),
                  const SizedBox(width: EspacoTocaEssa.medio),
                  Expanded(
                    child: Text(
                      louvor
                          ? ''
                          : apresentacao.pedidosAbertos
                              ? 'Pedidos abertos'
                              : 'Pedidos fechados',
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: texto.labelMedium
                          ?.copyWith(color: CoresTocaEssa.textoSecundario),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: EspacoTocaEssa.medio),
              Text(apresentacao.nome, style: texto.headlineSmall),
              const SizedBox(height: EspacoTocaEssa.mini),
              Text(
                '${apresentacao.local} · ${formatarData(apresentacao.data)}',
                style: texto.bodyMedium
                    ?.copyWith(color: CoresTocaEssa.textoSecundario),
              ),
              const SizedBox(height: EspacoTocaEssa.grande - 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: abrirFila,
                  icon: Icon(louvor
                      ? Icons.playlist_play_rounded
                      : Icons.queue_music_rounded),
                  label: Text(louvor ? 'Abrir hinos' : 'Abrir fila'),
                ),
              ),
              const SizedBox(height: EspacoTocaEssa.pequeno),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: mostrarCodigo,
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Código e link'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: CoresTocaEssa.textoSecundario,
                      ),
                      onPressed: salvando ? null : encerrar,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Encerrar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
