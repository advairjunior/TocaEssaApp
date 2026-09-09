import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/assinatura_tempo_real.dart';
import '../infraestrutura/baixar_arquivo.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'progresso_do_publico.dart';
import 'perfil_participante.dart';

part 'area_do_publico_estado.dart';
part 'area_do_publico_sessao.dart';
part 'area_do_publico_pedidos.dart';
part 'area_do_publico_perfil.dart';
part 'area_do_publico_retrospectiva.dart';
part 'area_do_publico_construcao.dart';
part 'area_do_publico_aba_pedir.dart';
part 'area_do_publico_aba_fila.dart';
part 'componentes_publico_galera.dart';
part 'componentes_publico_perfil.dart';
part 'componentes_publico_cabecalho.dart';
part 'componentes_publico_pedidos.dart';
part 'componentes_publico_fila.dart';

class AreaDoPublico extends StatefulWidget {
  const AreaDoPublico(
      {super.key, required this.api, required this.codigoInicial});

  final ApiTocaEssa api;
  final String codigoInicial;

  @override
  State<AreaDoPublico> createState() => _AreaDoPublicoState();
}
