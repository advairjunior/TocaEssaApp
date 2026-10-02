part of 'area_do_publico.dart';

/// Uma pessoa da resenha; tocar abre o perfil dela.
class _LinhaPessoaDaResenha extends StatelessWidget {
  const _LinhaPessoaDaResenha({
    required this.participante,
    required this.souEu,
    required this.enderecoFoto,
  });

  final ParticipanteDaResenha participante;
  final bool souEu;
  final String? enderecoFoto;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final secundario =
        texto.bodyMedium?.copyWith(color: CoresTocaEssa.textoSecundario);
    final marca = souEu
        ? 'Você'
        : participante.ehArtista
            ? 'Artista'
            : null;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () =>
            abrirPerfilParticipante(context, participante, enderecoFoto),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: EspacoTocaEssa.base,
            vertical: EspacoTocaEssa.medio,
          ),
          child: Row(
            children: [
              IgnorePointer(
                child: FotoPerfilArtistico(
                  enderecoFoto: enderecoFoto,
                  tamanho: 44,
                  iconeFallback: participante.ehArtista
                      ? Icons.mic_rounded
                      : Icons.person_rounded,
                ),
              ),
              const SizedBox(width: EspacoTocaEssa.medio),
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
                            style: texto.titleMedium,
                          ),
                        ),
                        if (marca != null) ...[
                          const SizedBox(width: EspacoTocaEssa.pequeno),
                          Text(
                            marca,
                            style: texto.labelMedium
                                ?.copyWith(color: CoresTocaEssa.roxoClaro),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      participante.ehArtista
                          ? 'Anfitrião da resenha'
                          : '${participante.pedidos} pedidos · '
                              '${participante.pedidosTocados} tocados',
                      style: secundario,
                    ),
                    if (participante.musicasMaisPedidas.isNotEmpty)
                      Text(
                        'Mais pedida: '
                        '${participante.musicasMaisPedidas.first.musica}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: texto.labelMedium
                            ?.copyWith(color: CoresTocaEssa.roxoClaro),
                      ),
                  ],
                ),
              ),
              if (participante.mediaAvaliacoes != null)
                Text(
                  '${participante.mediaAvaliacoes!.toStringAsFixed(1)} ★',
                  style: texto.labelLarge
                      ?.copyWith(color: const Color(0xFFFFC857)),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
