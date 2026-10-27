part of 'noite_de_karaoke_galera.dart';

/// Onde a pessoa está na noite, do ponto de vista dela.
enum MomentoNaNoite {
  cantando,
  suaVez,
  proximo,
  naFila,
  naGalera,
  foraDaOrdem;

  static MomentoNaNoite de(NoiteDeKaraoke noite, String? eu) {
    if (eu == null || noite.posicaoDe(eu) == null) return foraDaOrdem;
    if (noite.cantando?.publicoId == eu) return cantando;
    if (!noite.sorteada) return naGalera;
    if (noite.proximo != eu) return naFila;
    return noite.cantando == null ? suaVez : proximo;
  }

  bool get podeTocar => this == suaVez || this == proximo;
}

class _AcoesDaVez {
  const _AcoesDaVez({
    required this.ocupado,
    required this.confirmada,
    required this.escolher,
    required this.girar,
    required this.confirmar,
    required this.tocarNaTv,
    required this.terminar,
  });

  final bool ocupado;
  final bool confirmada;
  final VoidCallback escolher;
  final VoidCallback girar;
  final VoidCallback confirmar;
  final void Function(MusicaDoKaraoke musica) tocarNaTv;
  final VoidCallback terminar;
}

class _CartaoDaVez extends StatelessWidget {
  const _CartaoDaVez({
    required this.noite,
    required this.momento,
    required this.acoes,
    required this.eu,
  });

  final NoiteDeKaraoke noite;
  final MomentoNaNoite momento;
  final _AcoesDaVez acoes;
  final String? eu;

  (String, String) get _textos => switch (momento) {
        MomentoNaNoite.cantando => (
            'Você está cantando!',
            noite.cantando?.musica.titulo ?? ''
          ),
        MomentoNaNoite.suaVez => (
            'Sua vez!',
            'Pegue o microfone e toque em Tocar na TV.'
          ),
        MomentoNaNoite.proximo => (
            'Você é o próximo',
            'Escolha a música e se prepare.'
          ),
        MomentoNaNoite.naFila => _naFila(noite.posicaoDe(eu) ?? 1),
        MomentoNaNoite.naGalera => (
            'Você está na galera',
            'O dono da noite ainda vai sortear a ordem de quem canta.'
          ),
        MomentoNaNoite.foraDaOrdem => (
            'Você está fora da ordem',
            'Fale com o dono da noite para voltar.'
          ),
      };

  static (String, String) _naFila(int posicao) {
    final antes = posicao - 1;
    return (
      antes == 0
          ? 'Você é o 1º · abre a noite'
          : 'Você é o $posicaoº · ${antes == 1 ? 'falta 1' : 'faltam $antes'} '
              'antes de você',
      'Vá pensando na música e na coragem.'
    );
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final (titulo, detalhe) = _textos;
    final destaque = momento.podeTocar || momento == MomentoNaNoite.cantando;
    return Container(
      padding: const EdgeInsets.all(EspacoTocaEssa.base),
      decoration: BoxDecoration(
        color: CoresTocaEssa.superficie,
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
        border: Border.all(
            color: destaque ? CoresTocaEssa.roxoClaro : CoresTocaEssa.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo,
              style: destaque ? texto.headlineSmall : texto.titleMedium),
          const SizedBox(height: EspacoTocaEssa.mini),
          Text(detalhe,
              style: texto.bodyMedium
                  ?.copyWith(color: CoresTocaEssa.textoSecundario)),
          if (momento == MomentoNaNoite.cantando)
            _BotoesDeQuemCanta(noite: noite, acoes: acoes)
          else if (momento != MomentoNaNoite.foraDaOrdem)
            _MinhaMusica(
                noite: noite,
                musica: noite.pessoa(eu)?.musica,
                momento: momento,
                acoes: acoes),
        ],
      ),
    );
  }
}

class _BotoesDeQuemCanta extends StatelessWidget {
  const _BotoesDeQuemCanta({required this.noite, required this.acoes});

