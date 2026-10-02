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
            var emailNormalizado = NormalizarEmail(email);
            if (_contasArtistas.Values.Any(
                    item => item.EmailNormalizado == emailNormalizado))
                throw new EmailArtistaJaCadastradoException();
            var registro = new ContaArtistaRegistro
            {
                Id = Guid.NewGuid(),
                Nome = nome.Trim(),
                Email = email.Trim(),
                EmailNormalizado = emailNormalizado,
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

    public PerfilArtistico? ObterPerfil(string token)
    {
        var conta = ExigirRegistroArtista(token);
        return _configuracoesPerfis.GetValueOrDefault(conta.Id)?.Perfil;
    }

    public ConfiguracaoPerfilArtistico? ObterConfiguracaoPerfil(string token)
    {
        var conta = ExigirRegistroArtista(token);
        return _configuracoesPerfis.GetValueOrDefault(conta.Id);
    }

    public PerfilArtistico SalvarPerfilDaConta(string token, SalvarPerfilArtistico dados)
    {
        var conta = ExigirRegistroArtista(token);
        return SalvarPerfilDoArtista(conta.Id, dados);
    }

    public PerfilArtistico AtualizarFotoPerfil(string token, string fotoUrl)
    {
        var conta = ExigirRegistroArtista(token);
        lock (_sincronizacao)
        {
            var configuracao = _configuracoesPerfis.GetValueOrDefault(conta.Id)
                ?? throw new PerfilArtisticoNaoCadastradoException();
            var perfil = configuracao.Perfil with { FotoUrl = fotoUrl };
            _configuracoesPerfis[conta.Id] = configuracao with { Perfil = perfil };
            foreach (var item in _apresentacoes.ToArray()
                         .Where(item => item.Value.ArtistaId == conta.Id))
                _apresentacoes[item.Key] = item.Value with { PerfilArtistico = perfil };
            SalvarEstado();
            return perfil;
        }
    }

    internal PerfilArtistico SalvarPerfil(string nomeArtistico, string? bio)
    {
        var configuracao = _configuracaoPerfil;
        return SalvarPerfil(new SalvarPerfilArtistico(
            nomeArtistico,
            bio,
            configuracao?.Instagram,
            configuracao?.ExibirInstagram ?? false,
            configuracao?.Whatsapp,
            configuracao?.ExibirWhatsapp ?? false,
            configuracao?.PixAtivo ?? false,
            configuracao?.PixChave,
            configuracao?.PixNomeBeneficiario,
            configuracao?.PixCidadeBeneficiario,
            configuracao?.PixMensagem));
    }

    internal PerfilArtistico SalvarPerfil(SalvarPerfilArtistico dados)
    {
        var artistaId = _contasArtistas.Count == 1
            ? _contasArtistas.Keys.Single()
            : (Guid?)null;
        return SalvarPerfilDoArtista(artistaId, dados);
    }

    private PerfilArtistico SalvarPerfilDoArtista(
        Guid? artistaId, SalvarPerfilArtistico dados)
    {
        lock (_sincronizacao)
        {
            var instagram = Limitar(dados.Instagram, 120);
            var whatsapp = Limitar(dados.Whatsapp, 20);
            var pixChave = Limitar(dados.PixChave is null
                ? null
                : ServicoPix.NormalizarChave(dados.PixChave), 140);
            var pixNome = Limitar(dados.PixNomeBeneficiario, 25);
            var pixCidade = Limitar(dados.PixCidadeBeneficiario, 15);
            var pixMensagem = Limitar(dados.PixMensagem, 72);
            var apoioDisponivel = dados.PixAtivo && pixChave is not null &&
                                  pixNome is not null && pixCidade is not null;
            var configuracaoAtual = artistaId is { } id
                ? _configuracoesPerfis.GetValueOrDefault(id)
                : _configuracaoPerfil;
            var perfilAtual = configuracaoAtual?.Perfil;
            var perfil = new PerfilArtistico(
                perfilAtual?.Id ?? Guid.NewGuid(),
                dados.NomeArtistico.Trim(),
                Limitar(dados.Bio, 500),
                perfilAtual?.FotoUrl,
                dados.ExibirInstagram ? instagram : null,
                dados.ExibirWhatsapp ? whatsapp : null,
                apoioDisponivel);
            var configuracao = new ConfiguracaoPerfilArtistico(
                perfil,
                instagram,
                dados.ExibirInstagram,
                whatsapp,
                dados.ExibirWhatsapp,
                dados.PixAtivo,
                pixChave,
                pixNome,
                pixCidade,
                pixMensagem);
            if (artistaId is { } proprietarioId)
                _configuracoesPerfis[proprietarioId] = configuracao;
            _perfil = perfil;
            _configuracaoPerfil = configuracao;
            foreach (var item in _apresentacoes.ToArray()
                         .Where(item => artistaId is null ||
                                        item.Value.ArtistaId == artistaId ||
                                        item.Value.ArtistaId == Guid.Empty))
                _apresentacoes[item.Key] = item.Value with
                {
                    PerfilArtistico = perfil,
                    ArtistaId = artistaId ?? item.Value.ArtistaId
                };
            SalvarEstado();
            return perfil;
        }
    }

    internal PerfilArtistico AtualizarFotoPerfil(string fotoUrl)
    {
        lock (_sincronizacao)
        {
            var perfil = _perfil ?? throw new PerfilArtisticoNaoCadastradoException();
            _perfil = perfil with { FotoUrl = fotoUrl };
            if (_configuracaoPerfil is not null)
            {
                _configuracaoPerfil = _configuracaoPerfil with { Perfil = _perfil };
                if (_contasArtistas.Count == 1)
                    _configuracoesPerfis[_contasArtistas.Keys.Single()] = _configuracaoPerfil;
            }
            foreach (var item in _apresentacoes.ToArray())
                _apresentacoes[item.Key] = item.Value with { PerfilArtistico = _perfil };
            SalvarEstado();
            return _perfil;
        }
    }

    private ContaArtistaRegistro ExigirRegistroArtista(string token) =>
        ObterRegistroArtista(token) ?? throw new SessaoArtistaInvalidaException();

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
