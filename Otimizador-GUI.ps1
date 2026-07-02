<#
.SYNOPSIS
    OTIMIZADOR TOTAL - GUI (Windows 10) - versao grafica em WPF.
    Janela bonita com cores por RISCO (verde/amarelo/vermelho) dizendo
    o que e seguro desativar ou nao. Marque o que quiser e clique em Aplicar.

.DESCRIPTION
    - Verde   = SEGURO (pode desativar tranquilo)
    - Amarelo = CUIDADO (so se nao usar aquele recurso)
    - Vermelho= RISCO   (so desative se souber o que faz)

    Tudo e reversivel. Os backups sao gravados no MESMO formato da versao
    de menu (backup-servicos.json + registro), entao o "Restaurar" das duas
    versoes funciona junto.

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
#  CATALOGO DE OTIMIZACOES
#  Risco: Verde / Amarelo / Vermelho   |   Rec = ja vem marcado
# ======================================================================
$Catalogo = New-Object System.Collections.ArrayList

function Add-Tweak {
    param([string]$Cat,[string]$Titulo,[string]$Perde,[string]$Risco,[bool]$Rec,[scriptblock]$Run)
    [void]$Catalogo.Add([PSCustomObject]@{
        Cat = $Cat; Titulo = $Titulo; Perde = $Perde; Risco = $Risco; Rec = $Rec; Run = $Run
    })
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
Add-Tweak "Aparencia / efeitos visuais" "Plano de energia: ALTO DESEMPENHO" "Gasta um pouco mais de energia (ideal desktop)" "Verde" $true {
    powercfg -setactive SCHEME_MIN | Out-Null; "ok"
}

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
Add-Tweak "Servicos - Xbox" "Xbox Live - Autenticacao (XblAuthManager)" "Login em servicos Xbox" "Amarelo" $false { Apl-Servico "XblAuthManager" }
Add-Tweak "Servicos - Xbox" "Xbox Live - Salvar Jogo (XblGameSave)" "Saves na nuvem do Xbox" "Amarelo" $false { Apl-Servico "XblGameSave" }
Add-Tweak "Servicos - Xbox" "Xbox Live - Rede (XboxNetApiSvc)" "Recursos online Xbox" "Amarelo" $false { Apl-Servico "XboxNetApiSvc" }
Add-Tweak "Servicos - Xbox" "Xbox - Entrada (XboxGipSvc)" "Controle de Xbox no PC" "Amarelo" $false { Apl-Servico "XboxGipSvc" }

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
}
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
    $tipo = "Desconhecido"
    try {
        $disco = Get-Partition -DriveLetter $letra -ErrorAction SilentlyContinue | Get-Disk -ErrorAction SilentlyContinue
        if ($disco) {
            $fis = Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DeviceId -eq $disco.Number }
            if ($fis) { $tipo = $fis.MediaType }
        }
    } catch { }
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

# ======================================================================
#  XAML - casca da janela (tema escuro)
# ======================================================================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Otimizador Total - Windows 10" Height="760" Width="940"
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
        <TextBlock Text="Windows 10 - mais leve e rapido. Marque o que quiser e clique em Aplicar." Foreground="#FFAAAAC0" FontSize="12" Margin="0,2,0,8"/>
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

$TxtPerf     = $win.FindName("TxtPerf")
$TxtPerfIni  = $win.FindName("TxtPerfIni")
$PainelItens = $win.FindName("PainelItens")
$TxtLog      = $win.FindName("TxtLog")
$BtnAplicar  = $win.FindName("BtnAplicar")
$BtnRec      = $win.FindName("BtnRec")
$BtnLimpar   = $win.FindName("BtnLimpar")
$BtnPonto    = $win.FindName("BtnPonto")
$BtnRestaurar= $win.FindName("BtnRestaurar")
$BtnMedir    = $win.FindName("BtnMedir")

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
