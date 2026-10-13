import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('página do app nasce com o fundo escuro enquanto o Flutter carrega',
      () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('background-color: #0B080F'));
  });
}
