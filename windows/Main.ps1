Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\Utils-Functions.ps1"
. "$PSScriptRoot\DHCP-Functions.ps1"
. "$PSScriptRoot\DNS-Functions.ps1"
. "$PSScriptRoot\SSH-Functions.ps1"

Verificar-Administrador

while ($true) {
    Clear-Host
    Write-Host "=== PANEL DE ADMINISTRACION ===" -ForegroundColor White
    Write-Host "1. Gestionar DNS"
    Write-Host "2. Gestionar DHCP"
    Write-Host "3. Gestionar SSH"
    Write-Host "0. Salir"
    $op = (Read-Host "Seleccion").Trim()
    switch ($op) {
        "1" { Iniciar-MenuDNS  }
        "2" { Iniciar-MenuDHCP }
        "3" { Iniciar-MenuSSH  }
        "0" { exit }
        default { Write-Host " Opcion no valida." -ForegroundColor Yellow; Pausa }
    }
}
