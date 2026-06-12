<#
.SYNOPSIS
    Otimizador interativo do Windows 10 - deixa o sistema leve e rapido.

.DESCRIPTION
    Cada otimizacao pergunta Y (sim) ou N (nao) antes de aplicar.
    Foco em desativar efeitos visuais, animacoes, transparencia e
    coisas de aparencia que pesam no sistema.

    Execute como ADMINISTRADOR:
        - Clique direito no PowerShell > "Executar como administrador"
        - Ou:  powershell -ExecutionPolicy Bypass -File .\Otimizar-Windows10.ps1

    Autor: Alexandre Alan
#>

# ----------------------------------------------------------------------
#  Verifica se esta rodando como administrador
# ----------------------------------------------------------------------
$ehAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $ehAdmin) {
    Write-Host ""
    Write-Host " ERRO: Este script precisa ser executado como ADMINISTRADOR." -ForegroundColor Red
    Write-Host " Feche, clique com o botao direito no PowerShell e escolha" -ForegroundColor Yellow
    Write-Host " 'Executar como administrador', depois rode o script de novo." -ForegroundColor Yellow
    Write-Host ""
    Read-Host " Pressione ENTER para sair"
    exit 1
}

# ----------------------------------------------------------------------
#  Funcoes auxiliares
# ----------------------------------------------------------------------
$Global:Aplicadas = 0
$Global:Puladas   = 0

function Perguntar {
    param([string]$Texto)
    while ($true) {
        $r = Read-Host " $Texto (Y/N)"
        switch ($r.ToUpper()) {
            "Y" { return $true }
            "S" { return $true }
            "N" { return $false }
            default { Write-Host "   Digite Y para sim ou N para nao." -ForegroundColor DarkGray }
        }
    }
}

function Definir-Registro {
    param(
        [string]$Caminho,
        [string]$Nome,
        $Valor,
        [string]$Tipo = "DWord"
    )
    if (-not (Test-Path $Caminho)) {
        New-Item -Path $Caminho -Force | Out-Null
    }
    New-ItemProperty -Path $Caminho -Name $Nome -Value $Valor -PropertyType $Tipo -Force | Out-Null
}

function Otimizacao {
    param(
        [string]$Titulo,
        [string]$Descricao,
        [scriptblock]$Acao
    )
    Write-Host ""
    Write-Host ("-" * 64) -ForegroundColor DarkCyan
    Write-Host "  $Titulo" -ForegroundColor Cyan
    Write-Host "  $Descricao" -ForegroundColor Gray
    if (Perguntar "Aplicar?") {
        try {
            & $Acao
            Write-Host "   [OK] Aplicado." -ForegroundColor Green
            $Global:Aplicadas++
        } catch {
            Write-Host "   [ERRO] $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "   [--] Pulado." -ForegroundColor DarkYellow
        $Global:Puladas++
    }
}

# Chaves de registro usadas com frequencia
$HKCU = "HKCU:"
$RegMetrics   = "$HKCU\Control Panel\Desktop\WindowMetrics"
$RegDesktop   = "$HKCU\Control Panel\Desktop"
$RegAdvanced  = "$HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$RegVisualFX  = "$HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
$RegDWM       = "$HKCU\Software\Microsoft\Windows\DWM"

# ----------------------------------------------------------------------
#  Cabecalho
# ----------------------------------------------------------------------
Clear-Host
Write-Host ""
Write-Host "  ==============================================================" -ForegroundColor Magenta
Write-Host "        OTIMIZADOR DE APARENCIA - WINDOWS 10 (leve e rapido)" -ForegroundColor White
Write-Host "  ==============================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Voce decide cada mudanca digitando Y (sim) ou N (nao)." -ForegroundColor Gray
Write-Host "  Dica: crie um ponto de restauracao antes (recomendado)." -ForegroundColor DarkGray
Write-Host ""

# Ponto de restauracao (opcional)
Otimizacao -Titulo "Criar ponto de restauracao do sistema" `
    -Descricao "Seguranca: permite desfazer tudo caso algo de errado." `
    -Acao {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "Antes do Otimizador" -RestorePointType "MODIFY_SETTINGS"
    }

# ----------------------------------------------------------------------
#  EFEITOS VISUAIS / APARENCIA
# ----------------------------------------------------------------------

Otimizacao -Titulo "Ajustar para MELHOR DESEMPENHO (desliga efeitos visuais)" `
    -Descricao "Equivale a 'Ajustar para melhor desempenho' nas opcoes de performance." `
    -Acao {
        Definir-Registro $RegVisualFX "VisualFXSetting" 2
        # Mascara que desliga praticamente todas as animacoes/sombras
        Definir-Registro $RegDesktop "UserPreferencesMask" ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) "Binary"
    }

