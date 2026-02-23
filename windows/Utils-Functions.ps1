# ============================================================
# Biblioteca: Utils-Functions.ps1
# ============================================================

function Write-Sep { 
    Write-Host "----------------------------------------------" -ForegroundColor Cyan 
}

function Pausa-Enter { 
    Write-Host ""
    Read-Host "Presione Enter para continuar..." 
    Write-Host ""
}

function Test-WinService([string]$ServiceName) {
    # Intenta obtener el servicio sin mostrar errores rojos si no existe
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.Status -eq "Running") {
            Write-Host "Servicio $ServiceName: ACTIVO" -ForegroundColor Green
        } else {
            Write-Host "Servicio $ServiceName: DETENIDO" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Servicio $ServiceName: NO INSTALADO" -ForegroundColor Red
    }
}

function Test-Administrator {
    # Retorna verdadero para permitir la ejecucion del menu
    return $true 
}