import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/midia_do_story.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';

const _chaveAparelho = 'aparelho_dos_stories';
const _chaveAvisoVisto = 'aviso_dos_stories_visto';
const _megabyte = 1024 * 1024;
const _duracaoMaxima = Duration(seconds: 60);
// A URL de envio vale 15 min; depois disso o envio é aberto de novo.
const _validadeDoEnvio = Duration(minutes: 10);
const _tiposAceitos = {
  'video/mp4',
  'video/quicktime',
  'image/jpeg',
  'image/png',
  'image/heic',
};

/// "Enviar vídeo ou foto" para os stories do show: escolhe na câmera ou na
/// galeria, manda direto para o armazenamento com progresso e, se a
/// internet cair, tenta de novo sem escolher outra vez.
class EnviarStory extends StatefulWidget {
  EnviarStory({
    super.key,
    required this.api,
    required this.codigo,
    required this.nome,
    this.aoEnviar,
    SeletorDeMidia? seletor,
    EnviadorDeArquivo? enviador,
  })  : seletor = seletor ?? SeletorDoAparelho(),
        enviador = enviador ?? EnviadorDoAparelho();

  final ApiTocaEssa api;
  final String codigo;
  final String? nome;
  final VoidCallback? aoEnviar;
  final SeletorDeMidia seletor;
  final EnviadorDeArquivo enviador;

  @override
  State<EnviarStory> createState() => _EnviarStoryState();
}

enum _Origem { video, foto, galeria }

class _EnviarStoryState extends State<EnviarStory> {
  MidiaEscolhida? _midia;
  EnvioAberto? _envio;
  DateTime? _abertoEm;
  double? _progresso;
  var _falhou = false;

  bool get _ocupado => _midia != null;

  Future<void> _comecar() async {
    if (_ocupado) return;
    final preferencias = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (preferencias.getBool(_chaveAvisoVisto) != true) {
      final entendeu = await showDialog<bool>(
        context: context,
        builder: (contexto) => AlertDialog(
          title: const Text('Stories do show'),
          content: const Text(
              'Todo mundo do show vai ver por 24 h, e o artista guarda por '
              '7 dias. Não envie quem não quer aparecer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contexto, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(contexto, true),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      if (entendeu != true || !mounted) return;
      await preferencias.setBool(_chaveAvisoVisto, true);
      if (!mounted) return;
    }
    final origem = await showModalBottomSheet<_Origem>(
      context: context,
      showDragHandle: true,
      builder: (contexto) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam_rounded),
              title: const Text('Gravar vídeo'),
              subtitle: const Text('Até 60 segundos'),
              onTap: () => Navigator.pop(contexto, _Origem.video),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(contexto, _Origem.foto),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(contexto, _Origem.galeria),
            ),
          ],
        ),
      ),
    );
    if (origem == null || !mounted) return;
    final midia = await switch (origem) {
      _Origem.video => widget.seletor.gravarVideo(),
      _Origem.foto => widget.seletor.tirarFoto(),
      _Origem.galeria => widget.seletor.escolherDaGaleria(),
    };
    if (midia == null || !mounted) return;
    if ((midia.duracao ?? Duration.zero) > _duracaoMaxima) {
      mostrarErro(context, 'Envie um vídeo de até 60 segundos.');
      return;
    }
    final limite =
        midia.tipo == TipoDeStory.video ? 100 * _megabyte : 15 * _megabyte;
    if (!_tiposAceitos.contains(midia.tipoDeConteudo) ||
        midia.tamanho <= 0 ||
        midia.tamanho > limite) {
      mostrarErro(
          context, 'Envie um vídeo de até 100 MB ou uma foto de até 15 MB.');
      return;
    }
    setState(() => _midia = midia);
    await _enviar();
  }

  Future<void> _enviar() async {
    final midia = _midia!;
    setState(() {
      _falhou = false;
      _progresso = 0;
    });
    try {
      final aberto = _abertoEm;
      if (_envio == null ||
          aberto == null ||
          DateTime.now().difference(aberto) > _validadeDoEnvio) {
        _envio = await widget.api.abrirEnvioDeStory(
          widget.codigo,
          tipo: midia.tipo,
          tipoDeConteudo: midia.tipoDeConteudo,
          tamanho: midia.tamanho,
          nome: widget.nome?.trim().isEmpty == true ? null : widget.nome?.trim(),
          aparelho: await _aparelho(),
        );
        _abertoEm = DateTime.now();
      }
    } on FalhaNaApi catch (erro) {
      // O servidor recusou (fechado, limite): tentar de novo não adianta.
      _terminar();
      if (mounted) mostrarErro(context, erro);
      return;
    } catch (_) {
      _marcarFalha();
      return;
    }
    final envio = _envio!;
    try {
      await widget.enviador.enviar(envio.urlDeEnvio, envio.cabecalhos,
          midia.arquivo, (fracao) {
        if (mounted) setState(() => _progresso = fracao);
      });
    } catch (_) {
      _marcarFalha();
      return;
    }
    try {
      await widget.api.confirmarEnvioDeStory(widget.codigo, envio.id);
    } on FalhaNaApi catch (erro) {
      _terminar();
      if (mounted) mostrarErro(context, erro);
      return;
    } catch (_) {
      _marcarFalha();
      return;
    }
    _terminar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enviado! Já aparece nos stories do show.')));
    widget.aoEnviar?.call();
  }

  void _marcarFalha() {
    if (mounted) setState(() => _falhou = true);
  }

  void _terminar() {
    _envio = null;
    _abertoEm = null;
    if (mounted) {
      setState(() {
        _midia = null;
        _progresso = null;
        _falhou = false;
      });
    }
  }

  static Future<String> _aparelho() async {
    final preferencias = await SharedPreferences.getInstance();
    final salvo = preferencias.getString(_chaveAparelho);
    if (salvo != null && salvo.isNotEmpty) return salvo;
    final aleatorio = Random.secure();
    final novo = [
      for (var i = 0; i < 16; i++)
        aleatorio.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    await preferencias.setString(_chaveAparelho, novo);
    return novo;
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final secundario =
        texto.bodyMedium?.copyWith(color: CoresTocaEssa.textoSecundario);
    return Container(
      decoration: BoxDecoration(
        color: CoresTocaEssa.superficie,
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
        border: Border.all(color: CoresTocaEssa.borda),
      ),
      child: Material(
        color: Colors.transparent,
        child: !_ocupado
            ? InkWell(
                onTap: _comecar,
                borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
                child: Padding(
                  padding: const EdgeInsets.all(EspacoTocaEssa.base),
                  child: Row(
                    children: [
                      const Icon(Icons.video_camera_front_rounded,
                          color: CoresTocaEssa.roxoClaro),
                      const SizedBox(width: EspacoTocaEssa.base),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Enviar vídeo ou foto',
                                style: texto.bodyLarge),
                            Text('Todo mundo do show vê por 24 h',
                                style: secundario),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: CoresTocaEssa.textoSecundario),
                    ],
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(EspacoTocaEssa.base),
                child: _falhou
                    ? Row(
                        children: [
                          Expanded(
                            child: Text('Não foi possível enviar.',
                                style: texto.bodyLarge),
                          ),
                          TextButton(
                            onPressed: _terminar,
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: _enviar,
                            child: const Text('Tentar de novo'),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Enviando… ${((_progresso ?? 0) * 100).round()}%',
                            style: texto.bodyLarge,
                          ),
                          const SizedBox(height: EspacoTocaEssa.pequeno),
                          LinearProgressIndicator(value: _progresso),
                        ],
                      ),
              ),
      ),
    );
  }
}
