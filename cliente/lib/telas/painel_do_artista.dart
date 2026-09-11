import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'perfil_participante.dart';
import 'estatisticas_da_apresentacao.dart';
import 'fila_musical_artista.dart';
import 'fundo_toca_essa.dart';

part 'painel_do_artista_estado.dart';
part 'painel_do_artista_acoes_apresentacao.dart';
part 'painel_do_artista_construcao.dart';
part 'painel_do_artista_aba_perfil.dart';
part 'painel_do_artista_aba_galera.dart';
part 'painel_do_artista_abas_apresentacoes.dart';
part 'painel_do_artista_abas_gestao.dart';
part 'componentes_painel_progresso.dart';
part 'componentes_painel_apresentacao.dart';
part 'editar_apresentacao.dart';
part 'codigo_da_apresentacao.dart';

enum _FiltroApresentacoes { aoVivo, agendadas, historico }

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
