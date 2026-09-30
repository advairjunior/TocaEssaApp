# TocaEssaApp Multiartista — Especificação de Design

## Objetivo

Permitir que vários artistas criem contas e utilizem o TocaEssaApp com
isolamento completo dos seus dados. Cada conta artística será proprietária de
um perfil artístico, das próprias cifras e das próprias apresentações. A
conta já existente em produção continuará com todos os dados atuais após a
migração.

## Escopo

Esta etapa inclui:

- cadastro e autenticação de múltiplas contas artísticas;
- um perfil artístico por conta;
- propriedade das apresentações por conta artística;
- isolamento de agenda, histórico, fila, estatísticas, participantes,
  avaliações, fotos e retrospectivas por meio da apresentação proprietária;
- preservação dos códigos e links públicos existentes;
- migração automática e idempotente dos dados atuais de produção;
- autorização de todas as operações privadas do artista.

Não fazem parte desta etapa:

- múltiplos integrantes com logins diferentes administrando a mesma banda;
- unificação das contas de público e artista;
- planos pagos, cobrança ou limites comerciais;
- painel administrativo global.

Nesta versão, uma conta artística representa um único perfil artístico. Uma
banda ou dupla pode compartilhar a mesma conta até existir uma funcionalidade
específica para equipes.

## Modelo de propriedade

`ContaArtista` é a raiz dos dados privados:

```text
ContaArtista
├── PerfilArtistico (um para um)
├── CifrasDoArtista (um para muitos)
└── Apresentacoes (um para muitos)
    ├── Pedidos e fila
    ├── ParticipacoesResenha
    ├── Avaliacoes
    ├── Fotos
    ├── Estatisticas
    └── Retrospectiva
```

O banco receberá os seguintes vínculos:

- `PerfilArtisticoRegistro.ArtistaId`, obrigatório e único;
- `ApresentacaoRegistro.ArtistaId`, obrigatório e indexado;
- índice único para `ContaArtistaRegistro.EmailNormalizado`.

Pedidos, avaliações e participações não precisam repetir `ArtistaId`, pois a
apresentação já estabelece a propriedade. `CifraDoArtistaRegistro` já possui
`ArtistaId` e permanece inalterado.

## Autenticação e autorização

O token de artista continuará resolvendo uma `ContaArtista`. Os métodos
privados do repositório receberão o token ou o identificador da conta resolvida
e sempre filtrarão pelo `ArtistaId` autenticado.

As seguintes operações validarão propriedade:

- obter, criar e atualizar o perfil artístico;
- enviar ou alterar a foto do perfil;
- listar, criar, editar e excluir apresentações;
- abrir ou encerrar pedidos e alterar o estado da apresentação;
- administrar pedidos e reordenar a fila;
- consultar estatísticas, participantes e retrospectivas privadas;
- enviar fotos e gerar conteúdo compartilhável da apresentação.

Conhecer o `Guid` de uma apresentação de outro artista não concede acesso. Uma
operação privada sobre recurso alheio responderá como recurso não encontrado,
sem revelar sua existência.

As rotas públicas baseadas no código da apresentação continuam acessíveis sem
token artístico e retornam somente os dados públicos já previstos pelo produto.

## Cadastro e perfil inicial

O cadastro artístico deixa de verificar se existe qualquer conta no sistema.
Ele passa a verificar somente a unicidade do e-mail normalizado. E-mails são
comparados sem diferenciação de maiúsculas e com espaços externos removidos.

Ao criar uma conta:

1. a senha é armazenada com o hash já utilizado pelo sistema;
2. uma sessão artística é criada;
3. a conta começa sem perfil artístico e sem apresentações;
4. o aplicativo direciona o artista à configuração do próprio perfil antes de
   permitir a criação da primeira apresentação.

As contas de público continuam independentes. O mesmo endereço pode existir
uma vez no cadastro de público e uma vez no cadastro artístico, pois são papéis
e fluxos separados nesta etapa.

## API e compatibilidade do cliente

