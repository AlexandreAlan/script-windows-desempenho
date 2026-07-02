<#
.SYNOPSIS
    OTIMIZADOR TOTAL - Windows 10 e 11 (tudo em um so script)
    Deixa o sistema o mais leve e rapido possivel, com menu e Y/N por item.
    Detecta o sistema automaticamente e libera os ajustes do Windows 11.

.DESCRIPTION
    Menu com tudo:
      1  - Aparencia / efeitos visuais
      2  - Limpeza (temporarios + lixeira)
      3  - Programas de inicializacao (startup)
      4  - Servicos / processos em segundo plano
      5  - Tarefas agendadas (telemetria/compatibilidade)
      6  - Remover apps inuteis (Candy Crush, etc.)
      7  - Otimizar disco (HD/SSD automatico)
      8  - Ajustes de rede (DNS rapido + throttling)
      9  - Maxima performance (CPU + sistema, monitoring-safe)
      10 - Ajustes do Windows 11 (menu classico, widgets, Teams)
      11 - Ver melhora de desempenho (antes x depois)
      12 - APLICAR TUDO (passa por todas as secoes)
      13 - RESTAURAR (servicos + inicializacao + registro)
      0  - Sair

    Cada mudanca pergunta Y (sim) / N (nao). Backups sao salvos para
    reverter (servicos em backup-servicos.json, startup no registro).
    Ao sair, gera um relatorio otimizador-log_<data>.txt na Area de Trabalho.

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
# Quando rodado direto da web (irm | iex) nao existe arquivo, entao $PastaScript
# fica vazio. Cai pro %TEMP% pra os backups (backup-servicos.json) terem onde ficar.
if ([string]::IsNullOrWhiteSpace($PastaScript) -or -not (Test-Path $PastaScript)) {
    $PastaScript = $env:TEMP
}
$ArquivoBackupSvc = Join-Path $PastaScript "backup-servicos.json"
$ArquivoBackupReg = Join-Path $PastaScript "backup-registro.json"

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

# ----------------------------------------------------------------------
#  BACKUP DE REGISTRO (pra restauracao completa pela opcao 13)
# ----------------------------------------------------------------------
# Antes de cada Definir-Registro, guardamos o valor ANTIGO (ou marcamos que nao
# existia) num backup-registro.json. A opcao 13 usa isso pra desfazer os tweaks de
# registro (aparencia, throttling de rede, widgets/Teams do W11, etc.).
#   $Global:BackupReg   = { "Caminho|Nome" -> @{ Existia; Caminho; Nome; Valor; Tipo } }
#   $Global:BackupRegDel = chaves criadas do zero que devem ser APAGADAS no restore
#                          (ex.: a chave do menu de contexto classico do W11).
$Global:BackupReg    = @{}
$Global:BackupRegDel = @{}
if (Test-Path $ArquivoBackupReg) {
    try {
        $jr = Get-Content $ArquivoBackupReg -Raw | ConvertFrom-Json
        if ($jr.props)   { foreach ($p in $jr.props.PSObject.Properties)   { $Global:BackupReg[$p.Name]    = $p.Value } }
        if ($jr.delKeys) { foreach ($k in $jr.delKeys)                     { $Global:BackupRegDel[$k]      = $true   } }
    } catch { }
}

function Salvar-BackupReg {
    try {
        $obj = [PSCustomObject]@{ props = $Global:BackupReg; delKeys = @($Global:BackupRegDel.Keys) }
        $obj | ConvertTo-Json -Depth 6 | Set-Content -Path $ArquivoBackupReg -Encoding UTF8
    } catch { }
}

