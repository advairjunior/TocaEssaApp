# TocaEssaApp

Primeiro fluxo vertical em Flutter Web/PWA e ASP.NET Core.

O roadmap funcional está em [PLANO_IMPLEMENTACAO.md](PLANO_IMPLEMENTACAO.md).

## Executar localmente com um comando

Na raiz do projeto, execute:

```powershell
.\rodar.ps1
```

O comando inicia a API, executa `flutter run`, abre o Chrome e encerra a API ao sair.

Para testar em um celular na mesma rede, use `web-server`, endereço `0.0.0.0` e substitua
`localhost` pelo IP do computador no `API_URL`. Configure também
`Aplicacao__EnderecoPublico=http://IP-DO-COMPUTADOR:5173` ao iniciar a API.

Os dados são salvos no banco SQLite `servidor/TocaEssaApp.Api/dados/tocaessa.db`
e continuam disponíveis depois que o aplicativo é reiniciado. Na primeira execução,
o conteúdo do antigo `tocaessa.json` é importado automaticamente.
