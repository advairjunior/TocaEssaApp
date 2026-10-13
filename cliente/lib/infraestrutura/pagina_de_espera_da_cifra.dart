/// Conteúdo da aba aberta no toque enquanto o link da cifra chega do servidor.
/// No iPhone o app fica pausado atrás dessa aba; sem este aviso ela parecia
/// uma tela branca travada no meio do show.
const paginaDeEsperaDaCifra = '<!DOCTYPE html>'
    '<html lang="pt-BR"><head><meta charset="UTF-8">'
    '<meta name="viewport" content="width=device-width, initial-scale=1">'
    '<meta name="theme-color" content="#0B080F">'
    '<title>Abrindo a cifra…</title></head>'
    '<body style="margin:0;min-height:100vh;display:flex;align-items:center;'
    'justify-content:center;text-align:center;padding:24px;'
    'box-sizing:border-box;background:#0B080F;color:#FFFFFF;'
    'font-family:-apple-system,system-ui,sans-serif">'
    '<div><p style="font-size:22px;margin:0 0 12px">Abrindo a cifra…</p>'
    '<p style="font-size:16px;margin:0;color:#C8C2D0">'
    'Se demorar, volte para o TocaEssa e toque na cifra de novo.</p></div>'
    '</body></html>';
