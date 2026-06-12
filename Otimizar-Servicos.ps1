<#
.SYNOPSIS
    Reduz processos/servicos em segundo plano do Windows 10 para deixar
    o sistema o mais leve possivel - "so roda o que precisa rodar".

.DESCRIPTION
    Cada servico pergunta Y (sim) / N (nao) antes de desativar e mostra
    O QUE VOCE PERDE ao desligar. O estado original de cada servico e
    salvo em 'backup-servicos.json' (na mesma pasta) para poder reverter
    com o Restaurar-Servicos.ps1.

    Execute como ADMINISTRADOR.
    Autor: Alexandre Alan
#>

# --- Verifica administrador --------------------------------------------
$ehAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $ehAdmin) {
    Write-Host " ERRO: Execute como ADMINISTRADOR." -ForegroundColor Red
    Read-Host " Pressione ENTER para sair"; exit 1
}

$PastaScript = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ArquivoBackup = Join-Path $PastaScript "backup-servicos.json"
$Backup = @{}
if (Test-Path $ArquivoBackup) {
    try { $Backup = (Get-Content $ArquivoBackup -Raw | ConvertFrom-Json) } catch { $Backup = @{} }
    # converte para hashtable editavel
    $tmp = @{}; foreach ($p in $Backup.PSObject.Properties) { $tmp[$p.Name] = $p.Value }; $Backup = $tmp
}

$Aplicadas = 0; $Puladas = 0

function Perguntar {
    param([string]$Texto)
    while ($true) {
        $r = Read-Host " $Texto (Y/N)"
        switch ($r.ToUpper()) {
            "Y" { return $true } "S" { return $true } "N" { return $false }
            default { Write-Host "   Digite Y ou N." -ForegroundColor DarkGray }
        }
    }
}

