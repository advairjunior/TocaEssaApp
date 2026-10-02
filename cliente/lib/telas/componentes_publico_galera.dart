part of 'area_do_publico.dart';

class _CartaoPessoaDaResenha extends StatelessWidget {
  const _CartaoPessoaDaResenha({
    required this.participante,
    required this.souEu,
    required this.enderecoFoto,
  });

  final ParticipanteDaResenha participante;
  final bool souEu;
  final String? enderecoFoto;

  @override
  Widget build(BuildContext context) => Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: souEu ? CoresTocaEssa.roxoClaro : CoresTocaEssa.borda,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () =>
              abrirPerfilParticipante(context, participante, enderecoFoto),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    FotoPerfilArtistico(
                      enderecoFoto: enderecoFoto,
                      tamanho: 54,
                      iconeFallback: Icons.person_rounded,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  participante.nome,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              if (souEu) ...[
                                const SizedBox(width: 7),
                                const _Etiqueta(texto: 'Você'),
                              ],
                              if (participante.ehArtista) ...[
                                const SizedBox(width: 7),
                                const _Etiqueta(texto: 'Artista'),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            participante.ehArtista
                                ? 'Anfitrião da resenha'
                                : '${participante.pedidos} pedidos · ${participante.pedidosTocados} tocados',
                            style: const TextStyle(
                              color: CoresTocaEssa.textoSecundario,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (participante.mediaAvaliacoes != null)
                      Text(
                        '${participante.mediaAvaliacoes!.toStringAsFixed(1)} ★',
                        style: const TextStyle(
                          color: Color(0xFFFFC857),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                if (participante.musicasMaisPedidas.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Mais pedida: ${participante.musicasMaisPedidas.first.musica}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CoresTocaEssa.roxoClaro,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

class _AcessoPerfilPublico extends StatelessWidget {
  const _AcessoPerfilPublico({
    required this.obrigatorio,
    required this.criandoConta,
    required this.autenticando,
    required this.nome,
    required this.email,
    required this.senha,
    required this.alternarModo,
    required this.autenticar,
    this.continuarComoConvidado,
  });

  final bool obrigatorio;
  final bool criandoConta;
  final bool autenticando;
  final TextEditingController nome;
  final TextEditingController email;
  final TextEditingController senha;
  final VoidCallback alternarModo;
  final VoidCallback autenticar;
  final VoidCallback? continuarComoConvidado;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    const entreCampos = SizedBox(height: EspacoTocaEssa.base + 4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          obrigatorio ? 'Entre na resenha' : 'Seu perfil do público',
          style: texto.headlineSmall,
        ),
        const SizedBox(height: EspacoTocaEssa.mini),
        Text(
          !obrigatorio
              ? 'Opcional: guarde seus pedidos, sua foto e seu histórico.'
              : criandoConta
                  ? 'Crie seu perfil para guardar suas participações.'
                  : 'Entre com seu perfil e continue seu histórico entre amigos.',
          style:
              texto.bodyMedium?.copyWith(color: CoresTocaEssa.textoSecundario),
        ),
        const SizedBox(height: EspacoTocaEssa.grande),
        if (criandoConta) ...[
          CampoTexto(
            rotulo: 'Seu nome',
            controlador: nome,
            capitalizacao: TextCapitalization.words,
            acaoTeclado: TextInputAction.next,
          ),
          entreCampos,
        ],
        CampoTexto(
          rotulo: 'E-mail',
          controlador: email,
          dica: 'voce@exemplo.com',
          teclado: TextInputType.emailAddress,
          acaoTeclado: TextInputAction.next,
        ),
        entreCampos,
        CampoTexto(
          rotulo: 'Senha',
          controlador: senha,
          dica: criandoConta ? 'Pelo menos 6 caracteres' : null,
          oculto: true,
          aoEnviar: (_) => autenticar(),
        ),
        const SizedBox(height: EspacoTocaEssa.grande),
        FilledButton(
          onPressed: autenticando ? null : autenticar,
          child: Text(autenticando
              ? 'Aguarde...'
              : criandoConta
                  ? 'Criar perfil e entrar'
                  : 'Entrar'),
        ),
        const SizedBox(height: EspacoTocaEssa.pequeno),
        TextButton(
          onPressed: autenticando ? null : alternarModo,
          child: Text(criandoConta ? 'Já tenho um perfil' : 'Criar meu perfil'),
        ),
        if (!obrigatorio)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: CoresTocaEssa.textoSecundario,
            ),
            onPressed: autenticando ? null : continuarComoConvidado,
            child: const Text('Continuar como convidado'),
          ),
      ],
    );
  }
}
