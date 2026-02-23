# ============================================================
# ADMINISTRADOR INTEGRADO - WINDOWS SERVER
# ============================================================
$ErrorActionPreference = "SilentlyContinue"

# --- BIBLIOTECA DE FUNCIONES (Integrada) ---
function Write-Sep { Write-Host "----------------------------------------------" -ForegroundColor Cyan }
function Pausa-Enter { Write-Host ""; Read-Host "Presione Enter para continuar..."; Write-Host "" }

function Test-WinService([string]$ServiceName) {
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

function Configurar-ModuloSSH {
    Write-Sep
    Write-Host "Configurando Acceso Remoto SSH..." -ForegroundColor Cyan
    Start-Service sshd
    Set-Service -Name sshd -StartupType 'Automatic'
    Write-Host "[OK] Proceso finalizado." -ForegroundColor Green
    Pausa-Enter
}

# --- MENÚ PRINCIPAL ---
$main_loop = $true
while ($main_loop) {
    Clear-Host
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "   ADMINISTRADOR DE SERVIDORES WINDOWS        " -ForegroundColor Yellow
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "1. SSH   - Configurar acceso remoto"
    Write-Host "2. DHCP  - Gestion del servidor"
    Write-Host "4. Estado - Ver todos los servicios"
    Write-Host "0. Salir"
    Write-Host ""
    $op = (Read-Host "Seleccione una opcion").Trim()
    
    switch ($op) {
        "1" { Configurar-ModuloSSH }
        "2" { Write-Host "Modulo DHCP seleccionado"; Pausa-Enter }
        "4" { 
            Write-Host "--- Estado General de Servicios ---" -ForegroundColor Gray
            Test-WinService "sshd"
            Test-WinService "DHCPServer"
            Test-WinService "DNS"
            Pausa-Enter 
        }
        "0" { $main_loop = $false; exit 0 }
        default { Write-Host "Opcion no valida" -ForegroundColor Red; Start-Sleep 1 }
    }
}