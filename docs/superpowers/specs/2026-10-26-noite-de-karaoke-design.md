# Noite de karaokê — desenho

Aprovado pelo proprietário em 2026-10-26, com a importação da playlist. Uso: noites
de karaokê na casa do proprietário, de 10 a 15 pessoas, com TV, microfone,
mesa de som e caixa JBL. O vídeo de karaokê sai do YouTube do celular do
proprietário, espelhado na TV (o controle da TV é trabalhoso demais).

Princípio: o app não toca música nem mostra letra. Ele cuida do que dá
trabalho e do que deixa a noite divertida: a fila justa, achar o vídeo com
um toque, avisar a vez de cada um e a nota da galera na hora.

## Decisões do proprietário

- Quem controla o YouTube é sempre o proprietário, no celular dele, pela
  conta de artista que cria o evento.
- Para participar é preciso ter **conta do público** (como na Resenha): a
  nota e a memória da noite ficam presas à pessoa.
- A nota aparece **na hora**, no celular de todo mundo, enquanto a pessoa
  canta.

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
(descrição: "Fila de quem canta, vídeo no YouTube e nota da galera").

Sem Pix, sem alô, sem horas contratadas. Vocabulário próprio: "música" e
"cantar"; a setlist não é usada (a noite é feita dos pedidos).

## Celular do proprietário (quem controla)

```
 Karaokê de sexta                    12 na galera
 ─────────────────────────────────────────────────
 AGORA · Ana                          ★ 4,6 (8)
 Evidências · Chitãozinho & Xororó
 [ ▶ Abrir no YouTube ]   [ Terminou ✓ ]
 ─────────────────────────────────────────────────
 PRÓXIMO · Caio
 Trem-Bala · Ana Vilela
 ─────────────────────────────────────────────────
 Rodada 1 · faltam 4      Rodada 2 · 3 pedidos
 Bia  · Exagerado                         ⋯
 Davi · Tempo Perdido                     ⋯
```

- **▶ Abrir no YouTube:** abre o vídeo guardado para a música; sem vídeo
  guardado, abre a busca do YouTube "título cantor karaokê". O proprietário
  escolhe o vídeo e manda para a TV como já faz hoje.
- **Guardar o vídeo:** de volta ao app, "Colar link do vídeo" (como o colar
  da cifra) guarda o link na conta do artista para aquela música. Na próxima
  noite, é um toque. Fica no acervo da conta, não no evento.
- **Terminou ✓:** encerra a vez (a música vira tocada, a nota fecha) e o
  próximo passa a Agora. Desfazer por alguns segundos, como no Tocar.
- **⋯ em cada pedido:** Pular a vez (vai para depois do próximo), Remover.
- Abrir no YouTube no iPhone precisa abrir a aba/app no próprio toque, antes
  de qualquer espera (lição do Safari já registrada).

## Celular de cada participante

Entra pelo código ou QR, com conta (entrar ou criar, como na Resenha).

```
 Karaokê de sexta
 ┌─────────────────────────────────────┐
 │ AGORA · Ana                         │
 │ Evidências                          │
 │ Sua nota:  ☆ ☆ ☆ ☆ ☆    ★ 4,6 (8)   │
 └─────────────────────────────────────┘
 Você é o 3º · faltam 2 antes de você
 [ + Quero cantar ]
 Minhas músicas: Trem-Bala (rodada 1) · Anunciação (rodada 2)
 Placar da noite ›
```

- **Quero cantar:** título e cantor (busca no acervo do proprietário ajuda
  a achar a música já com vídeo guardado). Pode pedir mais de uma.
- **Sua vez:** na vez, a tela inteira diz "Sua vez! Pega o microfone" (e o
  telefone vibra, onde o navegador deixa). Um antes: "Você é o próximo".
- **Nota na hora:** enquanto alguém canta, os outros dão de 1 a 5 estrelas;
  dá para mudar até o Terminou. A média e quantos votaram aparecem na hora
  para todo mundo. Ninguém vota na própria vez.
- **Placar da noite:** média de cada um (das músicas que cantou), quem
  cantou mais e a melhor nota de uma música.

## Fila por rodadas

- Todo pedido entra direto na fila (sem o aceitar do show).
- A rodada de um pedido é a ordem dele entre os pedidos da mesma pessoa: o
  primeiro pedido de cada um é da rodada 1, o segundo da rodada 2…
- A fila anda por rodada; dentro da rodada, por ordem de chegada. Quem chega
  tarde entra no fim da rodada que está correndo, não espera todo mundo da
  rodada seguinte.
- Pular a vez troca o pedido com o seguinte; o proprietário pode remover.

## Fim da noite

- Encerrar mostra o placar final para todos com a **Voz da noite** (maior
  média, com pelo menos 3 votos por música).
- A noite entra em **Meus encontros** de cada participante, com o cartão
  compartilhável no jeito do que já existe ("cantei 2 músicas · nota 4,6 ·
  Voz da noite"), selfie opcional.

## O que muda no servidor (resumo para aprovar)

- `TipoApresentacao.Karaoke` (fim do enum).
- Pedido em Karaokê: exige conta, entra direto na fila, sem tom/recado/alô.
- Ordem da fila por rodadas (calculada, sem coluna nova).
- Nota durante a vez: hoje a avaliação só vale para música já tocada; no
  Karaokê passa a valer também para a música tocando agora, nunca para a
  própria. A média ao vivo sai no tempo real que já existe.
- Vídeo da música: o link fica na música do repertório (o acervo é da conta
  do artista); o pedido acha o vídeo pela mesma música do acervo. Colar o
  link à mão também grava lá.
- Rotas públicas novas ou alteradas (precisam de autorização): fila do
  karaokê com rodada e posição, nota na vez, placar da noite.

## Fica para depois

Duetos ("cantar com a Bia"), roleta de quem canta ou da música, desafios,
prêmios votados ("Mais corajoso", "Mais animado"), tema por noite.
