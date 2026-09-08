using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Api;

public sealed class TratamentoDeErros(RequestDelegate proximo)
{
    public async Task InvokeAsync(HttpContext contexto)
    {
        try
        {
            await proximo(contexto);
        }
        catch (PerfilArtisticoNaoCadastradoException excecao)
        {
            contexto.Response.StatusCode = StatusCodes.Status409Conflict;
            await contexto.Response.WriteAsJsonAsync(new { mensagem = excecao.Message });
        }
        catch (ApresentacaoNaoEncontradaException)
        {
            contexto.Response.StatusCode = StatusCodes.Status404NotFound;
            await contexto.Response.WriteAsJsonAsync(new { mensagem = "Apresentação não encontrada." });
        }
        catch (PedidoMusicalNaoEncontradoException)
        {
            contexto.Response.StatusCode = StatusCodes.Status404NotFound;
            await contexto.Response.WriteAsJsonAsync(new { mensagem = "Pedido Musical não encontrado." });
        }
        catch (PedidoMusicalNaoPodeSerCanceladoException)
        {
            contexto.Response.StatusCode = StatusCodes.Status409Conflict;
            await contexto.Response.WriteAsJsonAsync(new
            {
                mensagem = "Este Pedido Musical já foi analisado e não pode mais ser cancelado."
            });
        }
        catch (FilaMusicalInvalidaException)
        {
            contexto.Response.StatusCode = StatusCodes.Status409Conflict;
            await contexto.Response.WriteAsJsonAsync(new { mensagem = "A Fila Musical mudou. Atualize e tente novamente." });
        }
        catch (PedidosEncerradosException)
        {
            contexto.Response.StatusCode = StatusCodes.Status409Conflict;
            await contexto.Response.WriteAsJsonAsync(new { mensagem = "Os pedidos desta Apresentação estão encerrados." });
        }
        catch (EmailPublicoJaCadastradoException)
        {
            contexto.Response.StatusCode = StatusCodes.Status409Conflict;
            await contexto.Response.WriteAsJsonAsync(new { mensagem = "Este e-mail já possui uma conta." });
        }
        catch (CredenciaisPublicasInvalidasException)
        {
            contexto.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await contexto.Response.WriteAsJsonAsync(new { mensagem = "E-mail ou senha inválidos." });
        }
        catch (SessaoPublicaInvalidaException)
        {
            contexto.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await contexto.Response.WriteAsJsonAsync(new { mensagem = "Entre novamente para continuar." });
        }
        catch (IdentificacaoPublicaObrigatoriaException)
        {
            contexto.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await contexto.Response.WriteAsJsonAsync(new
            {
                mensagem = "Entre com seu Perfil do Público para participar desta resenha."
            });
        }
        catch (AvaliacaoInvalidaException)
        {
            contexto.Response.StatusCode = StatusCodes.Status400BadRequest;
            await contexto.Response.WriteAsJsonAsync(new { mensagem = "Escolha de 1 a 5 estrelas." });
        }
        catch (PedidoAindaNaoTocadoException)
        {
            contexto.Response.StatusCode = StatusCodes.Status409Conflict;
            await contexto.Response.WriteAsJsonAsync(new
            {
                mensagem = "A avaliação fica disponível depois que a música for tocada."
            });
        }
        catch (ContaArtistaJaConfiguradaException)
        {
            contexto.Response.StatusCode = StatusCodes.Status409Conflict;
            await contexto.Response.WriteAsJsonAsync(new
            {
                mensagem = "A conta do artista já foi configurada. Entre com seu e-mail e senha."
            });
        }
        catch (CredenciaisArtistaInvalidasException)
        {
            contexto.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await contexto.Response.WriteAsJsonAsync(new { mensagem = "E-mail ou senha inválidos." });
        }
        catch (SessaoArtistaInvalidaException)
        {
            contexto.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await contexto.Response.WriteAsJsonAsync(new
            {
                mensagem = "Entre na conta do artista para continuar."
            });
        }
        catch (RecursoDisponivelSomenteNaResenhaException)
        {
            contexto.Response.StatusCode = StatusCodes.Status409Conflict;
            await contexto.Response.WriteAsJsonAsync(new
            {
                mensagem = "Este recurso está disponível somente na Resenha entre Amigos."
            });
        }
        catch (DestinatarioAloObrigatorioException)
        {
            contexto.Response.StatusCode = StatusCodes.Status400BadRequest;
            await contexto.Response.WriteAsJsonAsync(new
            {
                mensagem = "Informe para quem o artista deve mandar o Alô."
            });
        }
        catch (IdentificacaoAvaliadorObrigatoriaException)
        {
            contexto.Response.StatusCode = StatusCodes.Status400BadRequest;
            await contexto.Response.WriteAsJsonAsync(new
            {
                mensagem = "Não foi possível identificar esta avaliação. Atualize a página."
            });
        }
    }
}
