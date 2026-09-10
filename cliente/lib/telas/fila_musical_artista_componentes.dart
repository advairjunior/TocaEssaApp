part of 'fila_musical_artista.dart';

class _TituloSecao extends StatelessWidget {
  const _TituloSecao(this.texto, {this.quantidade});

  final String texto;
  final int? quantidade;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(texto, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (quantidade != null)
          Text(
            '$quantidade',
            style: const TextStyle(color: CoresTocaEssa.roxoClaro),
          ),
      ]);
}

class _MensagemVazia extends StatelessWidget {
  const _MensagemVazia(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(texto, textAlign: TextAlign.center),
        ),
      );
}
