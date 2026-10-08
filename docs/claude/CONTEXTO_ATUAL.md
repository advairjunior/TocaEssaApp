# TocaEssaApp — Contexto atual

> Atualizado em: 2026-10-08

## Arquitetura

| Camada | Tecnologia |
|--------|-----------|
| Cliente | Flutter Web / PWA |
| Servidor | ASP.NET Core Minimal APIs (.NET 10) |
| Banco local | SQLite (desenvolvimento e testes) |
| Banco produção | PostgreSQL no Render |
| Deploy | Render — automático via push na `main` |

### Modelo de propriedade multiartista

```
ContaArtista
├── PerfilArtistico (1:1, isolado por ArtistaId)
├── CifrasDoArtista (1:N, isoladas por ArtistaId)
├── Repertorios (1:N, isolados por ArtistaId)
└── Apresentacoes (1:N, isoladas por ArtistaId)
    ├── Pedidos e fila
    ├── Setlist
    ├── ParticipacoesResenha
    ├── Avaliacoes
    ├── Fotos
    ├── Estatisticas
    └── Retrospectiva
```

Rotas públicas (por código de apresentação) continuam acessíveis sem token.
Operações privadas sempre extraem a conta do token — nunca aceitam `ArtistaId` do cliente.

## Estado atual (2026-10-08)

O roadmap do `PLANO_IMPLEMENTACAO.md` está todo entregue. Novas ideias ficam na
seção **Banco de ideias** do mesmo arquivo. O estado do Git muda a cada sessão:
confira com `git status` e `git log --oneline -15` em vez de confiar neste
arquivo.

### O que o app faz hoje

**Público (sem conta, pelo código ou QR Code)**
- Entra no evento, faz Pedido Musical, acompanha a fila e avalia músicas tocadas.
- Pix do artista (copia e cola ou chave), contagem de quem abriu o evento.
- Resenha entre Amigos: conta com foto, histórico em linha do tempo,
  retrospectiva do ano e cartões compartilháveis com foto do encontro.

**Artista (conta própria, isolado por `ArtistaId`)**
- Perfil artístico com foto e perfil público; apresentações Pública ou Resenha.
- Fila musical em tempo real (SSE em `/api/tempo-real/{codigo}`, com
  atualização periódica como reserva).
- Repertórios ordenáveis; setlist da apresentação segue o repertório.
- Cifras por música (link salvo por conta). Na setlist:
  - todas as cifras são buscadas ao abrir, para abrir na hora no palco;
  - barra fixa "Próxima" com Tocar (abre a cifra e marca como tocada), tom e
    a música seguinte;
  - aviso "X músicas sem cifra" com Resolver em sequência (Pesquisar na web e
    Colar e próxima); ícone de cifra em amarelo quando falta;
  - uma única aba de cifra: cada cifra nova fecha a anterior.
- Estatísticas da apresentação e retrospectiva do artista; câmera no app para
  as fotos dos cartões.

### Lições do iPhone/Safari

O proprietário testa e usa no iPhone. Testes de widget não pegam:
- Safari só abre aba nova como resposta direta a um toque: abrir a aba antes
  de qualquer `await` (`prepararAbertura`).
- Área de transferência só é lida com o app em primeiro plano e pode pedir
  confirmação ("Colar").
- Gestos de arrastar precisaram de ajuste específico para o iPhone.

### Investigações registradas

- Cifra Club bloqueia acesso automático (Akamai, 403). Ler resultados do
  Google também não é viável. Detalhes no Banco de ideias.

## Decisões de arquitetura registradas

- Minimal APIs sem controllers: reduz boilerplate e mantém o código próximo ao domínio.
- Repositório em arquivos parciais: evita arquivos gigantes sem introduzir camadas desnecessárias.
- Testes com banco real (SQLite): garante que migrações e queries funcionam de verdade.
- ArtistaId gravado pelo servidor, nunca pelo cliente: evita spoofing de propriedade.
- Rotas públicas por código: QR code compartilhável não expira e não exige login.

## Comandos úteis

```powershell
# Executar localmente (API + Flutter + Chrome)
.\rodar.ps1

# Verificar antes de commitar
dotnet build TocaEssaApp.sln --no-restore
dotnet test TocaEssaApp.sln --no-build
cd cliente; flutter analyze; flutter test

# Rodar testes específicos
dotnet test TocaEssaApp.sln --filter "FullyQualifiedName~NomeDaClasseTestes"

# Ver estado do git
git status
git log --oneline -15
```

## Riscos conhecidos

| Risco | Mitigação |
|-------|----------|
| Deploy quebra migração do banco de produção | Migração idempotente; não apagar banco do Render; smoke test após deploy |
| Push acidental da `main` com código sem testes | Verificação completa antes de qualquer push |
| `.vs/` entrar no repositório | Adicionado ao `.gitignore` |
| Token de artista exposto em log | Nenhum log de token; erros genéricos sem detalhes de sessão |

## Estrutura de pastas relevante

```
TocaEssaApp/
├── CLAUDE.md                          → regras do projeto
├── PLANO_IMPLEMENTACAO.md             → roadmap de produto
├── rodar.ps1                          → script para rodar localmente
├── render.yaml                        → configuração de deploy
├── servidor/TocaEssaApp.Api/          → API .NET
├── cliente/                           → Flutter Web/PWA
├── testes/TocaEssaApp.Testes/         → testes xUnit
└── docs/
    ├── DEPLOY_RENDER.md               → deploy e smoke test
    ├── claude/                        → contexto para Claude Code
    └── superpowers/
        ├── plans/                     → planos de implementação detalhados
        └── specs/                     → especificações de design
```
