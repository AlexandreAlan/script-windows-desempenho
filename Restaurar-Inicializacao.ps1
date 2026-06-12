<#
.SYNOPSIS
    Restaura programas de inicializacao que foram desativados pelo
    Otimizar-Windows10.ps1 (le do backup salvo no registro).

    Execute como ADMINISTRADOR.
#>

$ehAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $ehAdmin) {
    Write-Host " ERRO: Execute como ADMINISTRADOR." -ForegroundColor Red
    Read-Host " Pressione ENTER para sair"; exit 1
}

$BackupStartup = "HKCU:\Software\OtimizadorBackup\Startup"

if (-not (Test-Path $BackupStartup)) {
    Write-Host " Nao ha backup de inicializacao para restaurar." -ForegroundColor Yellow
    Read-Host " Pressione ENTER para sair"; exit 0
}

$props = Get-ItemProperty -Path $BackupStartup
$restaurados = 0

foreach ($p in $props.PSObject.Properties) {
    if ($p.Name -in @("PSPath","PSParentPath","PSChildName","PSDrive","PSProvider")) { continue }

    # Formato do backup:  Origem|CaminhoDaChaveRun|ValorOriginal
    $partes = $p.Value -split "\|", 3
    if ($partes.Count -lt 3) { continue }
    $caminhoRun = $partes[1]
    $valor      = $partes[2]

    Write-Host ""
    Write-Host " > $($p.Name)" -ForegroundColor White
    Write-Host "   $valor" -ForegroundColor DarkGray
    $r = Read-Host "   Restaurar na inicializacao? (Y/N)"
    if ($r.ToUpper() -in @("Y","S")) {
        try {
            if (-not (Test-Path $caminhoRun)) { New-Item -Path $caminhoRun -Force | Out-Null }
            New-ItemProperty -Path $caminhoRun -Name $p.Name -Value $valor -PropertyType String -Force | Out-Null
            Remove-ItemProperty -Path $BackupStartup -Name $p.Name -Force -ErrorAction SilentlyContinue
            Write-Host "   [OK] Restaurado." -ForegroundColor Green
            $restaurados++
        } catch {
            Write-Host "   [ERRO] $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "   [--] Mantido desativado." -ForegroundColor DarkYellow
    }
}

Write-Host ""
Write-Host " Restaurados: $restaurados" -ForegroundColor Green
Read-Host " Pressione ENTER para sair"
