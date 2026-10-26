using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Testes;

/// Títulos de verdade da playlist de karaokê do proprietário (2026-10-26).
/// A ordem "cantor - música" ou "música - cantor" fica como veio.
public sealed class TituloDeKaraokeTestes
{
    [Theory]
    [InlineData("Thiaguinho - Falta Você - Karaoke", "Thiaguinho - Falta Você")]
    [InlineData("Desejo Imortal - Gusttavo Lima (Karaokê Version)", "Desejo Imortal - Gusttavo Lima")]
    [InlineData("🎼 Djavan - Samurai - Karaokê (Instrumental)", "Djavan - Samurai")]
    [InlineData("Karaokê - Sorriso Maroto - Sinais", "Sorriso Maroto - Sinais")]
    [InlineData("Seu Polícia - Zé Neto & Cristiano, Karaokê (1 Tom Abaixo)", "Seu Polícia - Zé Neto & Cristiano")]
    [InlineData("Daqui Pra Sempre - Manu Bahtidão, Simone Mendes (Karaokê Version)", "Daqui Pra Sempre - Manu Bahtidão, Simone Mendes")]
    [InlineData("Isn't She Lovely - Stevie Wonder | Karaoke Version | KaraFun", "Isn't She Lovely - Stevie Wonder")]
    [InlineData("Fly me to the moon Karaoke - Frank Sinatra | Jazz Acoustic with Lyrics | Male Key", "Fly me to the moon - Frank Sinatra")]
    [InlineData("Karaokê de Arrocha - Mentes Tão Bem", "Mentes Tão Bem")]
    [InlineData("Hugo e Guilherme - Pot-Pourri Separação / Porta-Retrato - PLAYBACK ACÚSTICO", "Hugo e Guilherme - Pot-Pourri Separação / Porta-Retrato")]
    [InlineData("Ana Castela - Todo Mundo Menos Eu KARAOKE", "Ana Castela - Todo Mundo Menos Eu")]
    [InlineData("Marvvila - A pagodeira - Karaoke Completo 100% instrumental", "Marvvila - A pagodeira")]
    [InlineData("Garçom - Reginaldo Rossi - Versão Fran Lima - Karaokê", "Garçom - Reginaldo Rossi - Versão Fran Lima")]
    [InlineData("Felicidade dela - Hugo e Guilherme - Karaokê com 2ª voz (cover)", "Felicidade dela - Hugo e Guilherme")]
    [InlineData("Pablo Oficial - Pablo - Intriga da oposição   (KARAOKÊ)", "Pablo - Intriga da oposição")]
    [InlineData("Daniel Caesar ft. H.E.R. - Best Part (Karaoke Version)", "Daniel Caesar ft. H.E.R. - Best Part")]
    [InlineData("Menos é Mais - Fatalmente/Separação/Temporal - Karaoke", "Menos é Mais - Fatalmente/Separação/Temporal")]
    [InlineData("⭐ Pé Na Areia (A Caipirinha, Água de Coco, a Cervejinha) - Diogo Nogueira (Karaokê Version) (Cover)",
        "Pé Na Areia (A Caipirinha, Água de Coco, a Cervejinha) - Diogo Nogueira")]
    public void LimpaORuidoDoKaraoke(string doYouTube, string esperado) =>
        Assert.Equal(esperado, TituloDeKaraoke.Limpar(doYouTube));

    [Theory]
    [InlineData("TEMPO PERDIDO - Legião Urbana (KARAOKÊ VERSION)", "Tempo Perdido - Legião Urbana")]
    [InlineData("XOTE DOS MILAGRES - Falamansa (KARAOKÊ VERSION)", "Xote dos Milagres - Falamansa")]
    [InlineData("SANDY E JUNIOR - OLHA O QUE O AMOR ME FAZ ( KARAOKE )", "Sandy e Junior - Olha o que o Amor Me Faz")]
    [InlineData("KARAOKÊ -  HOMEM NÃO CHORA - PABLO", "Homem Não Chora - Pablo")]
    public void TrechoTodoEmMaiusculasViraTitulo(string doYouTube, string esperado) =>
        Assert.Equal(esperado, TituloDeKaraoke.Limpar(doYouTube));

    [Theory]
    [InlineData("Karaokê", "Karaokê")]
    [InlineData("   ", "")]
    public void SemNadaAlemDoRuidoFicaOTituloOriginal(string doYouTube, string esperado) =>
        Assert.Equal(esperado, TituloDeKaraoke.Limpar(doYouTube));
}