Os endereços atuais da API serão preservados para reduzir o impacto no
aplicativo Flutter. Rotas privadas passarão a extrair a conta do token e a
encaminhá-la ao repositório.

Alterações comportamentais:

- `POST /api/artista/contas` aceita vários artistas e retorna conflito somente
  para e-mail artístico já cadastrado;
- `GET` e `PUT /api/perfil-artistico` operam no perfil da conta autenticada;
- rotas de `/api/apresentacoes` listam e alteram somente apresentações da conta
  autenticada;
- rotas de cifras mantêm o comportamento atual, já isolado por artista.

No Flutter, a estrutura visual permanece. A mensagem global “a conta do
artista já foi configurada” deixa de existir. Uma conta recém-criada vê estado
vazio e o convite para configurar o perfil; a conta migrada vê seus dados
anteriores normalmente.

## Migração dos dados de produção

A migração será automática, transacional e idempotente:

1. adicionar `ArtistaId` inicialmente anulável aos perfis e apresentações;
2. localizar a conta artística existente;
3. atribuir essa conta ao perfil artístico atual e a todas as apresentações
   sem proprietário;
4. verificar que nenhum perfil ou apresentação permaneceu órfão;
5. criar os índices e tornar os vínculos obrigatórios;
6. manter todos os identificadores, códigos públicos e relações filhas.

Pedidos, avaliações, participantes, cifras, imagens e URLs existentes não
serão recriados nem renumerados. Como os identificadores das apresentações e
do perfil permanecem iguais, suas relações continuam válidas.

Se houver dados artísticos antigos sem nenhuma conta artística, a inicialização
não inventará uma conta nem excluirá dados. Ela registrará claramente a
inconsistência e interromperá a migração para evitar atribuição incorreta.

## Concorrência e integridade

A unicidade do e-mail será garantida no banco, não somente por uma consulta em
memória. Dois cadastros simultâneos com o mesmo e-mail resultarão em uma conta
e um conflito controlado.

Toda criação de perfil ou apresentação gravará o `ArtistaId` obtido da sessão,
nunca um identificador fornecido pelo cliente. Exclusões em cascata de contas
artísticas não serão introduzidas nesta etapa; não haverá endpoint de exclusão
de conta até existir uma política explícita de retenção.

## Erros

- e-mail artístico duplicado: conflito com mensagem específica;
- credenciais inválidas: mensagem genérica atual, sem indicar qual campo
  falhou;
- token ausente, inválido ou expirado: sessão artística inválida;
- recurso pertencente a outro artista: não encontrado;
- perfil ainda não configurado: resposta atual de perfil não cadastrado;
- inconsistência de migração: falha de inicialização com diagnóstico no log,
  sem alteração parcial dos dados.

## Estratégia de testes

Os testes automatizados deverão demonstrar:

- dois artistas com e-mails diferentes podem criar conta e entrar;
- o mesmo e-mail artístico não pode ser cadastrado duas vezes, incluindo
  variações de maiúsculas e espaços;
- cadastros simultâneos com o mesmo e-mail não criam duplicidade;
- cada artista cria, lista e edita somente o próprio perfil;
- cada artista cria e lista somente as próprias apresentações;
- IDs de outro artista não permitem leitura, edição, exclusão ou controle de
  fila por rotas privadas;
- cifras continuam isoladas por artista;
- códigos públicos continuam abrindo a apresentação correta;
- a migração associa os dados antigos à conta existente e pode ser executada
  novamente sem alterar o resultado;
- dados antigos sem conta impedem uma migração destrutiva;
- cliente Flutter apresenta perfil inicial vazio e mantém o fluxo da conta
  migrada.

## Implantação

O deploy seguirá a ordem compatível com dados existentes: estrutura anulável,
preenchimento, validação e restrições. A API será publicada junto da migração,
evitando uma versão que aceite novas contas sem isolamento.

Antes do push serão executados os testes completos do servidor e os comandos
de análise e teste do Flutter. Depois do deploy serão validados saúde da API,
login da conta existente, criação de uma segunda conta de teste, isolamento das
agendas e abertura de ambos os códigos públicos.

