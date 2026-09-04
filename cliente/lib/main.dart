import 'package:flutter/material.dart';

import 'infraestrutura/api_toca_essa.dart';
import 'tema/tema_toca_essa.dart';
import 'telas/area_do_publico.dart';
import 'telas/acesso_do_artista.dart';
import 'telas/inicio.dart';

void main() => runApp(const TocaEssaApp());

class TocaEssaApp extends StatelessWidget {
  const TocaEssaApp({super.key, this.api});

  final ApiTocaEssa? api;

  @override
  Widget build(BuildContext context) {
    final servico = api ?? ApiTocaEssa();
    return MaterialApp(
      title: 'TocaEssa',
      debugShowCheckedModeBanner: false,
      theme: TemaTocaEssa.escuro,
      onGenerateRoute: (configuracao) {
        final uri = Uri.parse(configuracao.name ?? '/');
        if (uri.pathSegments.length == 2 &&
            uri.pathSegments.first == 'publico') {
          return MaterialPageRoute<void>(
            settings: configuracao,
            builder: (_) => AreaDoPublico(
                api: servico, codigoInicial: uri.pathSegments.last),
          );
        }
        if (uri.path == '/artista') {
          return MaterialPageRoute<void>(
              builder: (_) => AcessoDoArtista(api: servico));
        }
        return MaterialPageRoute<void>(builder: (_) => Inicio(api: servico));
      },
    );
  }
}
