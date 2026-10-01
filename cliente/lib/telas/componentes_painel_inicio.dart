part of 'painel_do_artista.dart';

class _MenuDaConta extends StatelessWidget {
  const _MenuDaConta({
    required this.enderecoFoto,
    required this.abrirPerfil,
    required this.abrirRepertorios,
    required this.sair,
  });

  final String? enderecoFoto;
  final VoidCallback abrirPerfil;
  final VoidCallback abrirRepertorios;
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
              colors: [Color(0xFF2E1850), CoresTocaEssa.superficie],
            ),
            border: Border.all(color: const Color(0xFF5A3D8C)),
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
                      apresentacao.pedidosAbertos
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
                  icon: const Icon(Icons.queue_music_rounded),
                  label: const Text('Abrir fila'),
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

class _PontoAoVivo extends StatelessWidget {
  const _PontoAoVivo();

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: CoresTocaEssa.rosa,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x99FF4D9D), blurRadius: 8)],
        ),
      );
}

class _EstadoVazioPainel extends StatelessWidget {
  const _EstadoVazioPainel({
    required this.icone,
    required this.titulo,
    required this.descricao,
  });

  final IconData icone;
  final String titulo;
  final String descricao;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: EspacoTocaEssa.grande,
        vertical: EspacoTocaEssa.enorme + 8,
      ),
      child: Column(
        children: [
          Icon(icone, size: 40, color: CoresTocaEssa.roxoClaro),
          const SizedBox(height: EspacoTocaEssa.base),
          Text(titulo, textAlign: TextAlign.center, style: texto.titleLarge),
          const SizedBox(height: EspacoTocaEssa.pequeno),
          Text(
            descricao,
            textAlign: TextAlign.center,
            style: texto.bodyMedium
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
        ],
      ),
    );
  }
}

class _AbasApresentacoes extends StatelessWidget {
  const _AbasApresentacoes({
    required this.selecionada,
    required this.apresentacoes,
    required this.selecionar,
  });

  final _FiltroApresentacoes selecionada;
  final List<Apresentacao> apresentacoes;
  final ValueChanged<_FiltroApresentacoes> selecionar;

  int _quantidade(StatusApresentacao status) =>
      apresentacoes.where((item) => item.status == status).length;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Flexible(
            child: _AbaDeTexto(
              rotulo: 'Próximas',
              quantidade: _quantidade(StatusApresentacao.agendada),
              selecionada: selecionada == _FiltroApresentacoes.proximas,
              tocar: () => selecionar(_FiltroApresentacoes.proximas),
            ),
          ),
          const SizedBox(width: EspacoTocaEssa.base),
          Flexible(
            child: _AbaDeTexto(
              rotulo: 'Histórico',
              quantidade: _quantidade(StatusApresentacao.encerrada),
              selecionada: selecionada == _FiltroApresentacoes.historico,
              tocar: () => selecionar(_FiltroApresentacoes.historico),
            ),
          ),
        ],
      );
}

class _AbaDeTexto extends StatelessWidget {
  const _AbaDeTexto({
    required this.rotulo,
    required this.quantidade,
    required this.selecionada,
    required this.tocar,
  });

  final String rotulo;
  final int quantidade;
  final bool selecionada;
  final VoidCallback tocar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final cor =
        selecionada ? CoresTocaEssa.texto : CoresTocaEssa.textoSecundario;
    return Semantics(
      selected: selecionada,
      button: true,
      child: InkWell(
        onTap: tocar,
        borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: EspacoTocaEssa.mini,
            vertical: EspacoTocaEssa.pequeno,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      rotulo,
                      overflow: TextOverflow.ellipsis,
                      style: texto.titleMedium?.copyWith(color: cor),
                    ),
                  ),
                  const SizedBox(width: EspacoTocaEssa.pequeno - 2),
                  Text(
                    '$quantidade',
                    style: texto.labelLarge
                        ?.copyWith(color: CoresTocaEssa.textoSecundario),
                  ),
                ],
              ),
              const SizedBox(height: EspacoTocaEssa.pequeno - 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 3,
                width: selecionada ? 28 : 0,
                decoration: BoxDecoration(
                  color: CoresTocaEssa.roxoClaro,
                  borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListaApresentacoes extends StatelessWidget {
  const _ListaApresentacoes({
    required this.apresentacoes,
    required this.abrir,
  });

  final List<Apresentacao> apresentacoes;
  final ValueChanged<Apresentacao> abrir;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: CoresTocaEssa.superficie,
          borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
          border: Border.all(color: CoresTocaEssa.borda),
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              for (final (indice, apresentacao) in apresentacoes.indexed) ...[
                if (indice > 0)
                  const Divider(height: 1, indent: 84, endIndent: 16),
                _ItemApresentacao(
                  apresentacao: apresentacao,
                  tocar: () => abrir(apresentacao),
                ),
              ],
            ],
          ),
        ),
      );
}

class _ItemApresentacao extends StatelessWidget {
  const _ItemApresentacao({required this.apresentacao, required this.tocar});

  final Apresentacao apresentacao;
  final VoidCallback tocar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: tocar,
        child: Padding(
          padding: const EdgeInsets.all(EspacoTocaEssa.base),
          child: Row(
            children: [
              _BlocoData(data: apresentacao.data),
              const SizedBox(width: EspacoTocaEssa.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apresentacao.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texto.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${apresentacao.local} · ${apresentacao.tipo.rotuloCurto}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texto.bodyMedium
                          ?.copyWith(color: CoresTocaEssa.textoSecundario),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: EspacoTocaEssa.mini),
              const Icon(Icons.chevron_right_rounded,
                  color: CoresTocaEssa.textoSecundario),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlocoData extends StatelessWidget {
  const _BlocoData({required this.data});
  final DateTime data;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: EspacoTocaEssa.pequeno),
      decoration: BoxDecoration(
        color: CoresTocaEssa.roxo.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
      ),
      child: Column(
        children: [
          Text(
            mesesAbreviados[data.month - 1],
            style: texto.labelMedium?.copyWith(
              color: CoresTocaEssa.roxoClaro,
              letterSpacing: 1,
            ),
          ),
          Text(data.day.toString().padLeft(2, '0'), style: texto.titleLarge),
        ],
      ),
    );
  }
}
