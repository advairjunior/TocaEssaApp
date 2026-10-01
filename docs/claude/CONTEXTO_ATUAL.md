# TocaEssaApp — Contexto atual

> Atualizado em: 2026-10-01

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
└── Apresentacoes (1:N, isoladas por ArtistaId)
    ├── Pedidos e fila
    ├── ParticipacoesResenha
    ├── Avaliacoes
    ├── Fotos
    ├── Estatisticas
    └── Retrospectiva
```

Rotas públicas (por código de apresentação) continuam acessíveis sem token.
Operações privadas sempre extraem a conta do token — nunca aceitam `ArtistaId` do cliente.

## Estado atual (2026-10-01)

- Branch `main` com 1 commit à frente da `origin/main` (não publicado).
- `.vs/` untracked localmente (normal, Visual Studio).
- Implementação multiartista completa (Tasks 1–7 entregues).

### Commits recentes

```
d1620ee docs: definir transicao para claude code
7d5adc8 docs: registrar deploy multiartista
10a5e03 refactor: restringir apis legadas sem token
daddd4e test: validar primeira experiencia multiartista
2da47f7 feat: aplicar isolamento multiartista na api
```

### Status da implementação (`PLANO_IMPLEMENTACAO.md`)

Concluídos:
- Migração JSON → SQLite
- Autenticação por e-mail e senha, sessão persistente
- Avaliações de 1 a 5 estrelas
- Estatísticas privadas e histórico pessoal
- Retrospectivas e cartões compartilháveis
- Conta do artista e proteção do painel
- Detalhes de participantes e estatísticas coletivas
- Compartilhamento com imagens e foto do encontro
- **Multiartista: isolamento completo por conta artística**

Pendentes:
- Foto no Perfil Artístico (base de armazenamento de imagens)
- Dois tipos de Apresentação: Pública e Resenha entre Amigos
- Comunicação em tempo real (substituir polling)

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
