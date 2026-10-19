# Louvor com revezamento — desenho

Aprovado pelo proprietário em 2026-10-19. Primeiro uso: encontro de hinos
(hinário CCB) no sábado, 2026-10-24, na casa de uma amiga. Só quem participa
usa o app: quem toca, quem canta e quem faz os dois, cada um no seu telefone.

Princípio: o proprietário separa os hinos e os nomes; o app escala quem canta
cada estrofe, para ninguém cantar mais que ninguém, e cada um acompanha a
letra no próprio telefone.

## Decisões do proprietário

- O app escala as estrofes; o proprietário corrige qualquer parte à mão.
- Refrão (ou coro) e a última estrofe de cada hino são de **Todos**.
- Homens e mulheres se misturam nas estrofes; cada hino tem **um tom só**, do
  começo ao fim. O app não precisa saber a voz de ninguém.
- Quem não canta no microfone (o "coral") não é cadastrado: é o **Todos**.
- Quem toca acompanha pela letra, com o tom no topo.
- Só o proprietário avança o hino.
- Rota pública nova, só de leitura, pelo código: autorizada em 2026-10-19.

## Tipo de evento

Novo valor `Louvor` em `TipoApresentacao`, acrescentado no fim do enum (os
valores existentes não mudam). No formulário da apresentação: Pública,
Resenha, Louvor.

Num evento Louvor, quem entra pelo código vê o **roteiro** no lugar de pedir
música e fila. Pedidos, nota, alô e Pix não aparecem.

## Preparo (conta do proprietário)

```
 Louvor de sábado                         Cantores ✎
 João 3 · Ana 3 · Pedro 2 · Bia 2
 ─────────────────────────────────────────────────────
 15 · Por Cristo, resgatado     Sol    João · Ana
 22 · …                         Lá     Pedro · Bia
 ⚠ 31 · …                       —      sem letra
```