# Guarda o estado atual de um valor de registro (so na 1a vez que e tocado).
function Backup-Registro {
    param([string]$Caminho,[string]$Nome)
    $chave = "$Caminho|$Nome"
    if ($Global:BackupReg.ContainsKey($chave)) { return }
    $info = @{ Existia = $false; Caminho = $Caminho; Nome = $Nome }
    try {
        if ((Test-Path $Caminho) -and ($null -ne (Get-ItemProperty -Path $Caminho -Name $Nome -ErrorAction SilentlyContinue))) {
            $valor = (Get-ItemProperty -Path $Caminho -Name $Nome -ErrorAction Stop).$Nome
            $tipo  = (Get-Item -Path $Caminho).GetValueKind($Nome).ToString()
            $info  = @{ Existia = $true; Caminho = $Caminho; Nome = $Nome; Valor = $valor; Tipo = $tipo }
        }
    } catch { }
    $Global:BackupReg[$chave] = $info
    Salvar-BackupReg
}

# Marca uma chave inteira (criada do zero) pra ser apagada no restore.
function Registrar-KeyParaApagar {
    param([string]$Chave)
    if (-not $Global:BackupRegDel.ContainsKey($Chave)) {
        $Global:BackupRegDel[$Chave] = $true
        Salvar-BackupReg
    }
}

# guarda o desempenho do INICIO para comparar depois (antes x depois)
$Global:DesempenhoInicial = $null  # preenchido na 1a vez que o menu abre

# ----------------------------------------------------------------------
#  Deteccao do sistema (Windows 10 x 11) e LOG DE AUDITORIA
# ----------------------------------------------------------------------
# Build >= 22000 = Windows 11. Usado pra liberar a secao de ajustes do W11.
$Global:BuildSO = [int]([System.Environment]::OSVersion.Version.Build)
$Global:Win11   = $Global:BuildSO -ge 22000
$Global:NomeSO  = if ($Global:Win11) { "Windows 11" } else { "Windows 10" }

# Maquina em dominio (AD)? Usado pra RESPEITAR a Politica de Grupo (GPO): em
# maquina gerenciada nao mexemos na area de \Policies\ (quem manda la e a GPO).
$Global:EmDominio = $false
try { $Global:EmDominio = [bool](Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).PartOfDomain } catch { }

