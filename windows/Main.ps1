# Cargar funciones de utilidad primero
. .\Utils-Functions.ps1

# Verificar privilegios antes de cargar el resto
Verificar-Administrador

# Cargar modulos de servicios
. .\DNS-Functions.ps1
. .\DHCP-Functions.ps1
. .\SSH-Functions.ps1

while ($true) {
    Clear-Host
    Write-Host "========================================================" -ForegroundColor Magenta
    Write-Host "             PANEL DE ADMINISTRACION REMOTA             " -ForegroundColor White
    Write-Host "========================================================" -ForegroundColor Magenta
    Write-Host "   1. Gestionar Servidor DNS" -ForegroundColor White
    Write-Host "   2. Gestionar Servidor DHCP" -ForegroundColor White
    Write-Host "   3. Gestionar Servidor SSH" -ForegroundColor White
    Write-Host "   0. Salir completamente" -ForegroundColor White
    Write-Host "========================================================" -ForegroundColor Magenta
    Write-Host ""

    $opcion = Read-Host " Seleccione el servicio a configurar"

    switch ($opcion) {
        "1" { Iniciar-MenuDNS }
        "2" { Iniciar-MenuDHCP }
        "3" { Iniciar-MenuSSH }
        "0" { 
            Write-Host "Cerrando administrador..." -ForegroundColor Gray
            exit 
        }
        default { 
            Write-Host " Opcion invalida." -ForegroundColor Red
            Start-Sleep -Seconds 1 
        }
    }
}