using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

// Sessões, tokens e conversões dos registros para o domínio.
public sealed partial class RepositorioTocaEssa
{
    private SessaoDoPublico CriarSessao(PerfilPublicoRegistro registro)
    {
        var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        var tokenHash = GerarHashToken(token);
        _sessoesPublicas[tokenHash] = new SessaoPublicoRegistro
        {
            TokenHash = tokenHash,
            PublicoId = registro.Id,
            ExpiraEm = DateTimeOffset.UtcNow.AddDays(90)
        };
        return new SessaoDoPublico(ParaDominio(registro), token);
    }

    private SessaoDoArtista CriarSessaoArtista(ContaArtistaRegistro registro)
    {
        var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        var tokenHash = GerarHashToken(token);
        _sessoesArtistas[tokenHash] = new SessaoArtistaRegistro
        {
            TokenHash = tokenHash,
            ArtistaId = registro.Id,
            ExpiraEm = DateTimeOffset.UtcNow.AddDays(90)
        };
        return new SessaoDoArtista(ParaDominio(registro), token);
    }

    private ContaArtistaRegistro? ObterRegistroArtista(string? token)
    {
        if (string.IsNullOrWhiteSpace(token)) return null;
        var hash = GerarHashToken(token);
        if (!_sessoesArtistas.TryGetValue(hash, out var sessao) ||
            sessao.ExpiraEm <= DateTimeOffset.UtcNow)
            return null;
        return _contasArtistas.GetValueOrDefault(sessao.ArtistaId);
    }

    private PerfilPublicoRegistro? ObterRegistroPublico(string? token)
    {
        if (string.IsNullOrWhiteSpace(token)) return null;
        var hash = GerarHashToken(token);
        if (!_sessoesPublicas.TryGetValue(hash, out var sessao) ||
            sessao.ExpiraEm <= DateTimeOffset.UtcNow)
            return null;
        return _perfisPublicos.GetValueOrDefault(sessao.PublicoId);
    }

    private static PerfilPublico ParaDominio(PerfilPublicoRegistro registro) =>
        new(registro.Id, registro.Nome, registro.Email, registro.FotoUrl, registro.CriadoEm);

    private static ContaArtista ParaDominio(ContaArtistaRegistro registro) =>
        new(registro.Id, registro.Nome, registro.Email, registro.CriadoEm);

    private static PerfilArtistico ParaPerfilPublico(
        PerfilArtisticoRegistro registro)
    {
        var apoioDisponivel = registro.PixAtivo &&
                              !string.IsNullOrWhiteSpace(registro.PixChave) &&
                              !string.IsNullOrWhiteSpace(registro.PixNomeBeneficiario) &&
                              !string.IsNullOrWhiteSpace(registro.PixCidadeBeneficiario);
        return new PerfilArtistico(
            registro.Id,
            registro.NomeArtistico,
            registro.Bio,
            registro.FotoUrl,
            registro.ExibirInstagram ? registro.Instagram : null,
            registro.ExibirWhatsapp ? registro.Whatsapp : null,
            apoioDisponivel);
    }

    private static string NormalizarEmail(string email) =>
        email.Trim().ToUpperInvariant();

    private static string GerarHashToken(string token) =>
        Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(token)));

    private static IReadOnlyCollection<MusicaMaisPedida> AgruparMusicas(
        IEnumerable<PedidoMusical> pedidos) => pedidos
        .Where(item => !string.IsNullOrWhiteSpace(item.Musica))
        .GroupBy(item => item.Musica.Trim(), StringComparer.OrdinalIgnoreCase)
        .OrderByDescending(grupo => grupo.Count())
        .ThenBy(grupo => grupo.Key)
        .Take(5)
        .Select(grupo => new MusicaMaisPedida(grupo.First().Musica.Trim(), grupo.Count()))
        .ToArray();
}
