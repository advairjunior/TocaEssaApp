part of 'leitor_de_cifras.dart';

/// Letra na TV no leitor: com a opção ligada, a cifra mostra a seta, a
/// música aberta vai para a TV e a linha na seta vai junto. No louvor, cada
/// parte vai com o nome de quem canta.
mixin _LetraNaTvNoLeitor on State<LeitorDeCifras> {
  TransmissorDaLetra? _transmissor;
  // A música que a TV já recebeu; mudar a cifra colada manda de novo.
  String? _mostradaNaTv;

  Future<void> _lerLetraNaTv() async {
    if (!await PreferenciaDaLetraNaTv.ler() || !mounted) return;
    final saida =
        widget.saidaDaTela ?? SaidaDaTelaPelaApi(widget.sequencia.api);
    setState(() => _transmissor = TransmissorDaLetra(saida));
  }

  void _encerrarLetraNaTv() => _transmissor?.encerrar();

  /// A seta da página, se a Letra na TV estiver ligada.
  ValueChanged<int>? _setaDaTv(MusicaDoPalco pagina,
      List<TrechoDaCifra> trechos, MusicaDoPalco? proxima) {
    final transmissor = _transmissor;
    if (transmissor == null) return null;
    final texto = TrechoDaCifra.juntarParaTv(trechos);
    final chave = '${pagina.titulo}|${pagina.artista}|${texto.hashCode}';
    if (chave != _mostradaNaTv) {
      _mostradaNaTv = chave;
      transmissor.mostrar(ConteudoParaTv(
        titulo: pagina.titulo,
        subtitulo: pagina.artista,
        texto: texto,
        aSeguir: proxima == null
            ? null
            : aSeguirDaTv(
                proxima.titulo, proxima.pedido?.solicitantes ?? const []),
        codigo: widget.sequencia.codigo,
        linha: 0,
      ));
    }
    return transmissor.lerALinha;
  }
}
