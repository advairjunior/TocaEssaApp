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
import 'telas/comando_do_ajudante.dart';
import 'telas/conta_do_publico.dart';
import 'telas/convite_do_musico.dart';
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
        final doLink = const {'publico', 'cifra', 'tv', 'convite', 'comando'}
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
    final tela = _telaDoLink(servico, uri) ?? _telaDoCaminho(servico, uri.path);
    return MaterialPageRoute<void>(
        settings: configuracao, builder: (_) => tela);
  }

  /// Links com código que alguém manda: "#/publico/ABC", "#/cifra/…",
  /// "#/convite/…" (músico da noite) e "#/comando/…" (quem cuida da TV).
  static Widget? _telaDoLink(ApiTocaEssa servico, Uri uri) {
    if (uri.pathSegments.length != 2) return null;
    final valor = uri.pathSegments.last;
    return switch (uri.pathSegments.first) {
      'publico' => AreaDoPublico(
          api: servico,
          codigoInicial: valor,
          hinoInicial: uri.queryParameters['hino']),
      'cifra' => CifraCompartilhadaTela(api: servico, codigo: valor),
      'convite' => ConviteDoMusico(api: servico, codigo: valor),
      'comando' => ComandoDoAjudante(api: servico, token: valor),
      _ => null,
    };
  }

  static Widget _telaDoCaminho(ApiTocaEssa servico, String caminho) =>
      switch (caminho) {
        '/artista' => AcessoDoArtista(api: servico),
        // A TV da Letra na TV, aberta no navegador da televisão.
        '/tv' => TelaDaTv(api: servico),
        '/minha-conta' => ContaDoPublico(api: servico),
        _ => Inicio(api: servico),
      };
}
