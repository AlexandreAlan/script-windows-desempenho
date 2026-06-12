<#
.SYNOPSIS
    Restaura os servicos do Windows que foram desativados pelo
    Otimizar-Servicos.ps1, lendo o 'backup-servicos.json'.

    Execute como ADMINISTRADOR.
#>

$ehAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $ehAdmin) {
    Write-Host " ERRO: Execute como ADMINISTRADOR." -ForegroundColor Red
    Read-Host " Pressione ENTER para sair"; exit 1
}

$PastaScript = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ArquivoBackup = Join-Path $PastaScript "backup-servicos.json"

if (-not (Test-Path $ArquivoBackup)) {
    Write-Host " Nao encontrei backup-servicos.json. Nada a restaurar." -ForegroundColor Yellow
    Read-Host " Pressione ENTER para sair"; exit 0
}

$Backup = Get-Content $ArquivoBackup -Raw | ConvertFrom-Json
$restaurados = 0

foreach ($p in $Backup.PSObject.Properties) {
    $nome   = $p.Name
    $tipo   = $p.Value   # ex: Automatic, Manual...
    $svc = Get-Service -Name $nome -ErrorAction SilentlyContinue
    if (-not $svc) { continue }

    Write-Host ""
    Write-Host " > $nome  ->  restaurar para: $tipo" -ForegroundColor White
    $r = Read-Host "   Restaurar este servico? (Y/N)"
    if ($r.ToUpper() -in @("Y","S")) {
        try {
            Set-Service -Name $nome -StartupType $tipo -ErrorAction Stop
            Write-Host "   [OK] Restaurado para $tipo." -ForegroundColor Green
            $restaurados++
        } catch {
            Write-Host "   [ERRO] $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "   [--] Mantido desativado." -ForegroundColor DarkYellow
    }
}

Write-Host ""
Write-Host " Servicos restaurados: $restaurados" -ForegroundColor Green
Write-Host " Recomendado REINICIAR o PC." -ForegroundColor Yellow
Read-Host " Pressione ENTER para sair"
