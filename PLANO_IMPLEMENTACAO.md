# Plano de implementação do TocaEssaApp

## Dois tipos de Apresentação

### Apresentação Pública

Fluxo de entrada rápido, pensado para bares, shows e eventos com muitas pessoas.

- O público entra pelo código ou QR Code, sem criar conta.
- Informa somente um nome curto, que pode continuar opcional.
- Pode enviar Pedido Musical, acompanhar seu pedido e avaliar músicas tocadas.
- Não há foto nem histórico público permanente da pessoa.
- As estatísticas ficam privadas para o artista: músicas mais pedidas, pedidos aceitos e tocados, participação e avaliações recebidas.

### Resenha entre Amigos

Fluxo identificado, pensado para encontros recorrentes de um grupo.

- Cada participante entra com sua conta.
- O Perfil do Público possui nome e foto.
- O histórico acumula entre resenhas: participações, músicas pedidas, aceitas e tocadas, avaliações e preferências.
- A resenha mostra informações mais detalhadas dos participantes e do encontro.
- Estatísticas divertidas entre amigos e retrospectivas compartilháveis entram em uma etapa posterior.
- O artista pode tirar ou escolher uma foto do encontro para compor a retrospectiva visual com as estatísticas.
- Cada pessoa poderá controlar sua foto, visibilidade e exclusão dos próprios dados.

## Perfil Artístico

- Adicionar foto ao Perfil Artístico.
- Mostrar a foto no Painel do Artista e na Área do Público.
- Manter um avatar padrão quando não houver foto.
- Preparar compressão e limite de tamanho para funcionar bem no celular.

## Ordem de implementação

1. Adicionar `Pública` e `Resenha entre Amigos` na criação e edição da Apresentação. Apresentações existentes serão consideradas públicas.
2. Ajustar os textos e a Área do Público conforme o tipo, mantendo o fluxo atual intacto para apresentações públicas.
3. Adicionar foto ao Perfil Artístico e criar a base de armazenamento de imagens.
4. ✅ Migrar os dados locais em JSON para SQLite, com importação automática dos dados existentes.
5. ✅ Implementar autenticação por e-mail e senha, sessão persistente e Perfil do Público com foto somente para Resenha entre Amigos.
6. ✅ Registrar avaliações de 1 a 5 estrelas depois que uma música for tocada e exibi-las ao artista.
7. ✅ Criar estatísticas privadas por Apresentação para o artista e histórico pessoal acumulado para participantes autenticados.
8. ✅ Criar retrospectivas e cartões compartilháveis da Resenha entre Amigos.
9. ✅ Criar conta do artista, sessão persistente e proteger o Painel do Artista.
10. ✅ Detalhar participantes e estatísticas coletivas da Resenha entre Amigos.
11. ✅ Evoluir o compartilhamento para imagens com estatísticas e foto opcional do encontro, prontas para redes sociais.
12. Substituir a atualização periódica por comunicação em tempo real.

## Regras para manter o produto simples

- Apresentação Pública nunca exigirá cadastro, senha ou foto.
- Resenha entre Amigos exigirá login porque o histórico será acumulado.
- A Fila Musical continuará sendo formada somente por pedidos do público.
- O artista não precisará registrar no aplicativo as músicas do próprio repertório.
- Rankings compartilháveis serão opcionais e evitarão expor recusas ou informações constrangedoras.

## Decisões que podem esperar

- Método de login da Resenha: e-mail e senha, código por e-mail ou provedor social.
- Armazenamento definitivo das fotos quando o aplicativo for publicado.
- Quais estatísticas e cartões poderão ser compartilhados fora do grupo.
