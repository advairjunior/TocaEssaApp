import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_guitar_chord/flutter_guitar_chord.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/desenho_de_acorde.dart';
import '../dominio/letra_da_tela.dart';
import '../dominio/quebrar_cifra.dart';
import '../dominio/transpor_cifra.dart';
import '../tema/tema_toca_essa.dart';

part 'cifra_do_palco_cifra.dart';
part 'cifra_do_palco_acorde.dart';
part 'cifra_do_palco_seta.dart';

const _chaveEscala = 'leitor_escala';
const _chaveVelocidade = 'leitor_velocidade_vezes';
// Antes das velocidades lentas, guardava só 1 a 5 (1x a 5x).
const _chaveVelocidadeAntiga = 'leitor_velocidade';
// Cada velocidade da rolagem automática e os pixels por segundo dela.
const _velocidades = [
  (vezes: .5, pixels: 6.0),
  (vezes: .75, pixels: 9.0),
  (vezes: 1.0, pixels: 12.0),
  (vezes: 2.0, pixels: 20.0),
  (vezes: 3.0, pixels: 30.0),
  (vezes: 4.0, pixels: 45.0),
  (vezes: 5.0, pixels: 65.0),
];
const _velocidadeInicial = 2; // 1x

int _indiceDaVelocidade(num vezes) {
  final indice = _velocidades.indexWhere((v) => v.vezes == vezes);
  return indice < 0 ? _velocidadeInicial : indice;
}

/// "0,5x", "0,75x" ou "2x".
String _rotuloDaVelocidade(double vezes) => vezes == vezes.roundToDouble()
    ? '${vezes.round()}x'
    : '${'$vezes'.replaceAll('.', ',')}x';

/// A fonte de largura fixa ocupa 0,6 da altura por caractere.
const _larguraDaLetra = .6;

/// Tamanho da fonte para a linha mais larga caber em [largura].
double tamanhoDaFonteDaCifra({
  required double largura,
  required int maiorLinha,
}) =>
    maiorLinha == 0
        ? 24
        : (largura / (maiorLinha * _larguraDaLetra)).clamp(10, 24);

/// Pedaço da cifra com quem canta: no louvor, cada parte do hino vira um
/// trecho com o nome numa faixa que fica presa no topo enquanto ele passa.
class TrechoDaCifra {
  const TrechoDaCifra({
    required this.texto,
    this.rotulo,
    this.cor = CoresTocaEssa.textoSecundario,
    this.destaque = false,
    this.aviso,
    this.apagado = false,
  });

  final String texto;
  // Sem rótulo, a cifra corre sem faixa, como num show.
  final String? rotulo;
  final Color cor;
  // A vez de quem está com o telefone.
  final bool destaque;
  // Recado à direita da faixa, como "você é o próximo".
  final String? aviso;
  // Parte em que a pessoa não canta: fica fraca, para ela saber quando parar.
  final bool apagado;

  /// O texto que vai para a TV: cada trecho com o nome como marca
  /// ("[ANA + CORAL]"), separados por linha em branco. Marcas e linhas em
  /// branco não são letra, então a TV conta as linhas como a cifra do palco.
  static String juntarParaTv(List<TrechoDaCifra> trechos) => [
        for (final trecho in trechos)
          if (trecho.rotulo case final rotulo?)
            '[${rotulo.replaceAll(RegExp(r'[\[\]]'), '')}]\n${trecho.texto}'
          else
            trecho.texto,
      ].join('\n\n');
}

/// Cifra na tela do palco: tamanho automático, pinça para aumentar,
/// rolagem automática e acorde que mostra o desenho ao toque. Serve o
/// leitor do artista e o roteiro do louvor.
class CifraDoPalco extends StatefulWidget {
  const CifraDoPalco({
    super.key,
    required this.trechos,
    required this.pagina,
    this.cabecalho,
    this.aoLerALinha,
    this.chaveDaVelocidade,
  });

  final List<TrechoDaCifra> trechos;
  // Muda ao trocar de música ou hino: a rolagem volta ao começo.
  final Object pagina;
  // Rola junto, antes da cifra: título, tom e avisos.
  final Widget? cabecalho;
  // Letra na TV ligada: mostra a seta e avisa a linha de letra que passa
  // nela, contada como em [LetraDaTela].
  final ValueChanged<int>? aoLerALinha;
  // A música aberta: a rolagem automática começa na velocidade que ficou
  // nela. Sem chave (ou música nunca rolada), vale a última usada.
  final String? chaveDaVelocidade;

  @override
  State<CifraDoPalco> createState() => _CifraDoPalcoState();
}

class _CifraDoPalcoState extends State<CifraDoPalco> with _LeituraDaSeta {
  double _escala = 1;
  // Dedos na tela, para a pinça sem atrapalhar a rolagem.
  final _dedos = <int, Offset>{};
  double? _distanciaInicial;
  double _escalaInicial = 1;
  final _rolagem = ScrollController(keepScrollOffset: false);
  Timer? _rolando;
  // Posição em [_velocidades].
  int _velocidade = _velocidadeInicial;
  SharedPreferences? _preferencias;

  @override
  ScrollController get _controladorDaSeta => _rolagem;

  @override
  void initState() {
    super.initState();
    _lerPreferencias();
    _comecarALer();
  }

