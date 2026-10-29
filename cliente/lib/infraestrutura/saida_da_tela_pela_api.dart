import '../dominio/tela_da_tv.dart';
import '../dominio/transmissor_da_letra.dart';
import 'api_toca_essa.dart';

/// A TV de verdade: o que o celular do dono mostra vai pelas rotas das telas.
class SaidaDaTelaPelaApi implements SaidaDaTela {
  const SaidaDaTelaPelaApi(this._api);

  final ApiTocaEssa _api;

  @override
  Future<void> mostrar(ConteudoParaTv conteudo) => _api.mostrarNaTv(conteudo);

  @override
  Future<void> irParaALinha(int linha) => _api.irParaALinhaNaTv(linha);

  @override
  Future<void> limpar() => _api.limparTv();
}
