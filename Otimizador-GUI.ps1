<#
.SYNOPSIS
    OTIMIZADOR TOTAL - GUI (Windows 10 e 11) - versao grafica em WPF.
    Detecta o sistema automaticamente (titulo/subtitulo mostram o SO real) e
    libera a secao "Ajustes do Windows 11" so quando aplicavel. Janela bonita
    com cores por RISCO (verde/amarelo/vermelho) dizendo o que e seguro
    desativar ou nao. Marque o que quiser e clique em Aplicar.

.DESCRIPTION
    - Verde   = SEGURO (pode desativar tranquilo)
    - Amarelo = CUIDADO (so se nao usar aquele recurso)
    - Vermelho= RISCO   (so desative se souber o que faz)

    Ferramentas extras (mesmas da versao de menu):
    - Botao "Relatorio de hardware": gera uma pagina HTML na Area de Trabalho
      (CPU, RAM, discos/SMART, GPU, bateria, ativacao, drivers) e abre.
    - Categoria "Limpeza avancada": cache do Windows Update, WinSxS (DISM),
      dumps/logs antigos, cache dos navegadores e lista dos maiores arquivos.

    Servicos e inicializacao sao reversiveis pelo botao "Restaurar" (backup no
    MESMO formato da versao de menu - backup-servicos.json - entao funciona
    junto com a opcao 13 de la). Ajustes de REGISTRO (aparencia, telemetria,
    Windows 11 etc.) ainda NAO tem backup nesta versao GUI - por enquanto,
    reverta-os manualmente ou use um ponto de restauracao do Windows (botao
    "Criar ponto de restauracao"). A versao de menu (Otimizador-Total.ps1) ja
    reverte registro tambem, se precisar dessa garantia.

    Execute como ADMINISTRADOR (use o .bat ou clique direito > admin).
    Autor: Alexandre Alan
#>