Otimizacao -Titulo "Desativar animacoes de janelas (minimizar/maximizar)" `
    -Descricao "Tira o efeito de animacao ao abrir/fechar janelas." `
    -Acao {
        Definir-Registro $RegMetrics "MinAnimate" "0" "String"
    }

Otimizacao -Titulo "Desativar transparencia (barra de tarefas / menu iniciar)" `
    -Descricao "Remove o efeito de vidro/transparencia que gasta GPU." `
    -Acao {
        Definir-Registro "$HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0
    }

Otimizacao -Titulo "Desativar sombras e suavizacao desnecessarias" `
    -Descricao "Desliga sombras de janelas e animacoes de controles." `
    -Acao {
        Definir-Registro $RegDWM "EnableAeroPeek" 0
        Definir-Registro $RegDWM "AlwaysHibernateThumbnails" 0
    }

Otimizacao -Titulo "Mostrar conteudo da janela ao arrastar = OFF" `
    -Descricao "Arrasta so o contorno da janela (mais leve em PCs fracos)." `
    -Acao {
        Definir-Registro $RegDesktop "DragFullWindows" "0" "String"
    }

Otimizacao -Titulo "Animacoes do menu / fade de menus = OFF" `
    -Descricao "Menus aparecem instantaneamente, sem fade." `
    -Acao {
        Definir-Registro $RegDesktop "MenuShowDelay" "0" "String"
    }

# ----------------------------------------------------------------------
#  PESO DO SISTEMA / FUNDO
# ----------------------------------------------------------------------

Otimizacao -Titulo "Desativar efeitos de animacao da barra de tarefas" `
    -Descricao "Remove animacoes ao passar o mouse e abrir apps." `
    -Acao {
        Definir-Registro $RegAdvanced "TaskbarAnimations" 0
        Definir-Registro $RegAdvanced "ListviewAlphaSelect" 0
        Definir-Registro $RegAdvanced "ListviewShadow" 0
    }

Otimizacao -Titulo "Desativar dicas, sugestoes e propaganda do Windows" `
    -Descricao "Tira notificacoes de 'dicas' e sugestoes que pesam o explorer." `
    -Acao {
        $cdm = "$HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        Definir-Registro $cdm "SubscribedContent-338389Enabled" 0
        Definir-Registro $cdm "SubscribedContent-310093Enabled" 0
        Definir-Registro $cdm "SystemPaneSuggestionsEnabled" 0
    }

Otimizacao -Titulo "Desativar efeitos de transicao do menu Iniciar" `
    -Descricao "Menu iniciar abre direto, sem animacao de entrada." `
    -Acao {
        Definir-Registro $RegAdvanced "Start_AnimationEnabled" 0 -ErrorAction SilentlyContinue
    }

Otimizacao -Titulo "Plano de energia: ALTO DESEMPENHO" `
    -Descricao "Coloca a maquina em modo de alto desempenho (mais responsiva)." `
    -Acao {
        powercfg -setactive SCHEME_MIN | Out-Null
    }

Otimizacao -Titulo "Reiniciar o Explorer para aplicar as mudancas visuais" `
    -Descricao "Fecha e reabre a barra de tarefas/area de trabalho (rapido)." `
    -Acao {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
            Start-Process explorer
        }
    }

# ----------------------------------------------------------------------
#  LIMPEZA DE ARQUIVOS TEMPORARIOS
# ----------------------------------------------------------------------