  final NoiteDeKaraoke noite;
  final _AcoesDaVez acoes;

  @override
  Widget build(BuildContext context) {
    final musica = noite.cantando?.musica;
    final nota =
        mediaComVotos(noite.cantando?.media, noite.cantando?.votos ?? 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A nota da galera chega na hora, enquanto a pessoa canta.
        if (nota != null) ...[
          const SizedBox(height: EspacoTocaEssa.pequeno),
          Text('Nota da galera: $nota',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: CoresTocaEssa.ouro)),
        ],
        const SizedBox(height: EspacoTocaEssa.base),
        FilledButton.icon(
          onPressed: acoes.ocupado ? null : acoes.terminar,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Terminei'),
        ),
        if (musica != null)
          TextButton.icon(
            onPressed: () => acoes.tocarNaTv(musica),
            icon: const Icon(Icons.cast_rounded),
            label: const Text('Abrir de novo na TV'),
          ),
      ],
    );
  }
}

/// A música para a próxima vez: escolhida (Livre) ou sorteada (Roleta), e o
/// Tocar na TV quando é a vez.
class _MinhaMusica extends StatelessWidget {
  const _MinhaMusica({
    required this.noite,
    required this.musica,
    required this.momento,
    required this.acoes,
  });

  final NoiteDeKaraoke noite;
  final MusicaDoKaraoke? musica;
  final MomentoNaNoite momento;
  final _AcoesDaVez acoes;

  bool get _roleta => noite.modo == ModoDasMusicas.roleta;

  @override
  Widget build(BuildContext context) {
    final escolhida = musica;
    final pronta = escolhida != null && (!_roleta || acoes.confirmada);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: EspacoTocaEssa.base),
        if (escolhida == null)
          OutlinedButton.icon(
            onPressed:
                acoes.ocupado ? null : (_roleta ? acoes.girar : acoes.escolher),
            icon: Icon(
                _roleta ? Icons.casino_rounded : Icons.queue_music_rounded),
            label: Text(_roleta ? 'Girar a roleta' : 'Escolher minha música'),
          )
        else
          _MusicaEscolhida(musica: escolhida, roleta: _roleta, acoes: acoes),
        if (pronta && momento.podeTocar) ...[
          const SizedBox(height: EspacoTocaEssa.base),
          FilledButton.icon(
            onPressed: acoes.ocupado ? null : () => acoes.tocarNaTv(escolhida),
            icon: const Icon(Icons.cast_rounded),
            label: const Text('Tocar na TV'),
          ),
          const SizedBox(height: EspacoTocaEssa.mini),
          Text(
            'Abre o vídeo no YouTube: toque em Transmitir para mandar para a TV.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
        ],
      ],
    );
  }
}

class _MusicaEscolhida extends StatelessWidget {
  const _MusicaEscolhida(
      {required this.musica, required this.roleta, required this.acoes});

  final MusicaDoKaraoke musica;
  final bool roleta;
  final _AcoesDaVez acoes;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final decidir = roleta && !acoes.confirmada;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(roleta ? 'A roleta escolheu' : 'Sua música',
                      style: texto.labelMedium
                          ?.copyWith(color: CoresTocaEssa.textoSecundario)),
                  Text(musica.titulo, style: texto.titleMedium),
                ],
              ),
            ),
            if (!roleta)
              TextButton(
                  onPressed: acoes.ocupado ? null : acoes.escolher,
                  child: const Text('Trocar')),
          ],
        ),
        if (decidir) ...[
          const SizedBox(height: EspacoTocaEssa.pequeno),
          FilledButton(
            onPressed: acoes.ocupado ? null : acoes.confirmar,
            child: const Text('Conheço, vou cantar!'),
          ),
          TextButton(
            onPressed: acoes.ocupado ? null : acoes.girar,
            child: const Text('Não conheço, sortear outra'),
          ),
        ],
      ],
    );
  }
}