function Desativar-Servico {
    param(
        [string]$Nome,        # nome real do servico
        [string]$Amigavel,    # descricao para voce
        [string]$Perde        # o que voce perde ao desativar
    )
    $svc = Get-Service -Name $Nome -ErrorAction SilentlyContinue
    if (-not $svc) {
        return  # servico nao existe nesta maquina; ignora silenciosamente
    }
    Write-Host ""
    Write-Host ("-" * 64) -ForegroundColor DarkCyan
    Write-Host "  $Amigavel  ($Nome)" -ForegroundColor Cyan
    Write-Host "  Voce PERDE: $Perde" -ForegroundColor Yellow
    Write-Host "  Estado atual: $($svc.Status) / inicio: $((Get-Service $Nome).StartType)" -ForegroundColor DarkGray
    if (Perguntar "Desativar este servico?") {
        try {
            # salva backup do tipo de inicializacao original (se ainda nao salvou)
            if (-not $script:Backup.ContainsKey($Nome)) {
                $script:Backup[$Nome] = (Get-Service $Nome).StartType.ToString()
            }
            Stop-Service -Name $Nome -Force -ErrorAction SilentlyContinue
            Set-Service -Name $Nome -StartupType Disabled -ErrorAction Stop
            Write-Host "   [OK] Desativado (backup salvo)." -ForegroundColor Green
            $script:Aplicadas++
        } catch {
            Write-Host "   [ERRO] $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "   [--] Mantido ligado." -ForegroundColor DarkYellow
        $script:Puladas++
    }
}

# --- Cabecalho ---------------------------------------------------------
Clear-Host
Write-Host ""
Write-Host "  ==============================================================" -ForegroundColor Magenta
Write-Host "     REDUZIR PROCESSOS / SERVICOS - WINDOWS 10 (modo leve)" -ForegroundColor White
Write-Host "  ==============================================================" -ForegroundColor Magenta
Write-Host "  Cada item mostra O QUE VOCE PERDE. Tudo e reversivel." -ForegroundColor Gray
Write-Host ""

# ====================================================================
#  SEGUROS - quase ninguem sente falta (recomendado desativar)
# ====================================================================
Write-Host "  >>> GRUPO 1: SEGUROS (recomendado) <<<" -ForegroundColor Green

Desativar-Servico "DiagTrack"        "Telemetria / Experiencias do Usuario Conectado" "Envio de dados de uso para a Microsoft (nada que voce use)"
Desativar-Servico "dmwappushservice" "Roteamento de mensagens WAP Push (telemetria)"  "Nada perceptivel no uso comum"
Desativar-Servico "SysMain"          "SysMain (antigo Superfetch)"                    "Pre-carregamento de apps; em SSD nao faz falta"
Desativar-Servico "Fax"              "Servico de Fax"                                 "Enviar/receber fax (ninguem usa)"
Desativar-Servico "RetailDemo"       "Modo Demonstracao de Loja"                      "Modo de demo usado em lojas; inutil em casa"
Desativar-Servico "RemoteRegistry"   "Registro Remoto"                                "Editar seu registro pela rede (melhor desligado por seguranca)"
Desativar-Servico "WerSvc"           "Relatorio de Erros do Windows"                  "Envio automatico de relatorios de erro a Microsoft"
Desativar-Servico "MapsBroker"       "Gerenciador de Mapas Baixados"                  "Mapas offline do app Mapas"
Desativar-Servico "WMPNetworkSvc"    "Compartilhamento de Rede do Windows Media"      "Compartilhar biblioteca do Media Player na rede"

# ====================================================================
#  XBOX / JOGOS - desative se NAO joga via Xbox/Game Bar
# ====================================================================
Write-Host ""
Write-Host "  >>> GRUPO 2: XBOX / GAME BAR (desative se nao usa) <<<" -ForegroundColor Green

Desativar-Servico "XblAuthManager"   "Xbox Live - Gerenciador de Autenticacao" "Login em jogos/servicos Xbox Live"
Desativar-Servico "XblGameSave"      "Xbox Live - Salvar Jogo"                 "Saves na nuvem do Xbox"
Desativar-Servico "XboxNetApiSvc"    "Xbox Live - Servico de Rede"             "Multiplayer/recursos online Xbox"
Desativar-Servico "XboxGipSvc"       "Xbox - Dispositivos de Entrada"          "Controle de Xbox conectado ao PC"

# ====================================================================
#  CUIDADO - so desative se tiver CERTEZA que nao usa
# ====================================================================
Write-Host ""
Write-Host "  >>> GRUPO 3: CUIDADO - leia antes de desativar <<<" -ForegroundColor Yellow

Desativar-Servico "Spooler"          "Spooler de Impressao"            "IMPRIMIR. So desative se NAO tem impressora"
Desativar-Servico "WSearch"          "Windows Search (indexacao)"      "Busca rapida de arquivos/menu iniciar fica mais lenta"
Desativar-Servico "TabletInputService" "Servico de Teclado de Toque"  "Teclado virtual / painel de emoji (Win+.) em PCs sem touch"
Desativar-Servico "PrintNotify"      "Notificacoes de Impressao"       "Avisos da impressora"
Desativar-Servico "PhoneSvc"         "Servico de Telefone"             "Integracao com telefone (Seu Telefone)"
Desativar-Servico "lfsvc"            "Servico de Geolocalizacao"       "Apps saberem sua localizacao"

# ====================================================================
#  APPS EM SEGUNDO PLANO + TELEMETRIA (registro)
# ====================================================================
Write-Host ""
Write-Host "  >>> GRUPO 4: APPS EM SEGUNDO PLANO E TELEMETRIA <<<" -ForegroundColor Green
Write-Host ("-" * 64) -ForegroundColor DarkCyan
Write-Host "  Impedir que apps da Loja rodem escondidos em segundo plano" -ForegroundColor Cyan
Write-Host "  Voce PERDE: notificacoes em tempo real de apps da Loja (Mail, etc.)" -ForegroundColor Yellow
if (Perguntar "Desativar apps em segundo plano?") {
    try {
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" `
            -Name "GlobalUserDisabled" -Value 1 -PropertyType DWord -Force | Out-Null
        Write-Host "   [OK] Apps em segundo plano desativados." -ForegroundColor Green
        $Aplicadas++
    } catch { Write-Host "   [ERRO] $($_.Exception.Message)" -ForegroundColor Red }
} else { Write-Host "   [--] Pulado." -ForegroundColor DarkYellow; $Puladas++ }

Write-Host ""
Write-Host ("-" * 64) -ForegroundColor DarkCyan
Write-Host "  Reduzir telemetria ao minimo (nivel Seguranca)" -ForegroundColor Cyan
Write-Host "  Voce PERDE: nada de util; so para de mandar dados de diagnostico" -ForegroundColor Yellow
if (Perguntar "Reduzir telemetria?") {
    try {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" `
            -Name "AllowTelemetry" -Value 0 -PropertyType DWord -Force | Out-Null
        Write-Host "   [OK] Telemetria reduzida." -ForegroundColor Green
        $Aplicadas++
    } catch { Write-Host "   [ERRO] $($_.Exception.Message)" -ForegroundColor Red }
} else { Write-Host "   [--] Pulado." -ForegroundColor DarkYellow; $Puladas++ }

# --- Salva backup ------------------------------------------------------
try {
    $Backup | ConvertTo-Json | Set-Content -Path $ArquivoBackup -Encoding UTF8
} catch { }

# --- Resumo ------------------------------------------------------------
Write-Host ""
Write-Host "  ==============================================================" -ForegroundColor Magenta
Write-Host "   Servicos/itens desativados: $Aplicadas" -ForegroundColor Green
Write-Host "   Itens mantidos:             $Puladas" -ForegroundColor DarkYellow
Write-Host "   Backup salvo em: $ArquivoBackup" -ForegroundColor Gray
Write-Host "  ==============================================================" -ForegroundColor Magenta
Write-Host "  Para reverter, rode: Restaurar-Servicos.ps1 (como admin)" -ForegroundColor Yellow
Write-Host "  Recomendado REINICIAR o PC." -ForegroundColor Yellow
Write-Host ""
Read-Host "  Pressione ENTER para sair"
