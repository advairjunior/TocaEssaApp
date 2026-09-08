using System.Text.Json;
using Microsoft.Extensions.Configuration;
using TocaEssaApp.Api.Infraestrutura;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Testes;

public class RepositorioTocaEssaTestes
{
    [Fact]
    public void ContaDoArtistaProtegeEAdotaOsDadosExistentes()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-artista-{Guid.NewGuid()}.db");
        try
        {
            var repositorio = new RepositorioTocaEssa(arquivo);
            repositorio.SalvarPerfil("Duo Aurora", "Voz e violão");
            var apresentacao = repositorio.CriarApresentacao(
                "Noite acústica", new DateOnly(2026, 9, 12), "Café Central");

            var criada = repositorio.CriarContaArtista(
                "Ana", "ana@artista.com", "senha123");

            Assert.Equal("Ana", repositorio.ObterContaArtista(criada.Token).Nome);
            Assert.Throws<ContaArtistaJaConfiguradaException>(() =>
                repositorio.CriarContaArtista("Outro", "outro@artista.com", "senha123"));

            var reiniciado = new RepositorioTocaEssa(arquivo);
            var sessao = reiniciado.EntrarContaArtista(
                "ANA@artista.com", "senha123");

            Assert.Equal(criada.Conta.Id, sessao.Conta.Id);
            Assert.Equal(apresentacao.Id, reiniciado.ListarApresentacoes().Single().Id);
            Assert.Throws<CredenciaisArtistaInvalidasException>(() =>
                reiniciado.EntrarContaArtista("ana@artista.com", "errada"));
            reiniciado.EncerrarSessaoArtista(sessao.Token);
            Assert.Throws<SessaoArtistaInvalidaException>(() =>
                reiniciado.ObterContaArtista(sessao.Token));
        }
        finally
        {
            ExcluirBanco(arquivo);
        }
    }

    [Fact]
    public void CriarApresentacaoExigePerfilArtistico()
    {
        var repositorio = new RepositorioTocaEssa();

        Assert.Throws<PerfilArtisticoNaoCadastradoException>(() =>
            repositorio.CriarApresentacao("Noite acústica", new DateOnly(2026, 9, 12), "Café Central"));
    }

    [Fact]
    public void ApresentacaoCriadaPodeSerConsultadaPeloCodigoSemDiferenciarMaiusculas()
    {
        var repositorio = new RepositorioTocaEssa();
        repositorio.SalvarPerfil("Duo Aurora", "Voz e violão");

        var criada = repositorio.CriarApresentacao(
            "Noite acústica", new DateOnly(2026, 9, 12), "Café Central");
        var encontrada = repositorio.ObterApresentacaoPublica(criada.Codigo.ToLowerInvariant());

        Assert.NotNull(encontrada);
        Assert.Equal("Duo Aurora", encontrada.PerfilArtistico.NomeArtistico);
        Assert.Equal(6, encontrada.Codigo.Length);
    }

    [Fact]
    public void PedidoAceitoEntraDiretoNoFimDaFilaPublica()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
        var pedido = repositorio.CriarPedido(apresentacao.Codigo, "Evidências", "Chitãozinho & Xororó", "Ana");

        Assert.Empty(repositorio.ListarFilaPublica(apresentacao.Codigo));
        var aceito = repositorio.AlterarStatus(apresentacao.Id, pedido.Id, StatusPedidoMusical.Aceito);

        Assert.Equal(1, aceito.Posicao);
        Assert.Single(repositorio.ListarFilaPublica(apresentacao.Codigo));
    }

    [Fact]
    public void ArtistaPodeReordenarFilaComoUmaPlaylist()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
        var primeiro = repositorio.CriarPedido(apresentacao.Codigo, "Primeira", null, null);
        var segundo = repositorio.CriarPedido(apresentacao.Codigo, "Segunda", null, null);
        repositorio.AlterarStatus(apresentacao.Id, primeiro.Id, StatusPedidoMusical.Aceito);
        repositorio.AlterarStatus(apresentacao.Id, segundo.Id, StatusPedidoMusical.Aceito);

        repositorio.ReordenarFila(apresentacao.Id, [segundo.Id, primeiro.Id]);
        var fila = repositorio.ListarFilaPublica(apresentacao.Codigo).ToArray();

        Assert.Equal("Segunda", fila[0].Musica);
        Assert.Equal(1, fila[0].Posicao);
        Assert.Equal("Primeira", fila[1].Musica);
        Assert.Equal(2, fila[1].Posicao);
    }

    [Fact]
    public void PedidoRecusadoNaoApareceNaFilaPublica()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
        var pedido = repositorio.CriarPedido(apresentacao.Codigo, "Música desconhecida", null, null);

        repositorio.AlterarStatus(apresentacao.Id, pedido.Id, StatusPedidoMusical.NaoConhecemos);

        Assert.Empty(repositorio.ListarFilaPublica(apresentacao.Codigo));
        Assert.Single(repositorio.ListarPedidosDoArtista(apresentacao.Id));
    }

    [Fact]
    public void ApresentacaoComPedidosEncerradosNaoAceitaNovosPedidos()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
        repositorio.AlterarPedidos(apresentacao.Id, false);

        Assert.Throws<PedidosEncerradosException>(() =>
            repositorio.CriarPedido(apresentacao.Codigo, "Evidências", null, null));
    }

    [Fact]
    public void DadosContinuamDisponiveisDepoisDeReiniciarRepositorio()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-{Guid.NewGuid()}.db");
        try
        {
            var repositorio = new RepositorioTocaEssa(arquivo);
            repositorio.SalvarPerfil("Duo Aurora", "Voz e violão");
            var apresentacao = repositorio.CriarApresentacao(
                "Noite acústica", new DateOnly(2026, 9, 12), "Café Central");
            var pedido = repositorio.CriarPedido(
                apresentacao.Codigo, "Evidências", "Chitãozinho & Xororó", "Ana");
            repositorio.AlterarStatus(apresentacao.Id, pedido.Id, StatusPedidoMusical.Aceito);

            var reiniciado = new RepositorioTocaEssa(arquivo);

            Assert.Equal("Duo Aurora", reiniciado.ObterPerfil()?.NomeArtistico);
            Assert.Equal(apresentacao.Codigo, reiniciado.ListarApresentacoes().Single().Codigo);
            Assert.Equal("Evidências", reiniciado.ListarFilaPublica(apresentacao.Codigo).Single().Musica);
        }
        finally
        {
            ExcluirBanco(arquivo);
        }
    }

    [Fact]
    public void AlterarPerfilAtualizaApresentacoesExistentes()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);

        repositorio.SalvarPerfil("Duo Aurora Renovado", "Novo repertório");

        var publica = repositorio.ObterApresentacaoPublica(apresentacao.Codigo);
        Assert.Equal("Duo Aurora Renovado", publica?.PerfilArtistico.NomeArtistico);
        Assert.Equal("Novo repertório", publica?.PerfilArtistico.Bio);
    }

    [Fact]
    public void ArtistaPodeEditarApresentacaoSemAlterarCodigoPublico()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);

        var editada = repositorio.EditarApresentacao(
            apresentacao.Id, "Especial de sábado", new DateOnly(2026, 10, 3), "Praça Central");

        Assert.Equal(apresentacao.Codigo, editada.Codigo);
        Assert.Equal("Especial de sábado", editada.Nome);
        Assert.Equal(new DateOnly(2026, 10, 3), editada.Data);
        Assert.Equal("Praça Central", editada.Local);
    }

    [Fact]
    public void ExcluirApresentacaoRemoveTambemSeusPedidos()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
        repositorio.CriarPedido(apresentacao.Codigo, "Evidências", null, null);

        repositorio.ExcluirApresentacao(apresentacao.Id);

        Assert.Null(repositorio.ObterApresentacaoPublica(apresentacao.Codigo));
        Assert.Empty(repositorio.ListarPedidosDoArtista(apresentacao.Id));
    }

    [Fact]
    public void IniciarEEncerrarApresentacaoControlaNovosPedidos()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);

        var iniciada = repositorio.AlterarStatusApresentacao(
            apresentacao.Id, StatusApresentacao.EmAndamento);
        Assert.Equal(StatusApresentacao.EmAndamento, iniciada.Status);
        Assert.True(iniciada.PedidosAbertos);

        var encerrada = repositorio.AlterarStatusApresentacao(
            apresentacao.Id, StatusApresentacao.Encerrada);
        Assert.Equal(StatusApresentacao.Encerrada, encerrada.Status);
        Assert.False(encerrada.PedidosAbertos);
        Assert.Throws<PedidosEncerradosException>(() =>
            repositorio.CriarPedido(apresentacao.Codigo, "Evidências", null, null));
    }

    [Fact]
    public void TocarProximaMusicaFinalizaAnteriorERenumeraFila()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
        var primeira = repositorio.CriarPedido(apresentacao.Codigo, "Primeira", null, null);
        var segunda = repositorio.CriarPedido(apresentacao.Codigo, "Segunda", null, null);
        var terceira = repositorio.CriarPedido(apresentacao.Codigo, "Terceira", null, null);
        repositorio.AlterarStatus(apresentacao.Id, primeira.Id, StatusPedidoMusical.Aceito);
        repositorio.AlterarStatus(apresentacao.Id, segunda.Id, StatusPedidoMusical.Aceito);
        repositorio.AlterarStatus(apresentacao.Id, terceira.Id, StatusPedidoMusical.Aceito);

        repositorio.AlterarStatus(apresentacao.Id, primeira.Id, StatusPedidoMusical.TocandoAgora);
        repositorio.AlterarStatus(apresentacao.Id, segunda.Id, StatusPedidoMusical.TocandoAgora);
        var pedidos = repositorio.ListarPedidosDoArtista(apresentacao.Id).ToArray();

        Assert.Equal(StatusPedidoMusical.Finalizado,
            pedidos.Single(item => item.Id == primeira.Id).Status);
        Assert.Null(pedidos.Single(item => item.Id == primeira.Id).Posicao);
        Assert.Equal(StatusPedidoMusical.TocandoAgora,
            pedidos.Single(item => item.Id == segunda.Id).Status);
        Assert.Null(pedidos.Single(item => item.Id == segunda.Id).Posicao);
        Assert.Equal(1, pedidos.Single(item => item.Id == terceira.Id).Posicao);
        Assert.Single(pedidos, item => item.Status == StatusPedidoMusical.TocandoAgora);
    }

    [Fact]
    public void PublicoPodeCancelarSomentePedidoAindaNaoAnalisado()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
        var aguardando = repositorio.CriarPedido(
            apresentacao.Codigo, "Pedido enviado errado", null, "Ana");
        var aceito = repositorio.CriarPedido(
            apresentacao.Codigo, "Pedido aceito", null, "Beto");
        repositorio.AlterarStatus(apresentacao.Id, aceito.Id, StatusPedidoMusical.Aceito);

        var cancelado = repositorio.CancelarPedidoPeloPublico(
            apresentacao.Codigo, aguardando.Id);

        Assert.Equal(StatusPedidoMusical.CanceladoPeloPublico, cancelado.Status);
        Assert.Throws<PedidoMusicalNaoPodeSerCanceladoException>(() =>
            repositorio.CancelarPedidoPeloPublico(apresentacao.Codigo, aceito.Id));
        Assert.Single(repositorio.ListarFilaPublica(apresentacao.Codigo));
    }

    [Fact]
    public void ApresentacaoPodeSerCriadaComoResenhaEntreAmigos()
    {
        var repositorio = new RepositorioTocaEssa();
        repositorio.SalvarPerfil("Duo Aurora", null);

        var resenha = repositorio.CriarApresentacao(
            "Resenha de sexta", new DateOnly(2026, 9, 18), "Casa da Ana",
            TipoApresentacao.ResenhaEntreAmigos);

        Assert.Equal(TipoApresentacao.ResenhaEntreAmigos, resenha.Tipo);
        Assert.Equal(resenha.Tipo,
            repositorio.ObterApresentacaoPublica(resenha.Codigo)?.Tipo);
    }

    [Fact]
    public void FotoDoPerfilArtisticoApareceNasApresentacoesEPersiste()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-foto-{Guid.NewGuid()}.db");
        try
        {
            var repositorio = new RepositorioTocaEssa(arquivo);
            repositorio.SalvarPerfil("Duo Aurora", null);
            var apresentacao = repositorio.CriarApresentacao(
                "Noite acústica", new DateOnly(2026, 9, 12), "Café Central");

            repositorio.AtualizarFotoPerfil("/arquivos/perfil-artista.jpg?v=1");
            var reiniciado = new RepositorioTocaEssa(arquivo);

            Assert.Equal("/arquivos/perfil-artista.jpg?v=1", reiniciado.ObterPerfil()?.FotoUrl);
            Assert.Equal("/arquivos/perfil-artista.jpg?v=1",
                reiniciado.ObterApresentacaoPublica(apresentacao.Codigo)?.PerfilArtistico.FotoUrl);
        }
        finally
        {
            ExcluirBanco(arquivo);
        }
    }

    [Fact]
    public void FotoDaRetrospectivaFicaSalvaNaResenha()
    {
        var arquivo = Path.Combine(
            Path.GetTempPath(), $"tocaessa-resenha-foto-{Guid.NewGuid()}.db");
        try
        {
            var repositorio = new RepositorioTocaEssa(arquivo);
            repositorio.SalvarPerfil("Duo Aurora", null);
            var resenha = repositorio.CriarApresentacao(
                "Resenha de sexta", new DateOnly(2026, 9, 18), "Casa da Ana",
                TipoApresentacao.ResenhaEntreAmigos);

            repositorio.AtualizarFotoRetrospectiva(
                resenha.Id, "/arquivos/resenha.jpg?v=1");
            var reiniciado = new RepositorioTocaEssa(arquivo);

            Assert.Equal("/arquivos/resenha.jpg?v=1",
                reiniciado.ObterApresentacao(resenha.Id)?.FotoRetrospectivaUrl);
        }
        finally
        {
            ExcluirBanco(arquivo);
        }
    }

    [Fact]
    public void DadosDoJsonExistenteSaoImportadosAutomaticamenteParaSqlite()
    {
        var identificador = Guid.NewGuid();
        var arquivoBanco = Path.Combine(Path.GetTempPath(), $"tocaessa-{identificador}.db");
        var arquivoJson = Path.Combine(Path.GetTempPath(), $"tocaessa-{identificador}.json");
        var perfil = new PerfilArtistico(Guid.NewGuid(), "Duo Aurora", "Voz e violão");
        var apresentacao = new Apresentacao(
            Guid.NewGuid(), "Noite acústica", new DateOnly(2026, 9, 12),
            "Café Central", "A1B2C3", perfil);
        var pedido = new PedidoMusical(
            Guid.NewGuid(), apresentacao.Id, "Evidências", null, "Ana",
            StatusPedidoMusical.Aguardando, null, DateTimeOffset.UtcNow);

        try
        {
            File.WriteAllText(arquivoJson, JsonSerializer.Serialize(
                new EstadoPersistido(perfil, [apresentacao], [pedido])));

            var repositorio = new RepositorioTocaEssa(arquivoBanco, arquivoJson);
            var reiniciado = new RepositorioTocaEssa(arquivoBanco, arquivoJson);

            Assert.True(File.Exists(arquivoBanco));
            Assert.Equal("Duo Aurora", reiniciado.ObterPerfil()?.NomeArtistico);
            Assert.Equal("Noite acústica",
                reiniciado.ObterApresentacaoPublica("A1B2C3")?.Nome);
            Assert.Equal("Evidências",
                reiniciado.ListarPedidosDoArtista(apresentacao.Id).Single().Musica);
        }
        finally
        {
            ExcluirBanco(arquivoBanco);
            if (File.Exists(arquivoJson)) File.Delete(arquivoJson);
        }
    }

    [Fact]
    public void ContaDoPublicoPodeEntrarNovamenteDepoisDeReiniciar()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-conta-{Guid.NewGuid()}.db");
        try
        {
            var repositorio = new RepositorioTocaEssa(arquivo);
            var criada = repositorio.CriarPerfilPublico(
                "Ana Souza", "ana@example.com", "senha123");

            var reiniciado = new RepositorioTocaEssa(arquivo);
            var sessao = reiniciado.EntrarPerfilPublico(
                "ANA@example.com", "senha123");

            Assert.Equal(criada.Perfil.Id, sessao.Perfil.Id);
            Assert.Equal("Ana Souza", reiniciado.ObterPerfilPublico(sessao.Token).Nome);
            Assert.Throws<CredenciaisPublicasInvalidasException>(() =>
                reiniciado.EntrarPerfilPublico("ana@example.com", "errada"));
        }
        finally
        {
            ExcluirBanco(arquivo);
        }
    }

    [Fact]
    public void ResenhaExigeContaEAssociaPedidoAoPerfilDoPublico()
    {
        var repositorio = new RepositorioTocaEssa();
        repositorio.SalvarPerfil("Duo Aurora", null);
        var resenha = repositorio.CriarApresentacao(
            "Resenha de sexta", new DateOnly(2026, 9, 18), "Casa da Ana",
            TipoApresentacao.ResenhaEntreAmigos);
        var sessao = repositorio.CriarPerfilPublico(
            "Ana Souza", "ana@example.com", "senha123");

        Assert.Throws<IdentificacaoPublicaObrigatoriaException>(() =>
            repositorio.CriarPedido(resenha.Codigo, "Evidências", null, "Outro nome"));

        var pedido = repositorio.CriarPedido(
            resenha.Codigo, "Evidências", null, "Outro nome", sessao.Token);

        Assert.Equal(sessao.Perfil.Id, pedido.PublicoId);
        Assert.Equal("Ana Souza", pedido.NomeSolicitante);
        Assert.Equal(pedido.Id,
            repositorio.ListarPedidosDoPublico(resenha.Codigo, sessao.Token).Single().Id);
    }

    [Fact]
    public void ApresentacaoPublicaAceitaConvidadoOuPerfilDoPublico()
    {
        var repositorio = new RepositorioTocaEssa();
        repositorio.SalvarPerfil("Duo Aurora", null);
        var apresentacao = repositorio.CriarApresentacao(
            "Noite acústica", new DateOnly(2026, 9, 18), "Café Central");
        var sessao = repositorio.CriarPerfilPublico(
            "Ana Souza", "ana@example.com", "senha123");

        var convidado = repositorio.CriarPedido(
            apresentacao.Codigo, "Primeira", null, "Beto");
        var identificado = repositorio.CriarPedido(
            apresentacao.Codigo, "Segunda", null, "Nome ignorado", sessao.Token);

        Assert.Null(convidado.PublicoId);
        Assert.Equal("Beto", convidado.NomeSolicitante);
        Assert.Equal(sessao.Perfil.Id, identificado.PublicoId);
        Assert.Equal("Ana Souza", identificado.NomeSolicitante);
        Assert.Equal(identificado.Id,
            repositorio.ListarPedidosDoPublico(
                apresentacao.Codigo, sessao.Token).Single().Id);
    }

    [Fact]
    public void PublicoAvaliaDeUmaACincoEstrelasSomenteDepoisDaMusicaTocada()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-avaliacao-{Guid.NewGuid()}.db");
        try
        {
            var repositorio = new RepositorioTocaEssa(arquivo);
            repositorio.SalvarPerfil("Duo Aurora", null);
            var apresentacao = repositorio.CriarApresentacao(
                "Noite acústica", new DateOnly(2026, 9, 12), "Café Central");
            var pedido = repositorio.CriarPedido(
                apresentacao.Codigo, "Evidências", null, "Ana");

            Assert.Throws<PedidoAindaNaoTocadoException>(() =>
                repositorio.AvaliarPedidoPeloPublico(
                    apresentacao.Codigo, pedido.Id, 5, "aparelho-ana"));

            repositorio.AlterarStatus(
                apresentacao.Id, pedido.Id, StatusPedidoMusical.Finalizado);
            var avaliado = repositorio.AvaliarPedidoPeloPublico(
                apresentacao.Codigo, pedido.Id, 5, "aparelho-ana");
            var reiniciado = new RepositorioTocaEssa(arquivo);

            Assert.Equal(5, avaliado.MinhaAvaliacao);
            Assert.Equal(5, reiniciado.ListarFilaPublica(
                apresentacao.Codigo, "aparelho-ana").Single().MinhaAvaliacao);
            Assert.Throws<AvaliacaoInvalidaException>(() =>
                repositorio.AvaliarPedidoPeloPublico(
                    apresentacao.Codigo, pedido.Id, 6, "aparelho-ana"));
        }
        finally
        {
            ExcluirBanco(arquivo);
        }
    }

    [Fact]
    public void EstatisticasResumemApresentacaoEHistoricoDoParticipante()
    {
        var repositorio = new RepositorioTocaEssa();
        repositorio.SalvarPerfil("Duo Aurora", null);
        var resenha = repositorio.CriarApresentacao(
            "Resenha de sexta", new DateOnly(2026, 9, 18), "Casa da Ana",
            TipoApresentacao.ResenhaEntreAmigos);
        var outraResenha = repositorio.CriarApresentacao(
            "Resenha de sábado", new DateOnly(2026, 9, 19), "Casa do Beto",
            TipoApresentacao.ResenhaEntreAmigos);
        var sessao = repositorio.CriarPerfilPublico(
            "Ana", "ana@example.com", "senha123");
        var tocado = repositorio.CriarPedido(
            resenha.Codigo, "Evidências", null, null, sessao.Token);
        var recusado = repositorio.CriarPedido(
            resenha.Codigo, "evidências", null, null, sessao.Token);
        repositorio.CriarPedido(
            outraResenha.Codigo, "Tocando em Frente", null, null, sessao.Token);
        repositorio.AlterarStatus(
            resenha.Id, tocado.Id, StatusPedidoMusical.Finalizado);
        repositorio.AvaliarPedidoPeloPublico(
            resenha.Codigo, tocado.Id, 5, null, sessao.Token);
        repositorio.AlterarStatus(
            resenha.Id, recusado.Id, StatusPedidoMusical.NaoConhecemos);

        var estatisticasApresentacao =
            repositorio.ObterEstatisticasDaApresentacao(resenha.Id);
        var estatisticasPublico =
            repositorio.ObterEstatisticasDoPublico(sessao.Token);

        Assert.Equal(2, estatisticasApresentacao.TotalPedidos);
        Assert.Equal(1, estatisticasApresentacao.Tocados);
        Assert.Equal(1, estatisticasApresentacao.Recusados);
        Assert.Equal(5, estatisticasApresentacao.MediaAvaliacoes);
        Assert.Equal(2, estatisticasApresentacao.MusicasMaisPedidas.Single().Quantidade);
        Assert.Equal(2, estatisticasPublico.Participacoes);
        Assert.Equal(3, estatisticasPublico.Pedidos);
        Assert.Equal(1, estatisticasPublico.PedidosTocados);
        Assert.Equal(5, estatisticasPublico.MediaAvaliacoes);
    }

    [Fact]
    public void ResenhaListaParticipantesSemExporPedidosRecusados()
    {
        var repositorio = new RepositorioTocaEssa();
        repositorio.SalvarPerfil("Duo Aurora", null);
        var resenha = repositorio.CriarApresentacao(
            "Resenha de sexta", new DateOnly(2026, 9, 18), "Casa da Ana",
            TipoApresentacao.ResenhaEntreAmigos);
        var ana = repositorio.CriarPerfilPublico(
            "Ana", "ana@example.com", "senha123");
        var beto = repositorio.CriarPerfilPublico(
            "Beto", "beto@example.com", "senha123");
        var carla = repositorio.CriarPerfilPublico(
            "Carla", "carla@example.com", "senha123");
        repositorio.RegistrarParticipacaoNaResenha(resenha.Codigo, carla.Token);
        var tocado = repositorio.CriarPedido(
            resenha.Codigo, "Evidências", null, null, ana.Token);
        var recusado = repositorio.CriarPedido(
            resenha.Codigo, "Segredo", null, null, ana.Token);
        repositorio.CriarPedido(
            resenha.Codigo, "Depois", null, null, beto.Token);
        repositorio.AlterarStatus(
            resenha.Id, tocado.Id, StatusPedidoMusical.Finalizado);
        repositorio.AlterarStatus(
            resenha.Id, recusado.Id, StatusPedidoMusical.NaoConhecemos);

        var participantes = repositorio.ListarParticipantesDaResenha(
            resenha.Codigo, beto.Token);
        var participanteAna = participantes.Single(item => item.Nome == "Ana");
        var participanteCarla = participantes.Single(item => item.Nome == "Carla");

        Assert.Equal(4, participantes.Count);
        Assert.True(participantes.Single(item => item.Nome == "Duo Aurora").EhArtista);
        Assert.Equal(1, participanteAna.Pedidos);
        Assert.Equal(1, participanteAna.PedidosTocados);
        Assert.Equal(0, participanteCarla.Pedidos);
        Assert.Equal(0, participanteCarla.PedidosTocados);
        Assert.Empty(participanteCarla.MusicasMaisPedidas);
        Assert.Equal("Evidências", participanteAna.MusicasMaisPedidas.Single().Musica);
        Assert.DoesNotContain(
            participantes.SelectMany(item => item.MusicasMaisPedidas),
            item => item.Musica == "Segredo");
    }

    [Fact]
    public void ResenhaSalvaComoOPublicoQuerParticiparDaMusica()
    {
        var arquivo = Path.Combine(
            Path.GetTempPath(), $"tocaessa-participacao-{Guid.NewGuid()}.db");
        try
        {
            var repositorio = new RepositorioTocaEssa(arquivo);
            repositorio.SalvarPerfil("Duo Aurora", null);
            var resenha = repositorio.CriarApresentacao(
                "Resenha de sexta", new DateOnly(2026, 9, 18), "Casa da Ana",
                TipoApresentacao.ResenhaEntreAmigos);
            var sessao = repositorio.CriarPerfilPublico(
                "Ana", "ana@example.com", "senha123");
            var convidada = repositorio.CriarPerfilPublico(
                "Carla", "carla@example.com", "senha123");
            repositorio.RegistrarParticipacaoNaResenha(
                resenha.Codigo, convidada.Token);

            var pedido = repositorio.CriarPedido(
                resenha.Codigo,
                "Evidências",
                "Chitãozinho & Xororó",
                null,
                sessao.Token,
                FormaParticipacaoPedido.EuCanto,
                "G",
                "Para todo mundo cantar junto");
            var reiniciado = new RepositorioTocaEssa(arquivo);
            var salvo = reiniciado.ListarPedidosDoArtista(resenha.Id).Single();

            Assert.Equal(FormaParticipacaoPedido.EuCanto,
                pedido.FormaParticipacao);
            Assert.Equal(FormaParticipacaoPedido.EuCanto,
                salvo.FormaParticipacao);
            Assert.Equal("G", salvo.TomPreferido);
            Assert.Equal("Para todo mundo cantar junto", salvo.Recado);
            var participanteSemPedido = reiniciado
                .ListarParticipantesDaResenha(resenha.Id)
                .Single(item => item.Nome == "Carla");
            Assert.Equal(0, participanteSemPedido.Pedidos);
        }
        finally
        {
            ExcluirBanco(arquivo);
        }
    }

    [Fact]
    public void ApresentacaoPublicaIgnoraOpcoesExclusivasDaResenha()
    {
        var repositorio = new RepositorioTocaEssa();
        repositorio.SalvarPerfil("Duo Aurora", null);
        var apresentacao = repositorio.CriarApresentacao(
            "Noite acústica", new DateOnly(2026, 9, 18), "Café Central");

        var pedido = repositorio.CriarPedido(
            apresentacao.Codigo,
            "Evidências",
            null,
            "Ana",
            null,
            FormaParticipacaoPedido.EuCanto,
            "G",
            "Quero cantar");

        Assert.Equal(FormaParticipacaoPedido.PedidoNormal,
            pedido.FormaParticipacao);
        Assert.Null(pedido.TomPreferido);
        Assert.Null(pedido.Recado);
    }

    [Fact]
    public void TodosPodemAvaliarAMesmaMusicaEAMediaFicaPublica()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
        var perfil = repositorio.CriarPerfilPublico(
            "Beto", "beto@example.com", "senha123");
        var pedido = repositorio.CriarPedido(
            apresentacao.Codigo, "Evidências", null, "Ana");
        repositorio.AlterarStatus(
            apresentacao.Id, pedido.Id, StatusPedidoMusical.Finalizado);

        repositorio.AvaliarPedidoPeloPublico(
            apresentacao.Codigo, pedido.Id, 5, "aparelho-ana");
        repositorio.AvaliarPedidoPeloPublico(
            apresentacao.Codigo, pedido.Id, 3, null, perfil.Token);

        var paraAna = repositorio.ListarFilaPublica(
            apresentacao.Codigo, "aparelho-ana").Single();
        var paraBeto = repositorio.ListarFilaPublica(
            apresentacao.Codigo, null, perfil.Token).Single();
        Assert.Equal(2, paraAna.QuantidadeAvaliacoes);
        Assert.Equal(4, paraAna.MediaAvaliacoes);
        Assert.Equal(5, paraAna.MinhaAvaliacao);
        Assert.Equal(3, paraBeto.MinhaAvaliacao);
    }

    [Fact]
    public void FilaPublicaAgrupaPedidosIguaisEMostraQuemPediu()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
        var primeiro = repositorio.CriarPedido(
            apresentacao.Codigo, "Evidências", null, "Ana");
        var segundo = repositorio.CriarPedido(
            apresentacao.Codigo, "evidências", null, "Beto");
        repositorio.AlterarStatus(
            apresentacao.Id, primeiro.Id, StatusPedidoMusical.Aceito);
        repositorio.AlterarStatus(
            apresentacao.Id, segundo.Id, StatusPedidoMusical.Aceito);

        var item = repositorio.ListarFilaPublica(apresentacao.Codigo).Single();

        Assert.Equal(2, item.Solicitantes?.Count);
        Assert.Contains("Ana", item.Solicitantes!);
        Assert.Contains("Beto", item.Solicitantes!);
    }

    [Fact]
    public void PedidoAntesDoInicioContinuaAguardandoDecisaoDoArtista()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);

        var pedido = repositorio.CriarPedido(
            apresentacao.Codigo, "Tempo Perdido", null, "Ana");

        Assert.Equal(StatusApresentacao.Agendada, apresentacao.Status);
        Assert.Equal(StatusPedidoMusical.Aguardando, pedido.Status);
        Assert.Equal(StatusPedidoMusical.Aguardando,
            repositorio.ListarPedidosDoArtista(apresentacao.Id).Single().Status);
    }

    [Fact]
    public void PublicoPodePedirAloParaOArtistaMandarNoMicrofone()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);

        var alo = repositorio.CriarPedido(
            apresentacao.Codigo, "", null, "Ana", tipo: TipoPedido.Alo,
            destinatarioAlo: "João da mesa 8", recado: "É aniversário dele");

        Assert.Equal(TipoPedido.Alo, alo.Tipo);
        Assert.Equal("João da mesa 8", alo.DestinatarioAlo);
        Assert.Equal(StatusPedidoMusical.Aguardando, alo.Status);
        Assert.Empty(repositorio.ListarFilaPublica(apresentacao.Codigo));
        Assert.Single(repositorio.ListarPedidosDoArtista(apresentacao.Id));
    }

    [Fact]
    public async Task ImagemFicaPersistidaNoBancoSemServicoExterno()
    {
        var raiz = Path.Combine(Path.GetTempPath(), $"tocaessa-imagem-{Guid.NewGuid()}");
        var banco = Path.Combine(raiz, "tocaessa.db");
        Directory.CreateDirectory(raiz);
        try
        {
            var configuracao = new ConfigurationBuilder().Build();
            using (var armazenamento = new ArmazenamentoDeImagens(
                       configuracao, banco))
                await armazenamento.Salvar(
                    "perfil.jpg", "image/jpeg", [1, 2, 3, 4], default);

            using var reiniciado = new ArmazenamentoDeImagens(
                configuracao, banco);
            var imagem = await reiniciado.Abrir("imagens/perfil.jpg", default);

            Assert.NotNull(imagem);
            Assert.Equal([1, 2, 3, 4], imagem.Value.Conteudo);
            Assert.Equal("image/jpeg", imagem.Value.TipoDeConteudo);
        }
        finally
        {
            if (Directory.Exists(raiz)) Directory.Delete(raiz, true);
        }
    }

    private static RepositorioTocaEssa CriarRepositorioComApresentacao(out Apresentacao apresentacao)
    {
        var repositorio = new RepositorioTocaEssa();
        repositorio.SalvarPerfil("Duo Aurora", null);
        apresentacao = repositorio.CriarApresentacao(
            "Noite acústica", new DateOnly(2026, 9, 12), "Café Central");
        return repositorio;
    }

    private static void ExcluirBanco(string caminho)
    {
        foreach (var arquivo in new[] { caminho, $"{caminho}-shm", $"{caminho}-wal" })
            if (File.Exists(arquivo)) File.Delete(arquivo);
    }
}
