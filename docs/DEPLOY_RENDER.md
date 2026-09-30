# Deploy no Render

O `render.yaml` mantém o deploy automático ligado ao repositório. Antes de enviar
uma alteração para a branch publicada, execute na raiz:

```powershell
dotnet build TocaEssaApp.sln --no-restore
dotnet test TocaEssaApp.sln --no-build
cd cliente
flutter analyze
flutter test
```

## Primeiro deploy multiartista

A migração é executada automaticamente ao iniciar a API. Quando o banco antigo
possui uma única conta artística, o perfil e as apresentações existentes são
associados a essa conta. Se existirem dados antigos sem um proprietário único e
seguro, a inicialização é interrompida sem aplicar uma associação ambígua; nesse
caso, preserve o banco e revise os registros antes de tentar novamente.

Não apague o banco nem o disco persistente do Render durante a atualização.

## Smoke test depois do deploy

1. Entre com a conta artística que já existia e confirme perfil e agenda.
2. Crie uma segunda conta com outro e-mail e configure seu primeiro perfil.
3. Crie uma apresentação em cada conta.
4. Confirme que cada painel lista somente a própria apresentação.
5. Tente abrir, com a segunda conta, uma rota privada da primeira apresentação;
   a API deve responder `404`.
6. Abra os dois códigos públicos sem login artístico; ambos devem responder e
   mostrar o respectivo artista.
7. Reinicie o serviço e confirme que contas, fotos, perfis e apresentações
   permanecem disponíveis.

Se qualquer etapa falhar, não remova dados. Consulte os logs do deploy e restaure
o snapshot do banco antes de uma intervenção manual.
