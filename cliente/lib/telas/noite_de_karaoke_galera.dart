import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/assinatura_tempo_real.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_lista.dart';
import 'entrar_para_guardar.dart';

/// A noite no celular de cada um: entra na galera com a conta e acompanha a
/// ordem sorteada e a própria vez.
class NoiteDeKaraokeDaGalera extends StatefulWidget {
  const NoiteDeKaraokeDaGalera(
      {super.key, required this.api, required this.codigo});

  final ApiTocaEssa api;
  final String codigo;

  @override
  State<NoiteDeKaraokeDaGalera> createState() => _NoiteDeKaraokeDaGaleraState();
}

class _NoiteDeKaraokeDaGaleraState extends State<NoiteDeKaraokeDaGalera> {
  Apresentacao? _apresentacao;
  NoiteDeKaraoke? _noite;
  String? _token;
  String? _eu;
  bool _carregando = true;
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
      final noite =
          await widget.api.obterNoiteDeKaraokePublica(widget.codigo, token);
      if (mounted) setState(() => _noite = noite);
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
    return [
      _CartaoDaVez(noite: noite, eu: _eu),
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
    ];
  }
}

/// Onde a pessoa está na noite.
class _CartaoDaVez extends StatelessWidget {
  const _CartaoDaVez({required this.noite, required this.eu});

  final NoiteDeKaraoke noite;
  final String? eu;

  (String, String) get _textos {
    final posicao = noite.posicaoDe(eu);
    if (posicao == null) {
      return (
        'Você está fora da ordem',
        'Fale com o dono da noite para voltar.'
      );
    }
    if (!noite.sorteada) {
      return (
        'Você está na galera',
        'O dono da noite ainda vai sortear a ordem de quem canta.'
      );
    }
    final antes = posicao - 1;
    return (
      antes == 0
          ? 'Você é o 1º · abre a noite'
          : 'Você é o $posicaoº · ${antes == 1 ? 'falta 1' : 'faltam $antes'} '
              'antes de você',
      'Vá pensando na música e na coragem.'
    );
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final (titulo, detalhe) = _textos;
    return Container(
      padding: const EdgeInsets.all(EspacoTocaEssa.base),
      decoration: BoxDecoration(
        color: CoresTocaEssa.superficie,
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
        border: Border.all(color: CoresTocaEssa.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: texto.titleMedium),
          const SizedBox(height: EspacoTocaEssa.mini),
          Text(detalhe,
              style: texto.bodyMedium
                  ?.copyWith(color: CoresTocaEssa.textoSecundario)),
        ],
      ),
    );
  }
}
