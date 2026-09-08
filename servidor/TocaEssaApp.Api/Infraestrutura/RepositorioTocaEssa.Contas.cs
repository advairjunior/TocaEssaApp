using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    public SessaoDoArtista CriarContaArtista(string nome, string email, string senha)
    {
        lock (_sincronizacao)
        {
            if (!_contasArtistas.IsEmpty)
                throw new ContaArtistaJaConfiguradaException();
            var registro = new ContaArtistaRegistro
            {
                Id = Guid.NewGuid(),
                Nome = nome.Trim(),
                Email = email.Trim(),
                EmailNormalizado = NormalizarEmail(email),
                CriadoEm = DateTimeOffset.UtcNow
            };
            registro.SenhaHash = SenhasArtista.HashPassword(registro, senha);
            _contasArtistas[registro.Id] = registro;
            var sessao = CriarSessaoArtista(registro);
            SalvarEstado();
            return sessao;
        }
    }

    public SessaoDoArtista EntrarContaArtista(string email, string senha)
    {
        lock (_sincronizacao)
        {
            var emailNormalizado = NormalizarEmail(email);
            var registro = _contasArtistas.Values.SingleOrDefault(
                item => item.EmailNormalizado == emailNormalizado)
                ?? throw new CredenciaisArtistaInvalidasException();
            if (SenhasArtista.VerifyHashedPassword(registro, registro.SenhaHash, senha) ==
                PasswordVerificationResult.Failed)
                throw new CredenciaisArtistaInvalidasException();
            var sessao = CriarSessaoArtista(registro);
            SalvarEstado();
            return sessao;
        }
    }

    public ContaArtista ObterContaArtista(string token) =>
        ObterRegistroArtista(token) is { } registro
            ? ParaDominio(registro)
            : throw new SessaoArtistaInvalidaException();

    public void ValidarSessaoArtista(string token) => _ = ObterContaArtista(token);

    public void EncerrarSessaoArtista(string token)
    {
        lock (_sincronizacao)
        {
            if (string.IsNullOrWhiteSpace(token)) return;
            _sessoesArtistas.TryRemove(GerarHashToken(token), out _);
            SalvarEstado();
        }
    }

    public PerfilArtistico SalvarPerfil(string nomeArtistico, string? bio)
    {
        lock (_sincronizacao)
        {
            _perfil = new PerfilArtistico(
                _perfil?.Id ?? Guid.NewGuid(), nomeArtistico, bio, _perfil?.FotoUrl);
            foreach (var item in _apresentacoes.ToArray())
                _apresentacoes[item.Key] = item.Value with { PerfilArtistico = _perfil };
            SalvarEstado();
            return _perfil;
        }
    }

    public PerfilArtistico AtualizarFotoPerfil(string fotoUrl)
    {
        lock (_sincronizacao)
        {
            var perfil = _perfil ?? throw new PerfilArtisticoNaoCadastradoException();
            _perfil = perfil with { FotoUrl = fotoUrl };
            foreach (var item in _apresentacoes.ToArray())
                _apresentacoes[item.Key] = item.Value with { PerfilArtistico = _perfil };
            SalvarEstado();
            return _perfil;
        }
    }

    public SessaoDoPublico CriarPerfilPublico(string nome, string email, string senha)
    {
        lock (_sincronizacao)
        {
            var emailNormalizado = NormalizarEmail(email);
            if (_perfisPublicos.Values.Any(item => item.EmailNormalizado == emailNormalizado))
                throw new EmailPublicoJaCadastradoException();

            var registro = new PerfilPublicoRegistro
            {
                Id = Guid.NewGuid(),
                Nome = nome,
                Email = email.Trim(),
                EmailNormalizado = emailNormalizado,
                CriadoEm = DateTimeOffset.UtcNow
            };
            registro.SenhaHash = Senhas.HashPassword(registro, senha);
            _perfisPublicos[registro.Id] = registro;
            var sessao = CriarSessao(registro);
            SalvarEstado();
            return sessao;
        }
    }

    public SessaoDoPublico EntrarPerfilPublico(string email, string senha)
    {
        lock (_sincronizacao)
        {
            var emailNormalizado = NormalizarEmail(email);
            var registro = _perfisPublicos.Values.SingleOrDefault(
                item => item.EmailNormalizado == emailNormalizado)
                ?? throw new CredenciaisPublicasInvalidasException();
            var resultado = Senhas.VerifyHashedPassword(registro, registro.SenhaHash, senha);
            if (resultado == PasswordVerificationResult.Failed)
                throw new CredenciaisPublicasInvalidasException();

            var sessao = CriarSessao(registro);
            SalvarEstado();
            return sessao;
        }
    }

    public PerfilPublico ObterPerfilPublico(string token) =>
        ObterRegistroPublico(token) is { } registro
            ? ParaDominio(registro)
            : throw new SessaoPublicaInvalidaException();

    public PerfilPublico AtualizarFotoPerfilPublico(string token, string fotoUrl)
    {
        lock (_sincronizacao)
        {
            var atual = ObterRegistroPublico(token)
                ?? throw new SessaoPublicaInvalidaException();
            atual.FotoUrl = fotoUrl;
            _perfisPublicos[atual.Id] = atual;
            SalvarEstado();
            return ParaDominio(atual);
        }
    }

    public void EncerrarSessaoPublica(string token)
    {
        lock (_sincronizacao)
        {
            if (string.IsNullOrWhiteSpace(token)) return;
            _sessoesPublicas.TryRemove(GerarHashToken(token), out _);
            SalvarEstado();
        }
    }

}
