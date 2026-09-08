part of 'painel_do_artista.dart';

extension _ConstrucaoApresentacoesDoArtista on _PainelDoArtistaState {
  List<Widget> _construirAbaCriar(BuildContext context) => [
        const SizedBox(height: 30),
        const _TituloSecaoPainel(
          icone: Icons.add_circle_outline_rounded,
          titulo: 'Nova Apresentação',
          descricao: 'Prepare o acesso do seu público',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _decoracaoPainel(),
          child: Column(
            children: [
              DropdownButtonFormField<TipoApresentacao>(
                value: _tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Apresentação',
                  prefixIcon: Icon(Icons.groups_2_outlined),
                ),
                items: TipoApresentacao.values
                    .map((tipo) => DropdownMenuItem(
                          value: tipo,
                          child: Text(tipo.rotulo),
                        ))
                    .toList(),
                onChanged: _perfil == null
                    ? null
                    : (tipo) {
                        if (tipo != null) {
                          _mudarEstado(() => _tipo = tipo);
                        }
                      },
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _tipo.descricao,
                  style: const TextStyle(
                    color: CoresTocaEssa.textoSecundario,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nomeApresentacao,
                enabled: _perfil != null,
                decoration: const InputDecoration(
                  labelText: 'Nome da apresentação',
                  prefixIcon: Icon(Icons.music_note_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _local,
                enabled: _perfil != null,
                decoration: const InputDecoration(
                  labelText: 'Local',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                enabled: _perfil != null,
                shape: RoundedRectangleBorder(
                  side:
                      BorderSide(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(Icons.calendar_today_rounded),
                title: const Text('Data'),
                subtitle: Text(formatarData(_data)),
                onTap: _escolherData,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _perfil == null || _salvando ? null : _criarApresentacao,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Criar Apresentação'),
                ),
              ),
              if (_perfil == null) ...[
                const SizedBox(height: 8),
                const Text('Salve o Perfil Artístico primeiro.'),
              ],
            ],
          ),
        ),
      ];

  List<Widget> _construirAbaApresentacoes(BuildContext context) => [
        if (_apresentacoes.isNotEmpty) ...[
          const SizedBox(height: 30),
          _TituloSecaoPainel(
            icone: Icons.calendar_month_rounded,
            titulo: 'Apresentações',
            descricao:
                '${_apresentacoes.length} ${_apresentacoes.length == 1 ? 'evento criado' : 'eventos criados'}',
          ),
          const SizedBox(height: 16),
          _AbasApresentacoes(
            selecionada: _filtroApresentacoes,
            apresentacoes: _apresentacoes,
            selecionar: (filtro) =>
                _mudarEstado(() => _filtroApresentacoes = filtro),
          ),
          const SizedBox(height: 16),
          if (_apresentacoesFiltradas.isEmpty)
            _EstadoVazioApresentacoes(filtro: _filtroApresentacoes)
          else
            for (final apresentacao in _apresentacoesFiltradas) ...[
              _CartaoApresentacaoArtista(
                apresentacao: apresentacao,
                salvando: _salvando,
                mostrarCodigo: () => _mostrarCodigo(apresentacao),
                alterarStatus: (status) =>
                    _alterarStatusApresentacao(apresentacao, status),
                alterarPedidos: () => _alterarPedidos(apresentacao),
                selecionarOpcao: (opcao) {
                  if (opcao == 'editar') {
                    _editarApresentacao(apresentacao);
                  } else if (opcao == 'excluir') {
                    _excluirApresentacao(apresentacao);
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
        ] else ...[
          const SizedBox(height: 80),
          const Icon(Icons.calendar_month_outlined,
              size: 54, color: CoresTocaEssa.roxoClaro),
          const SizedBox(height: 16),
          Text(
            'Nenhuma Apresentação ainda',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Use a aba Criar para preparar sua primeira apresentação.',
            textAlign: TextAlign.center,
            style: TextStyle(color: CoresTocaEssa.textoSecundario),
          ),
        ],
        const SizedBox(height: 24),
      ];
}