# Log de auditoria: cada acao registra OK/ERRO/PULADO; ao sair, gera um
# relatorio otimizador-log_<data>.txt na Area de Trabalho (comprovante de servico).
$Global:Log = New-Object System.Collections.Generic.List[string]
function Add-Log {
    param([string]$Status,[string]$Mensagem)
    $Global:Log.Add(("[{0}] {1,-7} {2}" -f (Get-Date -Format "HH:mm:ss"), $Status, $Mensagem))
}
function Salvar-Log {
    if ($Global:Log.Count -eq 0) { return }
    try {
        $desktop = [Environment]::GetFolderPath('Desktop')
        if ([string]::IsNullOrWhiteSpace($desktop) -or -not (Test-Path $desktop)) { $desktop = $PastaScript }
        $arq = Join-Path $desktop ("otimizador-log_{0}.txt" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"))
        $cab = @(
            "==============================================================",
            " OTIMIZADOR TOTAL - Relatorio de execucao",
            " Data:    $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')",
            " Maquina: $env:COMPUTERNAME   Usuario: $env:USERNAME",
            " Sistema: $Global:NomeSO (build $Global:BuildSO)",
            " Dominio: $(if ($Global:EmDominio) { 'SIM (AD) - ajustes de GPO respeitados' } else { 'NAO (PC fora de dominio)' })",
            " Aplicadas: $Global:Aplicadas  |  Puladas: $Global:Puladas",
            "=============================================================="
        )
        # @(...) forca array (o $Global:Log e uma List[string]); junta cabecalho + linhas.
        $conteudo = @($cab) + "" + @($Global:Log)
        Set-Content -Path $arq -Value $conteudo -Encoding UTF8
        Write-Host ""
        Write-Host "  Relatorio salvo em: $arq" -ForegroundColor Cyan
    } catch {
        Write-Host "  (nao consegui salvar o relatorio: $($_.Exception.Message))" -ForegroundColor DarkYellow
    }
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

# Mede o desempenho atual da maquina (RAM, processos, servicos ativos)
function Medir-Desempenho {
    $os = Get-CimInstance Win32_OperatingSystem
    $usoKB   = $os.TotalVisibleMemorySize - $os.FreePhysicalMemory
    return [PSCustomObject]@{
        RamUsoPct      = [math]::Round(($usoKB / $os.TotalVisibleMemorySize) * 100, 1)
        RamLivreGB     = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        Processos      = (Get-Process).Count
        ServicosAtivos = (Get-Service | Where-Object { $_.Status -eq "Running" }).Count
    }
}

# Mostra uma linha comparando dois valores com seta de melhora/piora
function Linha-Comparacao {
    param([string]$Rotulo,$Antes,$Depois,[string]$Sufixo="",[switch]$MenorMelhor)
    $delta = [math]::Round($Depois - $Antes, 2)
    if ($delta -eq 0) {
        $cor = "Gray";  $seta = "="
    } elseif ( ($MenorMelhor -and $delta -lt 0) -or (-not $MenorMelhor -and $delta -gt 0) ) {
        $cor = "Green"; $seta = "v MELHOROU"
    } else {
        $cor = "Red";   $seta = "^ subiu"
    }
    $sinal = if ($delta -gt 0) { "+$delta" } else { "$delta" }
    Write-Host ("   {0,-18} {1,8}{4}  ->  {2,8}{4}   ({3} {5})" -f $Rotulo, $Antes, $Depois, $sinal, $Sufixo, $seta) -ForegroundColor $cor
}

function Definir-Registro {
    param([string]$Caminho,[string]$Nome,$Valor,[string]$Tipo="DWord")
    # RESPEITO A GPO: a chave \Policies\ e territorio da Politica de Grupo. Em
    # maquina de DOMINIO (AD), ou se o valor JA estiver definido (GPO/admin no
    # controle), NAO mexemos - pra nunca sobrescrever/atrapalhar uma GPO. Em PC
    # domestico (sem dominio) e com a chave livre, aplicamos normalmente.
    if ($Caminho -match '\\Policies\\') {
        $jaDefinido = (Test-Path $Caminho) -and ($null -ne (Get-ItemProperty -Path $Caminho -Name $Nome -ErrorAction SilentlyContinue))
        if ($Global:EmDominio -or $jaDefinido) {
            $motivo = if ($Global:EmDominio) { "maquina em dominio" } else { "ja definido (GPO/admin)" }
            Write-Host "   [GPO] '$Nome' fica a cargo da Politica de Grupo ($motivo) - nao alterado." -ForegroundColor DarkCyan
            Add-Log "GPO" "Ignorado p/ respeitar GPO ($motivo): $Caminho\$Nome"
            return
        }
    }
    # Guarda o valor antigo ANTES de mexer, pra opcao 13 conseguir desfazer.
    Backup-Registro $Caminho $Nome
    # -ErrorAction Stop: se o registro estiver bloqueado (GPO/permissao), o erro
    # vira "terminating" e e capturado por quem chama (Item) -> vira aviso + log,
    # nunca uma tela vermelha de erro nao tratado.
    if (-not (Test-Path $Caminho)) { New-Item -Path $Caminho -Force -ErrorAction Stop | Out-Null }
    New-ItemProperty -Path $Caminho -Name $Nome -Value $Valor -PropertyType $Tipo -Force -ErrorAction Stop | Out-Null
}

function Item {
    param([string]$Titulo,[string]$Descricao,[scriptblock]$Acao)
    Write-Host ""
    Write-Host ("-" * 64) -ForegroundColor DarkCyan
    Write-Host "  $Titulo" -ForegroundColor Cyan
    if ($Descricao) { Write-Host "  $Descricao" -ForegroundColor Gray }
    if (Perguntar "Aplicar?") {
        try {
            & $Acao
            Write-Host "   [OK] Aplicado." -ForegroundColor Green
            $Global:Aplicadas++; Add-Log "OK" $Titulo
        } catch {
            # Nao quebra a tela com vermelho: vira aviso amigavel + registra no log.
            Write-Host "   [AVISO] Nao foi possivel aplicar: $($_.Exception.Message)" -ForegroundColor Yellow
            Add-Log "ERRO" "$Titulo  ->  $($_.Exception.Message)"
        }
    } else { Write-Host "   [--] Pulado." -ForegroundColor DarkYellow; $Global:Puladas++; Add-Log "PULADO" $Titulo }
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
            $Global:Aplicadas++; Add-Log "OK" "Servico desativado: $Amigavel ($Nome)"
        } catch {
            Write-Host "   [AVISO] Nao foi possivel desativar: $($_.Exception.Message)" -ForegroundColor Yellow
            Add-Log "ERRO" "Servico $Nome  ->  $($_.Exception.Message)"
        }
    } else { Write-Host "   [--] Mantido ligado." -ForegroundColor DarkYellow; $Global:Puladas++; Add-Log "PULADO" "Servico mantido: $Nome" }
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
                    $Global:Aplicadas++; Add-Log "OK" "Inicializacao desativada: $($p.Name) [$($chave.Origem)]"
                } catch {
                    Write-Host "   [AVISO] Nao foi possivel desativar: $($_.Exception.Message)" -ForegroundColor Yellow
                    Add-Log "ERRO" "Inicializacao $($p.Name)  ->  $($_.Exception.Message)"
                }
            } else { Write-Host "   [--] Mantido." -ForegroundColor DarkYellow; $Global:Puladas++; Add-Log "PULADO" "Inicializacao mantida: $($p.Name)" }
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
                $Global:Aplicadas++; Add-Log "OK" "App removido: $($app.Name)"
            } catch {
                Write-Host "   [AVISO] Nao foi possivel remover: $($_.Exception.Message)" -ForegroundColor Yellow
                Add-Log "ERRO" "App $($app.Name)  ->  $($_.Exception.Message)"
            }
        } else { Write-Host "   [--] Mantido." -ForegroundColor DarkYellow; $Global:Puladas++; Add-Log "PULADO" "App mantido: $($app.Name)" }
    }
    Write-Host ""
    Write-Host "   Obs: apps removidos podem ser reinstalados pela Microsoft Store." -ForegroundColor DarkGray
}

