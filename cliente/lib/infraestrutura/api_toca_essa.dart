import 'dart:convert';

import 'package:http/http.dart' as http;

import '../dominio/modelos.dart';
part 'api_toca_essa_cifras_perfil.dart';
part 'api_toca_essa_apresentacoes.dart';
part 'api_toca_essa_pedidos.dart';
part 'api_toca_essa_contas.dart';

abstract class _ApiTocaEssaBase {
  _ApiTocaEssaBase({http.Client? cliente, String? enderecoBase})
      : _cliente = cliente ?? http.Client(),
        _enderecoBase = enderecoBase ?? _enderecoConfigurado();

  final http.Client _cliente;
  final String _enderecoBase;
  String? _tokenArtista;

  void definirTokenArtista(String? token) => _tokenArtista = token;

  String enderecoTempoReal(String codigo) =>
      '$_enderecoBase/api/tempo-real/${codigo.trim().toUpperCase()}';

  static String _enderecoConfigurado() {
    const configurado = String.fromEnvironment('API_URL');
    if (configurado.isNotEmpty) return configurado;
    if (Uri.base.scheme == 'http' || Uri.base.scheme == 'https') {
      return Uri.base.origin;
    }
    return 'http://localhost:5080';
  }

  Map<String, String> _cabecalhos({String? token, bool json = false}) => {
        if (json) 'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  void _validar(http.Response resposta) {
    if (resposta.statusCode >= 200 && resposta.statusCode < 300) return;
    try {
      final corpo = jsonDecode(resposta.body) as Map<String, dynamic>;
      final erros = corpo['errors'];
      if (erros is Map<String, dynamic>) {
        for (final valor in erros.values) {
          if (valor is List && valor.isNotEmpty) {
            throw FalhaNaApi(valor.first.toString());
          }
          if (valor is String && valor.isNotEmpty) {
            throw FalhaNaApi(valor);
          }
        }
      }
      throw FalhaNaApi(corpo['mensagem'] as String? ??
          corpo['title'] as String? ??
          'Não foi possível concluir.');
    } on FormatException {
      throw const FalhaNaApi('Não foi possível conectar ao TocaEssaApp.');
    }
  }

  String _formatarData(DateTime data) =>
      '${data.year.toString().padLeft(4, '0')}-'
      '${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}';
}

class ApiTocaEssa extends _ApiTocaEssaBase
    with _ApiCifrasPerfil, _ApiApresentacoes, _ApiPedidos, _ApiContas {
  ApiTocaEssa({super.cliente, super.enderecoBase});
}

class FalhaNaApi implements Exception {
  const FalhaNaApi(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}
