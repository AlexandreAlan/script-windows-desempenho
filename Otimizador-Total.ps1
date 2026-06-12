<#
.SYNOPSIS
    OTIMIZADOR TOTAL - Windows 10 (tudo em um so script)
    Deixa o sistema o mais leve e rapido possivel, com menu e Y/N por item.

.DESCRIPTION
    Menu com tudo:
      1 - Aparencia / efeitos visuais
      2 - Limpeza (temporarios + lixeira)
      3 - Programas de inicializacao (startup)
      4 - Servicos / processos em segundo plano
      5 - Tarefas agendadas (telemetria/compatibilidade)
      6 - Remover apps inuteis (Candy Crush, etc.)
      7 - APLICAR TUDO (passa por todas as secoes)
      8 - RESTAURAR (servicos + inicializacao)
      0 - Sair

    Cada mudanca pergunta Y (sim) / N (nao). Backups sao salvos para
    reverter (servicos em backup-servicos.json, startup no registro).

    Execute como ADMINISTRADOR (use o .bat ou clique direito > admin).
    Autor: Alexandre Alan
#>

# ======================================================================
#  Verifica administrador
# ======================================================================
$ehAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $ehAdmin) {
    Write-Host ""
    Write-Host " ERRO: Este script precisa ser ADMINISTRADOR." -ForegroundColor Red
    Write-Host " Use o Otimizador-Total.bat ou clique direito > Executar como admin." -ForegroundColor Yellow
    Read-Host " Pressione ENTER para sair"; exit 1
}

# ======================================================================
#  Globais e funcoes auxiliares
# ======================================================================
$Global:Aplicadas = 0
$Global:Puladas   = 0
$PastaScript      = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ArquivoBackupSvc = Join-Path $PastaScript "backup-servicos.json"

$HKCU          = "HKCU:"
$RegMetrics    = "$HKCU\Control Panel\Desktop\WindowMetrics"
$RegDesktop    = "$HKCU\Control Panel\Desktop"
$RegAdvanced   = "$HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$RegVisualFX   = "$HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
$RegDWM        = "$HKCU\Software\Microsoft\Windows\DWM"
$BackupStartup = "$HKCU\Software\OtimizadorBackup\Startup"

# carrega backup de servicos (se existir)
$Global:BackupSvc = @{}
if (Test-Path $ArquivoBackupSvc) {
    try {
        $j = Get-Content $ArquivoBackupSvc -Raw | ConvertFrom-Json
        foreach ($p in $j.PSObject.Properties) { $Global:BackupSvc[$p.Name] = $p.Value }
    } catch { }
}

function Perguntar {
    param([string]$Texto)
    while ($true) {
        $r = Read-Host " $Texto (Y/N)"
        switch ($r.ToUpper()) {
            "Y" { return $true } "S" { return $true } "N" { return $false }
            default { Write-Host "   Digite Y (sim) ou N (nao)." -ForegroundColor DarkGray }
        }
    }
}

function Definir-Registro {
    param([string]$Caminho,[string]$Nome,$Valor,[string]$Tipo="DWord")
    if (-not (Test-Path $Caminho)) { New-Item -Path $Caminho -Force | Out-Null }
    New-ItemProperty -Path $Caminho -Name $Nome -Value $Valor -PropertyType $Tipo -Force | Out-Null
}

function Item {
    param([string]$Titulo,[string]$Descricao,[scriptblock]$Acao)
    Write-Host ""
    Write-Host ("-" * 64) -ForegroundColor DarkCyan
    Write-Host "  $Titulo" -ForegroundColor Cyan
    if ($Descricao) { Write-Host "  $Descricao" -ForegroundColor Gray }
    if (Perguntar "Aplicar?") {
        try { & $Acao; Write-Host "   [OK] Aplicado." -ForegroundColor Green; $Global:Aplicadas++ }
        catch { Write-Host "   [ERRO] $($_.Exception.Message)" -ForegroundColor Red }
    } else { Write-Host "   [--] Pulado." -ForegroundColor DarkYellow; $Global:Puladas++ }
}

function Salvar-BackupSvc {
    try { $Global:BackupSvc | ConvertTo-Json | Set-Content -Path $ArquivoBackupSvc -Encoding UTF8 } catch { }
}

