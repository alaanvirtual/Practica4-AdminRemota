# ============================================================
# Archivo     : Main.ps1 - VERSION ESTABLE SIN ERRORES
# ============================================================
$LIB = Join-Path $PSScriptRoot "lib"
. "$LIB\Utils-Functions.ps1"
. "$LIB\SSH-Functions.ps1"
. "$LIB\DHCP-Functions.ps1"
. "$LIB\DNS-Functions.ps1"

$ErrorActionPreference = "Stop"
Test-Administrator

function Menu-DHCP {
    $s_loop = $true
    while ($s_loop) {
        Clear-Host
        Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║      SUBMÓDULO – SERVIDOR DHCP       ║" -ForegroundColor Green
        Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Green
        Write-Host " 1. Verificar instalacion"
        Write-Host " 2. Instalar rol DHCP"
        Write-Host " 3. Configurar ambito (scope)"
        Write-Host " 0. Volver"
        $sub = (Read-Host " Opcion").Trim()
        switch ($sub) {
            "1" { Show-DHCPStatus; Pausa-Enter }
            "2" { Install-DHCPRole; Pausa-Enter }
            "3" { Configure-DHCPScope; Pausa-Enter }
            "0" { $s_loop = $false }
        }
    }
}

$main_loop = $true
while ($main_loop) {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   PRÁCTICA 4 – ADMINISTRADOR DE SERVIDORES   ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host " 1. SSH   - Configurar acceso remoto"
    Write-Host " 2. DHCP  - Gestion del servidor"
    Write-Host " 3. DNS   - Gestion del servidor"
    Write-Host " 4. Estado - Ver servicios"
    Write-Host " 0. Salir"
    $op = (Read-Host " Seleccione").Trim()
    switch ($op) {
        "1" { Configurar-ModuloSSH; Pausa-Enter }
        "2" { Menu-DHCP }
        "3" { Write-Host "DNS no implementado en este menu"; Pausa-Enter }
        "4" { Test-WinService "sshd"; Test-WinService "DHCPServer"; Pausa-Enter }
        "0" { $main_loop = $false; exit 0 }
    }
}