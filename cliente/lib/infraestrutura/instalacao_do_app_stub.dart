import 'instalacao_do_app.dart';

/// Fora da Web o app já está no aparelho: não há o que instalar.
InstalacaoDoApp criarInstalacaoDoNavegador() => const _JaInstalado();

class _JaInstalado implements InstalacaoDoApp {
  const _JaInstalado();

  @override
  bool get instalado => true;
  @override
  bool get podePedirAoNavegador => false;
  @override
  bool get iPhone => false;
  @override
  Future<bool> pedir() async => false;
}
