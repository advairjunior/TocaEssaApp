param(
    [int]$PortaApi = 5080,
    [int]$PortaWeb = 5173,
    [switch]$SomenteValidar
)

$ErrorActionPreference = 'Stop'

$raizProjeto = $PSScriptRoot
$projetoApi = Join-Path $raizProjeto 'servidor\TocaEssaApp.Api\TocaEssaApp.Api.csproj'
$pastaCliente = Join-Path $raizProjeto 'cliente'
$enderecoApi = "http://127.0.0.1:$PortaApi"
$processoApi = $null

function Testar-Api {
    try {
        $resposta = Invoke-RestMethod -Uri "$enderecoApi/api/saude" -TimeoutSec 1
        return $resposta.status -eq 'ok'
    }
    catch {
        return $false
    }
}

try {
    if (-not (Testar-Api)) {
        Write-Host 'Iniciando a API do TocaEssaApp...'
        $dotnet = (Get-Command dotnet -ErrorAction Stop).Source
        $argumentosApi = @(
            'run',
            '--project', $projetoApi,
            '--no-launch-profile',
            '--urls', "http://0.0.0.0:$PortaApi"
        )
        $processoApi = Start-Process `
            -FilePath $dotnet `
            -ArgumentList $argumentosApi `
            -WorkingDirectory $raizProjeto `
            -WindowStyle Hidden `
            -PassThru

        $apiDisponivel = $false
        for ($tentativa = 0; $tentativa -lt 60; $tentativa++) {
            if ($processoApi.HasExited) {
                throw 'A API foi encerrada antes de ficar disponível.'
            }
            if (Testar-Api) {
                $apiDisponivel = $true
                break
            }
            Start-Sleep -Milliseconds 500
        }
        if (-not $apiDisponivel) {
            throw "A API não respondeu em $enderecoApi."
        }
    }
    else {
        Write-Host "A API já está disponível em $enderecoApi."
    }

    if ($SomenteValidar) {
        Write-Host 'Inicialização validada com sucesso.'
        return
    }

    Write-Host 'Abrindo o TocaEssaApp no navegador...'
    Push-Location $pastaCliente
    try {
        & flutter run `
            -d chrome `
            --web-port $PortaWeb `
            --dart-define="API_URL=$enderecoApi"
        if ($LASTEXITCODE -ne 0) {
            throw "O Flutter foi encerrado com o código $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    if ($null -ne $processoApi -and -not $processoApi.HasExited) {
        Write-Host 'Encerrando a API do TocaEssaApp...'
        Stop-Process -Id $processoApi.Id
        [void]$processoApi.WaitForExit(5000)
    }
}
