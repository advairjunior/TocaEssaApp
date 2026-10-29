part of 'cifra_do_palco.dart';

/// Seta da Letra na TV: fica parada no terço de cima e a cifra passa por
/// ela. A linha de letra na seta é a linha acesa na TV.
const chaveDaSetaDaTv = ValueKey('seta-da-tv');

/// Linhas de letra que estão montadas na tela, para achar a que cruza a
/// seta. Só as linhas perto da tela existem; a seta está sempre na tela.
class _RegistroDasLinhas {
  final _marcas = <_MarcaDaLinhaState>{};

  /// A linha na altura [y] (global) ou, entre duas, a de cima.
  int? linhaNaAltura(double y) {
    int? acima;
    var topoDaAcima = double.negativeInfinity;
    for (final marca in _marcas) {
      final (topo, base) = marca.faixa() ?? (double.infinity, double.infinity);
      if (topo > y) continue;
      if (y < base) return marca.widget.numero;
      if (topo > topoDaAcima) {
        topoDaAcima = topo;
        acima = marca.widget.numero;
      }
    }
    return acima;
  }
}

/// Linha de letra com o número dela, registrada enquanto está montada.
class _MarcaDaLinha extends StatefulWidget {
  const _MarcaDaLinha({
    required this.numero,
    required this.registro,
    required this.child,
  });

  final int numero;
  final _RegistroDasLinhas registro;
  final Widget child;

  @override
  State<_MarcaDaLinha> createState() => _MarcaDaLinhaState();
}

class _MarcaDaLinhaState extends State<_MarcaDaLinha> {
  @override
  void initState() {
    super.initState();
    widget.registro._marcas.add(this);
  }

  @override
  void dispose() {
    widget.registro._marcas.remove(this);
    super.dispose();
  }

  /// Topo e base da linha na tela; nulo antes de desenhada.
  (double, double)? faixa() {
    final caixa = context.findRenderObject();
    if (caixa is! RenderBox || !caixa.attached || !caixa.hasSize) return null;
    final topo = caixa.localToGlobal(Offset.zero).dy;
    return (topo, topo + caixa.size.height);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Seta rosa na margem esquerda, com um fio fraco que cruza a cifra.
class _SetaDaTv extends StatelessWidget {
  const _SetaDaTv({required this.chave});

  // Da cifra que mede a altura da seta.
  final GlobalKey chave;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Align(
          alignment: const Alignment(-1, -1 / 3),
          child: KeyedSubtree(
            key: chaveDaSetaDaTv,
            child: Row(
              key: chave,
              children: [
                const Icon(Icons.play_arrow_rounded,
                    size: 16, color: CoresTocaEssa.rosa),
                Expanded(
                  child: Container(
                      height: 1,
                      color: CoresTocaEssa.rosa.withValues(alpha: .25)),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Acha a linha na seta a cada rolagem e avisa só quando ela muda.
mixin _LeituraDaSeta on State<CifraDoPalco> {
  final _registro = _RegistroDasLinhas();
  final _chaveDaSeta = GlobalKey();
  int? _ultimaLida;

  ScrollController get _controladorDaSeta;

  bool _procuraMarcada = false;

  // A rolagem avisa antes de redesenhar: as linhas só estão no lugar novo
  // depois do quadro seguinte.
  void _comecarALer() =>
      _controladorDaSeta.addListener(_procurarDepoisDeDesenhar);

  void _pararDeLer() =>
      _controladorDaSeta.removeListener(_procurarDepoisDeDesenhar);

  void _esquecerALinha() => _ultimaLida = null;

  void _procurarDepoisDeDesenhar() {
    if (widget.aoLerALinha == null || _procuraMarcada) return;
    _procuraMarcada = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _procuraMarcada = false;
      if (mounted) _procurarALinha();
    });
  }

  void _procurarALinha() {
    final avisar = widget.aoLerALinha;
    final caixa = _chaveDaSeta.currentContext?.findRenderObject();
    if (avisar == null || caixa is! RenderBox || !caixa.hasSize) return;
    final altura = caixa.localToGlobal(caixa.size.center(Offset.zero)).dy;
    final linha = _registro.linhaNaAltura(altura);
    if (linha == null || linha == _ultimaLida) return;
    _ultimaLida = linha;
    avisar(linha);
  }
}
