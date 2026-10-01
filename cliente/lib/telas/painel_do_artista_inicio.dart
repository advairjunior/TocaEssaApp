part of 'painel_do_artista.dart';

extension _InicioDoPainelDoArtista on _PainelDoArtistaState {
  Widget _construirInicio(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('Olá, $_nomeDeSaudacao'),
          actions: [
            _MenuDaConta(
              enderecoFoto: _api.enderecoArquivo(_perfil?.fotoUrl),
              abrirPerfil: () => _selecionarAba(_AbaPainel.perfil),
              abrirRepertorios: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => GerenciarRepertorios(api: _api),
                ),
              ),
              sair: _sair,
            ),
            const SizedBox(width: EspacoTocaEssa.pequeno),
          ],
        ),
        floatingActionButton: _perfil == null
            ? null
            : FloatingActionButton.extended(
                backgroundColor: CoresTocaEssa.roxo,
                foregroundColor: CoresTocaEssa.texto,
                onPressed: _salvando ? null : _novaApresentacao,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nova apresentação'),
              ),
        body: FundoTocaEssa(
          variante: VarianteFundoTocaEssa.bastidores,
          intensidade: IntensidadeFundoTocaEssa.cabecalho,
          child: ConteudoMobile(
            filho: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _conteudoDoInicio(context),
            ),
          ),
        ),
      );

  List<Widget> _conteudoDoInicio(BuildContext context) {
    if (_perfil == null) {
      return [
        const SizedBox(height: EspacoTocaEssa.grande),
        _ConviteCriarPerfil(
          criar: () => _selecionarAba(_AbaPainel.perfil),
        ),
      ];
    }
    return [
      for (final apresentacao in _apresentacoesAoVivo) ...[
        _CartaoAoVivo(
          apresentacao: apresentacao,
          salvando: _salvando,
          abrir: () => _abrirApresentacao(apresentacao),
          abrirFila: () =>
              _abrirApresentacao(apresentacao, aba: _AbaPainel.fila),
          mostrarCodigo: () => _mostrarCodigo(apresentacao),
          encerrar: () => _alterarStatusApresentacao(
            apresentacao,
            StatusApresentacao.encerrada,
          ),
        ),
        const SizedBox(height: EspacoTocaEssa.grande),
      ],
      if (_apresentacoes.isEmpty)
        const _EstadoVazioPainel(
          icone: Icons.mic_external_on_rounded,
          titulo: 'Nenhuma apresentação ainda',
          descricao:
              'Toque em Nova apresentação para preparar seu primeiro show.',
        )
      else ...[
        _AbasApresentacoes(
          selecionada: _filtroApresentacoes,
          apresentacoes: _apresentacoes,
          selecionar: (filtro) =>
              _mudarEstado(() => _filtroApresentacoes = filtro),
        ),
        const SizedBox(height: EspacoTocaEssa.base),
        if (_apresentacoesFiltradas.isEmpty)
          switch (_filtroApresentacoes) {
            _FiltroApresentacoes.proximas => const _EstadoVazioPainel(
                icone: Icons.event_outlined,
                titulo: 'Nenhum show agendado',
                descricao: 'Seus próximos shows aparecem aqui.',
              ),
            _FiltroApresentacoes.historico => const _EstadoVazioPainel(
                icone: Icons.history_rounded,
                titulo: 'Histórico vazio',
                descricao: 'Os shows encerrados ficam guardados aqui.',
              ),
          }
        else
          _ListaApresentacoes(
            apresentacoes: _apresentacoesFiltradas,
            abrir: _abrirApresentacao,
          ),
      ],
      // Espaço para o botão flutuante não cobrir o último item.
      const SizedBox(height: 88),
    ];
  }
}
