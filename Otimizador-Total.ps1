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
      14 - Diagnostico e saude do sistema (disco/RAM + SFC/DISM)
      15 - Relatorio de hardware (pagina HTML p/ entregar ao cliente)
      16 - Limpeza avancada (Windows Update, WinSxS, dumps, navegadores)
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

# ----------------------------------------------------------------------
#  PERFIL DA MAQUINA (deteccao adaptativa)
# ----------------------------------------------------------------------
# Descobre notebook x desktop, GPU dedicada x integrada, impressora e uso de
# Xbox. Usado pra dar RECOMENDACAO REAL (com motivo) em vez da mesma sugestao
# fixa pra qualquer PC - a decisao de aplicar continua sendo sempre do usuario
# (Y/N em cada item), isto so melhora o texto mostrado antes da pergunta.
function Obter-TipoDisco {
    param([string]$Letra)
    $tipo = "Desconhecido"
    try {
        $disco = Get-Partition -DriveLetter $Letra -ErrorAction SilentlyContinue | Get-Disk -ErrorAction SilentlyContinue
        if ($disco) {
            $fis = Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DeviceId -eq $disco.Number }
            if ($fis) { $tipo = $fis.MediaType }
        }
    } catch { }
    return $tipo
}

function Detectar-Perfil {
    $perfil = [PSCustomObject]@{
        RamTotalGB     = 0
        EhNotebook     = $false
        GPUs           = @()
        TemGpuDedicada = $false
        TemXbox        = $false
    }
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $perfil.RamTotalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    } catch { }
    try {
        if ((Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
            $perfil.EhNotebook = $true
        } else {
            $tiposPortateis = 8,9,10,11,12,14,18,21
            $chassi = Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue
            foreach ($c in $chassi) {
                foreach ($t in $c.ChassisTypes) { if ($t -in $tiposPortateis) { $perfil.EhNotebook = $true } }
            }
        }
    } catch { }
    try {
        $perfil.GPUs = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | Select-Object -ExpandProperty Name)
        foreach ($g in $perfil.GPUs) {
            if ($g -notmatch "Intel|Microsoft Basic|Microsoft Remote") { $perfil.TemGpuDedicada = $true }
        }
    } catch { }
    try {
        # Apps "Xbox"/"GamingApp" vem PRE-INSTALADOS por padrao em quase todo Windows
        # 10/11 mesmo sem uso real - nao servem de sinal. O controle Xbox de verdade
        # plugado/pareado e o sinal confiavel de uso real.
        $ctrlXbox = Get-PnpDevice -Class HIDClass -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match "Xbox" }
        if (($ctrlXbox | Measure-Object).Count -gt 0) { $perfil.TemXbox = $true }
    } catch { }
    return $perfil
}
$Global:Perfil = Detectar-Perfil

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
    param([string]$Titulo,[string]$Descricao,[scriptblock]$Acao,[switch]$Silencioso)
    if (-not $Silencioso) {
        Write-Host ""
        Write-Host ("-" * 64) -ForegroundColor DarkCyan
        Write-Host "  $Titulo" -ForegroundColor Cyan
        if ($Descricao) { Write-Host "  $Descricao" -ForegroundColor Gray }
    }
    if ($Silencioso -or (Perguntar "Aplicar?")) {
        try {
            & $Acao
            Write-Host "   [OK] Aplicado: $Titulo" -ForegroundColor Green
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
    param([string]$Nome,[string]$Amigavel,[string]$Perde,[Nullable[bool]]$Recomendado=$null,[string]$Motivo="",[switch]$Silencioso)
    $svc = Get-Service -Name $Nome -ErrorAction SilentlyContinue
    if (-not $svc) { return }
    if (-not $Silencioso) {
        Write-Host ""
        Write-Host ("-" * 64) -ForegroundColor DarkCyan
        Write-Host "  $Amigavel  ($Nome)" -ForegroundColor Cyan
        Write-Host "  Voce PERDE: $Perde" -ForegroundColor Yellow
        if ($null -ne $Recomendado) {
            if ($Recomendado) {
                Write-Host "  [RECOMENDADO PRA ESTE PC] $Motivo" -ForegroundColor Green
            } else {
                Write-Host "  [NAO RECOMENDADO NESTE PC] $Motivo" -ForegroundColor Red
            }
        }
        Write-Host "  Estado atual: $($svc.Status) / inicio: $((Get-Service $Nome).StartType)" -ForegroundColor DarkGray
    }
    if ($Silencioso -or (Perguntar "Desativar?")) {
        try {
            if (-not $Global:BackupSvc.ContainsKey($Nome)) {
                $Global:BackupSvc[$Nome] = (Get-Service $Nome).StartType.ToString()
            }
            Stop-Service -Name $Nome -Force -ErrorAction SilentlyContinue
            Set-Service -Name $Nome -StartupType Disabled -ErrorAction Stop
            Salvar-BackupSvc
            Write-Host "   [OK] Desativado (backup salvo): $Amigavel" -ForegroundColor Green
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
#  FERRAMENTAS: LIMPEZA AVANCADA + RELATORIO DE HARDWARE
#  (bloco IGUAL nas duas versoes - menu e GUI - pra manter paridade)
# ======================================================================

# ---- Helpers de tamanho/limpeza ----
function Formatar-Tamanho {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    return ("{0:N1} MB" -f ($Bytes / 1MB))
}

# Soma o tamanho de tudo que casa com os caminhos (aceita curinga, ex.: "C:\pasta\*").
function Medir-Bytes {
    param([string[]]$Caminhos)
    $total = 0
    foreach ($c in $Caminhos) {
        foreach ($item in @(Get-Item -Path $c -Force -ErrorAction SilentlyContinue)) {
            if ($item.PSIsContainer) {
                $s = (Get-ChildItem -LiteralPath $item.FullName -Recurse -Force -File -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum
            } else { $s = $item.Length }
            if ($s) { $total += $s }
        }
    }
    return [double]$total
}

# Apaga o que casa com os caminhos e devolve quantos bytes REALMENTE sairam
# (mede antes e depois: arquivo em uso que nao pode ser apagado nao conta).
function Limpar-Caminhos {
    param([string[]]$Caminhos)
    $antes = Medir-Bytes $Caminhos
    foreach ($c in $Caminhos) { Remove-Item -Path $c -Recurse -Force -ErrorAction SilentlyContinue }
    $depois = Medir-Bytes $Caminhos
    return [math]::Max(0, $antes - $depois)
}

function Obter-EspacoLivre {
    try { return [double](Get-PSDrive -Name $env:SystemDrive.TrimEnd(':') -ErrorAction Stop).Free } catch { return [double]0 }
}

# ---- Limpeza avancada ----
# Instaladores de atualizacoes JA aplicadas. O Windows baixa de novo se precisar.
function Limpar-CacheWindowsUpdate {
    $servicos = @("wuauserv","bits")
    $estavamRodando = @($servicos | Where-Object { (Get-Service $_ -ErrorAction SilentlyContinue).Status -eq "Running" })
    foreach ($s in $servicos) { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue }
    try {
        $liberado = Limpar-Caminhos @("$env:WINDIR\SoftwareDistribution\Download\*")
    } finally {
        foreach ($s in $estavamRodando) { Start-Service -Name $s -ErrorAction SilentlyContinue }
    }
    return "cache do Windows Update limpo, ~$(Formatar-Tamanho $liberado) liberados"
}

# Cache da Otimizacao de Entrega (atualizacoes compartilhadas entre PCs) +
# cache de miniaturas/icones do Explorer (o Windows recria sozinho).
function Limpar-CachesSistema {
    $partes = @()
    $doPasta = "$env:WINDIR\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*"
    if (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) {
        $antes = Medir-Bytes @($doPasta)
        Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue
        $partes += "Otimizacao de Entrega ~$(Formatar-Tamanho ([math]::Max(0, $antes - (Medir-Bytes @($doPasta)))))"
    }
    $thumbs = Limpar-Caminhos @("$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db",
                                "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache_*.db")
    $partes += "miniaturas/icones ~$(Formatar-Tamanho $thumbs) (os que o Explorer esta usando saem no proximo reinicio)"
    return ($partes -join "; ")
}

# Relatorios de erro (WER), dumps de memoria e logs do Windows com mais de 30 dias.
# Os logs recentes ficam: sao os que servem pra diagnosticar um problema atual.
function Limpar-LogsEDumps {
    $alvos = @(
        "$env:ProgramData\Microsoft\Windows\WER\ReportArchive\*",
        "$env:ProgramData\Microsoft\Windows\WER\ReportQueue\*",
        "$env:LOCALAPPDATA\CrashDumps\*",
        "$env:WINDIR\Minidump\*",
        "$env:WINDIR\MEMORY.DMP",
        "$env:WINDIR\LiveKernelReports\*.dmp"
    )
    $liberado = Limpar-Caminhos $alvos
    $limite = (Get-Date).AddDays(-30)
    $antigos = @(Get-ChildItem -Path "$env:WINDIR\Logs" -Recurse -Force -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $limite -and $_.Extension -in @(".log",".cab",".etl",".txt") })
    foreach ($f in $antigos) {
        try { $tam = $f.Length; Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop; $liberado += $tam } catch { }
    }
    return "relatorios de erro, dumps e logs com +30 dias apagados, ~$(Formatar-Tamanho $liberado) liberados"
}

# So o CACHE dos navegadores (copias de imagens/scripts de sites). Historico,
# senhas, cookies, favoritos e abas NAO sao tocados. Navegador aberto e pulado,
# porque ele trava os arquivos e recria o cache na hora.
function Limpar-CacheNavegadores {
    $navegadores = @(
        @{ Nome = "Chrome";  Processo = "chrome";  Base = "$env:LOCALAPPDATA\Google\Chrome\User Data";                Pastas = @("Cache","Code Cache","GPUCache") },
        @{ Nome = "Edge";    Processo = "msedge";  Base = "$env:LOCALAPPDATA\Microsoft\Edge\User Data";               Pastas = @("Cache","Code Cache","GPUCache") },
        @{ Nome = "Brave";   Processo = "brave";   Base = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"; Pastas = @("Cache","Code Cache","GPUCache") },
        @{ Nome = "Firefox"; Processo = "firefox"; Base = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles";               Pastas = @("cache2","startupCache") }
    )
    $partes = @(); $total = 0
    foreach ($n in $navegadores) {
        if (-not (Test-Path $n.Base)) { continue }
        if (Get-Process -Name $n.Processo -ErrorAction SilentlyContinue) {
            $partes += "$($n.Nome) esta aberto - feche e rode de novo"
            continue
        }
        # "\*\" = cada perfil do navegador (Default, Profile 1, ...)
        $caminhos = @($n.Pastas | ForEach-Object { "$($n.Base)\*\$_\*" })
        $lib = Limpar-Caminhos $caminhos
        $total += $lib
        $partes += "$($n.Nome) ~$(Formatar-Tamanho $lib)"
    }
    if ($partes.Count -eq 0) { return "nenhum navegador conhecido encontrado (Chrome/Edge/Brave/Firefox)" }
    return ("total ~{0}: {1}" -f (Formatar-Tamanho $total), ($partes -join "; "))
}

# Componentes antigos do Windows (WinSxS). SEM /ResetBase de proposito: as
# atualizacoes instaladas continuam podendo ser desinstaladas depois.
function Limpar-ComponentesWindows {
    $antes = Obter-EspacoLivre
    DISM /Online /Cleanup-Image /StartComponentCleanup | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "DISM StartComponentCleanup terminou com codigo $LASTEXITCODE" }
    $ganho = [math]::Max(0, (Obter-EspacoLivre) - $antes)
    return "componentes antigos do Windows limpos, ~$(Formatar-Tamanho $ganho) liberados"
}

# So LISTA os maiores arquivos da pasta do usuario (Desktop, Downloads,
# Documentos, Videos...). Nao apaga nada: quem decide e a pessoa.
# Sem -Force de proposito: pastas ocultas (AppData) sao dados de programas.
function Listar-MaioresArquivos {
    param([string]$Raiz = $env:USERPROFILE,[int]$Quantos = 15,[long]$MinimoBytes = 100MB)
    return @(Get-ChildItem -LiteralPath $Raiz -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -ge $MinimoBytes } |
        Sort-Object Length -Descending | Select-Object -First $Quantos)
}

# ---- Relatorio de hardware (HTML) ----
function Rel-Escapar { param($Texto) return [System.Net.WebUtility]::HtmlEncode([string]$Texto) }

# Tabela com cabecalho. $Linhas = lista de [ordered]@{ Coluna = valor }; a chave
# opcional "_classe" (ok/aviso/erro) pinta a linha. $NotaHtml vai cru (ja escapado).
function Rel-Tabela {
    param([string]$Titulo,$Linhas,[string]$Vazio = "Nada encontrado.",[string]$NotaHtml = "")
    $Linhas = @($Linhas | Where-Object { $_ })
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("<section><h2>$(Rel-Escapar $Titulo)</h2>")
    if ($Linhas.Count -eq 0) {
        [void]$sb.Append("<p class='vazio'>$(Rel-Escapar $Vazio)</p>")
    } else {
        $colunas = @($Linhas[0].Keys | Where-Object { $_ -ne "_classe" })
        [void]$sb.Append("<table><thead><tr>")
        foreach ($c in $colunas) { [void]$sb.Append("<th>$(Rel-Escapar $c)</th>") }
        [void]$sb.Append("</tr></thead><tbody>")
        foreach ($l in $Linhas) {
            $cls = if ($l.Contains("_classe") -and $l["_classe"]) { " class='$($l["_classe"])'" } else { "" }
            [void]$sb.Append("<tr$cls>")
            foreach ($c in $colunas) { [void]$sb.Append("<td>$(Rel-Escapar $l[$c])</td>") }
            [void]$sb.Append("</tr>")
        }
        [void]$sb.Append("</tbody></table>")
    }
    if ($NotaHtml) { [void]$sb.Append("<p class='nota'>$NotaHtml</p>") }
    [void]$sb.Append("</section>")
    return $sb.ToString()
}

# Tabela de 2 colunas (rotulo -> valor) a partir de um [ordered]@{}.
function Rel-Pares {
    param([string]$Titulo,$Pares,[string]$NotaHtml = "")
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("<section><h2>$(Rel-Escapar $Titulo)</h2><table class='pares'><tbody>")
    foreach ($k in $Pares.Keys) { [void]$sb.Append("<tr><th>$(Rel-Escapar $k)</th><td>$(Rel-Escapar $Pares[$k])</td></tr>") }
    [void]$sb.Append("</tbody></table>")
    if ($NotaHtml) { [void]$sb.Append("<p class='nota'>$NotaHtml</p>") }
    [void]$sb.Append("</section>")
    return $sb.ToString()
}

function Rel-Data { param($Data) if ($Data) { try { return ([datetime]$Data).ToString("dd/MM/yyyy") } catch { } }; return "-" }

# Coleta tudo (so LEITURA) e salva um HTML na Area de Trabalho. Cada bloco tem
# seu proprio try: se uma informacao nao puder ser lida, o resto do relatorio sai.
# Devolve @{ Arquivo; Alertas } - os alertas tambem aparecem no topo da pagina.
function Gerar-RelatorioHardware {
    $agora = Get-Date
    $pasta = [Environment]::GetFolderPath('Desktop')
    if ([string]::IsNullOrWhiteSpace($pasta) -or -not (Test-Path $pasta)) { $pasta = $PastaScript }
    $carimbo = $agora.ToString("yyyy-MM-dd_HHmmss")
    $arq = Join-Path $pasta ("relatorio-hardware_{0}_{1}.html" -f $env:COMPUTERNAME, $carimbo)
    $secoes  = New-Object System.Collections.Generic.List[string]
    $alertas = New-Object System.Collections.Generic.List[string]

    # --- Sistema ---
    $os = $null; $cs = $null
    try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop } catch { }
    try { $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop } catch { }
    $licenca = "nao foi possivel verificar"
    try {
        # ApplicationID fixo = produtos do Windows (exclui Office etc.)
        $lic = Get-CimInstance SoftwareLicensingProduct -ErrorAction Stop `
            -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" | Select-Object -First 1
        if ($lic) {
            $st = [int]$lic.LicenseStatus
            $licenca = switch ($st) {
                0 { "NAO licenciado" } 1 { "Ativado" } 2 { "Periodo de carencia" } 3 { "Periodo de carencia (prorrogado)" }
                4 { "Carencia - copia nao genuina" } 5 { "Notificacao - NAO ativado" } 6 { "Carencia estendida" }
                default { "Desconhecido ($st)" }
            }
            if ($st -ne 1) { $alertas.Add("Windows nao esta ativado: $licenca.") }
            $licenca += " - $($lic.Name) (chave terminada em $($lic.PartialProductKey))"
        }
    } catch { }
    $sis = [ordered]@{
        "Computador" = $env:COMPUTERNAME
        "Usuario"    = $env:USERNAME
    }
    if ($cs) {
        $sis["Fabricante / modelo"] = "$($cs.Manufacturer) $($cs.Model)".Trim()
        $sis["Dominio (AD)"] = if ($cs.PartOfDomain) { "SIM - $($cs.Domain)" } else { "NAO (grupo de trabalho $($cs.Domain))" }
    }
    if ($os) {
        $sis["Sistema"] = "$($os.Caption) - versao $($os.Version) (build $Global:BuildSO), $($os.OSArchitecture)"
        $sis["Instalado em"] = Rel-Data $os.InstallDate
        if ($os.LastBootUpTime) {
            $up = $agora - $os.LastBootUpTime
            $sis["Ligado ha"] = "{0} dia(s), {1} h e {2} min" -f $up.Days, $up.Hours, $up.Minutes
            if ($up.TotalDays -ge 14) { $alertas.Add("PC ligado ha $($up.Days) dias sem reiniciar - reiniciar aplica atualizacoes e libera memoria.") }
        }
    }
    $sis["Ativacao do Windows"] = $licenca
    $secoes.Add((Rel-Pares "Sistema" $sis))

    # --- Placa-mae / BIOS ---
    try {
        $bb   = Get-CimInstance Win32_BaseBoard -ErrorAction Stop | Select-Object -First 1
        $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop | Select-Object -First 1
        $secoes.Add((Rel-Pares "Placa-mae e BIOS" ([ordered]@{
            "Placa-mae"       = "$($bb.Manufacturer) $($bb.Product)".Trim()
            "BIOS / UEFI"     = "$($bios.Manufacturer) $($bios.SMBIOSBIOSVersion) - de $(Rel-Data $bios.ReleaseDate)"
            "Numero de serie" = $bios.SerialNumber
        })))
    } catch { }

    # --- CPU ---
    try {
        $cpus = @(Get-CimInstance Win32_Processor -ErrorAction Stop | ForEach-Object {
            [ordered]@{
                "Processador" = ($_.Name -replace '\s+', ' ').Trim()
                "Nucleos"     = $_.NumberOfCores
                "Threads"     = $_.NumberOfLogicalProcessors
                "Clock maximo" = "{0:N2} GHz" -f ($_.MaxClockSpeed / 1000)
                "Uso agora"   = "$($_.LoadPercentage)%"
            }
        })
        $secoes.Add((Rel-Tabela "Processador" $cpus))
    } catch { }

    # --- Memoria RAM (pente a pente) ---
    try {
        $tiposRam = @{ 20 = "DDR"; 21 = "DDR2"; 24 = "DDR3"; 26 = "DDR4"; 34 = "DDR5"; 35 = "LPDDR5" }
        $pentes = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop)
        $linhasRam = @($pentes | ForEach-Object {
            $vel = if ($_.ConfiguredClockSpeed) { $_.ConfiguredClockSpeed } else { $_.Speed }
            $tipo = if ($tiposRam.ContainsKey([int]$_.SMBIOSMemoryType)) { $tiposRam[[int]$_.SMBIOSMemoryType] } else { "-" }
            [ordered]@{
                "Slot"       = $_.DeviceLocator
                "Capacidade" = "{0} GB" -f [math]::Round($_.Capacity / 1GB, 1)
                "Tipo"       = $tipo
                "Velocidade" = if ($vel) { "$vel MHz" } else { "-" }
                "Fabricante" = $_.Manufacturer
                "Modelo"     = "$($_.PartNumber)".Trim()
            }
        })
        $slots = (Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue | Measure-Object -Property MemoryDevices -Sum).Sum
        $totalGB = [math]::Round((($pentes | Measure-Object -Property Capacity -Sum).Sum) / 1GB, 1)
        $nota = "Total instalado: $totalGB GB em $($pentes.Count) pente(s)"
        if ($slots) { $nota += " - $slots slot(s) na placa, $([math]::Max(0, $slots - $pentes.Count)) livre(s) para upgrade" }
        if ($os) {
            $livrePct = [math]::Round(($os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100, 1)
            $nota += ". RAM livre agora: $livrePct%"
            if ($livrePct -lt 10) { $alertas.Add("RAM quase esgotada agora ($livrePct% livre).") }
        }
        if ($totalGB -gt 0 -and $totalGB -lt 8) { $alertas.Add("So $totalGB GB de RAM - para Windows 10/11 o recomendado hoje e 8 GB ou mais.") }
        $secoes.Add((Rel-Tabela "Memoria RAM" $linhasRam -NotaHtml (Rel-Escapar $nota)))
    } catch { }

    # --- Placa de video ---
    try {
        $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | ForEach-Object {
            $res = if ($_.CurrentHorizontalResolution) { "{0}x{1} @ {2} Hz" -f $_.CurrentHorizontalResolution, $_.CurrentVerticalResolution, $_.CurrentRefreshRate } else { "-" }
            [ordered]@{
                "Placa de video" = $_.Name
                "Driver"         = $_.DriverVersion
                "Data do driver" = Rel-Data $_.DriverDate
                "Resolucao"      = $res
            }
        })
        $secoes.Add((Rel-Tabela "Placa de video" $gpus))
    } catch { }

    # --- Discos fisicos (saude S.M.A.R.T., temperatura, desgaste) ---
    try {
        $discos = @(Get-PhysicalDisk -ErrorAction Stop | Sort-Object DeviceId | ForEach-Object {
            $d = $_
            $rc = $null
            try { $rc = $d | Get-StorageReliabilityCounter -ErrorAction Stop } catch { }
            $cls = switch ("$($d.HealthStatus)") { "Healthy" { "ok" } "Warning" { "aviso" } default { "erro" } }
            if ($cls -ne "ok") { $alertas.Add("Disco '$($d.FriendlyName)' com saude $($d.HealthStatus) - faca BACKUP e avalie a troca.") }
            $temp = "-"; $desg = "-"; $horas = "-"
            if ($rc) {
                if ($rc.Temperature) {
                    $temp = "$($rc.Temperature) C"
                    if ($rc.Temperature -ge 60) { $alertas.Add("Disco '$($d.FriendlyName)' quente ($($rc.Temperature) C)."); if ($cls -eq "ok") { $cls = "aviso" } }
                }
                if ($null -ne $rc.Wear) {
                    $desg = "$($rc.Wear)%"
                    if ($rc.Wear -ge 80) { $alertas.Add("SSD '$($d.FriendlyName)' com $($rc.Wear)% de desgaste - perto do fim da vida util."); if ($cls -eq "ok") { $cls = "aviso" } }
                }
                if ($rc.PowerOnHours) { $horas = "{0:N0} h" -f $rc.PowerOnHours }
            }
            [ordered]@{
                "_classe"    = $cls
                "Disco"      = $d.FriendlyName
                "Tipo"       = "$($d.MediaType)"
                "Conexao"    = "$($d.BusType)"
                "Tamanho"    = "{0:N0} GB" -f ($d.Size / 1GB)
                "Saude"      = "$($d.HealthStatus)"
                "Temperatura" = $temp
                "Desgaste"   = $desg
                "Horas ligado" = $horas
            }
        })
        $secoes.Add((Rel-Tabela "Discos fisicos" $discos -NotaHtml "Temperatura, desgaste e horas dependem do disco/driver informar - &quot;-&quot; = nao informado."))
    } catch { }

    # --- Particoes / espaco livre ---
    try {
        $vols = @(Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter -and $_.DriveType -eq "Fixed" } | Sort-Object DriveLetter | ForEach-Object {
            $pct = if ($_.Size -gt 0) { [math]::Round(($_.SizeRemaining / $_.Size) * 100, 1) } else { 0 }
            $cls = if ($pct -lt 10) { "erro" } elseif ($pct -lt 20) { "aviso" } else { "ok" }
            if ($pct -lt 10) { $alertas.Add("Unidade $($_.DriveLetter): com pouco espaco ($pct% livre).") }
            [ordered]@{
                "_classe" = $cls
                "Unidade" = "$($_.DriveLetter):"
                "Nome"    = $_.FileSystemLabel
                "Formato" = $_.FileSystem
                "Tamanho" = "{0:N1} GB" -f ($_.Size / 1GB)
                "Livre"   = "{0:N1} GB" -f ($_.SizeRemaining / 1GB)
                "% livre" = "$pct%"
            }
        })
        $secoes.Add((Rel-Tabela "Unidades e espaco livre" $vols))
    } catch { }

    # --- Bateria (so notebook) ---
    try {
        $bat = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($bat) {
            $parBat = [ordered]@{ "Carga atual" = "$($bat.EstimatedChargeRemaining)%" }
            $design = (Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction SilentlyContinue | Select-Object -First 1).DesignedCapacity
            $cheia  = (Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue | Select-Object -First 1).FullChargedCapacity
            if ($design -and $cheia) {
                $saude = [math]::Round(($cheia / $design) * 100, 0)
                $parBat["Capacidade de fabrica"] = "{0:N0} mWh" -f $design
                $parBat["Capacidade hoje"]       = "{0:N0} mWh" -f $cheia
                $parBat["Saude da bateria"]      = "$saude%"
                if ($saude -lt 60) { $alertas.Add("Bateria com $saude% da capacidade original - considere trocar.") }
            }
            # Relatorio oficial do Windows (historico de ciclos/uso), salvo ao lado.
            $arqBat = Join-Path $pasta ("relatorio-bateria_{0}_{1}.html" -f $env:COMPUTERNAME, $carimbo)
            powercfg /batteryreport /output "$arqBat" 2>$null | Out-Null
            $nota = ""
            if (Test-Path $arqBat) {
                $nomeBat = Split-Path $arqBat -Leaf
                $nota = "Historico completo de uso e ciclos: <a href='$(Rel-Escapar $nomeBat)'>$(Rel-Escapar $nomeBat)</a> (gerado pelo powercfg, na mesma pasta)."
            }
            $secoes.Add((Rel-Pares "Bateria" $parBat -NotaHtml $nota))
        }
    } catch { }

    # --- Rede ---
    try {
        $redes = @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
            $ip = @(Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IPAddress) -join ", "
            [ordered]@{
                "Adaptador"  = $_.Name
                "Descricao"  = $_.InterfaceDescription
                "Velocidade" = $_.LinkSpeed
                "MAC"        = $_.MacAddress
                "IPv4"       = $ip
            }
        })
        $secoes.Add((Rel-Tabela "Rede (adaptadores conectados)" $redes -Vazio "Nenhum adaptador de rede fisico conectado."))
    } catch { }

    # --- Dispositivos com problema de driver ---
    try {
        $probs = @(Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object { $_.Status -in @("Error","Degraded","Unknown") } | ForEach-Object {
            [ordered]@{ "_classe" = "erro"; "Dispositivo" = $_.FriendlyName; "Classe" = $_.Class; "Status" = "$($_.Status)"; "ID" = $_.InstanceId }
        })
        if ($probs.Count -gt 0) { $alertas.Add("$($probs.Count) dispositivo(s) com problema de driver (veja a tabela 'Drivers com problema').") }
        $secoes.Add((Rel-Tabela "Drivers com problema" $probs -Vazio "Nenhum - todos os dispositivos estao funcionando."))
    } catch { }

    # --- Atualizacoes recentes do Windows ---
    try {
        $hf = @(Get-HotFix -ErrorAction Stop | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending)
        if ($hf.Count -gt 0 -and ($agora - $hf[0].InstalledOn).TotalDays -gt 60) {
            $alertas.Add("Ultima atualizacao do Windows instalada em $(Rel-Data $hf[0].InstalledOn) - mais de 60 dias atras.")
        }
        $linhasHf = @($hf | Select-Object -First 8 | ForEach-Object {
            [ordered]@{ "Atualizacao" = $_.HotFixID; "Tipo" = $_.Description; "Instalada em" = Rel-Data $_.InstalledOn }
        })
        $secoes.Add((Rel-Tabela "Atualizacoes recentes do Windows" $linhasHf -Vazio "Nenhuma atualizacao encontrada."))
    } catch { }

    # --- Monta a pagina ---
    $blocoAlertas = if ($alertas.Count -gt 0) {
        "<section class='alertas'><h2>Pontos de atencao ($($alertas.Count))</h2><ul>" +
            (($alertas | ForEach-Object { "<li>$(Rel-Escapar $_)</li>" }) -join "") + "</ul></section>"
    } else {
        "<section class='alertas ok'><h2>Pontos de atencao</h2><p class='semalerta'>Nenhum problema encontrado.</p></section>"
    }
    $css = @"
body{font-family:'Segoe UI',Arial,sans-serif;margin:0;background:#f4f5fa;color:#1e1e2e}
header{background:#1e1e2e;color:#fff;padding:22px 32px}
header h1{margin:0;font-size:22px}
header p{margin:4px 0 0;color:#aaaac0;font-size:13px}
main{padding:8px 32px 24px;max-width:1100px}
section{background:#fff;border-radius:10px;padding:14px 18px;margin:14px 0;box-shadow:0 1px 3px rgba(0,0,0,.08)}
h2{font-size:14px;margin:0 0 10px;color:#6c5ce7;text-transform:uppercase;letter-spacing:.5px}
table{border-collapse:collapse;width:100%;font-size:13px}
th,td{text-align:left;padding:6px 8px;border-bottom:1px solid #ececf3;vertical-align:top}
thead th{background:#f0effa;color:#444}
table.pares th{width:220px;color:#555;font-weight:600}
tr.aviso td{background:#fff8e1}
tr.erro td{background:#fdecea}
.alertas{border-left:5px solid #f1c40f}
.alertas.ok{border-left-color:#2ecc71}
.alertas li{margin:3px 0}
.semalerta{color:#1e8e5a;font-weight:600;margin:0}
.nota,.vazio{color:#777;font-size:12px;margin:8px 0 0}
footer{color:#888;font-size:12px;padding:0 32px 24px}
@media print{body{background:#fff}section{box-shadow:none;border:1px solid #ddd;break-inside:avoid}}
"@
    $html = @(
        "<!DOCTYPE html><html lang='pt-BR'><head><meta charset='utf-8'>",
        "<title>Relatorio de hardware - $(Rel-Escapar $env:COMPUTERNAME)</title><style>$css</style></head><body>",
        "<header><h1>Relatorio de hardware - $(Rel-Escapar $env:COMPUTERNAME)</h1>",
        "<p>Gerado em $($agora.ToString('dd/MM/yyyy HH:mm')) pelo Otimizador Total - so leitura, nada foi alterado no PC.</p></header>",
        "<main>$blocoAlertas$($secoes -join '')</main>",
        "<footer>Otimizador Total - github.com/AlexandreAlan/script-windows-desempenho</footer></body></html>"
    ) -join "`n"
    Set-Content -Path $arq -Value $html -Encoding UTF8
    return [PSCustomObject]@{ Arquivo = $arq; Alertas = @($alertas) }
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
    $descAltoDesempenho = "Deixa a maquina mais responsiva."
    if ($Global:Perfil.EhNotebook) {
        $descAltoDesempenho += " [NAO RECOMENDADO NESTE PC: notebook detectado - reduz bastante a autonomia da bateria; so vale se ficar sempre na tomada.]"
    } else {
        $descAltoDesempenho += " [RECOMENDADO NESTE PC: desktop detectado.]"
    }
    Item "Plano de energia: ALTO DESEMPENHO" $descAltoDesempenho {
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
    $motivoXbox = if ($Global:Perfil.TemXbox) { "detectei app/controle Xbox neste PC" } else { "nenhum uso de Xbox detectado neste PC" }
    Desativar-Servico "XblAuthManager"   "Xbox Live - Autenticacao"  "Login em servicos Xbox"  (-not $Global:Perfil.TemXbox) $motivoXbox
    Desativar-Servico "XblGameSave"      "Xbox Live - Salvar Jogo"   "Saves na nuvem do Xbox"  (-not $Global:Perfil.TemXbox) $motivoXbox
    Desativar-Servico "XboxNetApiSvc"    "Xbox Live - Rede"          "Recursos online Xbox"    (-not $Global:Perfil.TemXbox) $motivoXbox
    Desativar-Servico "XboxGipSvc"       "Xbox - Entrada"            "Controle de Xbox no PC"  (-not $Global:Perfil.TemXbox) $motivoXbox

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
        $tipo = Obter-TipoDisco $letra

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
#  SECAO 15 - RELATORIO DE HARDWARE (HTML)
# ======================================================================
function Secao-RelatorioHardware {
    Titulo-Secao "15) RELATORIO DE HARDWARE (pagina HTML)"
    Write-Host "  Gera uma pagina com CPU, RAM (pente a pente), discos (saude/temperatura/desgaste)," -ForegroundColor Gray
    Write-Host "  GPU, bateria, rede, ativacao do Windows, drivers com problema e atualizacoes." -ForegroundColor Gray
    Write-Host "  So le informacoes - nao altera nada. Bom pra entregar ao cliente." -ForegroundColor Gray
    Write-Host ""
    Write-Host "   Coletando informacoes (pode levar alguns segundos)..." -ForegroundColor DarkGray
    try {
        $r = Gerar-RelatorioHardware
        Write-Host "   [OK] Relatorio salvo em: $($r.Arquivo)" -ForegroundColor Green
        Add-Log "OK" "Relatorio de hardware gerado: $($r.Arquivo)"
        $Global:Aplicadas++
        if ($r.Alertas.Count -gt 0) {
            Write-Host ""
            Write-Host "  >>> PONTOS DE ATENCAO <<<" -ForegroundColor Yellow
            foreach ($a in $r.Alertas) { Write-Host "   - $a" -ForegroundColor Yellow; Add-Log "AVISO" $a }
        } else {
            Write-Host "   Nenhum ponto de atencao encontrado." -ForegroundColor Green
        }
        Write-Host ""
        if (Perguntar "Abrir o relatorio no navegador agora?") { Start-Process $r.Arquivo }
    } catch {
        Write-Host "   [AVISO] Nao foi possivel gerar o relatorio: $($_.Exception.Message)" -ForegroundColor Yellow
        Add-Log "ERRO" "Relatorio de hardware  ->  $($_.Exception.Message)"
    }
}

# ======================================================================
#  SECAO 16 - LIMPEZA AVANCADA
# ======================================================================
function Secao-LimpezaAvancada {
    Titulo-Secao "16) LIMPEZA AVANCADA (libera mais espaco em disco)"
    Write-Host "  Vai alem da limpeza basica (opcao 2). Nao apaga documentos, fotos nem senhas." -ForegroundColor Gray
    $livreAntes = Obter-EspacoLivre

    Item "Limpar cache do Windows Update" `
        "Instaladores de atualizacoes ja aplicadas. Perde: nada (o Windows baixa de novo se precisar)." {
        Write-Host "   $(Limpar-CacheWindowsUpdate)" -ForegroundColor Green
    }
    Item "Limpar cache de miniaturas e da Otimizacao de Entrega" `
        "Perde: nada - as miniaturas de fotos/videos sao recriadas quando voce abrir a pasta." {
        Write-Host "   $(Limpar-CachesSistema)" -ForegroundColor Green
    }
    Item "Apagar relatorios de erro, dumps de memoria e logs com +30 dias" `
        "Perde: arquivos usados pra investigar telas azuis/travamentos ANTIGOS (os logs recentes ficam)." {
        Write-Host "   $(Limpar-LogsEDumps)" -ForegroundColor Green
    }
    Item "Limpar cache dos navegadores (Chrome, Edge, Brave, Firefox)" `
        "So o cache - historico, senhas, cookies e abas NAO sao apagados. Feche os navegadores antes." {
        Write-Host "   $(Limpar-CacheNavegadores)" -ForegroundColor Green
    }
    Item "Limpar componentes antigos do Windows (DISM /StartComponentCleanup)" `
        "Pode demorar varios minutos. As atualizacoes instaladas continuam podendo ser desinstaladas." {
        Write-Host "   $(Limpar-ComponentesWindows)" -ForegroundColor Green
    }

    $ganho = [math]::Max(0, (Obter-EspacoLivre) - $livreAntes)
    Write-Host ""
    Write-Host "   Espaco livre no disco $($env:SystemDrive) aumentou ~$(Formatar-Tamanho $ganho)." -ForegroundColor Cyan
    Add-Log "INFO" "Limpeza avancada: ~$(Formatar-Tamanho $ganho) liberados no $($env:SystemDrive)"

    Write-Host ""
    Write-Host ("-" * 64) -ForegroundColor DarkCyan
    Write-Host "  Maiores arquivos da sua pasta de usuario (Desktop, Downloads, Documentos...)" -ForegroundColor Cyan
    Write-Host "  So MOSTRA (acima de 100 MB) - nao apaga nada. Voce decide o que fazer." -ForegroundColor Gray
    if (Perguntar "Procurar os maiores arquivos agora?") {
        Write-Host "   Procurando (pode levar um pouco em pastas grandes)..." -ForegroundColor DarkGray
        $grandes = Listar-MaioresArquivos
        if ($grandes.Count -eq 0) {
            Write-Host "   Nenhum arquivo acima de 100 MB na sua pasta de usuario." -ForegroundColor Green
        } else {
            foreach ($f in $grandes) {
                Write-Host ("   {0,10}  {1}" -f (Formatar-Tamanho $f.Length), $f.FullName) -ForegroundColor Gray
            }
        }
    }
}

# ======================================================================
#  SECAO 14 - DIAGNOSTICO E SAUDE DO SISTEMA
# ======================================================================
function Secao-Diagnostico {
    Titulo-Secao "14) DIAGNOSTICO E SAUDE DO SISTEMA"
    Write-Host "  So verifica (nao altera nada, exceto se voce pedir reparo). Pode demorar alguns minutos." -ForegroundColor Gray
    # SFC/DISM reparam arquivos de sistema, nao registro - a opcao 13 nao desfaz isso.
    Ponto-Restauracao

    Write-Host ""; Write-Host "  >>> PERFIL DETECTADO DA MAQUINA <<<" -ForegroundColor Green
    Write-Host ("   Tipo: {0}" -f $(if ($Global:Perfil.EhNotebook) { "Notebook (tem bateria/chassi portatil)" } else { "Desktop" })) -ForegroundColor Gray
    Write-Host ("   RAM total: {0} GB" -f $Global:Perfil.RamTotalGB) -ForegroundColor Gray
    Write-Host ("   GPU(s): {0}" -f $(if ($Global:Perfil.GPUs.Count -gt 0) { $Global:Perfil.GPUs -join ", " } else { "nao detectada" })) -ForegroundColor Gray
    Write-Host ("   GPU dedicada: {0}" -f $(if ($Global:Perfil.TemGpuDedicada) { "sim" } else { "nao (so integrada)" })) -ForegroundColor Gray
    Write-Host ("   Uso de Xbox (app/controle): {0}" -f $(if ($Global:Perfil.TemXbox) { "sim" } else { "nao detectado" })) -ForegroundColor Gray
    Write-Host "   Esse perfil e usado pra recomendar (ou nao) itens nas secoes 4 e 9." -ForegroundColor DarkGray

    Write-Host ""; Write-Host "  >>> ESPACO EM DISCO E MEMORIA <<<" -ForegroundColor Green
    $volumes = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -and $_.DriveType -eq "Fixed" }
    foreach ($v in $volumes) {
        $livrePct = if ($v.Size -gt 0) { [math]::Round(($v.SizeRemaining / $v.Size) * 100, 1) } else { 0 }
        $cor = if ($livrePct -lt 10) { "Red" } elseif ($livrePct -lt 20) { "Yellow" } else { "Green" }
        Write-Host ("   Disco {0}:  {1} GB livres de {2} GB  ({3}% livre)" -f `
            $v.DriveLetter, [math]::Round($v.SizeRemaining/1GB,1), [math]::Round($v.Size/1GB,1), $livrePct) -ForegroundColor $cor
        if ($livrePct -lt 10) { Add-Log "AVISO" "Disco $($v.DriveLetter): espaco critico ($livrePct% livre)" }
    }
    $os = Get-CimInstance Win32_OperatingSystem
    $ramLivrePct = [math]::Round(($os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100, 1)
    $corRam = if ($ramLivrePct -lt 10) { "Red" } elseif ($ramLivrePct -lt 20) { "Yellow" } else { "Green" }
    Write-Host ("   RAM: {0} GB livres de {1} GB  ({2}% livre)" -f `
        [math]::Round($os.FreePhysicalMemory/1MB,2), [math]::Round($os.TotalVisibleMemorySize/1MB,2), $ramLivrePct) -ForegroundColor $corRam
    if ($ramLivrePct -lt 10) { Add-Log "AVISO" "RAM critica: $ramLivrePct% livre" }

    Write-Host ""; Write-Host "  >>> SAUDE FISICA DO(S) DISCO(S) <<<" -ForegroundColor Green
    try {
        $discosFisicos = Get-PhysicalDisk -ErrorAction Stop
        foreach ($d in $discosFisicos) {
            $cor = switch ($d.HealthStatus) { "Healthy" { "Green" } "Warning" { "Yellow" } default { "Red" } }
            Write-Host ("   Disco {0} ({1}, {2}): {3}" -f $d.DeviceId, $d.FriendlyName, $d.MediaType, $d.HealthStatus) -ForegroundColor $cor
            if ($d.HealthStatus -ne "Healthy") { Add-Log "AVISO" "Disco $($d.DeviceId) ($($d.FriendlyName)): $($d.HealthStatus)" }
        }
    } catch { Write-Host "   Nao foi possivel ler a saude fisica dos discos." -ForegroundColor DarkGray }

    Write-Host ""; Write-Host "  >>> ARQUIVOS DE SISTEMA (SFC + DISM) <<<" -ForegroundColor Green
    Write-Host "   A saida do comando aparece abaixo, na hora." -ForegroundColor Gray
    if (Perguntar "Rodar verificacao de arquivos de sistema (SFC /scannow)?") {
        sfc /scannow
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   [OK] SFC concluido (veja acima se encontrou/corrigiu algo)." -ForegroundColor Green
            Add-Log "OK" "SFC /scannow concluido"
        } else {
            Write-Host "   [AVISO] SFC terminou com codigo $LASTEXITCODE." -ForegroundColor Yellow
            Add-Log "AVISO" "SFC /scannow codigo $LASTEXITCODE"
        }
        $Global:Aplicadas++
    } else { Write-Host "   [--] SFC nao executado." -ForegroundColor DarkYellow; $Global:Puladas++; Add-Log "PULADO" "SFC /scannow" }

    Write-Host ""
    if (Perguntar "Rodar checagem de saude da imagem do Windows (DISM /ScanHealth)?") {
        DISM /Online /Cleanup-Image /ScanHealth
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   [OK] DISM ScanHealth concluido." -ForegroundColor Green
            Add-Log "OK" "DISM ScanHealth concluido"
        } else {
            Write-Host "   [AVISO] DISM ScanHealth terminou com codigo $LASTEXITCODE." -ForegroundColor Yellow
            Add-Log "AVISO" "DISM ScanHealth codigo $LASTEXITCODE"
        }
        $Global:Aplicadas++

        Write-Host ""
        if (Perguntar "Reparar a imagem agora (DISM /RestoreHealth - baixa arquivos via Windows Update se precisar)?") {
            DISM /Online /Cleanup-Image /RestoreHealth
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   [OK] RestoreHealth concluido. Rode o SFC de novo para confirmar." -ForegroundColor Green
                Add-Log "OK" "DISM RestoreHealth concluido"
            } else {
                Write-Host "   [AVISO] RestoreHealth terminou com codigo $LASTEXITCODE." -ForegroundColor Yellow
                Add-Log "AVISO" "DISM RestoreHealth codigo $LASTEXITCODE"
            }
            $Global:Aplicadas++
        } else { Write-Host "   [--] RestoreHealth nao executado." -ForegroundColor DarkYellow; $Global:Puladas++; Add-Log "PULADO" "DISM RestoreHealth" }
    } else { Write-Host "   [--] DISM nao executado." -ForegroundColor DarkYellow; $Global:Puladas++; Add-Log "PULADO" "DISM ScanHealth" }
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
    $descCpuMax = "Mantem os nucleos ativos e libera a frequencia maxima SOB CARGA. NAO fixa o minimo: ociosa, a CPU baixa o clock (o monitoramento ve a carga real)."
    if ($Global:Perfil.EhNotebook) {
        $descCpuMax += " [NAO RECOMENDADO NESTE PC: notebook detectado - reduz a autonomia da bateria.]"
    } else {
        $descCpuMax += " [RECOMENDADO NESTE PC: desktop detectado.]"
    }
    Item "CPU sempre pronta: core parking OFF + turbo liberado (max 100%)" $descCpuMax {
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
    $descHags = "Pode reduzir latencia da GPU. Precisa REINICIAR e ter GPU/driver compativel."
    if ($Global:Perfil.TemGpuDedicada) {
        $descHags += " [RECOMENDADO EXPERIMENTAR: GPU dedicada detectada ($($Global:Perfil.GPUs -join ', ')).]"
    } else {
        $descHags += " [GANHO PROVAVELMENTE PEQUENO: so GPU integrada detectada neste PC.]"
    }
    Item "Ativar HAGS (agendamento de GPU por hardware)" $descHags {
        Definir-Registro "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2
    }
    Item "Tirar o atraso dos programas de inicializacao" `
        "Apps de startup abrem sem o atraso artificial que o Windows aplica." {
        Definir-Registro "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "StartupDelayInMSec" 0
    }
}

# ======================================================================
#  PERFIS PRONTOS (Gamer / Escritorio / Servidor)
# ======================================================================
# Aplica direto (sem perguntar item a item) uma lista curada pro uso escolhido -
# igual ao "Aplicar Tudo", so que com o conjunto certo pro perfil. Reaproveita os
# mesmos Item/Desativar-Servico/Definir-Registro de sempre (modo -Silencioso),
# entao os backups de servico/registro e o log de auditoria funcionam igual.
function Aplicar-Perfil {
    param([ValidateSet("Gamer","Escritorio","Servidor")][string]$Nome)
    Titulo-Secao "PERFIL PRONTO: $($Nome.ToUpper())"
    Ponto-Restauracao

    Item "Visual pra desempenho (sem animacoes/transparencia/sombras)" "" -Silencioso {
        Definir-Registro $RegVisualFX "VisualFXSetting" 2
        Definir-Registro $RegDesktop "UserPreferencesMask" ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) "Binary"
        Definir-Registro $RegMetrics "MinAnimate" "0" "String"
        Definir-Registro $RegDWM "EnableAeroPeek" 0
        Definir-Registro $RegDWM "AlwaysHibernateThumbnails" 0
        Definir-Registro $RegAdvanced "TaskbarAnimations" 0
    }
    Item "Limpeza de temporarios + lixeira" "" -Silencioso {
        $alvos = @("$env:TEMP\*","$env:WINDIR\Temp\*","$env:WINDIR\Prefetch\*",
                   "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*")
        foreach ($a in $alvos) { Remove-Item $a -Recurse -Force -ErrorAction SilentlyContinue }
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    }

    $servicosSeguros = @(
        @{N="DiagTrack";A="Telemetria / Experiencias Conectadas"},
        @{N="dmwappushservice";A="Roteamento WAP Push"},
        @{N="SysMain";A="SysMain (Superfetch)"},
        @{N="Fax";A="Servico de Fax"},
        @{N="RetailDemo";A="Modo Demonstracao de Loja"},
        @{N="RemoteRegistry";A="Registro Remoto"},
        @{N="WerSvc";A="Relatorio de Erros do Windows"},
        @{N="MapsBroker";A="Gerenciador de Mapas Baixados"},
        @{N="WMPNetworkSvc";A="Compartilhamento do Windows Media"}
    )
    foreach ($s in $servicosSeguros) { Desativar-Servico $s.N $s.A "-" -Silencioso }

    if ($Nome -ne "Gamer") {
        foreach ($x in "XblAuthManager","XblGameSave","XboxNetApiSvc","XboxGipSvc") {
            Desativar-Servico $x "Xbox" "-" -Silencioso
        }
    }

    Item "Tarefas agendadas de telemetria/compatibilidade" "" -Silencioso {
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
        foreach ($t in $tarefas) {
            $nomeT = Split-Path $t -Leaf
            $caminhoT = Split-Path $t -Parent
            Disable-ScheduledTask -TaskName $nomeT -TaskPath ($caminhoT + "\") -ErrorAction SilentlyContinue | Out-Null
        }
    }
    Item "Remover apps inuteis detectados (bloatware)" "" -Silencioso {
        $padroes = @(
            "*king.com*","*CandyCrush*","*BubbleWitch*","*Microsoft.3DBuilder*",
            "*Microsoft.MixedReality.Portal*","*Microsoft.Microsoft3DViewer*","*Microsoft.Print3D*",
            "*Microsoft.SkypeApp*","*Microsoft.GetHelp*","*Microsoft.Getstarted*","*Microsoft.Messaging*",
            "*Microsoft.OneConnect*","*Microsoft.People*","*Microsoft.WindowsFeedbackHub*",
            "*Microsoft.WindowsMaps*","*Microsoft.YourPhone*","*Microsoft.ZuneMusic*","*Microsoft.ZuneVideo*",
            "*Microsoft.BingNews*","*Microsoft.BingWeather*","*Microsoft.MicrosoftSolitaireCollection*",
            "*Microsoft.WindowsAlarms*","*Microsoft.MicrosoftStickyNotes*","*Microsoft.MSPaint*",
            "*Microsoft.Wallet*","*Microsoft.Office.OneNote*","*Disney*","*Spotify*","*Facebook*",
            "*Twitter*","*Netflix*","*Microsoft.MicrosoftOfficeHub*","*Microsoft.Todos*","*Clipchamp*"
        )
        $instalados = @()
        foreach ($pat in $padroes) { $instalados += Get-AppxPackage -Name $pat -ErrorAction SilentlyContinue }
        foreach ($app in ($instalados | Sort-Object Name -Unique)) {
            Remove-AppxPackage -Package $app.PackageFullName -ErrorAction SilentlyContinue
        }
    }
    Item "Otimizar disco (TRIM/desfrag automatico por tipo)" "" -Silencioso {
        $volumes = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -and $_.DriveType -eq "Fixed" }
        foreach ($v in $volumes) {
            $t = Obter-TipoDisco $v.DriveLetter
            if ($t -eq "SSD") { Optimize-Volume -DriveLetter $v.DriveLetter -ReTrim -ErrorAction SilentlyContinue }
            elseif ($t -eq "HDD") { Optimize-Volume -DriveLetter $v.DriveLetter -Defrag -ErrorAction SilentlyContinue }
        }
    }
    Item "Desativar Network Throttling + limpar cache DNS" "" -Silencioso {
        Definir-Registro "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xffffffff
        Definir-Registro "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        ipconfig /flushdns | Out-Null
    }
    if ($Nome -eq "Gamer") {
        Item "Trocar DNS para Cloudflare (mais rapido pra jogos online)" "" -Silencioso {
            $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
            foreach ($a in $adapters) { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses ("1.1.1.1","1.0.0.1") -ErrorAction SilentlyContinue }
        }
    }

    if ($Nome -in "Gamer","Servidor") {
        if (-not ($Nome -eq "Gamer" -and $Global:Perfil.EhNotebook)) {
            Item "Nucleos liberados no boot + core parking off + turbo 100%" "" -Silencioso {
                cmd /c "bcdedit /deletevalue {current} numproc" 2>$null | Out-Null
                powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100      | Out-Null
                powercfg -setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100      | Out-Null
                powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
                powercfg -setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
                powercfg -setactive SCHEME_CURRENT | Out-Null
            }
            Item "Plano de energia: ALTO DESEMPENHO" "" -Silencioso { powercfg -setactive SCHEME_MIN | Out-Null }
        }
    }
    if ($Nome -eq "Gamer") {
        Item "Prioridade pro app em foco (mais resposta em jogo)" "" -Silencioso {
            Definir-Registro "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38
        }
    }
    if ($Nome -eq "Servidor") {
        Item "Prioridade pros servicos em 2o plano (correto pra servidor)" `
            "Servidor nao tem 'janela em foco' de verdade - o valor certo favorece servicos, nao apps." -Silencioso {
            Definir-Registro "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 24
        }
    }
    Item "Desativar Game DVR / gravacao em 2o plano" "" -Silencioso {
        Definir-Registro "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0
        Definir-Registro "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0
        Definir-Registro "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
    }
    if ($Nome -eq "Gamer" -and $Global:Perfil.TemGpuDedicada) {
        Item "Ativar HAGS (agendamento de GPU por hardware)" "" -Silencioso {
            Definir-Registro "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2
        }
    }
    if ($Nome -in "Gamer","Servidor") {
        Item "Tirar o atraso dos programas de inicializacao" "" -Silencioso {
            Definir-Registro "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "StartupDelayInMSec" 0
        }
    }

    if ($Global:Win11) {
        if ($Nome -eq "Escritorio") {
            Item "Menu de contexto classico (produtividade)" "" -Silencioso {
                $clsid = "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
                reg add $clsid /f /ve | Out-Null
                Registrar-KeyParaApagar "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
            }
        }
        Item "Desativar os WIDGETS da barra de tarefas" "" -Silencioso {
            Definir-Registro $RegAdvanced "TaskbarDa" 0
            Definir-Registro "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0
        }
        if ($Nome -ne "Escritorio") {
            Item "Desativar o CHAT (Teams) da barra de tarefas" "" -Silencioso {
                Definir-Registro $RegAdvanced "TaskbarMn" 0
            }
        }
        Item "Reiniciar o Explorer para aplicar os ajustes visuais" "" -Silencioso { Reiniciar-Explorer }
    }

    Titulo-Secao "PERFIL $($Nome.ToUpper()) APLICADO"
    Secao-Comparar
}

# ======================================================================
#  MENU PRINCIPAL
# ======================================================================
function Mostrar-Cabecalho {
    param([string]$Subtitulo)
    Clear-Host
    $agora = Medir-Desempenho
    if (-not $Global:DesempenhoInicial) { $Global:DesempenhoInicial = $agora }
    $ini = $Global:DesempenhoInicial

    Write-Host ""
    Write-Host "  ==============================================================" -ForegroundColor Magenta
    Write-Host ("          OTIMIZADOR TOTAL - {0} (leve e rapido)" -f $Global:NomeSO.ToUpper()) -ForegroundColor White
    if ($Subtitulo) { Write-Host ("          $Subtitulo") -ForegroundColor DarkGray }
    Write-Host "  ==============================================================" -ForegroundColor Magenta
    Write-Host ("   DESEMPENHO AGORA:  RAM em uso {0}%  | Livre {1} GB  | Processos {2}  | Servicos ativos {3}" -f `
        $agora.RamUsoPct, $agora.RamLivreGB, $agora.Processos, $agora.ServicosAtivos) -ForegroundColor Cyan
    Write-Host ("   No inicio:         RAM em uso {0}%  | Livre {1} GB  | Processos {2}  | Servicos ativos {3}" -f `
        $ini.RamUsoPct, $ini.RamLivreGB, $ini.Processos, $ini.ServicosAtivos) -ForegroundColor DarkGray
    if ($Global:EmDominio) {
        Write-Host "   Maquina em DOMINIO (AD): respeitando a Politica de Grupo (GPO)." -ForegroundColor DarkCyan
    }
    $tipoChassi = if ($Global:Perfil.EhNotebook) { "Notebook" } else { "Desktop" }
    $gpuResumo  = if ($Global:Perfil.GPUs.Count -gt 0) { $Global:Perfil.GPUs -join ", " } else { "nao detectada" }
    Write-Host ("   PERFIL: {0} | GPU: {1} | RAM total: {2} GB | Xbox: {3}" -f `
        $tipoChassi, $gpuResumo, $Global:Perfil.RamTotalGB, $(if ($Global:Perfil.TemXbox) {"sim"} else {"nao"})) -ForegroundColor DarkCyan
    Write-Host "  ==============================================================" -ForegroundColor Magenta
}

# Submenu generico: mostra um titulo + lista de itens (Num/Rotulo/Acao) e fica
# num loop ate a pessoa escolher "0 - Voltar". Reaproveitado pelas categorias.
function Mostrar-Submenu {
    param([string]$Titulo,[array]$Itens)
    do {
        Mostrar-Cabecalho $Titulo
        foreach ($it in $Itens) { Write-Host ("   {0} - {1}" -f $it.Num, $it.Rotulo) -ForegroundColor Gray }
        Write-Host "   0 - Voltar ao menu principal" -ForegroundColor Gray
        Write-Host "  ==============================================================" -ForegroundColor Magenta
        Write-Host "   Aplicadas: $Global:Aplicadas  |  Puladas: $Global:Puladas" -ForegroundColor DarkGray
        Write-Host ""
        $op = Read-Host "  Escolha uma opcao"
        if ($op -eq "0") { return }
        $escolhido = $Itens | Where-Object { $_.Num -eq $op }
        if ($escolhido) { & $escolhido.Acao; Pause }
        else { Write-Host "  Opcao invalida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    } while ($true)
}

function Mostrar-MenuPrincipal {
    Mostrar-Cabecalho ""
    Write-Host "   A - Sistema e limpeza        (aparencia, limpeza, limpeza avancada, inicializacao, disco)" -ForegroundColor Gray
    Write-Host "   B - Servicos e privacidade   (servicos, tarefas agendadas, bloatware)" -ForegroundColor Gray
    Write-Host "   C - Performance e jogos      (maxima performance, ajustes Windows 11)" -ForegroundColor Gray
    Write-Host "   D - Rede                     (DNS, throttling)" -ForegroundColor Gray
    Write-Host "   P - PERFIS PRONTOS           (Gamer / Escritorio / Servidor)" -ForegroundColor Green
    Write-Host "   M - Diagnostico e manutencao (diagnostico, relatorio de hardware, comparar, restaurar)" -ForegroundColor Gray
    Write-Host "   T - APLICAR TUDO (passa por todas as secoes)" -ForegroundColor Green
    Write-Host "   0 - Sair" -ForegroundColor Gray
    Write-Host "  ==============================================================" -ForegroundColor Magenta
    Write-Host "   Aplicadas: $Global:Aplicadas  |  Puladas: $Global:Puladas" -ForegroundColor DarkGray
    Write-Host ""
}

function Aplicar-Tudo {
    Ponto-Restauracao
    Secao-Diagnostico
    Secao-Aparencia
    Secao-Limpeza
    Secao-LimpezaAvancada
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
    Secao-RelatorioHardware
    Titulo-Secao "TUDO PROCESSADO - recomendado REINICIAR o PC"
}

function Menu-Perfis {
    Mostrar-Cabecalho "Perfis prontos"
    Write-Host "   Aplica direto (uma confirmacao geral) a lista certa de otimizacoes" -ForegroundColor Gray
    Write-Host "   pro uso escolhido, sem perguntar item a item." -ForegroundColor Gray
    Write-Host ""
    Write-Host "   1 - Gamer       (responsividade/FPS: performance maxima, DNS rapido, mantem Xbox)" -ForegroundColor Gray
    Write-Host "   2 - Escritorio  (produtividade: seguro e conservador, menu classico, mantem Teams)" -ForegroundColor Gray
    Write-Host "   3 - Servidor    (throughput/estabilidade: prioriza servicos, sem UI)" -ForegroundColor Gray
    Write-Host "   0 - Voltar ao menu principal" -ForegroundColor Gray
    Write-Host ""
    $op = Read-Host "  Escolha uma opcao"
    switch ($op) {
        "1" { if (Perguntar "Aplicar o perfil GAMER agora") { Aplicar-Perfil "Gamer" }; Pause }
        "2" { if (Perguntar "Aplicar o perfil ESCRITORIO agora") { Aplicar-Perfil "Escritorio" }; Pause }
        "3" { if (Perguntar "Aplicar o perfil SERVIDOR agora") { Aplicar-Perfil "Servidor" }; Pause }
        "0" { return }
        default { Write-Host "  Opcao invalida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}

# ======================================================================
#  LOOP
# ======================================================================
do {
    Mostrar-MenuPrincipal
    $op = Read-Host "  Escolha uma opcao"
    switch ($op.ToUpper()) {
        "A" {
            Mostrar-Submenu "Sistema e limpeza" @(
                @{Num="1"; Rotulo="Aparencia / efeitos visuais"; Acao={ Secao-Aparencia; Item "Reiniciar o Explorer para aplicar a aparencia" "" { Reiniciar-Explorer } }},
                @{Num="2"; Rotulo="Limpeza (temporarios + lixeira)"; Acao={ Secao-Limpeza }},
                @{Num="16"; Rotulo="Limpeza avancada (Windows Update, WinSxS, dumps, navegadores)"; Acao={ Secao-LimpezaAvancada }},
                @{Num="3"; Rotulo="Programas de inicializacao (startup)"; Acao={ Secao-Startup }},
                @{Num="7"; Rotulo="Otimizar disco (HD/SSD automatico)"; Acao={ Secao-Disco }}
            )
        }
        "B" {
            Mostrar-Submenu "Servicos e privacidade" @(
                @{Num="4"; Rotulo="Servicos / processos em segundo plano"; Acao={ Secao-Servicos }},
                @{Num="5"; Rotulo="Tarefas agendadas (telemetria)"; Acao={ Secao-Tarefas }},
                @{Num="6"; Rotulo="Remover apps inuteis (Candy Crush, etc.)"; Acao={ Secao-Bloatware }}
            )
        }
        "C" {
            Mostrar-Submenu "Performance e jogos" @(
                @{Num="9"; Rotulo="Maxima performance (CPU + sistema, monitoring-safe)"; Acao={ Secao-Performance }},
                @{Num="10"; Rotulo=("Ajustes do Windows 11 (menu classico, widgets, Teams){0}" -f $(if (-not $Global:Win11) { "  [seu PC: $Global:NomeSO]" } else { "" })); Acao={ Secao-Windows11 }}
            )
        }
        "D" {
            Mostrar-Submenu "Rede" @(
                @{Num="8"; Rotulo="Ajustes de rede (DNS rapido + throttling)"; Acao={ Secao-Rede }}
            )
        }
        "P" { Menu-Perfis }
        "M" {
            Mostrar-Submenu "Diagnostico e manutencao" @(
                @{Num="14"; Rotulo="Diagnostico e saude do sistema (disco/RAM + SFC/DISM)"; Acao={ Secao-Diagnostico }},
                @{Num="15"; Rotulo="Relatorio de hardware (pagina HTML p/ o cliente)"; Acao={ Secao-RelatorioHardware }},
                @{Num="11"; Rotulo="Ver melhora de desempenho (antes x depois)"; Acao={ Secao-Comparar }},
                @{Num="13"; Rotulo="RESTAURAR (desfazer servicos + inicializacao + registro)"; Acao={ Secao-Restaurar }}
            )
        }
        "T" { Aplicar-Tudo; Pause }
        "0" { Write-Host "  Saindo..." -ForegroundColor Gray }
        default { Write-Host "  Opcao invalida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
} while ($op -ne "0")

Write-Host ""
Write-Host "  Fim. Aplicadas: $Global:Aplicadas | Puladas: $Global:Puladas" -ForegroundColor Green
Salvar-Log   # gera o relatorio de auditoria (otimizador-log_<data>.txt) na Area de Trabalho
Write-Host "  Recomendado REINICIAR o computador." -ForegroundColor Yellow
