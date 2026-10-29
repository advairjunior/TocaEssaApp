part of 'tela_da_tv.dart';

/// Entre uma música e outra: o "A seguir" e o QR grandes à esquerda e as
/// fotos dos stories passando à direita, uma a cada [_tempoDaFoto].
class _IntervaloNaTv extends StatelessWidget {
  const _IntervaloNaTv({required this.conteudo, required this.fotos});

  final ConteudoDaTv conteudo;
  final List<StoryDoShow> fotos;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, limites) {
          final u = limites.maxWidth / 100;
          return Padding(
            padding: EdgeInsets.all(4.5 * u),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _ProximaEQr(conteudo: conteudo, u: u),
                ),
                SizedBox(width: 4 * u),
                Expanded(flex: 4, child: _FotosDoShow(fotos: fotos, u: u)),
              ],
            ),
          );
        },
      );
}

class _ProximaEQr extends StatelessWidget {
  const _ProximaEQr({required this.conteudo, required this.u});

  final ConteudoDaTv conteudo;
  final double u;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A SEGUIR',
              style: TextStyle(
                  fontSize: 1.4 * u,
                  letterSpacing: .2 * u,
                  color: CoresTocaEssa.rosa)),
          SizedBox(height: u),
          Text(conteudo.aSeguir ?? 'Já já tem mais música',
              style: TextStyle(
                  fontSize: 4.4 * u,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: CoresTocaEssa.texto)),
          SizedBox(height: 4 * u),
          if (conteudo.codigo case final codigo?)
            _QrDaResenha(
                codigo: codigo, u: u * 1.4, tamanho: 13 * u, emColuna: true),
        ],
      );
}

const _tempoDaFoto = Duration(seconds: 6);

/// As fotos que a galera mandou, trocando sozinhas.
class _FotosDoShow extends StatefulWidget {
  const _FotosDoShow({required this.fotos, required this.u});

  final List<StoryDoShow> fotos;
  final double u;

  @override
  State<_FotosDoShow> createState() => _FotosDoShowState();
}

class _FotosDoShowState extends State<_FotosDoShow> {
  var _atual = 0;
  Timer? _troca;

  @override
  void initState() {
    super.initState();
    _troca = Timer.periodic(_tempoDaFoto, (_) {
      if (widget.fotos.length > 1) {
        setState(() => _atual = (_atual + 1) % widget.fotos.length);
      }
    });
  }

  @override
  void dispose() {
    _troca?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.u;
    if (widget.fotos.isEmpty) {
      return Center(
        child: Text('Mande sua foto nos stories do show',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 2 * u, color: CoresTocaEssa.textoSecundario)),
      );
    }
    final foto = widget.fotos[_atual % widget.fotos.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(1.5 * u),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: Image.network(
                foto.url.toString(),
                key: ValueKey(foto.id),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: CoresTocaEssa.superficie),
              ),
            ),
          ),
        ),
        if (foto.nome case final nome?) ...[
          SizedBox(height: u),
          Text('Foto de $nome',
              style: TextStyle(
                  fontSize: 1.4 * u, color: CoresTocaEssa.textoSecundario)),
        ],
      ],
    );
  }
}
