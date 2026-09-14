using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    public ApoioPix GerarApoioPix(string codigo, decimal valor)
    {
        var apresentacao = ObterApresentacaoPublica(codigo)
            ?? throw new ApresentacaoNaoEncontradaException();
        var configuracao = _configuracaoPerfil;
        if (apresentacao.Tipo != TipoApresentacao.Publica ||
            configuracao is null || !configuracao.PixAtivo ||
            string.IsNullOrWhiteSpace(configuracao.PixChave) ||
            string.IsNullOrWhiteSpace(configuracao.PixNomeBeneficiario) ||
            string.IsNullOrWhiteSpace(configuracao.PixCidadeBeneficiario))
            throw new ApoioPixIndisponivelException();

        var payload = ServicoPix.Gerar(
            configuracao.PixChave,
            configuracao.PixNomeBeneficiario,
            configuracao.PixCidadeBeneficiario,
            valor,
            configuracao.PixMensagem);
        return new ApoioPix(
            valor,
            payload,
            configuracao.PixMensagem ?? "Obrigado por apoiar o artista!");
    }
}
