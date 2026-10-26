import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/rastros_locais_do_publico.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_formulario.dart';

/// Entra (ou cria) a conta do público para o evento ficar em Meus
/// encontros. Responde verdadeiro quando a conta ficou guardada no aparelho.
Future<bool> entrarParaGuardar(BuildContext context, ApiTocaEssa api,
        {String titulo = 'Guardar na conta',
        String explicacao = _explicacaoDoLouvor}) async =>
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) =>
          _EntrarParaGuardar(api: api, titulo: titulo, explicacao: explicacao),
    )) ??
    false;

const _explicacaoDoLouvor = 'Com a conta, o louvor fica em Meus encontros, com '
    'quem você foi e os hinos em que cantou.';

class _EntrarParaGuardar extends StatefulWidget {
  const _EntrarParaGuardar(
      {required this.api, required this.titulo, required this.explicacao});
  final ApiTocaEssa api;
  final String titulo;
  final String explicacao;

  @override
  State<_EntrarParaGuardar> createState() => _EntrarParaGuardarState();
}

class _EntrarParaGuardarState extends State<_EntrarParaGuardar> {
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _criando = false;
  bool _ocupado = false;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_email.text.contains('@') ||
        _senha.text.length < 6 ||
        (_criando && _nome.text.trim().length < 2)) {
      mostrarErro(context,
          'Informe um e-mail válido, senha com pelo menos 6 caracteres e seu nome no cadastro.');
      return;
    }
    setState(() => _ocupado = true);
    try {
      final sessao = _criando
          ? await widget.api.criarContaPublica(
              _nome.text.trim(), _email.text.trim(), _senha.text)
          : await widget.api
              .entrarContaPublica(_email.text.trim(), _senha.text);
      final preferencias = await SharedPreferences.getInstance();
      // A conta nova não herda pedidos nem nome de quem usou o aparelho.
      await limparRastrosLocaisDoPublico(preferencias);
      await preferencias.setString('token_do_publico', sessao.token);
      if (mounted) Navigator.of(context).pop(true);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    const entreCampos = SizedBox(height: EspacoTocaEssa.base);
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: ConteudoMobile(
        filho: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.explicacao,
              style: texto.bodyMedium
                  ?.copyWith(color: CoresTocaEssa.textoSecundario),
            ),
            const SizedBox(height: EspacoTocaEssa.grande),
            if (_criando) ...[
              CampoTexto(
                rotulo: 'Seu nome',
                controlador: _nome,
                capitalizacao: TextCapitalization.words,
                acaoTeclado: TextInputAction.next,
              ),
              entreCampos,
            ],
            CampoTexto(
              rotulo: 'E-mail',
              controlador: _email,
              dica: 'voce@exemplo.com',
              teclado: TextInputType.emailAddress,
              acaoTeclado: TextInputAction.next,
            ),
            entreCampos,
            CampoTexto(
              rotulo: 'Senha',
              controlador: _senha,
              oculto: true,
              aoEnviar: (_) => _entrar(),
            ),
            const SizedBox(height: EspacoTocaEssa.grande),
            FilledButton(
              onPressed: _ocupado ? null : _entrar,
              child:
                  Text(_criando ? 'Criar conta e guardar' : 'Entrar e guardar'),
            ),
            const SizedBox(height: EspacoTocaEssa.pequeno),
            TextButton(
              onPressed:
                  _ocupado ? null : () => setState(() => _criando = !_criando),
              child: Text(_criando
                  ? 'Já tenho conta: entrar'
                  : 'Não tenho conta: criar agora'),
            ),
          ],
        ),
      ),
    );
  }
}