# ======================================================================
#  Garante execucao como ADMINISTRADOR (auto-eleva se preciso)
# ======================================================================
$ehAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $ehAdmin) {
    try {
        Start-Process powershell.exe -Verb RunAs `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    } catch { }
    exit
}

# ======================================================================
#  Assemblies WPF
# ======================================================================
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ======================================================================
#  Globais / helpers (compativeis com a versao de menu)
# ======================================================================
$PastaScript      = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ArquivoBackupSvc = Join-Path $PastaScript "backup-servicos.json"

$HKCU          = "HKCU:"
$RegMetrics    = "$HKCU\Control Panel\Desktop\WindowMetrics"
$RegDesktop    = "$HKCU\Control Panel\Desktop"
$RegAdvanced   = "$HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$RegVisualFX   = "$HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
$RegDWM        = "$HKCU\Software\Microsoft\Windows\DWM"
$BackupStartup = "$HKCU\Software\OtimizadorBackup\Startup"

$Global:BackupSvc = @{}
if (Test-Path $ArquivoBackupSvc) {
    try {
        $j = Get-Content $ArquivoBackupSvc -Raw | ConvertFrom-Json
        foreach ($p in $j.PSObject.Properties) { $Global:BackupSvc[$p.Name] = $p.Value }
    } catch { }
}

# ----------------------------------------------------------------------
#  Deteccao do sistema (Windows 10 x 11) - mesmo criterio da versao de menu.
#  Usado pra: (1) titulo/subtitulo da janela mostrarem o SO real, e (2) so
#  incluir no catalogo os itens de "Ajustes do Windows 11" quando aplicavel
#  (em vez de listar e depois avisar "nao se aplica" como a versao de menu).
# ----------------------------------------------------------------------
$Global:BuildSO = [int]([System.Environment]::OSVersion.Version.Build)
$Global:Win11   = $Global:BuildSO -ge 22000
$Global:NomeSO  = if ($Global:Win11) { "Windows 11" } else { "Windows 10" }

# ----------------------------------------------------------------------
#  PERFIL DA MAQUINA (deteccao adaptativa) - mesma logica da versao de menu
# ----------------------------------------------------------------------
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

function Salvar-BackupSvc {
    try { $Global:BackupSvc | ConvertTo-Json | Set-Content -Path $ArquivoBackupSvc -Encoding UTF8 } catch { }
}

function Definir-Registro {
    param([string]$Caminho,[string]$Nome,$Valor,[string]$Tipo="DWord")
    if (-not (Test-Path $Caminho)) { New-Item -Path $Caminho -Force | Out-Null }
    New-ItemProperty -Path $Caminho -Name $Nome -Value $Valor -PropertyType $Tipo -Force | Out-Null
}

function Medir-Desempenho {
    $os = Get-CimInstance Win32_OperatingSystem
    $usoKB = $os.TotalVisibleMemorySize - $os.FreePhysicalMemory
    return [PSCustomObject]@{
        RamUsoPct      = [math]::Round(($usoKB / $os.TotalVisibleMemorySize) * 100, 1)
        RamLivreGB     = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        Processos      = (Get-Process).Count
        ServicosAtivos = (Get-Service | Where-Object { $_.Status -eq "Running" }).Count
    }
}

# Desativa um servico salvando backup (sem perguntar nada - modo GUI)
function Apl-Servico {
    param([string]$Nome)
    $svc = Get-Service -Name $Nome -ErrorAction SilentlyContinue
    if (-not $svc) { return "nao existe nesta maquina" }
    if (-not $Global:BackupSvc.ContainsKey($Nome)) {
        $Global:BackupSvc[$Nome] = (Get-Service $Nome).StartType.ToString()
    }
    Stop-Service -Name $Nome -Force -ErrorAction SilentlyContinue
    Set-Service -Name $Nome -StartupType Disabled -ErrorAction Stop
    Salvar-BackupSvc
    return "desativado (backup salvo)"
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
#  CATALOGO DE OTIMIZACOES
#  Risco: Verde / Amarelo / Vermelho   |   Rec = ja vem marcado
# ======================================================================
$Catalogo = New-Object System.Collections.ArrayList

function Add-Tweak {
    param([string]$Cat,[string]$Titulo,[string]$Perde,[string]$Risco,[bool]$Rec,[scriptblock]$Run,[string[]]$Perfis=@())
    [void]$Catalogo.Add([PSCustomObject]@{
        Cat = $Cat; Titulo = $Titulo; Perde = $Perde; Risco = $Risco; Rec = $Rec; Run = $Run; Perfis = $Perfis
    })
}
# Perfis prontos (Gamer/Escritorio/Servidor): usados pelos botoes "Perfil ..." pra
# pre-marcar os itens certos pro uso escolhido - a pessoa ainda revisa e clica em
# "Aplicar selecionados" normalmente, nada roda sozinho so por escolher o perfil.
$TodosPerfis = @("Gamer","Escritorio","Servidor")

# ---- DIAGNOSTICO E SAUDE DO SISTEMA (verde/amarelo) ----
Add-Tweak "Diagnostico e saude do sistema" "Verificar espaco em disco, RAM e saude fisica do(s) disco(s)" `
    "So le informacoes, nao altera nada" "Verde" $true {
    $partes = @()
    $volumes = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -and $_.DriveType -eq "Fixed" }
    foreach ($v in $volumes) {
        $pct = if ($v.Size -gt 0) { [math]::Round(($v.SizeRemaining / $v.Size) * 100, 1) } else { 0 }
        $partes += "Disco $($v.DriveLetter): $pct% livre"
    }
    $os = Get-CimInstance Win32_OperatingSystem
    $ramPct = [math]::Round(($os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100, 1)
    $partes += "RAM: $ramPct% livre"
    try {
        foreach ($d in (Get-PhysicalDisk -ErrorAction Stop)) { $partes += "Disco $($d.DeviceId) ($($d.MediaType)): $($d.HealthStatus)" }
    } catch { }
    $partes -join " | "
}
Add-Tweak "Diagnostico e saude do sistema" "Verificar arquivos de sistema (SFC /scannow)" `
    "Pode demorar varios minutos; so verifica/repara, nao apaga nada seu" "Amarelo" $false {
    sfc /scannow
    if ($LASTEXITCODE -ne 0) { throw "SFC terminou com codigo $LASTEXITCODE" }
    "SFC concluido (codigo 0) - veja a saida na janela do console atras"
}
Add-Tweak "Diagnostico e saude do sistema" "Reparar imagem do Windows (DISM /RestoreHealth)" `
    "Pode demorar bastante e baixar arquivos via Windows Update" "Amarelo" $false {
    DISM /Online /Cleanup-Image /RestoreHealth
    if ($LASTEXITCODE -ne 0) { throw "RestoreHealth terminou com codigo $LASTEXITCODE" }
    "RestoreHealth concluido (codigo 0) - rode o SFC de novo para confirmar"
}

# ---- APARENCIA / EFEITOS VISUAIS (verde) ----
Add-Tweak "Aparencia / efeitos visuais" "Ajustar para MELHOR DESEMPENHO (desliga efeitos)" `
    "Visual fica mais 'cru', porem bem mais leve" "Verde" $true {
    Definir-Registro $RegVisualFX "VisualFXSetting" 2
    Definir-Registro $RegDesktop "UserPreferencesMask" ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) "Binary"
    "ok"
}
Add-Tweak "Aparencia / efeitos visuais" "Desativar animacoes de janelas" "Animacao ao minimizar/maximizar" "Verde" $true {
    Definir-Registro $RegMetrics "MinAnimate" "0" "String"; "ok"
}
Add-Tweak "Aparencia / efeitos visuais" "Desativar transparencia (barra/menu)" "Efeito de vidro que gasta GPU" "Verde" $true {
    Definir-Registro "$HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0; "ok"
}
Add-Tweak "Aparencia / efeitos visuais" "Desativar sombras e Aero Peek" "Sombras e previa de janelas" "Verde" $true {
    Definir-Registro $RegDWM "EnableAeroPeek" 0
    Definir-Registro $RegDWM "AlwaysHibernateThumbnails" 0; "ok"
}
Add-Tweak "Aparencia / efeitos visuais" "Mostrar so contorno ao arrastar janelas" "Janela cheia ao arrastar" "Verde" $true {
    Definir-Registro $RegDesktop "DragFullWindows" "0" "String"; "ok"
}
Add-Tweak "Aparencia / efeitos visuais" "Menus instantaneos (sem delay)" "Atraso/fade dos menus" "Verde" $true {
    Definir-Registro $RegDesktop "MenuShowDelay" "0" "String"; "ok"
}
Add-Tweak "Aparencia / efeitos visuais" "Desativar animacoes da barra de tarefas" "Animacoes da taskbar" "Verde" $true {
    Definir-Registro $RegAdvanced "TaskbarAnimations" 0
    Definir-Registro $RegAdvanced "ListviewAlphaSelect" 0
    Definir-Registro $RegAdvanced "ListviewShadow" 0; "ok"
}
Add-Tweak "Aparencia / efeitos visuais" "Desativar dicas, sugestoes e propaganda" "Sugestoes e anuncios do Windows" "Verde" $true {
    $cdm = "$HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Definir-Registro $cdm "SubscribedContent-338389Enabled" 0
    Definir-Registro $cdm "SubscribedContent-310093Enabled" 0
    Definir-Registro $cdm "SystemPaneSuggestionsEnabled" 0; "ok"
}
$percaAltoDesempenho = if ($Global:Perfil.EhNotebook) { "Gasta mais energia - NAO recomendado em notebook (reduz bateria)" } else { "Gasta um pouco mais de energia (ideal desktop, detectado aqui)" }
Add-Tweak "Aparencia / efeitos visuais" "Plano de energia: ALTO DESEMPENHO" $percaAltoDesempenho "Verde" (-not $Global:Perfil.EhNotebook) {
    powercfg -setactive SCHEME_MIN | Out-Null; "ok"
} @("Gamer","Servidor")

# ---- LIMPEZA (verde) ----
Add-Tweak "Limpeza" "Limpar arquivos temporarios (Temp/Prefetch/cache)" "Nada seu - so lixo do sistema" "Verde" $true {
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
    "liberado ~$([math]::Round($antes/1MB,1)) MB"
}
Add-Tweak "Limpeza" "Esvaziar a Lixeira" "Itens da lixeira (sem volta)" "Amarelo" $false {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue; "ok"
}

# ---- LIMPEZA AVANCADA (verde/amarelo) - mesmas funcoes da opcao 16 do menu ----
Add-Tweak "Limpeza avancada" "Limpar cache do Windows Update" "Nada - o Windows baixa de novo se precisar" "Verde" $true {
    Limpar-CacheWindowsUpdate
}
Add-Tweak "Limpeza avancada" "Limpar cache de miniaturas e da Otimizacao de Entrega" "Nada - miniaturas sao recriadas ao abrir a pasta" "Verde" $true {
    Limpar-CachesSistema
}
Add-Tweak "Limpeza avancada" "Apagar relatorios de erro, dumps de memoria e logs com +30 dias" `
    "Arquivos usados pra investigar telas azuis ANTIGAS (os logs recentes ficam)" "Verde" $false {
    Limpar-LogsEDumps
}
Add-Tweak "Limpeza avancada" "Limpar cache dos navegadores (Chrome, Edge, Brave, Firefox)" `
    "So o cache; historico/senhas/cookies ficam. Navegador aberto e pulado - feche antes" "Verde" $false {
    Limpar-CacheNavegadores
}
Add-Tweak "Limpeza avancada" "Limpar componentes antigos do Windows (DISM /StartComponentCleanup)" `
    "Pode demorar varios minutos (janela fica parada). Atualizacoes continuam desinstalaveis" "Amarelo" $false {
    Limpar-ComponentesWindows
}
Add-Tweak "Limpeza avancada" "Listar os maiores arquivos da sua pasta de usuario (so mostra)" `
    "Nada - nao apaga nada, so lista no log os arquivos acima de 100 MB" "Verde" $false {
    $grandes = Listar-MaioresArquivos
    foreach ($f in $grandes) { Log ("     {0,10}  {1}" -f (Formatar-Tamanho $f.Length), $f.FullName) }
    if ($grandes.Count -eq 0) { "nenhum arquivo acima de 100 MB" } else { "$($grandes.Count) arquivo(s) listados abaixo" }
}

# ---- SERVICOS SEGUROS (verde) ----
Add-Tweak "Servicos - seguros" "Telemetria / Experiencias Conectadas (DiagTrack)" "Envio de dados de uso a Microsoft" "Verde" $true { Apl-Servico "DiagTrack" }
Add-Tweak "Servicos - seguros" "Roteamento WAP Push (dmwappushservice)" "Nada perceptivel" "Verde" $true { Apl-Servico "dmwappushservice" }
Add-Tweak "Servicos - seguros" "SysMain / Superfetch" "Pre-carregamento; em SSD nao faz falta" "Verde" $true { Apl-Servico "SysMain" }
Add-Tweak "Servicos - seguros" "Servico de Fax" "Enviar/receber fax" "Verde" $true { Apl-Servico "Fax" }
Add-Tweak "Servicos - seguros" "Modo Demonstracao de Loja (RetailDemo)" "Modo de demo de loja (inutil em casa)" "Verde" $true { Apl-Servico "RetailDemo" }
Add-Tweak "Servicos - seguros" "Registro Remoto (RemoteRegistry)" "Editar registro pela rede (melhor off)" "Verde" $true { Apl-Servico "RemoteRegistry" }
Add-Tweak "Servicos - seguros" "Relatorio de Erros do Windows (WerSvc)" "Envio de relatorios de erro" "Verde" $true { Apl-Servico "WerSvc" }
Add-Tweak "Servicos - seguros" "Gerenciador de Mapas Baixados (MapsBroker)" "Mapas offline do app Mapas" "Verde" $true { Apl-Servico "MapsBroker" }
Add-Tweak "Servicos - seguros" "Compartilhamento do Windows Media (WMPNetworkSvc)" "Compartilhar biblioteca na rede" "Verde" $true { Apl-Servico "WMPNetworkSvc" }

# ---- SERVICOS XBOX (amarelo) ----
$percaXbox = if ($Global:Perfil.TemXbox) { "detectei app/controle Xbox neste PC - login em servicos Xbox" } else { "nenhum uso de Xbox detectado neste PC - login em servicos Xbox" }
Add-Tweak "Servicos - Xbox" "Xbox Live - Autenticacao (XblAuthManager)" $percaXbox "Amarelo" (-not $Global:Perfil.TemXbox) { Apl-Servico "XblAuthManager" } @("Escritorio","Servidor")
Add-Tweak "Servicos - Xbox" "Xbox Live - Salvar Jogo (XblGameSave)" $percaXbox "Amarelo" (-not $Global:Perfil.TemXbox) { Apl-Servico "XblGameSave" } @("Escritorio","Servidor")
Add-Tweak "Servicos - Xbox" "Xbox Live - Rede (XboxNetApiSvc)" $percaXbox "Amarelo" (-not $Global:Perfil.TemXbox) { Apl-Servico "XboxNetApiSvc" } @("Escritorio","Servidor")
Add-Tweak "Servicos - Xbox" "Xbox - Entrada (XboxGipSvc)" $percaXbox "Amarelo" (-not $Global:Perfil.TemXbox) { Apl-Servico "XboxGipSvc" } @("Escritorio","Servidor")

# ---- SERVICOS CUIDADO (amarelo/vermelho) ----
Add-Tweak "Servicos - cuidado" "Teclado de Toque (TabletInputService)" "Teclado virtual / emoji (Win+.)" "Amarelo" $false { Apl-Servico "TabletInputService" }
Add-Tweak "Servicos - cuidado" "Servico de Telefone (PhoneSvc)" "Integracao com telefone" "Amarelo" $false { Apl-Servico "PhoneSvc" }
Add-Tweak "Servicos - cuidado" "Geolocalizacao (lfsvc)" "Apps saberem sua localizacao" "Amarelo" $false { Apl-Servico "lfsvc" }
Add-Tweak "Servicos - cuidado" "Spooler de Impressao (Spooler)" "VOCE NAO IMPRIME MAIS - so se nao tem impressora" "Vermelho" $false { Apl-Servico "Spooler" }
Add-Tweak "Servicos - cuidado" "Windows Search / indexacao (WSearch)" "Busca de arquivos fica lenta" "Vermelho" $false { Apl-Servico "WSearch" }
Add-Tweak "Servicos - cuidado" "Notificacoes de Impressao (PrintNotify)" "Avisos da impressora" "Vermelho" $false { Apl-Servico "PrintNotify" }

# ---- APPS EM 2o PLANO + TELEMETRIA (verde) ----
Add-Tweak "Apps e telemetria" "Desativar apps da Loja em segundo plano" "Notificacoes em tempo real de apps da Loja" "Verde" $true {
    Definir-Registro "$HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1; "ok"
}
Add-Tweak "Apps e telemetria" "Reduzir telemetria ao minimo" "Nada util; para de mandar diagnostico" "Verde" $true {
    Definir-Registro "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0; "ok"
}

# ---- TAREFAS AGENDADAS (verde) ----
Add-Tweak "Tarefas agendadas" "Desativar tarefas de telemetria/compatibilidade" "Coleta de dados em segundo plano" "Verde" $true {
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
        $nome = Split-Path $t -Leaf
        $caminho = Split-Path $t -Parent
        Disable-ScheduledTask -TaskName $nome -TaskPath ($caminho + "\") -ErrorAction SilentlyContinue | Out-Null
    }
    "ok"
}

# ---- REDE (verde) ----
Add-Tweak "Rede" "Trocar DNS para Cloudflare (1.1.1.1 - rapido e privado)" "Usa DNS do provedor (reversivel no item ao lado)" "Verde" $false {
    $ad = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
    foreach ($a in $ad) { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses ("1.1.1.1","1.0.0.1") -ErrorAction Stop }
    "DNS Cloudflare aplicado"
} @("Gamer")
Add-Tweak "Rede" "Voltar DNS para AUTOMATICO (do provedor)" "Desfaz a troca de DNS acima" "Amarelo" $false {
    $ad = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
    foreach ($a in $ad) { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses -ErrorAction Stop }
    "DNS voltou ao automatico"
}
Add-Tweak "Rede" "Desativar Network Throttling" "Nada relevante; libera a rede em 2o plano" "Verde" $true {
    Definir-Registro "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xffffffff
    Definir-Registro "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0; "ok"
}
Add-Tweak "Rede" "Limpar cache de DNS agora" "Nada - so limpa enderecos antigos" "Verde" $true {
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    ipconfig /flushdns | Out-Null; "ok"
}

# ---- DISCO (dinamico: detecta HD x SSD por volume) ----
$volumes = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -and $_.DriveType -eq "Fixed" }
foreach ($v in $volumes) {
    $letra = $v.DriveLetter
    $tipo = Obter-TipoDisco $letra
    $acaoTxt = if ($tipo -eq "SSD") { "TRIM (correto p/ SSD)" } elseif ($tipo -eq "HDD") { "Desfragmentar (HD comum)" } else { "Otimizacao padrao" }
    $L = "$letra"
    Add-Tweak "Disco" "Otimizar disco $($L): (tipo: $tipo) - $acaoTxt" "Pode demorar; nao apaga nada" "Verde" $false ([scriptblock]::Create(@"
        `$t = '$tipo'
        if (`$t -eq 'SSD') { Optimize-Volume -DriveLetter '$L' -ReTrim -ErrorAction Stop }
        elseif (`$t -eq 'HDD') { Optimize-Volume -DriveLetter '$L' -Defrag -ErrorAction Stop }
        else { Optimize-Volume -DriveLetter '$L' -ErrorAction Stop }
        'otimizado'
"@))
}

# ---- BLOATWARE (dinamico: so lista o que esta instalado) ----
$padroes = @(
    "*king.com*","*CandyCrush*","*BubbleWitch*",
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
$bloat = @()
foreach ($pat in $padroes) { $bloat += Get-AppxPackage -Name $pat -ErrorAction SilentlyContinue }
$bloat = $bloat | Sort-Object Name -Unique
foreach ($app in $bloat) {
    $pfn = $app.PackageFullName
    $nm  = $app.Name
    Add-Tweak "Remover apps inuteis" "Remover: $nm" "O app some (pode reinstalar pela Store)" "Verde" $false ([scriptblock]::Create(@"
        Remove-AppxPackage -Package '$pfn' -ErrorAction Stop
        'removido'
"@))
}

# ---- MAXIMA PERFORMANCE (CPU + Sistema) - mesmos itens da versao de menu ----
# powercfg/bcdedit nao sao desfeitos pelo Restaurar (nem aqui, nem na versao de
# menu) - por isso o botao "Criar ponto de restauracao" existe. Ja os itens de
# registro abaixo usam a mesma Definir-Registro do resto da GUI.
Add-Tweak "Maxima performance" "Garantir TODOS os nucleos liberados no boot" `
    "Remove qualquer limite de processadores (msconfig so LIMITA, isto de fato libera)" "Verde" $false {
    cmd /c "bcdedit /deletevalue {current} numproc" 2>$null | Out-Null
    "ok (limite de nucleos removido, se houvesse algum)"
} @("Gamer","Servidor")
$percaCpuMax = "Nada perceptivel; ociosa a CPU ainda baixa o clock (monitoramento continua vendo carga real)"
$percaCpuMax += if ($Global:Perfil.EhNotebook) { " - NAO recomendado em notebook (reduz bateria)" } else { " - recomendado (desktop detectado)" }
Add-Tweak "Maxima performance" "CPU sempre pronta: core parking OFF + turbo liberado" $percaCpuMax "Verde" (-not $Global:Perfil.EhNotebook) {
    powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100      | Out-Null
    powercfg -setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100      | Out-Null
    powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
    powercfg -setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
    powercfg -setactive SCHEME_CURRENT | Out-Null
    "ok"
} @("Gamer","Servidor")
Add-Tweak "Maxima performance" "Prioridade para o programa em foco" `
    "Da mais CPU pro app que voce esta usando agora" "Verde" $false {
    Definir-Registro "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38; "ok"
} @("Gamer")
Add-Tweak "Maxima performance" "Prioridade pros servicos em 2o plano (correto pra servidor)" `
    "Servidor nao tem 'janela em foco' de verdade - o valor certo favorece servicos, nao apps" "Verde" $false {
    Definir-Registro "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 24; "ok"
} @("Servidor")
Add-Tweak "Maxima performance" "Desativar Game DVR / gravacao em 2o plano" `
    "Para a captura de tela em 2o plano da Xbox Game Bar (libera CPU/GPU/RAM)" "Verde" $false {
    Definir-Registro "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0
    Definir-Registro "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
    "ok"
} @("Gamer","Servidor")
$percaHags = "Pode reduzir latencia da GPU. Precisa REINICIAR e ter GPU/driver compativel"
$percaHags += if ($Global:Perfil.TemGpuDedicada) { " - GPU dedicada detectada, vale experimentar" } else { " - so GPU integrada detectada, ganho provavelmente pequeno" }
Add-Tweak "Maxima performance" "Ativar HAGS (agendamento de GPU por hardware)" $percaHags "Amarelo" $Global:Perfil.TemGpuDedicada {
    Definir-Registro "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2; "ok"
} @("Gamer")
Add-Tweak "Maxima performance" "Tirar o atraso dos programas de inicializacao" `
    "Apps de startup abrem sem o atraso artificial que o Windows aplica" "Verde" $false {
    Definir-Registro "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "StartupDelayInMSec" 0; "ok"
} @("Gamer","Servidor")

# ---- AJUSTES DO WINDOWS 11 - so entra no catalogo se o sistema for W11 ----
# (a versao de menu mostra o item e avisa "nao se aplica" no Windows 10; aqui
# preferimos nem listar, fica mais limpo pra quem esta no W10)
if ($Global:Win11) {
    Add-Tweak "Ajustes do Windows 11" "Menu de contexto CLASSICO (igual ao Windows 10)" `
        "Volta o menu completo do botao direito, sem o 'Mostrar mais opcoes'" "Verde" $false {
        $clsid = "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        reg add $clsid /f /ve | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "reg add falhou (codigo $LASTEXITCODE)" }
        "ok"
    } @("Escritorio")
    Add-Tweak "Ajustes do Windows 11" "Desativar os WIDGETS da barra de tarefas" `
        "Tira o painel de noticias/clima (fica em 2o plano consumindo RAM)" "Verde" $false {
        # So a chave HKCU (usuario) - a de HKLM\...\Policies\Dsh fica de fora aqui
        # de proposito: e territorio de GPO e a Definir-Registro da GUI ainda nao
        # tem a checagem de dominio/GPO que a versao de menu tem.
        Definir-Registro $RegAdvanced "TaskbarDa" 0; "ok"
} @("Gamer","Servidor")
    Add-Tweak "Ajustes do Windows 11" "Desativar o CHAT (Teams) da barra de tarefas" `
        "Remove o icone do Microsoft Teams (consumidor) da barra" "Verde" $false {
        Definir-Registro $RegAdvanced "TaskbarMn" 0; "ok"
    } @("Gamer","Servidor")
    Add-Tweak "Ajustes do Windows 11" "Reiniciar o Explorer (aplica os ajustes do W11 acima)" `
        "A barra de tarefas pisca e recarrega por um instante" "Amarelo" $false {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer }
        "ok"
    } $TodosPerfis
}

# ======================================================================
#  XAML - casca da janela (tema escuro)
# ======================================================================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Otimizador Total" Height="760" Width="940"
        WindowStartupLocation="CenterScreen" Background="#FF1E1E2E">
  <Grid Margin="0">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Cabecalho -->
    <Border Grid.Row="0" Background="#FF181826" Padding="18,14">
      <StackPanel>
        <TextBlock Text="OTIMIZADOR TOTAL" Foreground="#FFFFFFFF" FontSize="22" FontWeight="Bold"/>
        <TextBlock x:Name="TxtSubtitulo" Text="Mais leve e rapido. Marque o que quiser e clique em Aplicar." Foreground="#FFAAAAC0" FontSize="12" Margin="0,2,0,8"/>
        <TextBlock x:Name="TxtPerf" Foreground="#FF7FE0C0" FontSize="13" FontWeight="SemiBold"/>
        <TextBlock x:Name="TxtPerfIni" Foreground="#FF7A7A90" FontSize="11"/>
      </StackPanel>
    </Border>

    <!-- Barra de ferramentas -->
    <Border Grid.Row="1" Background="#FF222232" Padding="14,10">
      <StackPanel>
        <WrapPanel>
          <Button x:Name="BtnAplicar" Content="  Aplicar selecionados  " Background="#FF2ECC71" Foreground="#FF10221A" FontWeight="Bold" Padding="6,6" Margin="0,0,8,0" BorderThickness="0"/>
          <Button x:Name="BtnRec" Content="  Marcar recomendados  " Background="#FF3A3A55" Foreground="#FFFFFFFF" Padding="6,6" Margin="0,0,8,0" BorderThickness="0"/>
          <Button x:Name="BtnLimpar" Content="  Desmarcar tudo  " Background="#FF3A3A55" Foreground="#FFFFFFFF" Padding="6,6" Margin="0,0,8,0" BorderThickness="0"/>
          <Button x:Name="BtnPonto" Content="  Criar ponto de restauracao  " Background="#FF3A3A55" Foreground="#FFFFFFFF" Padding="6,6" Margin="0,0,8,0" BorderThickness="0"/>
          <Button x:Name="BtnRestaurar" Content="  Restaurar (desfazer)  " Background="#FFF1C40F" Foreground="#FF2A2300" FontWeight="Bold" Padding="6,6" Margin="0,0,8,0" BorderThickness="0"/>
          <Button x:Name="BtnMedir" Content="  Atualizar medicao  " Background="#FF3A3A55" Foreground="#FFFFFFFF" Padding="6,6" Margin="0,0,8,0" BorderThickness="0"/>
          <Button x:Name="BtnRelatorio" Content="  Relatorio de hardware  " Background="#FF0984E3" Foreground="#FFFFFFFF" FontWeight="Bold" Padding="6,6" Margin="0,0,8,0" BorderThickness="0"/>
        </WrapPanel>
        <WrapPanel Margin="0,8,0,0">
          <TextBlock Text="Perfis prontos: " Foreground="#FFCCCCDD" FontSize="12" VerticalAlignment="Center" Margin="0,0,6,0"/>
          <Button x:Name="BtnPerfilGamer" Content="  Gamer  " Background="#FF6C5CE7" Foreground="#FFFFFFFF" FontWeight="Bold" Padding="6,4" Margin="0,0,8,0" BorderThickness="0"/>
          <Button x:Name="BtnPerfilEscritorio" Content="  Escritorio  " Background="#FF6C5CE7" Foreground="#FFFFFFFF" FontWeight="Bold" Padding="6,4" Margin="0,0,8,0" BorderThickness="0"/>
          <Button x:Name="BtnPerfilServidor" Content="  Servidor  " Background="#FF6C5CE7" Foreground="#FFFFFFFF" FontWeight="Bold" Padding="6,4" Margin="0,0,8,0" BorderThickness="0"/>
        </WrapPanel>
        <WrapPanel Margin="0,8,0,0">
          <Border Background="#FF2ECC71" Width="14" Height="14" CornerRadius="3"/><TextBlock Text=" SEGURO (pode desativar)   " Foreground="#FFCCCCDD" FontSize="11" Margin="4,0,12,0"/>
          <Border Background="#FFF1C40F" Width="14" Height="14" CornerRadius="3"/><TextBlock Text=" CUIDADO (so se nao usa)   " Foreground="#FFCCCCDD" FontSize="11" Margin="4,0,12,0"/>
          <Border Background="#FFE74C3C" Width="14" Height="14" CornerRadius="3"/><TextBlock Text=" RISCO (so se souber)" Foreground="#FFCCCCDD" FontSize="11" Margin="4,0,12,0"/>
        </WrapPanel>
      </StackPanel>
    </Border>

    <!-- Lista de itens -->
    <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" Padding="0,6">
      <StackPanel x:Name="PainelItens"/>
    </ScrollViewer>

    <!-- Rodape / log -->
    <Border Grid.Row="3" Background="#FF181826" Padding="14,8">
      <ScrollViewer Height="92" VerticalScrollBarVisibility="Auto">
        <TextBlock x:Name="TxtLog" Foreground="#FF9BE6B4" FontFamily="Consolas" FontSize="12" TextWrapping="Wrap"/>
      </ScrollViewer>
    </Border>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$win    = [Windows.Markup.XamlReader]::Load($reader)

$TxtPerf      = $win.FindName("TxtPerf")
$TxtPerfIni   = $win.FindName("TxtPerfIni")
$TxtSubtitulo = $win.FindName("TxtSubtitulo")
$PainelItens  = $win.FindName("PainelItens")
$TxtLog       = $win.FindName("TxtLog")
$BtnAplicar   = $win.FindName("BtnAplicar")
$BtnRec       = $win.FindName("BtnRec")
$BtnLimpar    = $win.FindName("BtnLimpar")
$BtnPonto     = $win.FindName("BtnPonto")
$BtnRestaurar = $win.FindName("BtnRestaurar")
$BtnMedir     = $win.FindName("BtnMedir")
$BtnRelatorio = $win.FindName("BtnRelatorio")
$BtnPerfilGamer      = $win.FindName("BtnPerfilGamer")
$BtnPerfilEscritorio = $win.FindName("BtnPerfilEscritorio")
$BtnPerfilServidor   = $win.FindName("BtnPerfilServidor")

# Titulo/subtitulo com o SO real (detectado no topo do script), em vez do
# "Windows 10" fixo que a janela tinha antes.
$win.Title = "Otimizador Total - $Global:NomeSO"
$tipoChassiGui = if ($Global:Perfil.EhNotebook) { "Notebook" } else { "Desktop" }
$TxtSubtitulo.Text = "$Global:NomeSO ($tipoChassiGui, $($Global:Perfil.RamTotalGB) GB RAM) - mais leve e rapido. Itens marcados/desmarcados de acordo com este PC."

$conv = New-Object Windows.Media.BrushConverter
function Brush([string]$hex) { return $conv.ConvertFromString($hex) }
function CorRisco([string]$r) {
    switch ($r) { "Verde" { "#FF2ECC71" } "Amarelo" { "#FFF1C40F" } "Vermelho" { "#FFE74C3C" } default { "#FF888888" } }
}

# ======================================================================
#  Monta os cards a partir do catalogo
# ======================================================================
$Global:Cards = New-Object System.Collections.ArrayList
$catAtual = $null

foreach ($tw in $Catalogo) {
    if ($tw.Cat -ne $catAtual) {
        $catAtual = $tw.Cat
        $hdr = New-Object Windows.Controls.TextBlock
        $hdr.Text = $catAtual.ToUpper()
        $hdr.Foreground = Brush "#FFB0A8FF"
        $hdr.FontWeight = "Bold"
        $hdr.FontSize = 13
        $hdr.Margin = "16,14,12,2"
        [void]$PainelItens.Children.Add($hdr)
    }

    $border = New-Object Windows.Controls.Border
    $border.Background = Brush "#FF2A2A3C"
    $border.CornerRadius = 8
    $border.Margin = "12,4,12,0"
    $border.Padding = "10,8"
    $border.BorderThickness = "5,0,0,0"
    $border.BorderBrush = Brush (CorRisco $tw.Risco)

    $linha = New-Object Windows.Controls.StackPanel
    $linha.Orientation = "Horizontal"

    $chk = New-Object Windows.Controls.CheckBox
    $chk.IsChecked = $tw.Rec
    $chk.VerticalAlignment = "Center"
    $chk.Margin = "2,0,10,0"
    $chk.Tag = $tw

    $txtbox = New-Object Windows.Controls.StackPanel
    $titulo = New-Object Windows.Controls.TextBlock
    $titulo.Text = $tw.Titulo
    $titulo.Foreground = Brush "#FFFFFFFF"
    $titulo.FontSize = 13
    $titulo.FontWeight = "SemiBold"
    $titulo.TextWrapping = "Wrap"
    $perde = New-Object Windows.Controls.TextBlock
    $perde.Text = "Perde: " + $tw.Perde
    $perde.Foreground = Brush "#FF9A9AB0"
    $perde.FontSize = 11
    $perde.TextWrapping = "Wrap"
    [void]$txtbox.Children.Add($titulo)
    [void]$txtbox.Children.Add($perde)

    [void]$linha.Children.Add($chk)
    [void]$linha.Children.Add($txtbox)
    $border.Child = $linha
    [void]$PainelItens.Children.Add($border)

    [void]$Global:Cards.Add([PSCustomObject]@{ Chk = $chk; Tweak = $tw })
}

# ======================================================================
#  Funcoes de UI
# ======================================================================
$Global:Inicial = Medir-Desempenho

function Atualizar-Perf {
    $a = Medir-Desempenho
    $TxtPerf.Text = "DESEMPENHO AGORA:  RAM em uso $($a.RamUsoPct)%  |  Livre $($a.RamLivreGB) GB  |  Processos $($a.Processos)  |  Servicos ativos $($a.ServicosAtivos)"
    $i = $Global:Inicial
    $TxtPerfIni.Text = "No inicio:  RAM $($i.RamUsoPct)%  |  Livre $($i.RamLivreGB) GB  |  Processos $($i.Processos)  |  Servicos ativos $($i.ServicosAtivos)"
}

function Log([string]$msg) {
    $hora = (Get-Date).ToString("HH:mm:ss")
    $TxtLog.Text = "[$hora] $msg`r`n" + $TxtLog.Text
}

Atualizar-Perf
Log "Pronto. $($Global:Cards.Count) otimizacoes carregadas. Marque e clique em Aplicar."

# ======================================================================
#  Botoes
# ======================================================================
$BtnRec.Add_Click({
    foreach ($c in $Global:Cards) { $c.Chk.IsChecked = [bool]$c.Tweak.Rec }
    Log "Marcados os itens recomendados (apenas os verdes seguros)."
})

$BtnLimpar.Add_Click({
    foreach ($c in $Global:Cards) { $c.Chk.IsChecked = $false }
    Log "Tudo desmarcado."
})

$BtnPonto.Add_Click({
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "Antes do Otimizador Total" -RestorePointType "MODIFY_SETTINGS"
        Log "[OK] Ponto de restauracao criado."
    } catch { Log "[ERRO] Ponto de restauracao: $($_.Exception.Message)" }
})

$BtnMedir.Add_Click({ Atualizar-Perf; Log "Medicao atualizada." })

# Relatorio de hardware: so LE informacoes, por isso e um botao direto (nao um
# item do catalogo pra marcar). Mesma funcao da opcao 15 da versao de menu.
$BtnRelatorio.Add_Click({
    Log "Gerando relatorio de hardware (pode levar alguns segundos)..."
    $win.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        $r = Gerar-RelatorioHardware
        foreach ($a in $r.Alertas) { Log "   [ATENCAO] $a" }
        Log "[OK] Relatorio salvo em: $($r.Arquivo) ($($r.Alertas.Count) ponto(s) de atencao)"
        Start-Process $r.Arquivo
    } catch {
        Log "[ERRO] Relatorio de hardware: $($_.Exception.Message)"
    } finally {
        $win.Cursor = $null
    }
})

function Marcar-Perfil([string]$Nome) {
    foreach ($c in $Global:Cards) { $c.Chk.IsChecked = [bool]($c.Tweak.Perfis -contains $Nome) }
    Log "Perfil $Nome selecionado - revise as marcacoes e clique em 'Aplicar selecionados'."
}
$BtnPerfilGamer.Add_Click({ Marcar-Perfil "Gamer" })
$BtnPerfilEscritorio.Add_Click({ Marcar-Perfil "Escritorio" })
$BtnPerfilServidor.Add_Click({ Marcar-Perfil "Servidor" })

$BtnAplicar.Add_Click({
    $marcados = @($Global:Cards | Where-Object { $_.Chk.IsChecked })
    if ($marcados.Count -eq 0) { Log "Nada marcado. Marque ao menos um item."; return }

    $temVermelho = $marcados | Where-Object { $_.Tweak.Risco -eq "Vermelho" }
    if ($temVermelho) {
        $r = [Windows.MessageBox]::Show(
            "Voce marcou itens de RISCO (vermelho). Eles podem tirar recursos importantes (ex: impressao, busca de arquivos).`n`nDeseja continuar?",
            "Atencao - itens de risco", "YesNo", "Warning")
        if ($r -ne "Yes") { Log "Cancelado pelo usuario (itens de risco)."; return }
    }

    $ok = 0; $erro = 0
    foreach ($c in $marcados) {
        try {
            $res = & $c.Tweak.Run
            Log "[OK] $($c.Tweak.Titulo) -> $res"
            $ok++
        } catch {
            Log "[ERRO] $($c.Tweak.Titulo): $($_.Exception.Message)"
            $erro++
        }
    }
    Atualizar-Perf
    Log "CONCLUIDO. Aplicadas: $ok | Erros: $erro. Recomendado REINICIAR o PC."
})

$BtnRestaurar.Add_Click({
    $n = 0
    # Servicos
    if (Test-Path $ArquivoBackupSvc) {
        try {
            $j = Get-Content $ArquivoBackupSvc -Raw | ConvertFrom-Json
            foreach ($p in $j.PSObject.Properties) {
                $svc = Get-Service -Name $p.Name -ErrorAction SilentlyContinue
                if (-not $svc) { continue }
                try { Set-Service -Name $p.Name -StartupType $p.Value -ErrorAction Stop; Log "[OK] Servico $($p.Name) -> $($p.Value)"; $n++ }
                catch { Log "[ERRO] $($p.Name): $($_.Exception.Message)" }
            }
        } catch { }
    }
    # Inicializacao
    if (Test-Path $BackupStartup) {
        $props = Get-ItemProperty -Path $BackupStartup
        foreach ($p in $props.PSObject.Properties) {
            if ($p.Name -in @("PSPath","PSParentPath","PSChildName","PSDrive","PSProvider")) { continue }
            $partes = $p.Value -split "\|", 3
            if ($partes.Count -lt 3) { continue }
            try {
                if (-not (Test-Path $partes[1])) { New-Item -Path $partes[1] -Force | Out-Null }
                New-ItemProperty -Path $partes[1] -Name $p.Name -Value $partes[2] -PropertyType String -Force | Out-Null
                Remove-ItemProperty -Path $BackupStartup -Name $p.Name -Force -ErrorAction SilentlyContinue
                Log "[OK] Inicializacao restaurada: $($p.Name)"; $n++
            } catch { Log "[ERRO] $($p.Name): $($_.Exception.Message)" }
        }
    }
    if ($n -eq 0) { Log "Nada para restaurar (sem backups)." }
    else { Log "Restauracao concluida: $n itens. Reinicie o PC para efeito completo." }
    Atualizar-Perf
})

# ======================================================================
#  Mostra a janela
# ======================================================================
[void]$win.ShowDialog()
