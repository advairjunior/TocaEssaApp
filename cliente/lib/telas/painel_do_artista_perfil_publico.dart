part of 'painel_do_artista.dart';

extension _PerfilPublicoEApoioDoArtista on _PainelDoArtistaState {
  Widget _construirPerfilPublicoEApoio() => Container(
        padding: const EdgeInsets.all(18),
        decoration: _decoracaoPainel(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: CoresTocaEssa.roxo.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.public_rounded,
                      color: CoresTocaEssa.roxoClaro),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Perfil público e apoio',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600)),
                      Text('Contatos para o público e contribuições via Pix',
                          style: TextStyle(
                              color: CoresTocaEssa.textoSecundario,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _instagram,
              decoration: const InputDecoration(
                labelText: 'Instagram',
                hintText: '@seuperfil',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exibir Instagram ao público'),
              value: _exibirInstagram,
              onChanged: (valor) =>
                  _mudarEstado(() => _exibirInstagram = valor),
            ),
            TextField(
              controller: _whatsapp,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp profissional',
                hintText: '5511999999999',
                prefixIcon: Icon(Icons.chat_outlined),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exibir WhatsApp ao público'),
              value: _exibirWhatsapp,
              onChanged: (valor) => _mudarEstado(() => _exibirWhatsapp = valor),
            ),
            const Divider(height: 28),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary:
                  const Icon(Icons.pix_rounded, color: CoresTocaEssa.roxoClaro),
              title: const Text('Aceitar apoio por Pix'),
              subtitle: const Text(
                'Contribuição voluntária, sem confirmação automática.',
                style: TextStyle(color: CoresTocaEssa.textoSecundario),
              ),
              value: _pixAtivo,
              onChanged: (valor) => _mudarEstado(() => _pixAtivo = valor),
            ),
            if (_pixAtivo) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _pixChave,
                decoration: const InputDecoration(
                  labelText: 'Chave Pix',
                  prefixIcon: Icon(Icons.key_rounded),
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Prefira uma chave aleatória',
                style: TextStyle(
                    color: CoresTocaEssa.textoSecundario, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pixNomeBeneficiario,
                maxLength: 25,
                decoration: const InputDecoration(
                  labelText: 'Nome do beneficiário',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pixCidadeBeneficiario,
                maxLength: 15,
                decoration: const InputDecoration(
                  labelText: 'Cidade do beneficiário',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pixMensagem,
                maxLength: 72,
                decoration: const InputDecoration(
                  labelText: 'Mensagem de agradecimento',
                  prefixIcon: Icon(Icons.favorite_border_rounded),
                ),
              ),
            ],
          ],
        ),
      );
}
