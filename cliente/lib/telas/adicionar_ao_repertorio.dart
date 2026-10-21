import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';

/// Folha para levar músicas da setlist, hinos ou pedidos a um repertório
/// já existente ou a um novo, criado na hora com [nomeSugerido]. Avisa
/// quantas entraram e devolve o resultado (nulo se desistir).
Future<MusicasAdicionadas?> adicionarAoRepertorio(
  BuildContext context, {
  required ApiTocaEssa api,
  required List<MusicaParaRepertorio> musicas,
  String nomeSugerido = '',
  Vocabulario vocabulario = Vocabulario.musical,
}) async {
  final avisos = ScaffoldMessenger.of(context);
  final resultado = await showModalBottomSheet<MusicasAdicionadas>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _FolhaDoRepertorio(
      api: api,
      musicas: musicas,
      nomeSugerido: nomeSugerido,
      v: vocabulario,
    ),
  );
  if (resultado != null) {
    avisos.showSnackBar(
        SnackBar(content: Text(textoDoResultado(resultado, vocabulario))));
  }
  return resultado;
}

/// "3 músicas foram para "Barzinho" · 2 já estavam".
String textoDoResultado(MusicasAdicionadas resultado, Vocabulario v) {
  final nome = '"${resultado.repertorio.nome}"';
  final (novas, ja) = (resultado.adicionadas, resultado.jaEstavam);
  if (novas == 0) return ja == 1 ? 'Já estava em $nome' : 'Já estavam em $nome';
  return [
    novas == 1
        ? '1 ${v.musica} foi para $nome'
        : '$novas ${v.musicas} foram para $nome',
    if (ja > 0) ja == 1 ? '1 já estava' : '$ja já estavam',
  ].join(' · ');
}

class _FolhaDoRepertorio extends StatefulWidget {
  const _FolhaDoRepertorio({
    required this.api,
    required this.musicas,
    required this.nomeSugerido,
    required this.v,
  });

  final ApiTocaEssa api;
  final List<MusicaParaRepertorio> musicas;
  final String nomeSugerido;
  final Vocabulario v;

  @override
  State<_FolhaDoRepertorio> createState() => _FolhaDoRepertorioState();
}

class _FolhaDoRepertorioState extends State<_FolhaDoRepertorio> {
  late final _nome = TextEditingController(text: widget.nomeSugerido);
  List<Repertorio>? _repertorios;
  bool _salvando = false;

  Vocabulario get _v => widget.v;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final repertorios = await widget.api.listarRepertorios();
      if (mounted) setState(() => _repertorios = repertorios);
    } catch (erro) {
      if (mounted) {
        setState(() => _repertorios = const []);
        mostrarErro(context, erro);
      }
    }
  }

  Future<void> _salvar({String? repertorioId, String? nomeNovo}) async {
    setState(() => _salvando = true);
    try {
      final resultado = await widget.api.adicionarMusicasAoRepertorio(
        repertorioId: repertorioId,
        nomeNovo: nomeNovo,
        musicas: widget.musicas,
      );
      if (mounted) Navigator.pop(context, resultado);
    } catch (erro) {
      if (mounted) {
        setState(() => _salvando = false);
        mostrarErro(context, erro);
      }
    }
  }

  void _criar() {
    final nome = _nome.text.trim();
    if (nome.isEmpty) return;
    _salvar(nomeNovo: nome);
  }

  int _jaEstao(Repertorio repertorio) => widget.musicas
      .where((musica) => repertorio.musicas.any((m) =>
          mesmaMusica(m.titulo, m.artista, musica.titulo, musica.artista)))
      .length;

  String _detalhe(Repertorio repertorio) {
    final total = repertorio.musicas.length;
    final ja = _jaEstao(repertorio);
    return [
      total == 1 ? '1 ${_v.musica}' : '$total ${_v.musicas}',
      if (ja > 0)
        widget.musicas.length == 1
            ? 'já está'
            : ja == 1
                ? '1 já está'
                : '$ja já estão',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final quantas = widget.musicas.length;
    final titulo = quantas == 1
        ? 'Adicionar "${widget.musicas.single.titulo}" a…'
        : 'Adicionar $quantas ${_v.musicas} a…';
    final repertorios = _repertorios;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(EspacoTocaEssa.base, 0,
                EspacoTocaEssa.base, EspacoTocaEssa.base),
            children: [
              Text(titulo, style: texto.titleMedium),
              const SizedBox(height: EspacoTocaEssa.base),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nome,
                      enabled: !_salvando,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _criar(),
                      decoration: const InputDecoration(
                        labelText: 'Novo repertório',
                        prefixIcon: Icon(Icons.add_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: EspacoTocaEssa.pequeno),
                  FilledButton(
                    onPressed: _salvando ? null : _criar,
                    child: const Text('Criar'),
                  ),
                ],
              ),
              const SizedBox(height: EspacoTocaEssa.base),
              if (repertorios == null)
                const Center(child: CircularProgressIndicator())
              else
                for (final repertorio in repertorios)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: !_salvando,
                    leading: const Icon(Icons.library_music_outlined),
                    title: Text(repertorio.nome),
                    subtitle: Text(_detalhe(repertorio),
                        style: texto.bodySmall
                            ?.copyWith(color: CoresTocaEssa.textoSecundario)),
                    onTap: () => _salvar(repertorioId: repertorio.id),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