function Desativar-Servico {
    param([string]$Nome,[string]$Amigavel,[string]$Perde)
    $svc = Get-Service -Name $Nome -ErrorAction SilentlyContinue
    if (-not $svc) { return }
    Write-Host ""
    Write-Host ("-" * 64) -ForegroundColor DarkCyan
    Write-Host "  $Amigavel  ($Nome)" -ForegroundColor Cyan
    Write-Host "  Voce PERDE: $Perde" -ForegroundColor Yellow
    Write-Host "  Estado atual: $($svc.Status) / inicio: $((Get-Service $Nome).StartType)" -ForegroundColor DarkGray
    if (Perguntar "Desativar?") {
        try {
            if (-not $Global:BackupSvc.ContainsKey($Nome)) {
                $Global:BackupSvc[$Nome] = (Get-Service $Nome).StartType.ToString()
            }
            Stop-Service -Name $Nome -Force -ErrorAction SilentlyContinue
            Set-Service -Name $Nome -StartupType Disabled -ErrorAction Stop
            Salvar-BackupSvc
            Write-Host "   [OK] Desativado (backup salvo)." -ForegroundColor Green
            $Global:Aplicadas++
        } catch { Write-Host "   [ERRO] $($_.Exception.Message)" -ForegroundColor Red }
    } else { Write-Host "   [--] Mantido ligado." -ForegroundColor DarkYellow; $Global:Puladas++ }
}

function Titulo-Secao {
    param([string]$Texto)
    Write-Host ""
    Write-Host "  ==============================================================" -ForegroundColor Magenta
    Write-Host "   $Texto" -ForegroundColor White
    Write-Host "  ==============================================================" -ForegroundColor Magenta
}

