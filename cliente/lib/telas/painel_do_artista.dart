import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/baixar_arquivo.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_formulario.dart';
import 'perfil_participante.dart';
import 'estatisticas_da_apresentacao.dart';
import 'fila_musical_artista.dart';
import 'fundo_toca_essa.dart';
import 'setlist_do_artista.dart';
import 'gerenciar_repertorios.dart';

part 'painel_do_artista_estado.dart';
part 'painel_do_artista_acoes_apresentacao.dart';
part 'painel_do_artista_construcao.dart';
part 'painel_do_artista_aba_perfil.dart';
part 'painel_do_artista_perfil_publico.dart';
part 'painel_do_artista_galera.dart';
part 'painel_do_artista_inicio.dart';
part 'painel_do_artista_apresentacao.dart';
part 'componentes_painel_progresso.dart';
part 'componentes_painel_inicio.dart';
part 'componentes_painel_apresentacao.dart';
part 'formulario_apresentacao.dart';
part 'codigo_da_apresentacao.dart';

enum _FiltroApresentacoes { proximas, historico }

/// Telas do painel: o início e o perfil ficam fora de uma apresentação;
/// as demais são as abas de uma apresentação aberta.
enum _AbaPainel { inicio, perfil, fila, setlist, estatisticas, mais }

const _abasDaApresentacao = [
  _AbaPainel.fila,
  _AbaPainel.setlist,
  _AbaPainel.estatisticas,
  _AbaPainel.mais,
];

class PainelDoArtista extends StatefulWidget {
  const PainelDoArtista({
    super.key,
    required this.api,
    required this.conta,
    required this.sair,
  });
  final ApiTocaEssa api;
  final ContaArtista conta;
  final Future<void> Function() sair;

  @override
  State<PainelDoArtista> createState() => _PainelDoArtistaState();
}
