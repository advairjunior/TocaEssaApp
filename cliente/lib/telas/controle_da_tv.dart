import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/tela_da_tv.dart';
import '../infraestrutura/api_toca_essa.dart';

/// Encerra a assinatura do tempo real da TV.
typedef AssinaturaDaTv = void Function();

/// Abre o tempo real da TV e entrega cada evento ("linha:3:6").
typedef AssinarTempoRealDaTv = AssinaturaDaTv Function(
    String endereco, void Function(String dado) aoReceber);

const _chaveDoToken = 'tv_token';
const _chaveDoId = 'tv_id';

/// O que a TV faz sozinha, sem ninguém mexer nela: guarda o token, mostra o
/// código até alguém conectá-la, depois acompanha a música e a linha pelo
/// tempo real. Se o servidor esquecer a TV, pede um código novo.
class ControleDaTv extends ChangeNotifier {
  ControleDaTv({
    required this.api,
    required this.assinar,
    this.espera = const Duration(seconds: 3),
  });

  final ApiTocaEssa api;
  final AssinarTempoRealDaTv assinar;
  // De quanto em quanto tempo a TV pergunta se já foi conectada.
  final Duration espera;

  String? codigo;
  bool pareada = false;
  ConteudoDaTv? conteudo;

  String? _token;
  String? _id;
  AssinaturaDaTv? _encerrarTempoReal;
  Timer? _relogio;
  bool _descartado = false;

  Future<void> comecar() async {
    _relogio = Timer.periodic(espera, (_) => _aCadaVolta());
    await _aCadaVolta();
  }

  /// Enquanto ninguém conecta a TV, pergunta de novo; TV aberta sem
  /// internet tenta pegar o código na volta seguinte.
  Future<void> _aCadaVolta() async {
    if (pareada) return;
    try {
      if (_token == null) await _lerOuCriarTv();
      await consultar();
    } catch (_) {
      // Sem internet: tenta na próxima volta.
    }
  }

  Future<void> consultar() async {
    try {
      _aplicar(await api.obterEstadoDaTv(_token!));
    } on TvDesconhecida {
      _pararTempoReal();
      await _criarTv();
      await _consultarSemRepetir();
    } catch (_) {
      // Sem internet: a TV fica como está e pergunta de novo depois.
    }
  }

  Future<void> _consultarSemRepetir() async {
    try {
      _aplicar(await api.obterEstadoDaTv(_token!));
    } catch (_) {
      // Pergunta de novo na próxima volta do relógio.
    }
  }

  void _aplicar(EstadoDaTv estado) {
    pareada = estado.pareada;
    codigo = estado.codigo;
    conteudo = estado.conteudo;
    pareada ? _ouvir() : _pararTempoReal();
    _avisar();
  }

  void _ouvir() =>
      _encerrarTempoReal ??= assinar(api.enderecoTempoRealDaTv(_id!), _receber);

  /// Linha da mesma música só move o destaque; outra versão (música nova
  /// ou TV limpa) e reconexão buscam tudo de novo.
  void _receber(String dado) {
    final evento = EventoDaTv.ler(dado);
    final atual = conteudo;
    if (evento != null && atual != null && evento.versao == atual.versao) {
      conteudo = atual.naLinha(evento.linha);
      _avisar();
    } else if (evento != null || dado == 'conectado') {
      consultar();
    }
  }

  Future<void> _lerOuCriarTv() async {
    final preferencias = await SharedPreferences.getInstance();
    _token = preferencias.getString(_chaveDoToken);
    _id = preferencias.getString(_chaveDoId);
    if (_token == null || _id == null) await _criarTv();
  }

  Future<void> _criarTv() async {
    final tv = await api.criarTv();
    _token = tv.token;
    _id = tv.id;
    codigo = tv.codigo;
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString(_chaveDoToken, tv.token);
    await preferencias.setString(_chaveDoId, tv.id);
  }

  void _pararTempoReal() {
    _encerrarTempoReal?.call();
    _encerrarTempoReal = null;
  }

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _relogio?.cancel();
    _pararTempoReal();
    super.dispose();
  }
}
