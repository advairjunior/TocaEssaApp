import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/abrir_url_externa.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/assinatura_tempo_real.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_lista.dart';
import 'entrar_para_guardar.dart';
import 'escolher_musica_do_karaoke.dart';
import 'noite_de_karaoke_placar.dart';

part 'noite_de_karaoke_galera_vez.dart';
part 'noite_de_karaoke_galera_nota.dart';

void _abrirNoYouTube(Uri url) => abrirUrlExterna(url);

/// A noite no celular de cada um: entra na galera com a conta, escolhe a
/// música, acompanha a ordem e, na vez, toca o vídeo na TV pelo YouTube.
class NoiteDeKaraokeDaGalera extends StatefulWidget {
  const NoiteDeKaraokeDaGalera({
    super.key,
    required this.api,
    required this.codigo,
    this.abrirUrl = _abrirNoYouTube,
  });

  final ApiTocaEssa api;
  final String codigo;

  /// Abre o vídeo no próprio toque: o Safari bloqueia o que abre depois.
  final void Function(Uri url) abrirUrl;

  @override
  State<NoiteDeKaraokeDaGalera> createState() => _NoiteDeKaraokeDaGaleraState();
}

class _NoiteDeKaraokeDaGaleraState extends State<NoiteDeKaraokeDaGalera> {
  Apresentacao? _apresentacao;
  NoiteDeKaraoke? _noite;
  String? _token;
  String? _eu;
  bool _carregando = true;
  bool _ocupado = false;
  // Na roleta, a pessoa disse que conhece a música sorteada.
  bool _confirmada = false;
  AssinaturaTempoReal? _tempoReal;

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  @override
  void dispose() {
    _tempoReal?.encerrar();
    super.dispose();
  }

  Future<void> _abrir() async {
    try {
      final apresentacao =
          await widget.api.obterApresentacaoPublica(widget.codigo);
      final preferencias = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _apresentacao = apresentacao;
        _token = preferencias.getString('token_do_publico');
      });
      await _entrarNaGalera();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Com a conta no aparelho, a pessoa entra na galera e passa a ver a
  /// ordem, que se atualiza sozinha.
  Future<void> _entrarNaGalera() async {
    final token = _token;
    if (token == null) return;
    await widget.api.registrarParticipacao(widget.codigo, token);
    final perfil = await widget.api.obterPerfilPublico(token);
    if (mounted) setState(() => _eu = perfil.id);
    await _carregar();
    _tempoReal ??= AssinaturaTempoReal(
        widget.api.enderecoTempoReal(widget.codigo), _carregar);
  }

  Future<void> _carregar() async {
    final token = _token;
    if (token == null) return;
    try {
      // A apresentação junto: encerrada, o placar mostra a Voz da noite.
      final (noite, apresentacao) = await (
        widget.api.obterNoiteDeKaraokePublica(widget.codigo, token),
        widget.api.obterApresentacaoPublica(widget.codigo),
      ).wait;
      if (!mounted) return;
      setState(() {
        _noite = noite;
        _apresentacao = apresentacao ?? _apresentacao;
      });
    } catch (_) {
      // A ordem mostrada fica até a próxima atualização.
    }
  }

  Future<void> _entrarNaConta() async {
    final entrou = await entrarParaGuardar(context, widget.api,
        titulo: 'Entrar no karaokê',
        explicacao: 'Com a conta você entra na ordem de quem canta, recebe '
            'a sua vez e a noite fica em Meus encontros.');
    if (!entrou || !mounted) return;
    final preferencias = await SharedPreferences.getInstance();
    setState(() => _token = preferencias.getString('token_do_publico'));
    try {
      await _entrarNaGalera();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _executar(
      Future<NoiteDeKaraoke> Function(String token) acao) async {
    final token = _token;
    if (token == null) return;
    setState(() => _ocupado = true);
    try {
      final noite = await acao(token);
      if (mounted) setState(() => _noite = noite);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _escolher() async {
    final token = _token;
    if (token == null) return;
    final escolha = await escolherMusicaDoKaraoke(context,
        api: widget.api, codigo: widget.codigo, token: token);
    if (escolha == null || !mounted) return;
    await _executar((token) => widget.api.escolherMusicaNoKaraoke(
        widget.codigo, token,
        musicaId: escolha.musicaId,
        titulo: escolha.titulo,
        linkDoVideo: escolha.linkDoVideo));
  }

  Future<void> _girar() {
    setState(() => _confirmada = false);
    return _executar(
        (token) => widget.api.girarRoletaDoKaraoke(widget.codigo, token));
  }

  /// O vídeo abre antes de qualquer espera, ainda dentro do toque.
  Future<void> _tocarNaTv(MusicaDoKaraoke musica) {
    widget.abrirUrl(musica.enderecoNoYouTube);
    setState(() => _confirmada = false);
    return _executar(
        (token) => widget.api.comecarVezNoKaraoke(widget.codigo, token));
  }

  Future<void> _darNota(int estrelas) => _executar(
      (token) => widget.api.darNotaNoKaraoke(widget.codigo, token, estrelas));

  Future<void> _terminar() => _executar(
      (token) => widget.api.terminarVezNoKaraoke(widget.codigo, token));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_apresentacao?.nome ?? 'Karaokê')),
        body: _carregando
            ? const Center(child: CircularProgressIndicator())
            : ConteudoMobile(
                filho: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _token == null ? _semConta() : _naGalera(),
                ),
              ),
      );

  List<Widget> _semConta() => [
        const EstadoVazio(
          icone: Icons.mic_external_on_rounded,
          titulo: 'Bora cantar?',
          descricao: 'Entre com a sua conta para entrar no sorteio de quem '
              'canta e dar nota para a galera.',
        ),
        FilledButton(
          onPressed: _entrarNaConta,
          child: const Text('Entrar para participar'),
        ),
      ];

  List<Widget> _naGalera() {
    final noite = _noite;
    if (noite == null) return const [];
    final momento = MomentoNaNoite.de(noite, _eu);
    return [
      if (noite.cantando case final cantando? when cantando.publicoId != _eu)
        _CantandoAgora(
            cantando: cantando, darNota: _darNota, ocupado: _ocupado),
      _CartaoDaVez(
        noite: noite,
        momento: momento,
        acoes: _AcoesDaVez(
          ocupado: _ocupado,
          confirmada: _confirmada,
          escolher: _escolher,
          girar: _girar,
          confirmar: () => setState(() => _confirmada = true),
          tocarNaTv: _tocarNaTv,
          terminar: _terminar,
        ),
        eu: _eu,
      ),
      const SizedBox(height: EspacoTocaEssa.grande),
      TituloGrupo(noite.sorteada
          ? 'Ordem da noite'
          : 'Na galera · ${noite.ordem.length}'),
      GrupoDeLinhas(linhas: [
        for (final (indice, pessoa) in noite.ordem.indexed)
          ListTile(
            key: ValueKey(pessoa.publicoId),
            leading: SizedBox(
              width: 28,
              child: Center(
                child: Text(noite.sorteada ? '${indice + 1}º' : '·',
                    style: const TextStyle(color: CoresTocaEssa.roxoClaro)),
              ),
            ),
            title: Text(pessoa.nome),
            trailing: pessoa.publicoId == _eu ? const Text('você') : null,
          ),
      ]),
      PlacarDaNoite(
          noite: noite,
          encerrada: _apresentacao?.status == StatusApresentacao.encerrada),
    ];
  }
}
