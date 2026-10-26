# Noite de karaokê — desenho

Aprovado pelo proprietário em 2026-10-26, com a importação da playlist;
revisto no mesmo dia para o jeito real da noite. Uso: noites de karaokê na
casa do proprietário, de 10 a 15 pessoas, com TV, microfone, mesa de som e
caixa JBL. O vídeo de karaokê vai para a TV pelo **Transmitir** do YouTube
(o controle da TV é trabalhoso demais).

Princípio: o app não toca música nem mostra letra. Ele cuida do que dá
trabalho e do que deixa a noite divertida: a ordem de quem canta, achar o
vídeo com um toque, avisar a vez de cada um e a nota da galera na hora.

## Decisões do proprietário

- **O celular do proprietário não é o centro da noite.** Antes ele passava
  de mão em mão; agora cada um usa o próprio celular. Na vez, a pessoa abre
  o vídeo no YouTube do celular dela e toca em Transmitir (todos no Wi-Fi da
  casa; fora dele, o "Vincular com código da TV" do YouTube).
- O proprietário cria a noite pela conta de artista, sorteia a ordem e pode
  corrigir a fila; não precisa tocar em nada durante as músicas.
- Para participar é preciso ter **conta do público** (como na Resenha): a
  nota e a memória da noite ficam presas à pessoa.
- A nota aparece **na hora**, no celular de todo mundo, enquanto a pessoa
  canta.
- **Primeira versão comum:** sem limite de trocas na roleta e sem surpresa
  da música só na vez; isso entra depois, nas brincadeiras.

## Importar a playlist do YouTube (primeira etapa)

O proprietário já guarda os karaokês numa playlist do YouTube (pública ou
não listada; uma de teste tem mais de 100 vídeos).

- Num repertório: **Importar playlist do YouTube** → colar o link → lista
  para conferir, com "Todas" marcadas e o nome editável → confirmar.
- Cada música entra com o **link do vídeo** (coluna nova na música do
  repertório, criada só se faltar). **Atualizar da playlist** traz só os
  vídeos que ainda não estão no repertório (pelo vídeo, não pelo nome).
- A leitura é pela **API oficial do YouTube** (`playlistItems`, páginas de
  50), com a chave numa variável do Render (`YouTube__ChaveDaApi`), nunca
  no repositório. Ler a página do YouTube sem a API é frágil e não é usado.
  Vídeos privados ou apagados da playlist ficam de fora.
- **Título limpo, sem separar música e cantor:** os vídeos vêm ora "Cantor
  - Música", ora "Música - Cantor"; o app não adivinha. O título inteiro
  limpo vira o nome da música ("Thiaguinho - Falta Você"); a busca acha por
  qualquer pedaço. A limpeza tira emoji, "karaokê/karaoke", "version/versão",
  "playback", "instrumental", "oficial", "cover", "com letra", "(1 Tom
  Abaixo)", "| KaraFun" e afins, e o que vier entre parênteses só com isso;
  trecho todo em maiúsculas vira Título. Pot-pourri fica uma música só.
- Rota privada nova: ler a playlist e devolver a prévia limpa (título,
  link). Salvar usa o "adicionar várias músicas" que já existe, com o link.

## Tipo de evento

Novo valor `Karaoke` em `TipoApresentacao`, no fim do enum (os valores
existentes não mudam). No formulário: Pública, Resenha, Louvor, Karaokê
(descrição: "Ordem sorteada, vídeo no YouTube e nota da galera").

Ao criar: o **repertório da playlist** (de onde a galera escolhe) e o
**modo das músicas**:

- **Livre:** cada um escolhe a música no próprio celular.
- **Roleta:** o app sorteia a música da playlist para a pessoa.

Sem Pix, sem alô, sem horas contratadas. Vocabulário próprio: "música" e
"cantar"; a setlist não é usada.

## Ordem sorteada

- A galera entra pelo QR e aparece na lista "Na galera".
- **Sortear a ordem** (proprietário): embaralha quem está na galera e a
  ordem aparece para todos. **Sortear de novo** fica disponível até a
  primeira pessoa começar a cantar.
- A mesma ordem vale para todas as rodadas: quando o último canta, a fila
  volta ao primeiro (rodada 2, 3…).
