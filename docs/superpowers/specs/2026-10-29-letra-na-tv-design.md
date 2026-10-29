# Letra na TV — desenho

Aprovado pelo proprietário em 2026-10-29. Inspiração: uma jam em que
cantores, músicos e quem canta sem microfone olham todos para a mesma TV e
cantam juntos. Uso: a resenha, com a letra numa TV Samsung (navegador da
TV). Depois, o louvor usa a mesma TV.

Prévia visual aprovada: https://claude.ai/artifact/4fyyBXXJ3qShHNnjcU4Z1D

## Decisões do proprietário

- A TV acompanha o celular de quem puxa (jeito "B"): não é espelhamento.
  O celular manda só **qual linha da letra** está sendo cantada; a TV monta
  o próprio desenho deitado, em letra grande.
- **Seta fixa** na cifra do celular, no terço de cima: a linha que passa na
  seta é a linha acesa na TV. Serve também para acertar a velocidade da
  rolagem automática.
- Conexão com **código na TV** (transmitir pelo Wi-Fi não funciona num site
  no iPhone: Google Cast não roda no iOS e o AirPlay do Safari só leva vídeo).
- Opção **"Letra na TV"** ligável: ligada, a seta aparece na cifra e o
  celular passa a mandar a letra para a TV.
- A parte da TV é **abstrata**: o louvor vai usá-la depois, sem mudar a TV.
- Rota pública nova da TV **autorizada** (2026-10-29). As rotas públicas
  existentes não mudam.

## Como fica

**Na TV (primeira vez):** abre `tocaessaapp.onrender.com/#/tv` no navegador
da Samsung e salva nos favoritos. A tela mostra um código curto (ex.: K7Q2).
**No celular:** Mais → Letra na TV → Conectar TV → digita o código. A TV
fica presa à conta e lembra disso. Daí em diante, basta abrir o favorito.

**Durante a resenha:** com "Letra na TV" ligada, o leitor da cifra mostra a
seta. Ao abrir uma música, o celular manda a letra; ao rolar, manda o número
da linha que está na seta (só quando muda, no máximo ~3 por segundo). Sair
da cifra não apaga a TV: ela fica onde estava.

**A TV mostra** (visual da prévia, tela deitada, tema escuro): título e
artista no topo com o código da resenha; no centro, a parte atual (2 a 6
linhas) em letra grande, com a linha da vez acesa, as cantadas apagadas e o
selo da parte quando a cifra tem marca (`[Refrão]`, `(Estrofe 2)`…); no
rodapé, a primeira linha da próxima parte, a trilha das partes e "A seguir".
Sem acordes. Sem conteúdo: "Conectada · esperando a música". Tela acesa.

## Arquitetura

O servidor não entende de letra nem de tipo de evento: ele **leva** o que o
celular do dono mostra até as TVs da conta. Quem monta o conteúdo é uma
fonte no app (resenha agora, louvor depois); quem desenha é a TV. Assim, o
louvor entra só com uma fonte nova (aberto para extensão).

### Servidor

- **TVs da conta** (`TelasDaTv`, tabela nova, `CREATE TABLE IF NOT EXISTS`
  nos dois bancos): `Id`, `ArtistaId`, `TokenHash` (SHA-256 do token da TV),
  `CriadaEm`. O pareamento sobrevive ao servidor dormir no Render.
- **Códigos pendentes** em memória (4 caracteres sem 0/O/1/I, valem 10 min).
- **Conteúdo atual** em memória, por conta: `titulo`, `subtitulo`, `texto`
  (a cifra colada, até 20 mil caracteres), `aSeguir`, `codigo` (da
  apresentação, opcional), `linha`. Perder ao dormir não faz mal: o celular
  manda de novo quando a rota da linha responde 409.
- **Tempo real da TV** num canal próprio (`tela:{id da TV}`), para a linha
  não acordar os celulares do público. O evento leva o dado: `linha:6` ou
  `conteudo`.
- Rotas:
  - `POST /api/publico/telas` → `{ id, token, codigo }` (TV nova).
  - `GET /api/publico/telas/eu` com o token da TV no cabeçalho
    `Authorization: Bearer` → `{ pareada, codigo?, conteudo? }`; pedir de
    novo renova o código vencido.
  - `GET /api/publico/telas/{id}/tempo-real` (SSE; o `EventSource` não manda
    cabeçalho, e o canal só leva números de linha).
  - `POST /api/artista/telas/pareamento` `{ codigo }` (token do artista).
  - `GET /api/artista/telas` e `DELETE /api/artista/telas/{id}` (desconectar).
  - `PUT /api/artista/telas/conteudo`, `PUT /api/artista/telas/conteudo/linha`
    `{ linha }` (409 sem conteúdo) e `DELETE /api/artista/telas/conteudo`.
- TV de outra conta responde como não encontrada. Nenhum `ArtistaId` vem do
  cliente: a conta sai do token do artista; a TV, do token dela.

### App

- `dominio/letra_da_tela.dart`: separa o texto da cifra em partes (linhas em
  branco e marcas) e numera **só as linhas de letra** (sem acordes, sem
  marcas, sem vazias). A mesma função roda no celular e na TV, então a
  linha 6 é a mesma nos dois, com qualquer tamanho de tela ou pinça.
- `SaidaDaTela` (interface): `mostrar(ConteudoDaTela)`, `irParaALinha(int)`,
  `limpar()`. `SaidaDaTelaPelaApi` implementa; o `TransmissorDaLetra`
  descarta linha repetida, segura o ritmo e manda o conteúdo de novo no 409.
  Telas dependem da interface; testes usam uma falsa.
- `CifraDoPalco` ganha `aoLerALinha` opcional: com ele, mostra a seta e
  avisa a linha de letra que cruza a seta (cada linha visível se registra;
  a rolagem procura a que está na altura da seta).
- `tela_da_tv.dart` (`#/tv`): três estados — código para parear, esperando a
  música, letra. O token da TV fica no aparelho.
- Mais da resenha: chave "Letra na TV" (guardada no aparelho, como a
  velocidade da rolagem) e "Conectar TV" / lista com "Desconectar".

## Fora desta versão

- Louvor na TV (fonte com o nome de quem canta em cada parte).
- Passar o comando da TV para outro celular.
- Fundo com a foto do artista.

## Etapas (um commit por etapa, cada uma nascendo de teste)

1. Servidor: TVs, pareamento, conteúdo, linha e tempo real da TV.
2. App: `letra_da_tela.dart` e a API das telas.
3. App: seta na `CifraDoPalco` e `TransmissorDaLetra` no leitor da resenha.
4. App: tela da TV (`#/tv`).
5. App: "Letra na TV" e "Conectar TV" no Mais da resenha.