# ======================================================================
#  SECAO 1 - APARENCIA / EFEITOS VISUAIS
# ======================================================================
function Secao-Aparencia {
    Titulo-Secao "1) APARENCIA / EFEITOS VISUAIS"

    Item "Ajustar para MELHOR DESEMPENHO (desliga efeitos visuais)" `
        "Equivale a 'Ajustar para melhor desempenho' nas opcoes de performance." {
        Definir-Registro $RegVisualFX "VisualFXSetting" 2
        Definir-Registro $RegDesktop "UserPreferencesMask" ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) "Binary"
    }
    Item "Desativar animacoes de janelas (minimizar/maximizar)" "" {
        Definir-Registro $RegMetrics "MinAnimate" "0" "String"
    }
    Item "Desativar transparencia (barra de tarefas / menu iniciar)" "Remove o efeito de vidro que gasta GPU." {
        Definir-Registro "$HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0
    }
    Item "Desativar sombras e Aero Peek" "" {
        Definir-Registro $RegDWM "EnableAeroPeek" 0
        Definir-Registro $RegDWM "AlwaysHibernateThumbnails" 0
    }
    Item "Mostrar so o contorno ao arrastar janelas" "Mais leve em PCs fracos." {
        Definir-Registro $RegDesktop "DragFullWindows" "0" "String"
    }
    Item "Menus instantaneos (sem delay/fade)" "" {
        Definir-Registro $RegDesktop "MenuShowDelay" "0" "String"
    }
    Item "Desativar animacoes da barra de tarefas" "" {
        Definir-Registro $RegAdvanced "TaskbarAnimations" 0
        Definir-Registro $RegAdvanced "ListviewAlphaSelect" 0
        Definir-Registro $RegAdvanced "ListviewShadow" 0
    }
    Item "Desativar dicas, sugestoes e propaganda do Windows" "" {
        $cdm = "$HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        Definir-Registro $cdm "SubscribedContent-338389Enabled" 0
        Definir-Registro $cdm "SubscribedContent-310093Enabled" 0
        Definir-Registro $cdm "SystemPaneSuggestionsEnabled" 0
    }
    Item "Plano de energia: ALTO DESEMPENHO" "Deixa a maquina mais responsiva." {
        powercfg -setactive SCHEME_MIN | Out-Null
    }
}

# ======================================================================
#  SECAO 2 - LIMPEZA
# ======================================================================
function Secao-Limpeza {
    Titulo-Secao "2) LIMPEZA DE TEMPORARIOS"

    Item "Limpar arquivos temporarios (Temp / Prefetch / cache)" `
        "Apaga lixo do sistema e do usuario. Nao mexe nos seus arquivos." {
        $alvos = @("$env:TEMP\*","$env:WINDIR\Temp\*","$env:WINDIR\Prefetch\*",
                   "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*")
        $antes = 0
        foreach ($a in $alvos) {
            $p = Split-Path $a
            if (Test-Path $p) {
                $antes += (Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum
            }
        }
        foreach ($a in $alvos) { Remove-Item $a -Recurse -Force -ErrorAction SilentlyContinue }
        Write-Host "   Espaco liberado (aprox): $([math]::Round($antes/1MB,1)) MB" -ForegroundColor Green
    }
    Item "Esvaziar a Lixeira" "" {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    }
}

# ======================================================================
#  SECAO 3 - INICIALIZACAO (STARTUP)
# ======================================================================
function Secao-Startup {
    Titulo-Secao "3) PROGRAMAS QUE ABREM COM O WINDOWS"
    Write-Host "  Digite Y para DESATIVAR ou N para manter. Tudo reversivel." -ForegroundColor Gray

    $chaves = @(
        @{ Caminho = "$HKCU\Software\Microsoft\Windows\CurrentVersion\Run"; Origem = "Usuario" },
        @{ Caminho = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"; Origem = "Sistema" }
    )
    $achou = $false
    foreach ($chave in $chaves) {
        if (-not (Test-Path $chave.Caminho)) { continue }
        $props = Get-ItemProperty -Path $chave.Caminho -ErrorAction SilentlyContinue
        if (-not $props) { continue }
        foreach ($p in $props.PSObject.Properties) {
            if ($p.Name -in @("PSPath","PSParentPath","PSChildName","PSDrive","PSProvider")) { continue }
            $achou = $true
            Write-Host ""
            Write-Host "  > $($p.Name)  [$($chave.Origem)]" -ForegroundColor White
            Write-Host "    $($p.Value)" -ForegroundColor DarkGray
            if (Perguntar "Desativar na inicializacao?") {
                try {
                    Definir-Registro $BackupStartup $p.Name "$($chave.Origem)|$($chave.Caminho)|$($p.Value)" "String"
                    Remove-ItemProperty -Path $chave.Caminho -Name $p.Name -Force -ErrorAction Stop
                    Write-Host "   [OK] Desativado (backup salvo)." -ForegroundColor Green
                    $Global:Aplicadas++
                } catch { Write-Host "   [ERRO] $($_.Exception.Message)" -ForegroundColor Red }
            } else { Write-Host "   [--] Mantido." -ForegroundColor DarkYellow; $Global:Puladas++ }
        }
    }
    if (-not $achou) { Write-Host "   Nenhum programa de inicializacao encontrado." -ForegroundColor DarkGray }
}

# ======================================================================
#  SECAO 4 - SERVICOS / PROCESSOS
# ======================================================================
function Secao-Servicos {
    Titulo-Secao "4) SERVICOS / PROCESSOS EM SEGUNDO PLANO"
    Write-Host "  Cada item mostra O QUE VOCE PERDE. Tudo reversivel." -ForegroundColor Gray

    Write-Host ""; Write-Host "  >>> GRUPO 1: SEGUROS (recomendado) <<<" -ForegroundColor Green
    Desativar-Servico "DiagTrack"        "Telemetria / Experiencias Conectadas"  "Envio de dados de uso a Microsoft"
    Desativar-Servico "dmwappushservice" "Roteamento WAP Push (telemetria)"       "Nada perceptivel"
    Desativar-Servico "SysMain"          "SysMain (Superfetch)"                   "Pre-carregamento; em SSD nao faz falta"
    Desativar-Servico "Fax"              "Servico de Fax"                         "Enviar/receber fax"
    Desativar-Servico "RetailDemo"       "Modo Demonstracao de Loja"              "Modo de demo de loja (inutil em casa)"
    Desativar-Servico "RemoteRegistry"   "Registro Remoto"                        "Editar registro pela rede (melhor off)"
    Desativar-Servico "WerSvc"           "Relatorio de Erros do Windows"          "Envio de relatorios de erro"
    Desativar-Servico "MapsBroker"       "Gerenciador de Mapas Baixados"          "Mapas offline do app Mapas"
    Desativar-Servico "WMPNetworkSvc"    "Compartilhamento do Windows Media"      "Compartilhar biblioteca na rede"

    Write-Host ""; Write-Host "  >>> GRUPO 2: XBOX / GAME BAR (se nao usa) <<<" -ForegroundColor Green
    Desativar-Servico "XblAuthManager"   "Xbox Live - Autenticacao"  "Login em servicos Xbox"
    Desativar-Servico "XblGameSave"      "Xbox Live - Salvar Jogo"   "Saves na nuvem do Xbox"
    Desativar-Servico "XboxNetApiSvc"    "Xbox Live - Rede"          "Recursos online Xbox"
    Desativar-Servico "XboxGipSvc"       "Xbox - Entrada"            "Controle de Xbox no PC"

    Write-Host ""; Write-Host "  >>> GRUPO 3: CUIDADO - leia antes <<<" -ForegroundColor Yellow
    Desativar-Servico "Spooler"            "Spooler de Impressao"       "IMPRIMIR (so se NAO tem impressora)"
    Desativar-Servico "WSearch"            "Windows Search (indexacao)" "Busca rapida de arquivos fica lenta"
    Desativar-Servico "TabletInputService" "Teclado de Toque"          "Teclado virtual / emoji (Win+.)"
    Desativar-Servico "PrintNotify"        "Notificacoes de Impressao"  "Avisos da impressora"
    Desativar-Servico "PhoneSvc"           "Servico de Telefone"        "Integracao com telefone"
    Desativar-Servico "lfsvc"              "Geolocalizacao"             "Apps saberem sua localizacao"

    Write-Host ""; Write-Host "  >>> GRUPO 4: APPS EM 2o PLANO + TELEMETRIA <<<" -ForegroundColor Green
    Item "Desativar apps da Loja em segundo plano" "Perde: notificacoes em tempo real de apps da Loja." {
        Definir-Registro "$HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1
    }
    Item "Reduzir telemetria ao minimo" "Perde: nada util; para de mandar diagnostico." {
        Definir-Registro "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
    }
}

# ======================================================================
#  SECAO 5 - TAREFAS AGENDADAS
# ======================================================================
function Secao-Tarefas {
    Titulo-Secao "5) TAREFAS AGENDADAS (telemetria/compatibilidade)"
    Write-Host "  Desativa tarefas de fundo de coleta de dados e compatibilidade." -ForegroundColor Gray

    $tarefas = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Autochk\Proxy",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
        "\Microsoft\Windows\Feedback\Siuf\DmClient",
        "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
        "\Microsoft\Windows\Windows Error Reporting\QueueReporting"
    )
    Item "Desativar tarefas agendadas de telemetria/compatibilidade" `
        "Sao $($tarefas.Count) tarefas conhecidas de coleta de dados." {
        foreach ($t in $tarefas) {
            $nome = Split-Path $t -Leaf
            $caminho = Split-Path $t -Parent
            Disable-ScheduledTask -TaskName $nome -TaskPath ($caminho + "\") -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

# ======================================================================
#  SECAO 6 - REMOVER APPS INUTEIS (BLOATWARE)
# ======================================================================
function Secao-Bloatware {
    Titulo-Secao "6) REMOVER APPS INUTEIS (BLOATWARE)"
    Write-Host "  Lista apps inuteis INSTALADOS. Y remove, N mantem." -ForegroundColor Gray
    Write-Host "  (Apps essenciais do Windows nao entram nesta lista.)" -ForegroundColor DarkGray

    $padroes = @(
        "*king.com*","*CandyCrush*","*BubbleWitch*",   # jogos King
        "*Microsoft.3DBuilder*","*Microsoft.MixedReality.Portal*",
        "*Microsoft.Microsoft3DViewer*","*Microsoft.Print3D*",
        "*Microsoft.SkypeApp*","*Microsoft.GetHelp*","*Microsoft.Getstarted*",
        "*Microsoft.Messaging*","*Microsoft.OneConnect*","*Microsoft.People*",
        "*Microsoft.WindowsFeedbackHub*","*Microsoft.WindowsMaps*",
        "*Microsoft.YourPhone*","*Microsoft.ZuneMusic*","*Microsoft.ZuneVideo*",
        "*Microsoft.BingNews*","*Microsoft.BingWeather*","*Microsoft.MicrosoftSolitaireCollection*",
        "*Microsoft.WindowsAlarms*","*Microsoft.MicrosoftStickyNotes*",
        "*Microsoft.MSPaint*","*Microsoft.Wallet*","*Microsoft.Office.OneNote*",
        "*Disney*","*Spotify*","*Facebook*","*Twitter*","*Netflix*",
        "*Microsoft.MicrosoftOfficeHub*","*Microsoft.Todos*","*Clipchamp*"
    )

    $instalados = @()
    foreach ($pat in $padroes) {
        $instalados += Get-AppxPackage -Name $pat -ErrorAction SilentlyContinue
    }
    $instalados = $instalados | Sort-Object Name -Unique

    if (-not $instalados -or $instalados.Count -eq 0) {
        Write-Host "   Nenhum app inutil conhecido encontrado. Otimo!" -ForegroundColor Green
        return
    }
    foreach ($app in $instalados) {
        Write-Host ""
        Write-Host "  > $($app.Name)" -ForegroundColor White
        if (Perguntar "Remover este app?") {
            try {
                Remove-AppxPackage -Package $app.PackageFullName -ErrorAction Stop
                Write-Host "   [OK] Removido." -ForegroundColor Green
                $Global:Aplicadas++
            } catch { Write-Host "   [ERRO] $($_.Exception.Message)" -ForegroundColor Red }
        } else { Write-Host "   [--] Mantido." -ForegroundColor DarkYellow; $Global:Puladas++ }
    }
    Write-Host ""
    Write-Host "   Obs: apps removidos podem ser reinstalados pela Microsoft Store." -ForegroundColor DarkGray
}

# ======================================================================
#  SECAO 9 - OTIMIZAR DISCO (HD/SSD)
# ======================================================================
function Secao-Disco {
    Titulo-Secao "9) OTIMIZAR DISCO (detecta HD ou SSD)"
    Write-Host "  HD comum: desfragmenta. SSD: faz TRIM (limpeza). Automatico." -ForegroundColor Gray

    $volumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq "Fixed" }
    if (-not $volumes) { Write-Host "   Nenhum disco fixo encontrado." -ForegroundColor DarkGray; return }

    foreach ($v in $volumes) {
        $letra = $v.DriveLetter
        # descobre o tipo de midia (SSD x HDD)
        $tipo = "Desconhecido"
        try {
            $pd = Get-PhysicalDisk -ErrorAction SilentlyContinue |
                  Where-Object { $_.DeviceId -ne $null } | Select-Object -First 1
            $disco = Get-Partition -DriveLetter $letra -ErrorAction SilentlyContinue |
                     Get-Disk -ErrorAction SilentlyContinue
            if ($disco) {
                $fis = Get-PhysicalDisk -ErrorAction SilentlyContinue |
                       Where-Object { $_.DeviceId -eq $disco.Number }
                if ($fis) { $tipo = $fis.MediaType }
            }
        } catch { }

        Write-Host ""
        Write-Host ("-" * 64) -ForegroundColor DarkCyan
        Write-Host "  Disco $($letra):  (tipo: $tipo)" -ForegroundColor Cyan
        if ($tipo -eq "SSD") {
            Write-Host "  Acao: TRIM (limpeza correta para SSD, NAO desfragmenta)." -ForegroundColor Gray
        } elseif ($tipo -eq "HDD") {
            Write-Host "  Acao: desfragmentar (recomendado para HD comum)." -ForegroundColor Gray
        } else {
            Write-Host "  Tipo desconhecido: vou usar otimizacao padrao do Windows." -ForegroundColor Gray
        }
        if (Perguntar "Otimizar o disco $($letra):?") {
            try {
                if ($tipo -eq "SSD") {
                    Optimize-Volume -DriveLetter $letra -ReTrim -ErrorAction Stop
                } elseif ($tipo -eq "HDD") {
                    Optimize-Volume -DriveLetter $letra -Defrag -ErrorAction Stop
                } else {
                    Optimize-Volume -DriveLetter $letra -ErrorAction Stop
                }
                Write-Host "   [OK] Disco $($letra): otimizado." -ForegroundColor Green
                $Global:Aplicadas++
            } catch { Write-Host "   [ERRO] $($_.Exception.Message)" -ForegroundColor Red }
        } else { Write-Host "   [--] Pulado." -ForegroundColor DarkYellow; $Global:Puladas++ }
    }
}

# ======================================================================
#  SECAO 10 - AJUSTES DE REDE (DNS + THROTTLING)
# ======================================================================
function Secao-Rede {
    Titulo-Secao "10) AJUSTES DE REDE (DNS rapido + throttling)"
    Write-Host "  Deixa a navegacao um pouco mais rapida. Reversivel." -ForegroundColor Gray

    # --- DNS rapido ---
    Write-Host ""
    Write-Host ("-" * 64) -ForegroundColor DarkCyan
    Write-Host "  Trocar DNS para um mais rapido" -ForegroundColor Cyan
    Write-Host "    1 = Cloudflare (1.1.1.1 / 1.0.0.1)  -> rapido e privado" -ForegroundColor Gray
    Write-Host "    2 = Google     (8.8.8.8 / 8.8.4.4)  -> rapido e estavel" -ForegroundColor Gray
    Write-Host "    3 = Voltar ao AUTOMATICO (DNS do provedor)" -ForegroundColor Gray
    Write-Host "    N = Nao mexer no DNS" -ForegroundColor Gray
    $escolha = Read-Host " Escolha (1/2/3/N)"
    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
    switch ($escolha.ToUpper()) {
        "1" {
            try {
                foreach ($a in $adapters) { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses ("1.1.1.1","1.0.0.1") -ErrorAction Stop }
                Write-Host "   [OK] DNS Cloudflare aplicado." -ForegroundColor Green; $Global:Aplicadas++
            } catch { Write-Host "   [ERRO] $($_.Exception.Message)" -ForegroundColor Red }
        }
        "2" {
            try {
                foreach ($a in $adapters) { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses ("8.8.8.8","8.8.4.4") -ErrorAction Stop }
                Write-Host "   [OK] DNS Google aplicado." -ForegroundColor Green; $Global:Aplicadas++
            } catch { Write-Host "   [ERRO] $($_.Exception.Message)" -ForegroundColor Red }
        }
        "3" {
            try {
                foreach ($a in $adapters) { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses -ErrorAction Stop }
                Write-Host "   [OK] DNS voltou ao automatico." -ForegroundColor Green; $Global:Aplicadas++
            } catch { Write-Host "   [ERRO] $($_.Exception.Message)" -ForegroundColor Red }
        }
        default { Write-Host "   [--] DNS nao alterado." -ForegroundColor DarkYellow; $Global:Puladas++ }
    }

    # --- Throttling de rede ---
    Item "Desativar 'Network Throttling' (soltar velocidade em 2o plano)" `
        "Perde: nada relevante; o Windows deixa de limitar a rede." {
        Definir-Registro "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xffffffff
        Definir-Registro "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0
    }

    Item "Limpar cache de DNS agora" "Resolve sites que ficaram 'presos' no cache antigo." {
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        ipconfig /flushdns | Out-Null
    }
}

# ======================================================================
#  SECAO 8 - RESTAURAR
# ======================================================================
function Secao-Restaurar {
    Titulo-Secao "RESTAURAR (desfazer)"

    # Servicos
    if (Test-Path $ArquivoBackupSvc) {
        Write-Host "  -- Servicos --" -ForegroundColor Cyan
        $j = Get-Content $ArquivoBackupSvc -Raw | ConvertFrom-Json
        foreach ($p in $j.PSObject.Properties) {
            $svc = Get-Service -Name $p.Name -ErrorAction SilentlyContinue
            if (-not $svc) { continue }
            Write-Host ""
            Write-Host "  > $($p.Name) -> $($p.Value)" -ForegroundColor White
            if (Perguntar "Restaurar este servico?") {
                try { Set-Service -Name $p.Name -StartupType $p.Value -ErrorAction Stop
                      Write-Host "   [OK] Restaurado." -ForegroundColor Green }
                catch { Write-Host "   [ERRO] $($_.Exception.Message)" -ForegroundColor Red }
            } else { Write-Host "   [--] Mantido desativado." -ForegroundColor DarkYellow }
        }
    } else { Write-Host "  Sem backup de servicos." -ForegroundColor DarkGray }

    # Inicializacao
    Write-Host ""
    if (Test-Path $BackupStartup) {
        Write-Host "  -- Inicializacao --" -ForegroundColor Cyan
        $props = Get-ItemProperty -Path $BackupStartup
        foreach ($p in $props.PSObject.Properties) {
            if ($p.Name -in @("PSPath","PSParentPath","PSChildName","PSDrive","PSProvider")) { continue }
            $partes = $p.Value -split "\|", 3
            if ($partes.Count -lt 3) { continue }
            Write-Host ""
            Write-Host "  > $($p.Name)" -ForegroundColor White
            Write-Host "    $($partes[2])" -ForegroundColor DarkGray
            if (Perguntar "Restaurar na inicializacao?") {
                try {
                    if (-not (Test-Path $partes[1])) { New-Item -Path $partes[1] -Force | Out-Null }
                    New-ItemProperty -Path $partes[1] -Name $p.Name -Value $partes[2] -PropertyType String -Force | Out-Null
                    Remove-ItemProperty -Path $BackupStartup -Name $p.Name -Force -ErrorAction SilentlyContinue
                    Write-Host "   [OK] Restaurado." -ForegroundColor Green
                } catch { Write-Host "   [ERRO] $($_.Exception.Message)" -ForegroundColor Red }
            } else { Write-Host "   [--] Mantido desativado." -ForegroundColor DarkYellow }
        }
    } else { Write-Host "  Sem backup de inicializacao." -ForegroundColor DarkGray }
}

# ======================================================================
#  Reiniciar Explorer + ponto de restauracao
# ======================================================================
function Reiniciar-Explorer {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer }
}