  @override
  void didUpdateWidget(CifraDoPalco anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.pagina != widget.pagina) {
      _pararRolagem();
      _esquecerALinha();
      if (_rolagem.hasClients) _rolagem.jumpTo(0);
    }
    final preferencias = _preferencias;
    if (anterior.chaveDaVelocidade != widget.chaveDaVelocidade &&
        preferencias != null) {
      _velocidade = _indiceDaVelocidade(
          _velocidadeGuardada(preferencias) ?? _velocidades[_velocidade].vezes);
    }
  }

  String? get _chaveDaVelocidadeDaMusica => switch (widget.chaveDaVelocidade) {
        final musica? => '$_chaveVelocidade|$musica',
        null => null,
      };

  num? _velocidadeGuardada(SharedPreferences preferencias) =>
      switch (_chaveDaVelocidadeDaMusica) {
        final chave? => preferencias.getDouble(chave),
        null => null,
      } ??
      preferencias.getDouble(_chaveVelocidade) ??
      preferencias.getInt(_chaveVelocidadeAntiga);

  @override
  void dispose() {
    _pararDeLer();
    _rolando?.cancel();
    _rolagem.dispose();
    super.dispose();
  }

  Future<void> _lerPreferencias() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      final salva = preferencias.getDouble(_chaveEscala);
      final velocidade = _velocidadeGuardada(preferencias);
      if (mounted) {
        setState(() {
          _preferencias = preferencias;
          if (salva != null) _escala = salva;
          if (velocidade != null) {
            _velocidade = _indiceDaVelocidade(velocidade);
          }
        });
      }
    } catch (_) {
      // Sem preferência salva, vale o tamanho automático.
    }
  }

  Future<void> _salvarEscala() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setDouble(_chaveEscala, _escala);
    } catch (_) {
      // O tamanho só não fica guardado para a próxima vez.
    }
  }

  void _iniciarRolagem() {
    _rolando?.cancel();
    const passo = Duration(milliseconds: 50);
    _rolando = Timer.periodic(passo, (_) {
      // Com o dedo na tela, espera: puxar a letra ajusta a posição e a
      // rolagem segue dali ao soltar. Só o pausar para.
      if (!_rolagem.hasClients || _dedos.isNotEmpty) return;
      final posicao = _rolagem.position;
      final destino = posicao.pixels +
          _velocidades[_velocidade].pixels * passo.inMilliseconds / 1000;
      if (destino >= posicao.maxScrollExtent) {
        _rolagem.jumpTo(posicao.maxScrollExtent);
        _pararRolagem();
      } else {
        _rolagem.jumpTo(destino);
      }
    });
    setState(() {});
  }

  void _pararRolagem() {
    if (_rolando == null) return;
    _rolando!.cancel();
    _rolando = null;
    if (mounted) setState(() {});
  }

  Future<void> _mudarVelocidade(int passo) async {
    setState(() =>
        _velocidade = (_velocidade + passo).clamp(0, _velocidades.length - 1));
    final vezes = _velocidades[_velocidade].vezes;
    try {
      await _preferencias?.setDouble(_chaveVelocidade, vezes);
      if (_chaveDaVelocidadeDaMusica case final chave?) {
        await _preferencias?.setDouble(chave, vezes);
      }
    } catch (_) {
      // A velocidade só não fica guardada para a próxima vez.
    }
  }

  void _dedoNaTela(PointerDownEvent evento) {
    _dedos[evento.pointer] = evento.position;
    if (_dedos.length == 2) {
      _distanciaInicial = _distanciaDosDedos();
      _escalaInicial = _escala;
    }
  }

  void _dedoMoveu(PointerMoveEvent evento) {
    if (!_dedos.containsKey(evento.pointer)) return;
    _dedos[evento.pointer] = evento.position;
    final inicial = _distanciaInicial;
    if (_dedos.length != 2 || inicial == null || inicial == 0) return;
    setState(() => _escala =
        (_escalaInicial * _distanciaDosDedos() / inicial).clamp(.6, 2.5));
  }

  void _dedoSaiu(PointerEvent evento) {
    _dedos.remove(evento.pointer);
    if (_distanciaInicial != null && _dedos.length < 2) {
      _distanciaInicial = null;
      _salvarEscala();
    }
  }

  double _distanciaDosDedos() {
    final pontos = _dedos.values.toList();
    return (pontos[0] - pontos[1]).distance;
  }

  @override
  Widget build(BuildContext context) {
    _procurarDepoisDeDesenhar();
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            onPointerDown: _dedoNaTela,
            onPointerMove: _dedoMoveu,
            onPointerUp: _dedoSaiu,
            onPointerCancel: _dedoSaiu,
            child: _Cifra(
              trechos: widget.trechos,
              cabecalho: widget.cabecalho,
              escala: _escala,
              controlador: _rolagem,
              registro: widget.aoLerALinha == null ? null : _registro,
            ),
          ),
        ),
        if (widget.aoLerALinha != null)
          Positioned.fill(child: _SetaDaTv(chave: _chaveDaSeta)),
        Positioned(
          right: EspacoTocaEssa.medio,
          bottom: EspacoTocaEssa.medio,
          child: _ControleDaRolagem(
            rolando: _rolando != null,
            velocidade: _velocidade,
            iniciar: _iniciarRolagem,
            pausar: _pararRolagem,
            mudarVelocidade: _mudarVelocidade,
          ),
        ),
      ],
    );
  }
}
