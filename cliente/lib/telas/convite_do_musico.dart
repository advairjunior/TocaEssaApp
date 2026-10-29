import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/musicos_da_noite.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'acesso_do_artista.dart';
import 'componentes.dart';
import 'fundo_toca_essa.dart';

/// Chave do convite aberto sem conta: o painel abre o convite depois que a
/// pessoa entra ou cria a conta de artista.
const chaveDoConvitePendente = 'convite_pendente';

/// O link `#/convite/<código>` que o dono manda aos amigos músicos. Entrar
/// no evento dá a setlist e as cifras daquela noite, não a conta do dono.
class ConviteDoMusico extends StatefulWidget {
  const ConviteDoMusico({super.key, required this.api, required this.codigo});

  final ApiTocaEssa api;
  final String codigo;

  @override
  State<ConviteDoMusico> createState() => _ConviteDoMusicoState();
}

enum _Etapa { carregando, semConta, convite, dentro, invalido }

class _ConviteDoMusicoState extends State<ConviteDoMusico> {
  _Etapa _etapa = _Etapa.carregando;
  ConviteDaNoite? _convite;
  String _aviso = '';
  bool _entrando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final preferencias = await SharedPreferences.getInstance();
    final token = preferencias.getString('token_do_artista');
    if (token == null) return _mudar(_Etapa.semConta);
    widget.api.definirTokenArtista(token);
    try {
      _convite = await widget.api.verConvite(widget.codigo);
      _mudar(_Etapa.convite);
    } on ConviteNaoEncontrado catch (erro) {
      _aviso = erro.mensagem;
      _mudar(_Etapa.invalido);
    } catch (_) {
      _aviso = 'Não deu para abrir o convite. Confira a internet e abra o '
          'link de novo.';
      _mudar(_Etapa.invalido);
    }
  }

  void _mudar(_Etapa etapa) {
    if (mounted) setState(() => _etapa = etapa);
  }

  Future<void> _entrar() async {
    setState(() => _entrando = true);
    try {
      await widget.api.entrarPeloConvite(widget.codigo);
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.remove(chaveDoConvitePendente);
      _mudar(_Etapa.dentro);
    } on ConviteNaoEncontrado catch (erro) {
      _aviso = erro.mensagem;
      _mudar(_Etapa.invalido);
    } on FalhaNaApi catch (falha) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(falha.mensagem)));
      }
    } finally {
      if (mounted) setState(() => _entrando = false);
    }
  }

  /// Sem conta: guarda o convite e leva para entrar ou criar a conta.
  Future<void> _entrarNaConta() async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString(chaveDoConvitePendente, widget.codigo);
    _abrirPainel();
  }

  void _abrirPainel() {
    if (!mounted) return;
    // Aberto pelo painel (convite guardado antes de entrar), só volta.
    final navegador = Navigator.of(context);
    if (navegador.canPop()) return navegador.pop();
    navegador.pushReplacement(MaterialPageRoute<void>(
        builder: (_) => AcessoDoArtista(api: widget.api)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: FundoTocaEssa(
          variante: VarianteFundoTocaEssa.bastidores,
          intensidade: IntensidadeFundoTocaEssa.imersiva,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(EspacoTocaEssa.grande),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _conteudo(context),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _conteudo(BuildContext context) => switch (_etapa) {
        _Etapa.carregando => const CircularProgressIndicator(),
        _Etapa.semConta => _Cartao(
            titulo: 'Convite para tocar',
            texto: 'Entre na sua conta de artista (ou crie uma) para ver a '
                'setlist e as cifras da noite.',
            botao: 'Entrar na conta de artista',
            aoTocar: _entrarNaConta,
          ),
        _Etapa.convite => _Cartao(
            titulo: _convite!.evento,
            texto: '${_convite!.dono} convidou você para tocar em '
                '${formatarData(_convite!.data)}. Você vai ver a setlist e as '
                'cifras desta noite.',
            botao: 'Entrar no evento',
            aoTocar: _entrando ? null : _entrar,
          ),
        _Etapa.dentro => _Cartao(
            titulo: 'Pronto!',
            texto: '${_convite!.evento} está nos Convites do seu painel.',
            botao: 'Abrir o painel',
            aoTocar: _abrirPainel,
          ),
        _Etapa.invalido => _Cartao(
            titulo: 'Convite para tocar',
            texto: _aviso,
            botao: 'Abrir o painel',
            aoTocar: _abrirPainel,
          ),
      };
}

class _Cartao extends StatelessWidget {
  const _Cartao({
    required this.titulo,
    required this.texto,
    required this.botao,
    required this.aoTocar,
  });

  final String titulo;
  final String texto;
  final String botao;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.music_note_rounded,
            size: 48, color: CoresTocaEssa.roxoClaro),
        const SizedBox(height: EspacoTocaEssa.medio),
        Text(titulo, textAlign: TextAlign.center, style: tema.headlineSmall),
        const SizedBox(height: EspacoTocaEssa.pequeno),
        Text(texto,
            textAlign: TextAlign.center,
            style: tema.bodyMedium
                ?.copyWith(color: CoresTocaEssa.textoSecundario)),
        const SizedBox(height: EspacoTocaEssa.grande),
        FilledButton(onPressed: aoTocar, child: Text(botao)),
      ],
    );
  }
}
