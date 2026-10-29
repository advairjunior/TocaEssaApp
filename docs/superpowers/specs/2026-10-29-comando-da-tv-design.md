# Comando da TV com um ajudante

Pedido do proprietário em 2026-10-29: quem toca e canta não precisa ficar de
olho se a TV está certa; dá para passar isso a outra pessoa. Decisões dele:
qualquer um, com ou sem conta; só acompanha a letra; sem ajudante, tudo
funciona como hoje; com ajudante, só ele mexe na linha da TV; o dono pode
retomar quando quiser.

## Como funciona

- **Sem ajudante:** nada muda. O celular do dono manda a música e a linha
  da seta.
- **Passar o comando:** em Mais → Letra na TV, **Passar o comando** gera um
  link `…/#/comando/<token>` (QR na tela e compartilhar). Gerar outro desfaz
  o anterior.
- **O ajudante** abre o link no celular dele, sem conta, e vê só a letra que
  está na TV, sem acordes, em letra grande, com a linha acesa. Ele toca na
  linha que a galera está cantando e a TV acompanha. Quando a música muda
  no celular do dono, a letra nova chega sozinha.
- **Enquanto o ajudante comanda,** a linha que vem do celular do dono é
  ignorada; a música (abrir outra no leitor) continua vindo do dono e
  começa na primeira linha.
- **Retomar:** o dono toca em **Retomar o comando**; o link para de valer e
  o celular do ajudante avisa "O comando voltou para quem toca".

## Servidor

- Comando na memória, por conta (como o conteúdo da TV): id, hash do token.
- Privadas (token do artista): `POST /api/artista/telas/comando` (gera; devolve
  o token), `GET /api/artista/telas/comando` (`{ ativo }`), `DELETE
  /api/artista/telas/comando` (retoma).
- Públicas (token do ajudante no cabeçalho): `GET /api/publico/comando`
  (conteúdo atual e o id do canal), `PUT /api/publico/comando/linha`
  (`{ linha }`), `GET /api/publico/comando/{id}/tempo-real` (o mesmo evento
  `linha:versão:linha` das TVs). Token que não vale: 404.
- Com comando ativo, `PUT /api/artista/telas/conteudo/linha` responde 204
  sem mudar nada.

## App

- `#/comando/<token>` abre sozinho (sem o início embaixo), como os outros
  links: a letra da `LetraDaTela`, uma linha por botão, a atual acesa.
- Letra na TV do dono: **Passar o comando** (QR e compartilhar) e, com ele
  ativo, "Comando com o ajudante" e **Retomar o comando**.

## Fora desta versão

- O ajudante trocar de música.
