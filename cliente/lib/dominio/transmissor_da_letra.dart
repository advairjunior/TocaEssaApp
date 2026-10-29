import 'dart:async';

import 'tela_da_tv.dart';

/// Para onde vai o que o celular do dono mostra. As telas dependem só desta
/// interface; a API é uma saída, e os testes usam uma falsa.
abstract interface class SaidaDaTela {
  Future<void> mostrar(ConteudoParaTv conteudo);
  Future<void> irParaALinha(int linha);
  Future<void> limpar();
}

/// Leva a música e a linha lida até a TV sem encher a rede: linha repetida
/// não vai, rolagem rápida manda no máximo uma linha por [intervalo] (e a
/// última sempre chega), e a música vai de novo se o servidor tiver dormido.
/// Falha de internet nunca atrapalha a cifra: a TV só fica parada.
class TransmissorDaLetra {
  TransmissorDaLetra(this._saida,
      {this.intervalo = const Duration(milliseconds: 300)});

  final SaidaDaTela _saida;
  final Duration intervalo;
  ConteudoParaTv? _conteudo;
  int? _ultimaEnviada;
  int? _pendente;
  Timer? _espera;

  void mostrar(ConteudoParaTv conteudo) {
    _esquecerPendente();
    _conteudo = conteudo;
    _ultimaEnviada = conteudo.linha;
    _semDerrubar(_saida.mostrar(conteudo));
  }

  void lerALinha(int linha) {
    if (_conteudo == null) return;
    if (_espera != null) {
      _pendente = linha;
    } else if (linha != _ultimaEnviada) {
      _enviarLinha(linha);
      _espera = Timer(intervalo, _fimDaEspera);
    }
  }

  void limpar() {
    _esquecerPendente();
    _conteudo = null;
    _ultimaEnviada = null;
    _semDerrubar(_saida.limpar());
  }

  void encerrar() => _esquecerPendente();

  void _fimDaEspera() {
    _espera = null;
    final pendente = _pendente;
    _pendente = null;
    if (pendente != null) lerALinha(pendente);
  }

  void _enviarLinha(int linha) {
    final conteudo = _conteudo!;
    _ultimaEnviada = linha;
    _semDerrubar(_saida.irParaALinha(linha).catchError(
        (Object _) => _saida.mostrar(conteudo.naLinha(linha)),
        test: (erro) => erro is TvAindaSemMusica && _conteudo == conteudo));
  }

  void _esquecerPendente() {
    _espera?.cancel();
    _espera = null;
    _pendente = null;
  }

  static void _semDerrubar(Future<void> envio) =>
      unawaited(envio.catchError((Object _) {}));
}
