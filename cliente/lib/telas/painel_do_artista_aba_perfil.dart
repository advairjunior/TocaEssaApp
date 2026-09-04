part of 'painel_do_artista.dart';

extension _ConstrucaoPerfilDoArtista on _PainelDoArtistaState {
  List<Widget> _construirAbaPerfil(BuildContext context) => [
        const SizedBox(height: 8),
        const _TituloSecaoPainel(
          icone: Icons.person_rounded,
          titulo: 'Perfil Artístico',
          descricao: 'Sua identidade para o público',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _decoracaoPainel(destaque: true),
          child: Column(
            children: [
              Row(
                children: [
                  FotoPerfilArtistico(
                    enderecoFoto: _api.enderecoArquivo(_perfil?.fotoUrl),
                    tamanho: 88,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nomeArtistico.text.trim().isEmpty
                              ? 'Seu nome artístico'
                              : _nomeArtistico.text.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _bio.text.trim().isEmpty
                              ? 'Adicione uma breve apresentação.'
                              : _bio.text.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: CoresTocaEssa.textoSecundario,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: _perfil == null || _enviandoFoto
                              ? null
                              : _selecionarFoto,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            size: 18,
                          ),
                          label: Text(_enviandoFoto
                              ? 'Enviando foto...'
                              : _perfil?.fotoUrl == null
                                  ? 'Adicionar foto'
                                  : 'Trocar foto'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_perfil == null) ...[
                const SizedBox(height: 8),
                const Text(
                  'Salve o perfil para adicionar uma foto.',
                  style: TextStyle(
                    color: CoresTocaEssa.textoSecundario,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 14),
              TextField(
                controller: _nomeArtistico,
                decoration: const InputDecoration(
                  labelText: 'Nome artístico',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bio,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Apresentação breve (opcional)',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.notes_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _salvando ? null : _salvarPerfil,
                  child: Text(_perfil == null
                      ? 'Criar Perfil Artístico'
                      : 'Salvar alterações'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _ProgressoDoArtista(apresentacoes: _apresentacoes),
        const SizedBox(height: 28),
        const _TituloSecaoPainel(
          icone: Icons.shield_outlined,
          titulo: 'Conta do artista',
          descricao: 'Acesso e segurança do painel',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _decoracaoPainel(),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF352064),
                foregroundColor: CoresTocaEssa.roxoClaro,
                child: Icon(Icons.person_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_conta.nome,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      _conta.email,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CoresTocaEssa.textoSecundario,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _salvando ? null : _sair,
                child: const Text('Sair'),
              ),
            ],
          ),
        ),
      ];
}
