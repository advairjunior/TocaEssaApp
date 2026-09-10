# Cifras do artista

## Objetivo

Permitir que o artista abra rapidamente uma cifra a partir de um pedido musical e reutilize a mesma escolha em apresentações futuras. A funcionalidade deve permanecer gratuita, preservar o estado da fila e não copiar letras ou acordes de terceiros para o TocaEssa.

## Escopo inicial

- Exibir `Abrir cifra` apenas em pedidos do tipo música.
- Usar música e artista do pedido para sugerir uma cifra e uma pesquisa externa.
- Permitir que o artista confirme a sugestão ou cole um link de outro site confiável.
- Salvar a associação no perfil geral da conta artística.
- Reutilizar a associação em qualquer apresentação da mesma conta.
- Permitir substituir ou remover uma associação.
- Abrir a cifra em outra aba, preservando fila, filtros, rolagem e apresentação atual.

Não fazem parte desta etapa: copiar ou renderizar cifras dentro do aplicativo, gerar acordes com IA, manter catálogo público de cifras, sincronizar listas do Cifra Club ou contratar uma API de busca.

## Experiência do artista

Cada cartão de pedido musical da fila apresenta a ação `Abrir cifra`.

Quando existe uma associação confirmada, a ação abre diretamente a URL salva. O menu do cartão oferece `Trocar cifra` para substituir ou remover o endereço.

Quando não existe associação, a ação abre uma janela com:

1. `Abrir sugestão`, quando for possível formar um endereço provável do Cifra Club;
2. `Pesquisar cifra`, que abre uma pesquisa preenchida com música, artista e a palavra `cifra`;
3. `Colar outro link`, que aceita uma URL informada pelo artista;
4. `Confirmar cifra`, que salva a sugestão ou o link informado.

A abertura de uma página externa não confirma automaticamente o resultado. O artista retorna ao TocaEssa e confirma a opção que verificou. Isso evita depender de comunicação entre sites diferentes e impede que um resultado incorreto seja memorizado sem consentimento.

## Identidade e correspondência

A associação pertence à conta artística autenticada. Sua chave lógica combina:

- nome normalizado da música;
- nome normalizado do artista do pedido.

A normalização remove espaços excedentes, diferenças entre maiúsculas e minúsculas, acentos e pontuação usada apenas para apresentação. Música e artista continuam sendo campos separados.

Quando o pedido não informa artista, a associação usa uma chave específica para artista ausente. Ela não deve ser aplicada automaticamente a pedidos futuros que informem um artista, mesmo que o título da música seja igual.

## Modelo de dados

Cada associação armazena:

- identificador;
- identificador da conta artística;
- título original da música;
- artista original, quando informado;
- título normalizado;
- artista normalizado;
- URL confirmada;
- fonte derivada do domínio da URL;
- data de criação;
- data da última alteração.

Deve existir no máximo uma associação para cada combinação de conta artística, título normalizado e artista normalizado. Salvar novamente a mesma combinação substitui a URL anterior.

## Backend e persistência

O servidor será responsável por normalizar as chaves e persistir as associações no mesmo armazenamento durável usado pelo restante da aplicação. As operações exigem autenticação artística e nunca aceitam o identificador da conta enviado pelo cliente.

Operações necessárias:

- consultar a cifra associada a uma música e artista;
- listar as associações do artista, preparando uma futura gestão pelo perfil geral;
- criar ou substituir uma associação;
- remover uma associação.

A resposta da consulta inclui a associação confirmada, quando existir, e os endereços externos sugeridos. Nesta primeira versão, a sugestão é determinística e não depende de uma API de IA.

## Sugestão e pesquisa

O serviço de sugestão transforma música e artista em segmentos compatíveis com endereços públicos do Cifra Club. Ele não baixa, extrai, replica nem valida o conteúdo da página.

Como um endereço construído pode não existir ou apontar para uma versão diferente, ele sempre é tratado como sugestão até a confirmação do artista.

A pesquisa alternativa abre uma busca web já preenchida e prioriza resultados do Cifra Club. O desenho permite substituir futuramente esse componente por uma API de pesquisa ou classificação com IA sem alterar as associações já salvas nem o fluxo da fila.

## Validação e segurança

- Aceitar somente URLs absolutas com protocolo `https` ou `http`.
- Recusar protocolos executáveis, URLs locais, endereços de loopback, credenciais embutidas e hosts inválidos.
- Limitar o tamanho dos campos e da URL.
- Não realizar requisições do servidor para URLs coladas pelo usuário; o servidor apenas valida e armazena o endereço.
- Abrir páginas externas com as proteções apropriadas para uma nova aba.
- Uma falha de consulta ou persistência mostra uma mensagem curta e nunca altera o pedido musical.

## Comportamento offline e falhas externas

Se a busca externa ou a página da cifra estiver indisponível, a fila continua utilizável. O artista pode tentar novamente, trocar o endereço ou remover a associação. Uma URL salva não é removida automaticamente por falha temporária.

## Estrutura no cliente

A integração será dividida em componentes pequenos:

- cliente de API para consultar e manter associações;
- modelo de cifra associada e resultado de sugestão;
- ação reutilizável `Abrir cifra` no cartão do pedido;
- janela responsável por sugestão, pesquisa, confirmação e link manual;
- serviço específico para abrir URL externa sem perder o estado atual.

Não será criada nesta etapa uma tela completa de repertório no perfil geral. Os dados já ficarão modelados para permitir essa evolução.

## Testes e critérios de aceitação

### Servidor

- associações são isoladas entre contas artísticas;
- uma associação é reutilizada em apresentações diferentes da mesma conta;
- acentos, caixa, pontuação e espaços não criam duplicatas;
- música sem artista não corresponde a música com artista informado;
- salvar novamente substitui a URL;
- remover elimina a correspondência;
- URLs perigosas ou inválidas são recusadas;
- operações sem autenticação artística são recusadas;
- o estado permanece após reiniciar o repositório persistente.

### Flutter

- o botão aparece em pedidos musicais e não aparece em alôs;
- cifra confirmada abre diretamente;
- ausência de cifra abre a janela de escolha;
- o artista consegue confirmar sugestão, colar, substituir e remover um link;
- falhas apresentam feedback sem modificar o pedido;
- abrir uma cifra preserva a apresentação, a fila, a posição de rolagem e os campos em edição.

## Evolução futura

Uma API de pesquisa ou IA poderá classificar candidatos e corrigir nomes digitados incorretamente. Ela deverá alimentar o mesmo resultado de sugestão e manter a confirmação humana antes de salvar. Uma seção `Minhas cifras` também poderá ser adicionada ao perfil geral para pesquisar, editar e remover associações fora da apresentação.
