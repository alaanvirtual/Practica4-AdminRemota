# ============================================================
# Archivo     : Main.ps1
# Descripcion : Punto de entrada principal – Menu interactivo
# Practica    : 4 – SSH y Refactorizacion Modular
# Uso         : Ejecutar como Administrador:
#               powershell -ExecutionPolicy Bypass -File Main.ps1
# ============================================================

# ── Cargar bibliotecas de funciones ─────────────────────────
$LIB = Join-Path $PSScriptRoot "lib"
. "$LIB\Utils-Functions.ps1"
. "$LIB\SSH-Functions.ps1"
. "$LIB\DHCP-Functions.ps1"
. "$LIB\DNS-Functions.ps1"

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Test-Administrator   # ← Sale si no es Administrador

# ── Submenú DHCP ────────────────────────────────────────────
function Menu-DHCP {
    while ($true) {
        Clear-Host
        Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║           SUBMÓDULO – SERVIDOR DHCP                 ║" -ForegroundColor Green
        Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Green
        Write-Host "║  1. Verificar instalacion                           ║" -ForegroundColor White
        Write-Host "║  2. Instalar rol DHCP                               ║" -ForegroundColor White
        Write-Host "║  3. Configurar ambito (scope)                       ║" -ForegroundColor White
        Write-Host "║  4. Monitoreo de leases                             ║" -ForegroundColor White
        Write-Host "║  5. Eliminar un ambito                              ║" -ForegroundColor White
        Write-Host "║  0. Volver al menu principal                        ║" -ForegroundColor White
        Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""
        $sub = (Read-Host " Opcion").Trim()
        try {
            switch ($sub) {
                "1" { Show-DHCPStatus;      Pausa-Enter }
                "2" { Install-DHCPRole;     Pausa-Enter }
                "3" { Configure-DHCPScope;  Pausa-Enter }
                "4" { Show-DHCPMonitor;     Pausa-Enter }
                "5" { Remove-DHCPScope;     Pausa-Enter }
                "0" { return }
                default { Write-Warn "Opcion invalida."; Start-Sleep 1 }
            }
        } catch { Write-Err "Error: $_"; Pausa-Enter }
    }
}

# ── Submenú DNS ──────────────────────────────────────────────
function Menu-DNS {
    while ($true) {
        Clear-Host
        Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Magenta
        Write-Host "║          SUBMÓDULO – SERVIDOR DNS                   ║" -ForegroundColor Magenta
        Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Magenta
        Write-Host "║  1. Verificar estado del servicio                   ║" -ForegroundColor White
        Write-Host "║  2. Instalar rol DNS Server                         ║" -ForegroundColor White
        Write-Host "║  3. Configurar Forwarders                           ║" -ForegroundColor White
        Write-Host "║  4. Listar zonas configuradas                       ║" -ForegroundColor White
        Write-Host "║  5. Agregar nueva zona                              ║" -ForegroundColor White
        Write-Host "║  6. Eliminar zona existente                         ║" -ForegroundColor White
        Write-Host "║  7. Probar resolucion DNS                           ║" -ForegroundColor White
        Write-Host "║  0. Volver al menu principal                        ║" -ForegroundColor White
        Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Magenta
        Write-Host ""
        $sub = (Read-Host " Opcion").Trim()
        try {
            switch ($sub) {
                "1" { Show-DNSStatus;       Pausa-Enter }
                "2" { Install-DNSRole;      Pausa-Enter }
                "3" { Set-DNSForwarder;     Pausa-Enter }
                "4" { Get-DNSZones;         Pausa-Enter }
                "5" { Add-DNSZone;          Pausa-Enter }
                "6" { Remove-DNSZone;       Pausa-Enter }
                "7" { Test-DNSResolution;   Pausa-Enter }
                "0" { return }
                default { Write-Warn "Opcion invalida."; Start-Sleep 1 }
            }
        } catch { Write-Err "Error: $_"; Pausa-Enter }
    }
}

# ── Estado general de servicios ──────────────────────────────
function Show-GeneralStatus {
    Write-Sep
    Write-Info "=== ESTADO GENERAL DE SERVICIOS (Windows) ==="
    Test-WinService "sshd"
    Test-WinService "DHCPServer"
    Test-WinService "DNS"
    Write-Sep
}

# ── Bucle del menú principal ─────────────────────────────────
try {
    while ($true) {
        Clear-Host
        Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║    PRÁCTICA 4 – ADMINISTRADOR DE SERVIDORES         ║" -ForegroundColor Yellow
        Write-Host "║              SERVIDOR WINDOWS                       ║" -ForegroundColor Yellow
        Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Cyan
        Write-Host "║  1.  SSH   – Instalar y configurar acceso remoto    ║" -ForegroundColor White
        Write-Host "║  2.  DHCP  – Gestion del servidor DHCP          >>  ║" -ForegroundColor White
        Write-Host "║  3.  DNS   – Gestion del servidor DNS           >>  ║" -ForegroundColor White
        Write-Host "║  4.  Estado – Ver todos los servicios               ║" -ForegroundColor White
        Write-Host "║  5.  TODO  – Instalar SSH + DHCP + DNS              ║" -ForegroundColor White
        Write-Host "║  0.  Salir                                          ║" -ForegroundColor White
        Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        $op = (Read-Host " Seleccione una opcion").Trim()
        try {
            switch ($op) {
                "1" { Configurar-ModuloSSH;  Pausa-Enter }
                "2" { Menu-DHCP }
                "3" { Menu-DNS }
                "4" { Show-GeneralStatus;    Pausa-Enter }
                "5" {
                    Configurar-ModuloSSH
                    Install-DHCPRole
                    Install-DNSRole
                    Pausa-Enter
                }
                "0" { Write-Info "Saliendo. Hasta luego!"; exit 0 }
                default { Write-Warn "Opcion no valida."; Start-Sleep 1 }
            }
        } catch {
            Write-Err "Error: $_"
            Pausa-Enter
        }
    }
} catch {
    Write-Err "ERROR FATAL: $_"
}