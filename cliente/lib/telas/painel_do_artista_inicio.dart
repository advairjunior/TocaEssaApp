part of 'painel_do_artista.dart';

extension _InicioDoPainelDoArtista on _PainelDoArtistaState {
  Widget _construirInicio(BuildContext context) => Scaffold(
        appBar: AppBar(
          // A seta levava à tela de entrada do app e confundia quem já está
          // no painel; ela agora fica no menu da conta.
          automaticallyImplyLeading: false,
          title: Text('Olá, $_nomeDeSaudacao'),
          actions: [
            _MenuDaConta(
              enderecoFoto: _api.enderecoArquivo(_perfil?.fotoUrl),
              abrirPerfil: () => _selecionarAba(_AbaPainel.perfil),
              abrirRepertorios: _abrirRepertorios,
              irParaTelaInicial: () => Navigator.of(context)
                  .pushNamedAndRemoveUntil('/', (_) => false),
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
          abrirFila: () => _abrirApresentacao(apresentacao,
              aba: apresentacao.tipo == TipoApresentacao.louvor
                  ? _AbaPainel.setlist
                  : _AbaPainel.fila),
          mostrarCodigo: () => _mostrarCodigo(apresentacao),
          encerrar: () => _alterarStatusApresentacao(
            apresentacao,
            StatusApresentacao.encerrada,
          ),
        ),
        const SizedBox(height: EspacoTocaEssa.grande),
      ],
      if (_apresentacoes.isEmpty)
        const EstadoVazio(
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
            _FiltroApresentacoes.proximas => const EstadoVazio(
                icone: Icons.event_outlined,
                titulo: 'Nenhum show agendado',
                descricao: 'Seus próximos shows aparecem aqui.',
              ),
            _FiltroApresentacoes.historico => const EstadoVazio(
                icone: Icons.history_rounded,
                titulo: 'Histórico vazio',
                descricao: 'Os shows encerrados ficam guardados aqui.',
              ),
          }
        else
          _ListaApresentacoes(
            apresentacoes: _apresentacoesFiltradas,
            jaPassou: _jaPassou,
            abrir: _abrirApresentacao,
          ),
      ],
      const SizedBox(height: EspacoTocaEssa.grande),
      const TituloGrupo('Acervo'),
      _LinhaDoAcervo(
        repertorios: _repertorios,
        abrir: _abrirRepertorios,
        tocar: _tocarMusicas,
      ),
      // Espaço para o botão flutuante não cobrir o último item.
      const SizedBox(height: 88),
    ];
  }
}
