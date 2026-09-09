part of 'painel_do_artista.dart';

extension _AbaGaleraPainelDoArtista on _PainelDoArtistaState {
  List<Widget> _construirAbaGalera(BuildContext context) {
    if (_resenhas.isEmpty) {
      return const [
        SizedBox(height: 80),
        Icon(Icons.groups_outlined, size: 54),
        SizedBox(height: 14),
        Text(
          'Crie uma Resenha entre Amigos para reunir a galera.',
          textAlign: TextAlign.center,
        ),
      ];
    }
    final selecionada = _resenhas.firstWhere(
      (item) => item.id == _resenhaGaleraId,
      orElse: () => _resenhas.first,
    );
    return [
      const SizedBox(height: 12),
      Text('Galera da resenha', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      const Text(
        'Você participa junto e acompanha quem entrou na resenha.',
        style: TextStyle(color: CoresTocaEssa.textoSecundario),
      ),
      const SizedBox(height: 16),
      if (!_dentroDaApresentacao)
        DropdownButtonFormField<String>(
          value: selecionada.id,
          decoration: const InputDecoration(
            labelText: 'Resenha',
            prefixIcon: Icon(Icons.celebration_rounded),
          ),
          items: _resenhas
              .map((item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(item.nome, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (id) {
            if (id != null) _carregarGalera(id);
          },
        ),
      const SizedBox(height: 18),
      if (_carregandoGalera)
        const Center(child: CircularProgressIndicator())
      else if (_galera.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'A galera aparecerá aqui assim que entrar na resenha.',
              textAlign: TextAlign.center,
            ),
          ),
        )
      else
        for (final participante in _galera) ...[
          _CartaoGaleraDoArtista(
            participante: participante,
            enderecoFoto: _api.enderecoArquivo(participante.fotoUrl),
          ),
          const SizedBox(height: 10),
        ],
    ];
  }
}

class _CartaoGaleraDoArtista extends StatelessWidget {
  const _CartaoGaleraDoArtista({
    required this.participante,
    required this.enderecoFoto,
  });

  final ParticipanteDaResenha participante;
  final String? enderecoFoto;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: () =>
              abrirPerfilParticipante(context, participante, enderecoFoto),
          contentPadding: const EdgeInsets.all(14),
          leading: SizedBox.square(
            dimension: 52,
            child: FotoPerfilArtistico(
              enderecoFoto: enderecoFoto,
              tamanho: 52,
              iconeFallback: participante.ehArtista
                  ? Icons.mic_rounded
                  : Icons.person_rounded,
            ),
          ),
          title: Row(
            children: [
              Expanded(child: Text(participante.nome)),
              if (participante.ehArtista) const Chip(label: Text('Artista')),
            ],
          ),
          subtitle: Text(
            participante.ehArtista
                ? 'Anfitrião da resenha'
                : '${participante.pedidos} pedidos · '
                    '${participante.pedidosTocados} tocados',
          ),
          trailing: participante.mediaAvaliacoes == null
              ? null
              : Text('${participante.mediaAvaliacoes!.toStringAsFixed(1)} ★'),
        ),
      );
}
