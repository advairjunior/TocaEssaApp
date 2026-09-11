# Sistema de fundos do TocaEssaApp

## Objetivo

Criar uma identidade visual imersiva e coerente para o TocaEssaApp sem transformar cada tela em um papel de parede diferente. O sistema deve transmitir a atmosfera de uma apresentação musical, preservar a leitura e manter o carregamento leve em celulares e navegadores.

## Direção visual

O aplicativo usará três famílias de fundo, todas construídas sobre a paleta escura, violeta e magenta já existente. A intensidade da imagem dependerá da responsabilidade da tela: entradas podem ser imersivas; telas operacionais devem privilegiar dados e ações.

### Palco

Fotografia ampla de um palco intimista, com luzes violetas, instrumentos nas laterais e público em silhueta. O centro permanece livre para a marca e os formulários.

Usos:

- tela inicial;
- entrada e criação de conta do público;
- login e criação de conta do artista.

### Bastidores

Imagem de instrumentos, microfone, cabos e iluminação de palco, com aparência profissional e sem pessoas reconhecíveis.

Usos:

- painel geral do artista;
- criação e edição de apresentação;
- apresentações agendadas e histórico.

Na fila e nas estatísticas do artista, essa família aparece apenas no cabeçalho ou na área superior. Listas extensas continuam sobre a superfície escura do aplicativo.

### Atmosfera

Composição abstrata de luzes desfocadas, fumaça suave e partículas, sem objetos que disputem atenção com o conteúdo.

Usos:

- área do público;
- fila pública;
- galera;
- perfis;
- histórico de resenhas.

## Componente compartilhado

Será criado um componente `FundoTocaEssa` com variantes `palco`, `bastidores` e `atmosfera`. Ele receberá o conteúdo da tela e uma intensidade visual, evitando que cada página implemente imagens, sobreposições e responsividade separadamente.

Responsabilidades:

- selecionar o recurso gráfico correspondente;
- usar enquadramento diferente em celular e desktop;
- aplicar gradiente de contraste adequado ao tipo de conteúdo;
- preservar um gradiente da marca como fallback;
- permitir que somente o cabeçalho use imagem em telas operacionais;
- respeitar áreas seguras e rolagem existentes.

O componente não conhecerá regras de negócio nem navegação. Cada tela apenas escolherá a variante e o nível de intensidade.

## Distribuição e legibilidade

- Formulários e cartões permanecem sobre superfícies escuras com borda definida.
- Textos nunca serão posicionados diretamente sobre áreas claras sem gradiente de contraste.
- Telas com filas, estatísticas ou muitas informações usarão a imagem somente como ambientação discreta.
- Retrospectivas continuarão usando a foto real da resenha como protagonista e não receberão um fundo temático concorrente.
- Em telas estreitas, o ponto focal da imagem será deslocado para mostrar elementos do palco sem esconder o conteúdo central.

## Recursos e desempenho

Serão mantidas somente três imagens finais, sem texto, logotipo, marcas ou rostos reconhecíveis. Os arquivos serão otimizados para web antes da inclusão no aplicativo. O objetivo é evitar múltiplas fotografias por página e limitar o impacto no carregamento inicial.

O fundo da tela inicial poderá ser carregado imediatamente. As demais famílias serão carregadas quando suas áreas forem abertas, aproveitando o cache de recursos do Flutter.

## Estados e falhas

Se um recurso gráfico não puder ser carregado, a tela continuará funcional usando o gradiente escuro da marca. Nenhuma mensagem de erro será exibida ao usuário, pois o fundo é decorativo e não deve bloquear o fluxo.

## Validação

- teste de widget para cada variante do componente;
- verificação de que o fallback mantém a tela utilizável;
- análise estática e suíte Flutter completas;
- compilação web;
- inspeção visual em largura de celular e desktop, conferindo contraste, corte e rolagem.

## Fora do escopo

- fundos personalizados pelo usuário;
- animações em vídeo;
- download remoto de imagens;
- troca automática de tema;
- alteração das fotografias das retrospectivas.
