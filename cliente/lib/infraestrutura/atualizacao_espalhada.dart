import 'dart:async';
import 'dart:math';

/// Agrupa avisos de alteração e espalha a atualização por um atraso sorteado,
/// para que todos os convidados não consultem o servidor no mesmo instante.
class AtualizacaoEspalhada {
  AtualizacaoEspalhada(
    this._atualizar, {
    Duration atrasoMaximo = const Duration(seconds: 3),
    Random? sorteio,
  })  : _atrasoMaximoEmMs = atrasoMaximo.inMilliseconds,
        _sorteio = sorteio ?? Random();

  final Future<void> Function() _atualizar;
  final int _atrasoMaximoEmMs;
  final Random _sorteio;
  Timer? _agendada;
  bool _executando = false;
  bool _pendente = false;
  bool _encerrada = false;

  void solicitar() {
    if (_encerrada) return;
    if (_executando) {
      _pendente = true;
      return;
    }
    _agendada ??= Timer(
      Duration(milliseconds: _sorteio.nextInt(_atrasoMaximoEmMs + 1)),
      _executar,
    );
  }

  Future<void> _executar() async {
    _agendada = null;
    _executando = true;
    try {
      await _atualizar();
    } finally {
      _executando = false;
      if (_pendente) {
        _pendente = false;
        solicitar();
      }
    }
  }

  void encerrar() {
    _encerrada = true;
    _agendada?.cancel();
    _agendada = null;
  }
}