function Ponto-Restauracao {
    Item "Criar ponto de restauracao do sistema (recomendado)" `
        "Seguranca: permite desfazer tudo pelo Windows se algo der errado." {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "Antes do Otimizador Total" -RestorePointType "MODIFY_SETTINGS"
    }
}

# ======================================================================
#  MENU PRINCIPAL
# ======================================================================
function Mostrar-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "  ==============================================================" -ForegroundColor Magenta
    Write-Host "          OTIMIZADOR TOTAL - WINDOWS 10 (leve e rapido)" -ForegroundColor White
    Write-Host "  ==============================================================" -ForegroundColor Magenta
    Write-Host "   1 - Aparencia / efeitos visuais" -ForegroundColor Gray
    Write-Host "   2 - Limpeza (temporarios + lixeira)" -ForegroundColor Gray
    Write-Host "   3 - Programas de inicializacao (startup)" -ForegroundColor Gray
    Write-Host "   4 - Servicos / processos em segundo plano" -ForegroundColor Gray
    Write-Host "   5 - Tarefas agendadas (telemetria)" -ForegroundColor Gray
    Write-Host "   6 - Remover apps inuteis (Candy Crush, etc.)" -ForegroundColor Gray
    Write-Host "   9 - Otimizar disco (HD/SSD automatico)" -ForegroundColor Gray
    Write-Host "  10 - Ajustes de rede (DNS rapido + throttling)" -ForegroundColor Gray
    Write-Host "   7 - APLICAR TUDO (passa por todas as secoes)" -ForegroundColor Green
    Write-Host "   8 - RESTAURAR (desfazer servicos + inicializacao)" -ForegroundColor Yellow
    Write-Host "   0 - Sair" -ForegroundColor Gray
    Write-Host "  ==============================================================" -ForegroundColor Magenta
    Write-Host "   Aplicadas: $Global:Aplicadas  |  Puladas: $Global:Puladas" -ForegroundColor DarkGray
    Write-Host ""
}

# ======================================================================
#  LOOP
# ======================================================================
do {
    Mostrar-Menu
    $op = Read-Host "  Escolha uma opcao"
    switch ($op) {
        "1" { Secao-Aparencia; Item "Reiniciar o Explorer para aplicar a aparencia" "" { Reiniciar-Explorer }; Pause }
        "2" { Secao-Limpeza; Pause }
        "3" { Secao-Startup; Pause }
        "4" { Secao-Servicos; Pause }
        "5" { Secao-Tarefas; Pause }
        "6" { Secao-Bloatware; Pause }
        "9" { Secao-Disco; Pause }
        "10" { Secao-Rede; Pause }
        "7" {
            Ponto-Restauracao
            Secao-Aparencia
            Secao-Limpeza
            Secao-Startup
            Secao-Servicos
            Secao-Tarefas
            Secao-Bloatware
            Secao-Disco
            Secao-Rede
            Item "Reiniciar o Explorer para aplicar a aparencia" "" { Reiniciar-Explorer }
            Titulo-Secao "TUDO PROCESSADO - recomendado REINICIAR o PC"
            Pause
        }
        "8" { Secao-Restaurar; Pause }
        "0" { Write-Host "  Saindo..." -ForegroundColor Gray }
        default { Write-Host "  Opcao invalida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
} while ($op -ne "0")

Write-Host ""
Write-Host "  Fim. Aplicadas: $Global:Aplicadas | Puladas: $Global:Puladas" -ForegroundColor Green
Write-Host "  Recomendado REINICIAR o computador." -ForegroundColor Yellow
