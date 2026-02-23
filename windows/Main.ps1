# ============================================================
# Archivo     : Main.ps1 - CORREGIDO
# ============================================================
$LIB_PATH = Join-Path $PSScriptRoot "lib"

# Validación de Arquitectura: ¿Existe la carpeta lib?
if (-not (Test-Path $LIB_PATH)) {
    Write-Host "ERROR: No se encuentra la carpeta 'lib' en $PSScriptRoot" -ForegroundColor Red
    Write-Host "Asegúrate de haber subido la carpeta completa con SCP." -ForegroundColor Yellow
    exit
}

# Carga de bibliotecas
. (Join-Path $LIB_PATH "Utils-Functions.ps1")
. (Join-Path $LIB_PATH "SSH-Functions.ps1")
. (Join-Path $LIB_PATH "DHCP-Functions.ps1")
. (Join-Path $LIB_PATH "DNS-Functions.ps1")

$ErrorActionPreference = "Stop"
Test-Administrator # Esta función vive en Utils-Functions

function Menu-DHCP {
    $s_loop = $true
    while ($s_loop) {
        Clear-Host
        Write-Host "--- SERVIDOR DHCP ---" -ForegroundColor Green
        Write-Host "1. Estado | 2. Instalar | 0. Volver"
        $sub = (Read-Host "Opcion").Trim()
        switch ($sub) {
            "1" { Show-DHCPStatus; Pausa-Enter }
            "2" { Install-DHCPRole; Pausa-Enter }
            "0" { $s_loop = $false }
        }
    }
}

# Menú Principal
$main_loop = $true
while ($main_loop) {
    Clear-Host
    Write-Host "=== ADMIN SERVIDORES WINDOWS ===" -ForegroundColor Cyan
    Write-Host "1. SSH | 2. DHCP | 3. DNS | 4. Estado | 0. Salir"
    $op = (Read-Host "Seleccione").Trim()
    switch ($op) {
        "1" { Configurar-ModuloSSH; Pausa-Enter }
        "2" { Menu-DHCP }
        "4" { Test-WinService "sshd"; Test-WinService "DHCPServer"; Pausa-Enter }
        "0" { $main_loop = $false; exit 0 }
    }
}