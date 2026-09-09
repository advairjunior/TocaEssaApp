part of 'conta_do_publico.dart';

extension _ConstrucaoContaPublico on _ContaDoPublicoState {
  Widget _construirConta(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Minha conta'), actions: [
          IconButton(
              tooltip: 'Atualizar',
              onPressed: _ocupado ? null : _carregar,
              icon: const Icon(Icons.refresh)),
        ]),
        bottomNavigationBar: _perfil == null
            ? null
            : NavigationBar(
                selectedIndex: _aba,
                onDestinationSelected: (indice) =>
                    _alterar(() => _aba = indice),
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.celebration_outlined),
                      label: 'Participações'),
                  NavigationDestination(
                      icon: Icon(Icons.person_outline), label: 'Perfil geral'),
                ],
              ),
        body: _ocupado
            ? const Center(child: CircularProgressIndicator())
            : ConteudoMobile(
                filho: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    if (_erro != null) ...[
                      Text(_erro!),
                      TextButton(
                          onPressed: _carregar,
                          child: const Text('Tentar novamente')),
                      TextButton(
                          onPressed: _sair,
                          child: const Text('Entrar com outra conta')),
                    ] else if (_perfil == null) ...[
                      Text(
                          _cadastro
                              ? 'Crie seu Perfil do Público'
                              : 'Entre na sua conta',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text(
                          'Reencontre suas resenhas, músicas e conquistas sem precisar guardar códigos.'),
                      const SizedBox(height: 20),
                      if (_cadastro) ...[
                        TextField(
                            controller: _nome,
                            decoration:
                                const InputDecoration(labelText: 'Seu nome')),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration:
                              const InputDecoration(labelText: 'E-mail')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _senha,
                          obscureText: true,
                          onSubmitted: (_) => _entrar(),
                          decoration:
                              const InputDecoration(labelText: 'Senha')),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: _entrar,
                          child: Text(_cadastro ? 'Criar conta' : 'Entrar')),
                      TextButton(
                          onPressed: () =>
                              _alterar(() => _cadastro = !_cadastro),
                          child: Text(_cadastro
                              ? 'Já tenho conta'
                              : 'Criar meu perfil')),
                      TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/'),
                          child: const Text('Entrar por código sem conta')),
                    ] else if (_aba == 1)
                      PerfilPublicoAtivo(
                          perfil: _perfil!,
                          estatisticas: _estatisticas,
                          enderecoFoto:
                              widget.api.enderecoArquivo(_perfil!.fotoUrl),
                          enviandoFoto: _ocupado,
                          trocarFoto: _foto,
                          sair: _sair)
                    else ...[
                      Text('Minhas participações',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text(
                          'Abra um encontro para acompanhar a fila, rever a galera e montar sua retrospectiva.'),
                      const SizedBox(height: 16),
                      SegmentedButton<StatusApresentacao>(
                        segments: const [
                          ButtonSegment(
                              value: StatusApresentacao.emAndamento,
                              label: Text('Ao vivo')),
                          ButtonSegment(
                              value: StatusApresentacao.agendada,
                              label: Text('Agendadas')),
                          ButtonSegment(
                              value: StatusApresentacao.encerrada,
                              label: Text('Histórico')),
                        ],
                        selected: {_filtro},
                        onSelectionChanged: (valores) =>
                            _alterar(() => _filtro = valores.single),
                      ),
                      const SizedBox(height: 16),
                      if (!_apresentacoes.any((a) => a.status == _filtro))
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                                'Nenhuma participação nesta categoria. Ao entrar em uma resenha com sua conta, ela ficará salva aqui.')),
                      for (final apresentacao
                          in _apresentacoes.where((a) => a.status == _filtro))
                        Card(
                            child: ListTile(
                                onTap: () => _abrir(apresentacao),
                                title: Text(apresentacao.nome),
                                subtitle: Text(
                                    '${formatarData(apresentacao.data)} · ${apresentacao.local}\n${apresentacao.perfilArtistico.nomeArtistico}'),
                                isThreeLine: true,
                                trailing: const Icon(Icons.chevron_right))),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                          onPressed: () async {
                            await Navigator.pushNamed(context, '/');
                            if (mounted) await _carregar();
                          },
                          icon: const Icon(Icons.tag),
                          label: const Text('Entrar em outra apresentação')),
                    ],
                  ])),
      );
}
