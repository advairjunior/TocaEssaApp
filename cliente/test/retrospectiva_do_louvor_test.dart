import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/estatisticas_da_apresentacao.dart';

const _estatisticas =
    '{"totalPedidos":0,"aguardando":0,"aceitos":0,"tocados":0,"recusados":0,'
    '"avaliados":0,"mediaAvaliacoes":null,"musicasMaisPedidas":[]}';

final _louvor = Apresentacao(
  id: '22222222-2222-2222-2222-222222222222',
  nome: 'Louvor de sábado',
  data: DateTime(2026, 10, 24),
  local: 'Casa da Bia',
  codigo: 'A1B2C3',
  perfilArtistico: const PerfilArtistico(
    id: '11111111-1111-1111-1111-111111111111',
    nomeArtistico: 'Advair',
  ),
  pedidosAbertos: false,
  status: StatusApresentacao.encerrada,
  tipo: TipoApresentacao.louvor,
  fotoRetrospectivaUrl: '/arquivos/foto.jpg',
);

void main() {
  testWidgets('o louvor encerrado mostra só a retrospectiva do louvor',
      (tester) async {
    final cliente = MockClient((_) async => http.Response(_estatisticas, 200));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EstatisticasDaApresentacaoTela(
          api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
          apresentacao: _louvor,
          incorporada: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Retrospectiva do louvor'), findsOneWidget);
    expect(find.text('Louvor de sábado'), findsOneWidget);
    expect(find.text('Casa da Bia · 24/10/2026'), findsOneWidget);
    expect(find.text('Compartilhar imagem'), findsOneWidget);
    expect(find.text('Copiar resumo em texto'), findsOneWidget);
    // Sem pedidos nem notas no louvor.
    expect(find.text('Retrospectiva do show'), findsNothing);
    expect(find.text('pedidos'), findsNothing);
    expect(find.text('Músicas mais pedidas'), findsNothing);
    expect(find.text('Ainda sem avaliações'), findsNothing);
  });

  test('o resumo em texto do louvor fica só com os dados principais', () {
    final texto = textoDaRetrospectiva(
        _louvor,
        EstatisticasDaApresentacao.deJson({
          'totalPedidos': 0,
          'aguardando': 0,
          'aceitos': 0,
          'tocados': 0,
          'recusados': 0,
          'avaliados': 0,
          'musicasMaisPedidas': [],
        }),
        const []);

    expect(texto,
        'Retrospectiva do louvor\nLouvor de sábado\nCasa da Bia · 24/10/2026\ncom Advair');
  });
}
