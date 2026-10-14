import 'instalacao_do_app_stub.dart'
    if (dart.library.js_interop) 'instalacao_do_app_web.dart';

/// O que o navegador diz sobre instalar o TocaEssa na tela do celular.
abstract interface class InstalacaoDoApp {
  /// Aberto pelo ícone na tela de início: não há o que instalar.
  bool get instalado;

  /// Chrome e Android oferecem a própria janela de instalação.
  bool get podePedirAoNavegador;

  /// No iPhone só se instala pelo Compartilhar do Safari.
  bool get iPhone;

  /// Abre a janela de instalação do navegador; verdadeiro se aceitou.
  Future<bool> pedir();
}

InstalacaoDoApp instalacaoDoNavegador() => criarInstalacaoDoNavegador();