- **Hinos:** a setlist de sempre. O título leva o número ("15 · Por Cristo,
  resgatado") e o campo tom já existente é o tom do hino. Nada novo aqui.
- **Letra:** colada como a cifra de hoje (`CifrasEmTexto`, mesmo fluxo de
  Colar). Aviso "N hinos sem letra · Colar", como o das cifras.
- **Cantores:** lista de nomes do evento, em ordem; editar e reordenar.
- **Placar** no topo: estrofes de cada um.
- Tocar no hino abre as partes:

```
 15 · Por Cristo, resgatado · Sol
 ─────────────────────────────────────
 Estrofe 1   Cristo Jesus, o santo…      João  ›
 Refrão      Por Cristo, resgatado…      Todos ›
 Estrofe 2   Preso estava na iniqu…      Ana   ›
 Refrão      (repete)                    Todos ›
 Estrofe 3   Tem minha alma grande…      Todos ›
 Refrão      (repete)                    Todos ›
```

- Tocar numa parte: escolher um ou mais nomes, **Todos** ou **Automático**
  (devolve a parte à escala). Escolha à mão fica marcada com um ponto.
- A escala se refaz sozinha a cada mudança (cantores, hinos, ordem, letra),
  mantendo o que foi escolhido à mão. Sem botão de refazer.
- A separação errada se corrige na própria letra: uma linha em branco sempre
  começa uma parte nova.

## Separar a letra em partes

Regras, na ordem (sem acento nem maiúscula nos marcadores):

1. Linha `Refrão:` ou `Coro:` começa o refrão; o marcador não aparece.
2. Linha `(Refrão)` ou `(Coro)` repete o refrão com o texto inteiro.
3. Linha em branco sempre separa partes.
4. Sem linha em branco: o tamanho da estrofe é o número de linhas antes do
   primeiro `Refrão:`. Entre `Refrão:` e o próximo `(Refrão)`, as últimas
   linhas desse tamanho são a estrofe seguinte e o resto é o refrão. Sem
   nenhum `(Refrão)` depois, o texto após o refrão é cortado em estrofes
   desse tamanho.
5. Hino com refrão é sempre cantado estrofe + refrão (confirmado pelo
   proprietário): toda estrofe é seguida do refrão, mesmo que a letra colada
   não marque `(Refrão)` depois dela.
6. Texto que sobra sem marcador e sem linha em branco fica numa parte só.

O hino de exemplo (3 estrofes de 4 linhas, refrão de 4) vira: estrofe 1,
refrão, estrofe 2, refrão, estrofe 3, refrão.

O Hinário 5 não vem embutido: os sites de letras pesquisados bloqueiam acesso
automático ou não trazem o texto, e o proprietário cola os hinos que separar.

## Escala

Feita no servidor, função pura e determinística, sobre os hinos na ordem da
setlist:

1. Refrão e última estrofe de cada hino: **Todos** (hino de uma estrofe só
   fica todo com Todos).
2. Partes escolhidas à mão ficam como estão e contam no placar.
3. Cada estrofe restante vai para o cantor com **menos estrofes** até ali;
   empate: quem está há mais tempo sem cantar; depois, a ordem da lista.
4. Ninguém canta duas estrofes seguidas se houver outro cantor disponível.
5. Duplas só à mão.

Sem cantores cadastrados, todas as partes são Todos.

## Roteiro (cada telefone, pelo código)

```
 Quem é você?   [João] [Ana] [Pedro] [Bia] [Só acompanhar]
```

Escolha guardada no aparelho (troca no topo). Depois:

```
 Hino 15 · Sol                      ● agora
 Você canta 1 estrofe neste hino
 ─────────────────────────────────────
 JOÃO
   Cristo Jesus, o santo Cordeiro …
 TODOS
   Por Cristo, resgatado …
 ANA · sua vez
   Preso estava na iniquidade …
 ─────────────────────────────────────
 Depois: 22 · …  (Lá)
```

- Abre no hino atual e acompanha quando o proprietário avança (tempo real que
  já existe, com a atualização periódica como reserva).
- Lista dos hinos com número, tom e "você canta 2" para navegar à vontade;
  voltar ao atual com um toque.
- Letra grande, tela acesa (`tela_acesa_web.dart`), nome de quem canta acima
  de cada parte; as partes da pessoa escolhida em destaque.
- Músicos usam a mesma tela (escolhem "Só acompanhar" ou o próprio nome).

## Avançar o hino

O proprietário usa o Tocar que já existe (setlist, barra Próxima e leitor). O
"agora" do roteiro é o último hino tocado na ordem da setlist. Nenhum
controle novo.

## Dados

Duas colunas novas em `Apresentacoes`, no mesmo padrão de `PedidosASeguir`,
acrescentadas só se não existirem (SQLite e PostgreSQL):

- `CantoresDoLouvor` — nomes em ordem, em JSON.
- `EscolhasDoLouvor` — partes escolhidas à mão (`ItemId`, `Indice`,
  `Cantores`; vazio = Todos), em JSON. Parte que deixa de existir após mudar
  a letra é ignorada; quem sai da lista de cantores sai das escolhas, e a
  parte que fica sem ninguém volta à escala.

A escala automática não é guardada: é calculada a cada leitura.

## Rotas

Privadas (dono pelo token; outro artista recebe não encontrado):

- `GET /api/apresentacoes/{id}/louvor` — cantores, placar e hinos com partes,
  quem canta e se foi escolhido à mão.
- `PUT /api/apresentacoes/{id}/louvor/cantores` — `{ nomes: [] }`.
- `PUT /api/apresentacoes/{id}/louvor/partes` —
  `{ itemId, indice, cantores: [] | null }` (`null` = Automático, `[]` = Todos).

Pública (nova, só leitura, só para evento Louvor; outro tipo responde não
encontrado):

- `GET /api/publico/apresentacoes/{codigo}/roteiro` — cantores, id do hino
  atual e hinos com título, tom, tocado e partes (tipo, texto, cantores).

Mudanças no Louvor avisam o tempo real do código, como a setlist.
Nenhuma rota existente muda de contrato.

## Testes

Servidor (SQLite real):
- Separar letra: exemplo com `Refrão:`/`(Refrão)` sem linhas em branco; com
  linhas em branco; `Coro:`; sem refrão; texto vazio.
- Escala: Todos no refrão e na última estrofe; placar equilibrado; empate por
  tempo sem cantar; ninguém duas seguidas; escolha à mão mantida e contada;
  Automático devolve à escala; sem cantores tudo Todos; mudar a ordem refaz.
- Roteiro público responde sem token só em Louvor; hino atual acompanha o
  Tocar; letra igual à colada.
- Token de outro artista não lê nem altera cantores e partes.
- Rotas públicas existentes continuam respondendo sem token.

Cliente:
- Preparo: placar, partes do hino, escolher nome/Todos/Automático, aviso de
  hino sem letra.
- Roteiro: "Quem é você?" guardado, destaque "sua vez", segue o hino atual,
  Louvor não mostra pedir, fila, nota nem Pix.

## Etapas

Até quinta (22–23/10), para teste no iPhone antes de sábado:
1. Servidor: tipo Louvor, separar letra, escala, tabelas e rotas.
2. App do proprietário: tipo Louvor no formulário; cantores, placar, partes
   do hino; "música" vira "hino" nas telas do evento Louvor (aprovado em
   2026-10-19).
3. Roteiro pelo código.

Depois do sábado: roteiro sem internet, sugestões vindas do uso real.

Fora: voz de cada cantor, tom por cantor, troca de tom dentro do hino,
microfone como cadastro, hinário embutido no app.