- Quem chega depois do sorteio entra no fim da ordem e já canta na rodada
  que está correndo.
- Correções do proprietário (⋯ na pessoa): passar a vez (vai para depois
  do próximo), tirar da ordem (quem saiu da festa).

## Escolher a música

- **Livre:** a qualquer momento antes da vez, "Escolher minha música" abre a
  playlist com busca (a mesma busca sem acento do app). Fora da playlist:
  **Outra música**, com o nome e, se quiser, o link do YouTube; sem link, o
  "Tocar na TV" abre a busca do YouTube "nome karaokê". Dá para trocar até
  começar a cantar.
- **Roleta:** na vez (ou quando a pessoa é a próxima), o app sorteia uma
  música da playlist: **Conheço, vou cantar!** ou **Não conheço, sortear
  outra**, sem limite. Não sorteia música já cantada na noite nem uma que já
  apareceu para a pessoa.

## Celular de cada participante

Entra pelo código ou QR, com conta (entrar ou criar, como na Resenha).

```
 Karaokê de sexta                    12 na galera
 ┌─────────────────────────────────────┐
 │ CANTANDO · Ana                      │
 │ Evidências                          │
 │ Sua nota:  ☆ ☆ ☆ ☆ ☆    ★ 4,6 (8)   │
 └─────────────────────────────────────┘
 Você é o 3º · faltam 2 antes de você
 Sua música: Trem-Bala            [ Trocar ]
 Ordem da noite ›     Placar da noite ›
```

- **Você é o próximo:** aviso um antes, para escolher a música (ou girar a
  roleta) e se preparar.
- **Sua vez!** tela inteira com **Tocar na TV** (abre o vídeo no YouTube do
  celular, já no próprio toque, por causa do Safari) e a dica "toque em
  Transmitir". Tocar na TV é o que começa a vez: a nota da galera abre.
- **Nota na hora:** enquanto alguém canta, os outros dão de 1 a 5 estrelas;
  dá para mudar até a vez acabar. A média e quantos votaram aparecem na
  hora para todo mundo. Ninguém vota na própria vez.
- **A vez acaba** quando o próximo toca em Tocar na TV (ou quando quem
  cantou toca em Terminei): a nota fecha e entra no placar.
- **Placar da noite:** média de cada um (das músicas que cantou), quem
  cantou mais e a melhor nota de uma música.

## Celular do proprietário

Participa como qualquer um (canta e vota) e tem, a mais, a tela da noite:
a galera, Sortear a ordem / Sortear de novo, as correções da ordem e
Encerrar a noite. Nada disso é preciso durante as músicas.

## Fim da noite

- Encerrar mostra o placar final para todos com a **Voz da noite** (maior
  média, com pelo menos 3 votos por música).
- A noite entra em **Meus encontros** de cada participante, com o cartão
  compartilhável no jeito do que já existe ("cantei 2 músicas · nota 4,6 ·
  Voz da noite"), selfie opcional.

## O que muda no servidor (resumo para aprovar)

- `TipoApresentacao.Karaoke` (fim do enum), com o repertório da playlist e
  o modo (Livre/Roleta) na apresentação (colunas novas, criadas só se
  faltarem).
- Ordem da noite: posição sorteada de cada participante (coluna nova na
  participação); sortear de novo só antes da primeira vez.
- Vez de cantar: participante, música (da playlist ou outra, com o link),
  rodada, início e fim. Começa no Tocar na TV de quem é a vez.
- Roleta: sorteio no servidor, sem repetir as cantadas na noite nem as já
  mostradas à pessoa.
- Nota durante a vez: vale para a vez em andamento, nunca para a própria.
  A média ao vivo sai no tempo real que já existe.
- Rotas públicas novas (precisam de autorização): entrar na galera, ordem e
  vez atual, escolher ou sortear a música, começar e terminar a vez, nota
  na vez, placar da noite.

## Fica para depois (brincadeiras)

Roleta com limite de trocas (a terceira é obrigatória) e com a música
revelada só na vez; "Me surpreenda" no modo Livre; duetos ("cantar com a
Bia"); desafios; prêmios votados ("Mais corajoso", "Mais animado"); tema
por noite.
