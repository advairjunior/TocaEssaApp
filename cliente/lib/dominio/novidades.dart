/// O que mudou no app, para o artista ver em Novidades. A cada atualização
/// com algo que a pessoa nota, entra uma linha no topo, no mesmo envio.
/// Correção técnica que ninguém percebe fica de fora.
enum TipoDeNovidade {
  novo('Novo'),
  melhoria('Melhoria'),
  correcao('Correção');

  const TipoDeNovidade(this.rotulo);

  final String rotulo;
}

class Novidade {
  const Novidade({
    required this.data,
    required this.tipo,
    required this.titulo,
    required this.texto,
  });

  final DateTime data;
  final TipoDeNovidade tipo;
  final String titulo;
  final String texto;
}

/// Da mais nova para a mais velha.
final novidadesDoApp = <Novidade>[
  Novidade(
    data: DateTime(2026, 10, 29),
    tipo: TipoDeNovidade.novo,
    titulo: 'Passar o comando da TV',
    texto: 'Em Letra na TV, passe a linha da TV para outra pessoa pelo QR: '
        'ela acompanha a letra no celular dela, sem conta, e você retoma '
        'quando quiser.',
  ),
  Novidade(
    data: DateTime(2026, 10, 29),
    tipo: TipoDeNovidade.novo,
    titulo: 'Músicos da noite',
    texto: 'No Mais da resenha ou do louvor, convide os amigos músicos por '
        'link. Eles veem a setlist e as suas cifras daquela noite, e só '
        'dela. O público continua entrando pelo código.',
  ),
  Novidade(
    data: DateTime(2026, 10, 29),
    tipo: TipoDeNovidade.novo,
    titulo: 'Letra na TV',
    texto: 'Abra tocaessaapp.onrender.com/tv na TV, conecte pelo código no '
        'Mais da resenha e a letra aparece deitada e grande, seguindo a seta '
        'da sua cifra. Entre as músicas, a TV mostra o A seguir, o QR e as '
        'fotos dos stories.',
  ),
  Novidade(
    data: DateTime(2026, 10, 29),
    tipo: TipoDeNovidade.melhoria,
    titulo: 'Tamanho da letra pelo controle da TV',
    texto: 'As setas para cima e para baixo do controle aumentam e diminuem '
        'a letra; a TV guarda o tamanho.',
  ),
  Novidade(
    data: DateTime(2026, 10, 29),
    tipo: TipoDeNovidade.melhoria,
    titulo: 'Rolagem lembra a velocidade',
    texto: 'Cada música guarda a velocidade da rolagem automática que você '
        'escolheu.',
  ),
  Novidade(
    data: DateTime(2026, 10, 29),
    tipo: TipoDeNovidade.correcao,
    titulo: 'Link da resenha e do louvor',
    texto: 'Quem abre o link não cai mais na tela inicial ao tocar em '
        'voltar.',
  ),
  Novidade(
    data: DateTime(2026, 10, 27),
    tipo: TipoDeNovidade.novo,
    titulo: 'Nota da galera no karaokê',
    texto: 'A galera dá estrelas na hora, o placar da noite aparece e sai a '
        'Voz da noite, com cartão para compartilhar.',
  ),
  Novidade(
    data: DateTime(2026, 10, 26),
    tipo: TipoDeNovidade.novo,
    titulo: 'Noite de karaokê',
    texto: 'Cole a playlist do YouTube, sorteie a ordem de quem canta e cada '
        'um começa e termina a sua vez pelo próprio celular.',
  ),
  Novidade(
    data: DateTime(2026, 10, 26),
    tipo: TipoDeNovidade.novo,
    titulo: 'Tocar sem show',
    texto: 'Toque e ensaie as músicas do acervo sem criar um show.',
  ),
  Novidade(
    data: DateTime(2026, 10, 26),
    tipo: TipoDeNovidade.novo,
    titulo: 'Retrospectiva do louvor',
    texto: 'Ao encerrar o louvor, o cartão traz a selfie, quem cantou e '
        'tocou, o lugar e a data.',
  ),
  Novidade(
    data: DateTime(2026, 10, 23),
    tipo: TipoDeNovidade.novo,
    titulo: 'Coral no louvor',
    texto: 'Marque (Coral) na letra e quem não está no microfone canta '
        'junto, com a entrada e a parada.',
  ),
  Novidade(
    data: DateTime(2026, 10, 21),
    tipo: TipoDeNovidade.novo,
    titulo: 'Compartilhar a cifra',
    texto: 'No leitor, mande o link de uma cifra colada: abre direto nela, '
        'sem conta.',
  ),
  Novidade(
    data: DateTime(2026, 10, 21),
    tipo: TipoDeNovidade.melhoria,
    titulo: 'Busca e repertórios',
    texto: 'Busca na setlist e nos hinos, e as músicas pedidas pelo público '
        'vão para um repertório.',
  ),
  Novidade(
    data: DateTime(2026, 10, 20),
    tipo: TipoDeNovidade.novo,
    titulo: 'Escala automática do louvor',
    texto: 'O app reveza quem canta cada parte, com cada pessoa na sua cor.',
  ),
  Novidade(
    data: DateTime(2026, 10, 17),
    tipo: TipoDeNovidade.melhoria,
    titulo: 'Editor de cifra em tela cheia',
    texto: 'Colar e corrigir a cifra sem quebra de linha, com conferência '
        'antes de salvar.',
  ),
  Novidade(
    data: DateTime(2026, 10, 15),
    tipo: TipoDeNovidade.novo,
    titulo: 'Stories do show',
    texto: 'O público grava pedaços do show e você vê tudo na galeria, no '
        'jeito das redes sociais.',
  ),
  Novidade(
    data: DateTime(2026, 10, 13),
    tipo: TipoDeNovidade.novo,
    titulo: 'Sem internet no show',
    texto: 'A setlist e as cifras ficam guardadas no aparelho e as tocadas '
        'sobem quando a internet voltar.',
  ),
];
