# ============================================================
# Archivo     : Main.ps1
# Practica    : 4 – SSH y Refactorización Modular
# ============================================================

# ── Cargar bibliotecas de funciones ─────────────────────────
$LIB = Join-Path $PSScriptRoot "lib"
. "$LIB\Utils-Functions.ps1"
. "$LIB\SSH-Functions.ps1"
. "$LIB\DHCP-Functions.ps1"
. "$LIB\DNS-Functions.ps1"

# Configuración de sesión
$ErrorActionPreference = "Stop"

# Validar privilegios
Test-Administrator

# ── Submenú DHCP ────────────────────────────────────────────
function Menu-DHCP {
    $sub_loop = $true
    while ($sub_loop) {
        Clear-Host
        Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║           SUBMÓDULO – SERVIDOR DHCP                  ║" -ForegroundColor Green
        Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Green
        Write-Host "║  1. Verificar instalacion                            ║"
        Write-Host "║  2. Instalar rol DHCP                                ║"
        Write-Host "║  3. Configurar ambito (scope)                        ║"
        Write-Host "║  4. Monitoreo de leases                              ║"
        Write-Host "║  5. Eliminar un ambito                               ║"
        Write-Host "║  0. Volver al menu principal                         ║"
        Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
        $sub = (Read-Host " Opcion").Trim()
        switch ($sub) {
            "1" { Show-DHCPStatus;      Pausa-Enter }
            "2" { Install-DHCPRole;     Pausa-Enter }
            "3" { Configure-DHCPScope;  Pausa-Enter }
            "4" { Show-DHCPMonitor;     Pausa-Enter }
            "5" { Remove-DHCPScope;     Pausa-Enter }
            "0" { $sub_loop = $false }
            default { Write-Warning "Invalido"; Start-Sleep 1 }
        }
    }
}

# ── Submenú DNS ──────────────────────────────────────────────
function Menu-DNS {
    $dns_loop = $true
    while ($dns_loop) {
        Clear-Host
        Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Magenta
        Write-Host "║           SUBMÓDULO – SERVIDOR DNS                   ║" -ForegroundColor Magenta
        Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Magenta
        Write-Host "║  1. Verificar estado del servicio                    ║"
        Write-Host "║  2. Instalar rol DNS Server                          ║"
        Write-Host "║  3. Configurar Forwarders                            ║"
        Write-Host "║  4. Listar zonas configuradas                        ║"
        Write-Host "║  5. Agregar nueva zona                               ║"
        Write-Host "║  6. Eliminar zona existente                          ║"
        Write-Host "║  7. Probar resolucion DNS                            ║"
        Write-Host "║  0. Volver al menu principal                         ║"
        Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Magenta
        $sub = (Read-Host " Opcion").Trim()
        switch ($sub) {
            "1" { Show-DNSStatus;       Pausa-Enter }
            "2" { Install-DNSRole;      Pausa-Enter }
            "3" { Set-DNSForwarder;     Pausa-Enter }
            "4" { Get-DNSZones;         Pausa-Enter }
            "5" { Add-DNSZone;          Pausa-Enter }
            "6" { Remove-DNSZone;       Pausa-Enter }
            "7" { Test-DNSResolution;   Pausa-Enter }
            "0" { $dns_loop = $false }
            default { Write-Warning "Invalido"; Start-Sleep 1 }
        }
    }
}

# ── Bucle del menú principal ─────────────────────────────────
$main_loop = $true
while ($main_loop) {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║    PRÁCTICA 4 – ADMINISTRADOR DE SERVIDORES          ║" -ForegroundColor Yellow
    Write-Host "║               SERVIDOR WINDOWS                       ║" -ForegroundColor Yellow
    Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║  1.  SSH   – Instalar y configurar acceso remoto     ║"
    Write-Host "║  2.  DHCP  – Gestion del servidor DHCP           >>  ║"
    Write-Host "║  3.  DNS   – Gestion del servidor DNS            >>  ║"
    Write-Host "║  4.  Estado – Ver todos los servicios                ║"
    Write-Host "║  5.  TODO  – Instalar SSH + DHCP + DNS              ║"
    Write-Host "║  0.  Salir                                           ║"
    Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    $op = (Read-Host " Seleccione").Trim()
    
    switch ($op) {
        "1" { Configurar-ModuloSSH;  Pausa-Enter }
        "2" { Menu-DHCP }
        "3" { Menu-DNS }
        "4" { 
            Write-Sep
            Test-WinService "sshd"; Test-WinService "DHCPServer"; Test-WinService "DNS"
            Write-Sep
            Pausa-Enter 
        }
        "5" { Configurar-ModuloSSH; Install-DHCPRole; Install-DNSRole; Pausa-Enter }
        "0" { $main_loop = $false; exit 0 }
        default { Write-Warning "No valida"; Start-Sleep 1 }
    }
}