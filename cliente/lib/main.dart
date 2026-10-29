import 'package:flutter/material.dart';

import 'infraestrutura/api_toca_essa.dart';
import 'infraestrutura/teclado_virtual.dart';
import 'tema/tema_toca_essa.dart';
import 'telas/area_do_publico.dart';
import 'telas/cifra_compartilhada.dart';
import 'telas/aviso_sem_internet.dart';
import 'telas/acesso_do_artista.dart';
import 'telas/componentes.dart';
import 'telas/inicio.dart';
import 'telas/conta_do_publico.dart';
import 'telas/tela_da_tv.dart';

void main() {
  instalarCorrecaoTecladoVirtual();
  runApp(const TocaEssaApp());
}

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
      // A faixa "Sem internet" fica acima de todas as telas.
      builder: (context, filho) => ComAvisoSemInternet(
        semInternetDesde: servico.semInternetDesde,
        child: ManterCampoFocadoVisivel(child: filho!),
      ),
      // Aberto por um link de quem está na roda (resenha, louvor, cifra ou
      // TV), o app não põe o início embaixo: o voltar do aparelho tirava a
      // pessoa dos hinos e ela tinha que abrir o link de novo.
      onGenerateInitialRoutes: (nome) {
        final rota = _rota(servico, RouteSettings(name: nome));
        final doLink = const {'publico', 'cifra', 'tv'}
            .contains(Uri.parse(nome).pathSegments.firstOrNull);
        return [
          if (!doLink && nome != '/')
            _rota(servico, const RouteSettings(name: '/')),
          rota,
        ];
      },
      onGenerateRoute: (configuracao) => _rota(servico, configuracao),
    );
  }

  static Route<void> _rota(ApiTocaEssa servico, RouteSettings configuracao) {
    final uri = Uri.parse(configuracao.name ?? '/');
    if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'publico') {
      return MaterialPageRoute<void>(
        settings: configuracao,
        builder: (_) => AreaDoPublico(
            api: servico,
            codigoInicial: uri.pathSegments.last,
            hinoInicial: uri.queryParameters['hino']),
      );
    }
    // Link de uma cifra compartilhada pelo artista, aberto sem conta.
    if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'cifra') {
      return MaterialPageRoute<void>(
        settings: configuracao,
        builder: (_) =>
            CifraCompartilhadaTela(api: servico, codigo: uri.pathSegments.last),
      );
    }
    if (uri.path == '/artista') {
      return MaterialPageRoute<void>(
          builder: (_) => AcessoDoArtista(api: servico));
    }
    // A TV da Letra na TV, aberta no navegador da televisão.
    if (uri.path == '/tv') {
      return MaterialPageRoute<void>(builder: (_) => TelaDaTv(api: servico));
    }
    if (uri.path == '/minha-conta') {
      return MaterialPageRoute<void>(
          builder: (_) => ContaDoPublico(api: servico));
    }
    return MaterialPageRoute<void>(builder: (_) => Inicio(api: servico));
  }
}
