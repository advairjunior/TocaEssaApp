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
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (souEu) ...[
                              const SizedBox(width: 7),
                              const _Etiqueta(texto: 'Você'),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${participante.pedidos} pedidos · ${participante.pedidosTocados} tocados',
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CoresTocaEssa.superficie,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF4B3470)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  obrigatorio ? Icons.group_rounded : Icons.person_rounded,
                  color: CoresTocaEssa.roxoClaro,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    obrigatorio
                        ? 'Entre na resenha'
                        : 'Use seu Perfil do Público',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              !obrigatorio
                  ? 'Opcional: use sua conta e foto ou continue como convidado.'
                  : criandoConta
                      ? 'Crie seu Perfil do Público para guardar suas participações.'
                      : 'Use seu Perfil do Público e continue seu histórico entre amigos.',
              style: const TextStyle(color: CoresTocaEssa.textoSecundario),
            ),
            const SizedBox(height: 18),
            if (criandoConta) ...[
              TextField(
                controller: nome,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Seu nome',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: senha,
              obscureText: true,
              enableSuggestions: false,
              onSubmitted: (_) => autenticar(),
              decoration: const InputDecoration(
                labelText: 'Senha',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: autenticando ? null : autenticar,
              icon: Icon(criandoConta
                  ? Icons.person_add_alt_1_rounded
                  : Icons.login_rounded),
              label: Text(autenticando
                  ? 'Aguarde...'
                  : criandoConta
                      ? 'Criar perfil e entrar'
                      : 'Entrar'),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: autenticando ? null : alternarModo,
              child: Text(criandoConta
                  ? 'Já tenho um perfil'
                  : 'Criar meu Perfil do Público'),
            ),
            if (!obrigatorio) ...[
              const Divider(),
              TextButton(
                onPressed: autenticando ? null : continuarComoConvidado,
                child: const Text('Continuar como convidado'),
              ),
            ],
          ],
        ),
      );
}
