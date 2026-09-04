part of 'painel_do_artista.dart';

class _CodigoDaApresentacao extends StatelessWidget {
  const _CodigoDaApresentacao({
    required this.apresentacao,
    required this.linkPublico,
  });

  final Apresentacao apresentacao;
  final String linkPublico;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Código da Apresentação')),
        body: ConteudoMobile(
          filho: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: CoresTocaEssa.roxo.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CoresTocaEssa.roxoClaro,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 52,
                  color: CoresTocaEssa.roxoClaro,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Apresentação criada!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Compartilhe o código ou o QR Code com o público.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                apresentacao.tipo.rotulo,
                style: const TextStyle(
                  color: CoresTocaEssa.roxoClaro,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 214,
                height: 214,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: linkPublico,
                  size: 190,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
                ),
              ),
              const SizedBox(height: 20),
              Text('Código público',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(
                apresentacao.codigo,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: CoresTocaEssa.roxoClaro,
                      letterSpacing: 3,
                    ),
              ),
              const SizedBox(height: 16),
              SelectableText(linkPublico, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: linkPublico));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copiado.')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copiar link'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Concluir'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
}