Otimizacao -Titulo "Limpar arquivos temporarios (Temp / Prefetch / cache)" `
    -Descricao "Apaga lixo do Windows e do usuario. Nao mexe em arquivos seus." `
    -Acao {
        $alvos = @(
            "$env:TEMP\*",
            "$env:WINDIR\Temp\*",
            "$env:WINDIR\Prefetch\*",
            "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*"
        )
        $antes = 0
        foreach ($a in $alvos) {
            $p = Split-Path $a
            if (Test-Path $p) {
                $antes += (Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum
            }
        }
        foreach ($a in $alvos) {
            Remove-Item $a -Recurse -Force -ErrorAction SilentlyContinue
        }
        $mb = [math]::Round($antes / 1MB, 1)
        Write-Host "   Espaco liberado (aprox): $mb MB" -ForegroundColor Green
    }

Otimizacao -Titulo "Esvaziar a Lixeira" `
    -Descricao "Remove de vez tudo que esta na Lixeira de todas as unidades." `
    -Acao {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    }

# ----------------------------------------------------------------------
#  PROGRAMAS QUE ABREM COM O WINDOWS (STARTUP)
# ----------------------------------------------------------------------
Write-Host ""
Write-Host ("-" * 64) -ForegroundColor DarkCyan
Write-Host "  PROGRAMAS QUE ABREM COM O WINDOWS (inicializacao)" -ForegroundColor Cyan
Write-Host "  Vou listar cada um. Digite Y para DESATIVAR ou N para manter." -ForegroundColor Gray
Write-Host "  Tudo que voce desativar fica salvo em backup e pode voltar." -ForegroundColor DarkGray

# Chave onde guardamos backup do que foi desativado (pra poder reverter)
$BackupStartup = "$HKCU\Software\OtimizadorBackup\Startup"

$ChavesRun = @(
    @{ Caminho = "$HKCU\Software\Microsoft\Windows\CurrentVersion\Run"; Origem = "Usuario" },
    @{ Caminho = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"; Origem = "Sistema" }
)

$achouAlgum = $false
foreach ($chave in $ChavesRun) {
    if (-not (Test-Path $chave.Caminho)) { continue }
    $props = Get-ItemProperty -Path $chave.Caminho -ErrorAction SilentlyContinue
    if (-not $props) { continue }

    foreach ($p in $props.PSObject.Properties) {
        if ($p.Name -in @("PSPath","PSParentPath","PSChildName","PSDrive","PSProvider")) { continue }
        $achouAlgum = $true
        Write-Host ""
        Write-Host "  > $($p.Name)  [$($chave.Origem)]" -ForegroundColor White
        Write-Host "    $($p.Value)" -ForegroundColor DarkGray
        if (Perguntar "Desativar este programa na inicializacao?") {
            try {
                # Salva backup (origem | caminho | nome | valor)
                $linhaBackup = "$($chave.Origem)|$($chave.Caminho)|$($p.Value)"
                Definir-Registro $BackupStartup $p.Name $linhaBackup "String"
                # Remove da inicializacao
                Remove-ItemProperty -Path $chave.Caminho -Name $p.Name -Force -ErrorAction Stop
                Write-Host "   [OK] Desativado (backup salvo)." -ForegroundColor Green
                $Global:Aplicadas++
            } catch {
                Write-Host "   [ERRO] $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "   [--] Mantido." -ForegroundColor DarkYellow
            $Global:Puladas++
        }
    }
}
if (-not $achouAlgum) {
    Write-Host ""
    Write-Host "   Nenhum programa de inicializacao encontrado nas chaves Run." -ForegroundColor DarkGray
}

# ----------------------------------------------------------------------
#  RESUMO
# ----------------------------------------------------------------------
Write-Host ""
Write-Host "  ==============================================================" -ForegroundColor Magenta
Write-Host "   RESUMO" -ForegroundColor White
Write-Host "   Otimizacoes aplicadas: $Global:Aplicadas" -ForegroundColor Green
Write-Host "   Otimizacoes puladas:   $Global:Puladas" -ForegroundColor DarkYellow
Write-Host "  ==============================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Recomendado REINICIAR o computador para garantir tudo." -ForegroundColor Yellow
Write-Host ""
Read-Host "  Pressione ENTER para sair"