# ======================================================================
#  SECAO 7 - OTIMIZAR DISCO (HD/SSD)
# ======================================================================
function Secao-Disco {
    Titulo-Secao "7) OTIMIZAR DISCO (detecta HD ou SSD)"
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
#  SECAO 8 - AJUSTES DE REDE (DNS + THROTTLING)
# ======================================================================
function Secao-Rede {
    Titulo-Secao "8) AJUSTES DE REDE (DNS rapido + throttling)"
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
#  SECAO 11 - COMPARAR DESEMPENHO (ANTES x DEPOIS)
# ======================================================================
function Secao-Comparar {
    Titulo-Secao "11) MELHORA DE DESEMPENHO (antes x depois)"
    if (-not $Global:DesempenhoInicial) {
        Write-Host "   Ainda nao ha medida inicial." -ForegroundColor DarkGray; return
    }
    $ini = $Global:DesempenhoInicial
    $ag  = Medir-Desempenho

    Write-Host "   Item                  ANTES         AGORA      resultado" -ForegroundColor White
    Write-Host ("   " + ("-" * 58)) -ForegroundColor DarkCyan
    Linha-Comparacao "RAM em uso"     $ini.RamUsoPct      $ag.RamUsoPct      "%"  -MenorMelhor
    Linha-Comparacao "RAM livre"      $ini.RamLivreGB     $ag.RamLivreGB     "GB"
    Linha-Comparacao "Processos"      $ini.Processos      $ag.Processos      ""   -MenorMelhor
    Linha-Comparacao "Servicos ativos" $ini.ServicosAtivos $ag.ServicosAtivos ""  -MenorMelhor
    Write-Host ""
    Write-Host "   Menos processos/servicos e mais RAM livre = mais leve e rapido." -ForegroundColor Gray
    Write-Host "   Dica: o ganho fica COMPLETO depois de REINICIAR o PC." -ForegroundColor Yellow
}

# ======================================================================
#  SECAO 13 - RESTAURAR
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

    # Registro (aparencia, throttling de rede, widgets/Teams do W11, etc.)
    Write-Host ""
    if (($Global:BackupReg.Count -eq 0) -and ($Global:BackupRegDel.Count -eq 0)) {
        Write-Host "  Sem backup de registro." -ForegroundColor DarkGray
    } else {
        Write-Host "  -- Ajustes de registro --" -ForegroundColor Cyan
        Write-Host "  $($Global:BackupReg.Count) valor(es) e $($Global:BackupRegDel.Count) chave(s) criada(s) para reverter." -ForegroundColor DarkGray
        if (Perguntar "Reverter TODOS os ajustes de registro para como estavam?") {
            $okReg = 0; $erroReg = 0
            foreach ($chave in @($Global:BackupReg.Keys)) {
                $b = $Global:BackupReg[$chave]
                try {
                    if ($b.Existia) {
                        if (-not (Test-Path $b.Caminho)) { New-Item -Path $b.Caminho -Force -ErrorAction Stop | Out-Null }
                        $valor = $b.Valor
                        switch ($b.Tipo) {
                            "Binary"      { $valor = [byte[]]($b.Valor) }
                            "MultiString" { $valor = [string[]]($b.Valor) }
                        }
                        New-ItemProperty -Path $b.Caminho -Name $b.Nome -Value $valor -PropertyType $b.Tipo -Force -ErrorAction Stop | Out-Null
                    } else {
                        Remove-ItemProperty -Path $b.Caminho -Name $b.Nome -Force -ErrorAction SilentlyContinue
                    }
                    $okReg++
                } catch { $erroReg++; Add-Log "ERRO" "Restaurar registro $chave  ->  $($_.Exception.Message)" }
            }
            foreach ($k in @($Global:BackupRegDel.Keys)) {
                try { if (Test-Path $k) { Remove-Item -Path $k -Recurse -Force -ErrorAction Stop }; $okReg++ }
                catch { $erroReg++; Add-Log "ERRO" "Apagar chave $k  ->  $($_.Exception.Message)" }
            }
            $Global:BackupReg = @{}; $Global:BackupRegDel = @{}; Salvar-BackupReg
            $extra = if ($erroReg) { ", $erroReg com aviso (veja o log)" } else { "" }
            Write-Host "   [OK] Registro revertido: $okReg item(ns)$extra." -ForegroundColor Green
            Add-Log "OK" "Registro revertido ($okReg ok, $erroReg avisos)"
            Write-Host "   Dica: reinicie o Explorer (opcao 1) ou o PC para ver tudo aplicado." -ForegroundColor Yellow
        } else { Write-Host "   [--] Registro mantido." -ForegroundColor DarkYellow }
    }
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
#  SECAO 10 - AJUSTES DO WINDOWS 11
# ======================================================================
function Secao-Windows11 {
    Titulo-Secao "10) AJUSTES DO WINDOWS 11"
    if (-not $Global:Win11) {
        Write-Host "   Este PC e $Global:NomeSO - esta secao e exclusiva do Windows 11." -ForegroundColor DarkYellow
        Add-Log "INFO" "Secao W11 ignorada (sistema: $Global:NomeSO)"
        return
    }
    Write-Host "  Ajustes especificos do W11. Reversiveis (ponto de restauracao / Windows)." -ForegroundColor Gray
    # Estes ajustes mexem no registro; sao revertidos pela opcao 13 (Restaurar),
    # mas oferecemos tambem um ponto de restauracao do Windows antes, por garantia.
    Ponto-Restauracao

    Item "Menu de contexto CLASSICO (igual ao Windows 10)" `
        "Volta o menu completo do botao direito, sem o 'Mostrar mais opcoes'." {
        $clsid = "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        reg add $clsid /f /ve | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "reg add falhou (codigo $LASTEXITCODE)" }
        # restore (opcao 13) apaga a chave inteira pra voltar ao menu do W11
        Registrar-KeyParaApagar "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
    }
    Item "Desativar os WIDGETS da barra de tarefas" `
        "Tira o painel de noticias/clima (fica em 2o plano consumindo RAM)." {
        Definir-Registro $RegAdvanced "TaskbarDa" 0
        Definir-Registro "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0
    }
    Item "Desativar o CHAT (Teams) da barra de tarefas" `
        "Remove o icone do Microsoft Teams (consumidor) da barra." {
        Definir-Registro $RegAdvanced "TaskbarMn" 0
    }
    Item "Reiniciar o Explorer para aplicar os ajustes do W11" "" { Reiniciar-Explorer }
}

# ======================================================================
#  SECAO 9 - MAXIMA PERFORMANCE (CPU + Sistema)
# ======================================================================
function Secao-Performance {
    Titulo-Secao "9) MAXIMA PERFORMANCE (CPU + Sistema)"
    Write-Host "  Solta o maximo da maquina SEM fixar a CPU em 100%: o clock ainda" -ForegroundColor Gray
    Write-Host "  escala com a carga, pra monitoramento (ex.: Zabbix) ver gargalo real." -ForegroundColor Gray
    # Os itens de powercfg/bcdedit NAO sao desfeitos pela opcao 13 (que cobre so o
    # registro); por isso oferecemos um ponto de restauracao do Windows antes.
    Ponto-Restauracao

    Write-Host ""; Write-Host "  >>> CPU / ENERGIA <<<" -ForegroundColor Green
    Item "Garantir TODOS os nucleos liberados no boot" `
        "Remove qualquer limite de processadores no boot. E o jeito CERTO de 'ativar nucleos' - o msconfig so LIMITA, nao ativa." {
        # /deletevalue da erro se nao houver limite definido; isso e OK (ja esta liberado).
        cmd /c "bcdedit /deletevalue {current} numproc" 2>$null | Out-Null
        Write-Host "   Qualquer limite de nucleos foi removido (Windows usa todos)." -ForegroundColor DarkGray
    }
    Item "CPU sempre pronta: core parking OFF + turbo liberado (max 100%)" `
        "Mantem os nucleos ativos e libera a frequencia maxima SOB CARGA. NAO fixa o minimo: ociosa, a CPU baixa o clock (o monitoramento ve a carga real)." {
        powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100      | Out-Null
        powercfg -setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100      | Out-Null
        powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
        powercfg -setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
        powercfg -setactive SCHEME_CURRENT | Out-Null
    }

    Write-Host ""; Write-Host "  >>> SISTEMA / REGISTRO (reversivel pela opcao 13) <<<" -ForegroundColor Green
    Item "Prioridade para o programa em foco (resposta mais rapida)" `
        "Win32PrioritySeparation: da mais CPU pro app que voce esta usando agora." {
        Definir-Registro "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38
    }
    Item "Desativar Game DVR / gravacao em 2o plano" `
        "Para a captura de tela em segundo plano da Xbox Game Bar (libera CPU/GPU/RAM)." {
        Definir-Registro "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0
        Definir-Registro "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0
        Definir-Registro "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
    }
    Item "Ativar HAGS (agendamento de GPU por hardware)" `
        "Pode reduzir latencia da GPU. Precisa REINICIAR e ter GPU/driver compativel." {
        Definir-Registro "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2
    }
    Item "Tirar o atraso dos programas de inicializacao" `
        "Apps de startup abrem sem o atraso artificial que o Windows aplica." {
        Definir-Registro "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "StartupDelayInMSec" 0
    }
}

# ======================================================================
#  MENU PRINCIPAL
# ======================================================================
function Mostrar-Menu {
    Clear-Host
    # mede agora e guarda o inicial na 1a vez
    $agora = Medir-Desempenho
    if (-not $Global:DesempenhoInicial) { $Global:DesempenhoInicial = $agora }
    $ini = $Global:DesempenhoInicial

    Write-Host ""
    Write-Host "  ==============================================================" -ForegroundColor Magenta
    Write-Host ("          OTIMIZADOR TOTAL - {0} (leve e rapido)" -f $Global:NomeSO.ToUpper()) -ForegroundColor White
    Write-Host "  ==============================================================" -ForegroundColor Magenta
    Write-Host ("   DESEMPENHO AGORA:  RAM em uso {0}%  | Livre {1} GB  | Processos {2}  | Servicos ativos {3}" -f `
        $agora.RamUsoPct, $agora.RamLivreGB, $agora.Processos, $agora.ServicosAtivos) -ForegroundColor Cyan
    Write-Host ("   No inicio:         RAM em uso {0}%  | Livre {1} GB  | Processos {2}  | Servicos ativos {3}" -f `
        $ini.RamUsoPct, $ini.RamLivreGB, $ini.Processos, $ini.ServicosAtivos) -ForegroundColor DarkGray
    if ($Global:EmDominio) {
        Write-Host "   Maquina em DOMINIO (AD): respeitando a Politica de Grupo (GPO)." -ForegroundColor DarkCyan
    }
    Write-Host "  ==============================================================" -ForegroundColor Magenta
    Write-Host "   1 - Aparencia / efeitos visuais" -ForegroundColor Gray
    Write-Host "   2 - Limpeza (temporarios + lixeira)" -ForegroundColor Gray
    Write-Host "   3 - Programas de inicializacao (startup)" -ForegroundColor Gray
    Write-Host "   4 - Servicos / processos em segundo plano" -ForegroundColor Gray
    Write-Host "   5 - Tarefas agendadas (telemetria)" -ForegroundColor Gray
    Write-Host "   6 - Remover apps inuteis (Candy Crush, etc.)" -ForegroundColor Gray
    Write-Host "   7 - Otimizar disco (HD/SSD automatico)" -ForegroundColor Gray
    Write-Host "   8 - Ajustes de rede (DNS rapido + throttling)" -ForegroundColor Gray
    Write-Host "   9 - Maxima performance (CPU + sistema, monitoring-safe)" -ForegroundColor Gray
    Write-Host ("  10 - Ajustes do Windows 11 (menu classico, widgets, Teams){0}" -f $(if (-not $Global:Win11) { "  [seu PC: $Global:NomeSO]" } else { "" })) -ForegroundColor Gray
    Write-Host "  11 - Ver melhora de desempenho (antes x depois)" -ForegroundColor Cyan
    Write-Host "  12 - APLICAR TUDO (passa por todas as secoes)" -ForegroundColor Green
    Write-Host "  13 - RESTAURAR (desfazer servicos + inicializacao + registro)" -ForegroundColor Yellow
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
        "7" { Secao-Disco; Pause }
        "8" { Secao-Rede; Pause }
        "9" { Secao-Performance; Pause }
        "10" { Secao-Windows11; Pause }
        "11" { Secao-Comparar; Pause }
        "12" {
            Ponto-Restauracao
            Secao-Aparencia
            Secao-Limpeza
            Secao-Startup
            Secao-Servicos
            Secao-Tarefas
            Secao-Bloatware
            Secao-Disco
            Secao-Rede
            Secao-Performance
            Secao-Windows11
            Item "Reiniciar o Explorer para aplicar a aparencia" "" { Reiniciar-Explorer }
            Secao-Comparar
            Titulo-Secao "TUDO PROCESSADO - recomendado REINICIAR o PC"
            Pause
        }
        "13" { Secao-Restaurar; Pause }
        "0" { Write-Host "  Saindo..." -ForegroundColor Gray }
        default { Write-Host "  Opcao invalida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
} while ($op -ne "0")

Write-Host ""
Write-Host "  Fim. Aplicadas: $Global:Aplicadas | Puladas: $Global:Puladas" -ForegroundColor Green
Salvar-Log   # gera o relatorio de auditoria (otimizador-log_<data>.txt) na Area de Trabalho
Write-Host "  Recomendado REINICIAR o computador." -ForegroundColor Yellow
