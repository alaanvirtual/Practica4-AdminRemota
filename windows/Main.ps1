# ============================================================
# Archivo     : Main.ps1 - ESTRUCTURA PLANA (Sin carpeta lib)
# ============================================================
$BASE_PATH = $PSScriptRoot

# Carga de bibliotecas directamente desde la carpeta actual
# Se usa Join-Path para evitar errores de espacios en la ruta
. (Join-Path $BASE_PATH "Utils-Functions.ps1")
. (Join-Path $BASE_PATH "SSH-Functions.ps1")
. (Join-Path $BASE_PATH "DHCP-Functions.ps1")
. (Join-Path $BASE_PATH "DNS-Functions.ps1")

$ErrorActionPreference = "Stop"

# Validar permisos (Función definida en Utils-Functions.ps1)
Test-Administrator 

function Menu-DHCP {
    $s_loop = $true
    while ($s_loop) {
        Clear-Host
        Write-Host "--- SERVIDOR DHCP (Windows) ---" -ForegroundColor Green
        Write-Host "1. Estado del servicio"
        Write-Host "2. Instalar rol DHCP"
        Write-Host "0. Volver al menu principal"
        $sub = (Read-Host " Opcion").Trim()
        switch ($sub) {
            "1" { Show-DHCPStatus; Pausa-Enter }
            "2" { Install-DHCPRole; Pausa-Enter }
            "0" { $s_loop = $false }
            default { Write-Warning "Opcion invalida"; Start-Sleep 1 }
        }
    }
}

# Menú Principal
$main_loop = $true
while ($main_loop) {
    Clear-Host
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "   ADMINISTRADOR DE SERVIDORES WINDOWS        " -ForegroundColor Yellow
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "1. SSH   - Configurar acceso remoto"
    Write-Host "2. DHCP  - Gestion del servidor"
    Write-Host "3. DNS   - Gestion del servidor"
    Write-Host "4. Estado - Ver todos los servicios"
    Write-Host "0. Salir"
    $op = (Read-Host " Seleccione una opcion").Trim()
    
    switch ($op) {
        "1" { Configurar-ModuloSSH; Pausa-Enter }
        "2" { Menu-DHCP }
        "3" { Write-Host "Modulo DNS en desarrollo"; Pausa-Enter }
        "4" { 
            Write-Host "--- Estado General ---" -ForegroundColor Gray
            Test-WinService "sshd"
            Test-WinService "DHCPServer"
            Test-WinService "DNS"
            Pausa-Enter 
        }
        "0" { $main_loop = $false; exit 0 }
        default { Write-Warning "Opcion no valida"; Start-Sleep 1 }
    }
}