part of 'painel_do_artista.dart';

class _CartaoImprimivel extends StatelessWidget {
  const _CartaoImprimivel({
    required this.apresentacao,
    required this.linkPublico,
    this.enderecoFoto,
  });

  final Apresentacao apresentacao;
  final String linkPublico;
  final String? enderecoFoto;

  static const _largura = 360.0;
  static const _altura = 500.0;
  static const _fundoTopo = Color(0xFF1B0D40);
  static const _fundoBase = Color(0xFF0B080F);
  static const _roxo = Color(0xFF784DFF);
  static const _roxoClaro = Color(0xFFB781FF);
  static const _branco = Colors.white;
  static const _cinza = Color(0xFFC8C2D0);
  static const _cinzaSutil = Color(0xFF5A4F6F);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: _largura,
        height: _altura,
        child: Container(
          width: _largura,
          height: _altura,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_fundoTopo, Color(0xFF0F0820), _fundoBase],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 24),
                // CTA principal
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.music_note_rounded,
                          color: _roxoClaro, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'PEÇA SUA MÚSICA',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: _branco,
                          letterSpacing: 1.8,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.music_note_rounded,
                          color: _roxoClaro, size: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  apresentacao.nome,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: _cinza,
                  ),
                ),
                const SizedBox(height: 16),
                // QR Code
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _branco,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55784DFF),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: linkPublico,
                    size: 208,
                    backgroundColor: _branco,
                    eyeStyle: const QrEyeStyle(color: _roxo),
                    dataModuleStyle: const QrDataModuleStyle(color: _fundoTopo),
                  ),
                ),
                const SizedBox(height: 16),
                // Artista
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _roxoClaro, width: 2),
                        color: const Color(0xFF2D175C),
                      ),
                      child: ClipOval(
                        child: enderecoFoto != null
                            ? Image.network(
                                enderecoFoto!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.mic_rounded,
                                  color: _roxoClaro,
                                  size: 24,
                                ),
                              )
                            : const Icon(Icons.mic_rounded,
                                color: _roxoClaro, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Flexível: nome e bio longos encolhem com reticências
                    // em vez de vazar pela borda do cartão impresso.
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            apresentacao.perfilArtistico.nomeArtistico,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _branco,
                            ),
                          ),
                          if (apresentacao.perfilArtistico.bio?.isNotEmpty ==
                              true)
                            Text(
                              apresentacao.perfilArtistico.bio!,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: _cinza,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Código como fallback
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                  decoration: BoxDecoration(
                    color: _roxo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _roxo.withValues(alpha: 0.28), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Código:',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: _cinza,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        apresentacao.codigo,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _roxoClaro,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Rodapé
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_note_rounded,
                        size: 11, color: _cinzaSutil),
                    SizedBox(width: 4),
                    Text(
                      'TocaEssa',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: _cinzaSutil,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      );
}
