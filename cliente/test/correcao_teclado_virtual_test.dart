import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/infraestrutura/correcao_teclado_virtual.dart';

const _viewportDoFlutter =
    'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';

class _JanelaFalsa implements JanelaDoNavegador {
  _JanelaFalsa({
    this.conteudoViewport = _viewportDoFlutter,
    this.deslocamentoVisivel = 0,
    this.escalaVisivel = 1,
  });

  @override
  String? conteudoViewport;
  @override
  double deslocamentoVisivel;
  @override
  double escalaVisivel;
  int rolagensParaOTopo = 0;

  @override
  void rolarParaOTopo() {
    rolagensParaOTopo++;
    deslocamentoVisivel = 0;
  }
}

void main() {
  group('ajustarViewport', () {
    test('pede ao navegador para encolher o conteúdo com o teclado', () {
      final janela = _JanelaFalsa();

      CorrecaoTecladoVirtual(janela).ajustarViewport();

      expect(janela.conteudoViewport,
          '$_viewportDoFlutter, interactive-widget=resizes-content');
    });

    test('não duplica a configuração já aplicada', () {
      final janela = _JanelaFalsa();
      final correcao = CorrecaoTecladoVirtual(janela);

      correcao.ajustarViewport();
      correcao.ajustarViewport();

      expect(
          'interactive-widget'.allMatches(janela.conteudoViewport!).length, 1);
    });

    test('não cria a configuração quando não há tag viewport', () {
      final janela = _JanelaFalsa(conteudoViewport: null);

      CorrecaoTecladoVirtual(janela).ajustarViewport();

      expect(janela.conteudoViewport, isNull);
    });
  });

  group('desfazerDeslocamento', () {
    test('devolve a página ao topo quando o navegador a empurrou', () {
      final janela = _JanelaFalsa(deslocamentoVisivel: 180);

      CorrecaoTecladoVirtual(janela).desfazerDeslocamento();

      expect(janela.rolagensParaOTopo, 1);
    });

    test('não faz nada quando a página já está no topo', () {
      final janela = _JanelaFalsa();

      CorrecaoTecladoVirtual(janela).desfazerDeslocamento();

      expect(janela.rolagensParaOTopo, 0);
    });

    test('respeita o zoom de pinça do usuário', () {
      final janela = _JanelaFalsa(deslocamentoVisivel: 180, escalaVisivel: 1.6);

      CorrecaoTecladoVirtual(janela).desfazerDeslocamento();

      expect(janela.rolagensParaOTopo, 0);
    });
  });
}
