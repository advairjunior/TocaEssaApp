import 'package:flutter/material.dart';

import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/assinatura_tempo_real.dart';

/// Encerra a assinatura do tempo real do evento.
typedef EncerrarAssinatura = void Function();

EncerrarAssinatura _assinarNoNavegador(String endereco, VoidCallback alterou) =>
    AssinaturaTempoReal(endereco, alterou).encerrar;

/// Invisível no painel do evento (fora das abas): quando um músico entra
/// pelo convite, avisa "Bia entrou na Resenha House", para o dono saber que
/// o link funcionou sem abrir o Mais.
class AvisoDeMusicoNovo extends StatefulWidget {
  const AvisoDeMusicoNovo({
    super.key,
    required this.api,
    required this.apresentacaoId,
    required this.codigo,
    required this.evento,
    this.assinar = _assinarNoNavegador,
  });

  final ApiTocaEssa api;
  final String apresentacaoId;
  final String codigo;
  final String evento;
  final EncerrarAssinatura Function(String endereco, VoidCallback alterou)
      assinar;

  @override
  State<AvisoDeMusicoNovo> createState() => _AvisoDeMusicoNovoState();
}

class _AvisoDeMusicoNovoState extends State<AvisoDeMusicoNovo> {
  // Nulo até a primeira lista: quem já estava não é novidade.
  Set<String>? _conhecidos;
  late final EncerrarAssinatura _encerrar;

  @override
  void initState() {
    super.initState();
    _conferir();
    _encerrar =
        widget.assinar(widget.api.enderecoTempoReal(widget.codigo), _conferir);
  }

  @override
  void dispose() {
    _encerrar();
    super.dispose();
  }

  Future<void> _conferir() async {
    try {
      final musicos = await widget.api.listarMusicos(widget.apresentacaoId);
      final conhecidos = _conhecidos;
      _conhecidos = {for (final musico in musicos) musico.artistaId};
      if (conhecidos == null || !mounted) return;
      for (final musico in musicos) {
        if (conhecidos.contains(musico.artistaId)) continue;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${musico.nome} entrou na ${widget.evento}')));
      }
    } catch (_) {
      // Sem internet: confere na próxima mudança.
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
