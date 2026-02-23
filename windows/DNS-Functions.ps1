function Obtener-IP($iface) {
    (Get-NetIPAddress -InterfaceAlias $iface -AddressFamily IPv4 |
      Where-Object {$_.IPAddress -notlike "169.*"}).IPAddress
}

function Verificar-DNS {
    Write-Host ">>> Verificando instalacion..." -ForegroundColor Cyan
    $dns = Get-WindowsFeature -Name DNS
    if ($dns.Installed) {
        Write-Host " El rol DNS esta INSTALADO." -ForegroundColor Green
        Get-Service DNS | Select-Object Status, Name, DisplayName | Format-Table -AutoSize
    } else {
        Write-Host " El rol DNS NO esta instalado." -ForegroundColor Red
    }
}

function Instalar-DNS {
    Write-Host ">>> Instalando DNS..." -ForegroundColor Cyan
    try {
        Install-WindowsFeature -Name DNS -IncludeManagementTools -ErrorAction Stop
        Start-Service DNS
        Write-Host " DNS instalado y servicio iniciado correctamente." -ForegroundColor Green
    } catch {
        Write-Host " Error al instalar: $_" -ForegroundColor Red
    }
}

function Configurar-DNS {
    Write-Host ">>> Configuracion de Forwarders" -ForegroundColor Cyan
    $forward = Read-Host " Ingrese IP del Forwarder (ej: 8.8.8.8)"
    
    Write-Host " Aplicando configuracion..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    
    try {
        Set-DnsServerForwarder -IPAddress ([string[]]$forward) -PassThru -ErrorAction Stop | Out-Null
        Write-Host " Forwarder configurado (Set-DnsServerForwarder)" -ForegroundColor Green
    } catch {
        Write-Host " Intentando metodo alternativo..." -ForegroundColor Yellow
        try {
            Add-DnsServerForwarder -IPAddress $forward -ErrorAction Stop
            Write-Host " Forwarder configurado (Add-DnsServerForwarder)" -ForegroundColor Green
        } catch {
            Write-Host " Error al configurar Forwarder: $_" -ForegroundColor Red
        }
    }
    
    Restart-Service DNS
    Write-Host " Servicio DNS reiniciado." -ForegroundColor Green
}

function Listar-Dominios {
    Write-Host "=== LISTA DE ZONAS CONFIGURADAS ===" -ForegroundColor Cyan
    $zonas = Get-DnsServerZone
    if ($zonas) {
        $zonas | Select-Object ZoneName, ZoneType | Format-Table -AutoSize
    } else {
        Write-Host " (No hay zonas configuradas)" -ForegroundColor Gray
    }
}

function Agregar-Dominio {
    Write-Host ">>> Agregar Nueva Zona" -ForegroundColor Cyan
    $dom = Read-Host " Nombre del dominio (ej: empresa.local)"

    Write-Host ""
    Write-Host " Interfaces de red disponibles:" -ForegroundColor Yellow
    $adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
    
    if (-not $adapters) {
        Write-Host " No hay interfaces activas." -ForegroundColor Red
        return
    }

    foreach ($a in $adapters) {
        Write-Host "  - $($a.Name) ($($a.InterfaceDescription))"
    }
    Write-Host ""

    $iface = Read-Host " Escribe el nombre EXACTO de la interfaz"
    
    try {
        $ip = Obtener-IP $iface
    } catch {
        $ip = $null
    }

    if (!$ip) {
        Write-Host " No se pudo obtener IP o interfaz invalida." -ForegroundColor Red
        return
    }

    Write-Host " IP detectada: $ip" -ForegroundColor Green

    $www = Read-Host " Agregar registro 'www'? (s/n)"

    try {
        Add-DnsServerPrimaryZone -Name $dom -ZoneFile "$dom.dns" -ErrorAction Stop
        
        Add-DnsServerResourceRecordA -Name "@" -ZoneName $dom -IPv4Address $ip -ErrorAction SilentlyContinue

        Add-DnsServerResourceRecordA -Name "ns" -ZoneName $dom -IPv4Address $ip -ErrorAction SilentlyContinue

        if ($www -eq "s") {
            Add-DnsServerResourceRecordA -Name "www" -ZoneName $dom -IPv4Address $ip -ErrorAction SilentlyContinue
        }

        Restart-Service DNS
        Write-Host " Dominio '$dom' agregado exitosamente." -ForegroundColor Green
    } catch {
        Write-Host " Error al crear zona: $_" -ForegroundColor Red
    }
}

function Borrar-Dominio {
    Write-Host ">>> Eliminar Zona" -ForegroundColor Cyan
    Listar-Dominios
    Write-Host ""
    $dom = Read-Host " Escribe el nombre del dominio a eliminar"
    
    if ([string]::IsNullOrWhiteSpace($dom)) { return }

    try {
        Remove-DnsServerZone -Name $dom -Force -ErrorAction Stop
        Restart-Service DNS
        Write-Host " Dominio eliminado correctamente." -ForegroundColor Green
    } catch {
        Write-Host " Error al eliminar: $_" -ForegroundColor Red
    }
}

function Consultar-DNS {
    Write-Host ">>> Prueba de Resolucion (NSLookup)" -ForegroundColor Cyan
    $dom = Read-Host " Dominio a consultar"
    if ([string]::IsNullOrWhiteSpace($dom)) { return }
    
    try {
        Resolve-DnsName $dom -ErrorAction Stop | Format-Table -AutoSize
    } catch {
        Write-Host " No se pudo resolver el nombre." -ForegroundColor Red
    }
}

function Dibujar-Menu-Principal-DNS {
    Clear-Host
    Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "              ADMINISTRADOR DE SERVIDOR DNS             " -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "   1. Verificar estado del servicio" -ForegroundColor White
    Write-Host "   2. Instalar rol DNS Server" -ForegroundColor White
    Write-Host "   3. Configurar Forwarders" -ForegroundColor White
    Write-Host "   4. Gestion de Dominios (Zonas) >>" -ForegroundColor White
    Write-Host "   5. Salir al menu principal" -ForegroundColor White
    Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""
}

function Dibujar-Menu-Dominios {
    Clear-Host
    Write-Host "--------------------------------------------------------" -ForegroundColor Green
    Write-Host "              GESTION DE ZONAS Y DOMINIOS               " -ForegroundColor White
    Write-Host "--------------------------------------------------------" -ForegroundColor Green
    Write-Host "   1. Listar dominios actuales" -ForegroundColor White
    Write-Host "   2. Agregar nuevo dominio" -ForegroundColor White
    Write-Host "   3. Eliminar dominio existente" -ForegroundColor White
    Write-Host "   4. Probar resolucion DNS" -ForegroundColor White
    Write-Host "   0. Volver al menu anterior" -ForegroundColor White
    Write-Host "--------------------------------------------------------" -ForegroundColor Green
    Write-Host ""
}

function Iniciar-MenuDNS {
    while ($true) {
        Dibujar-Menu-Principal-DNS
        $op = Read-Host " Seleccione una opcion"

        switch ($op) {
            "1" { Verificar-DNS; Pausa }
            "2" { Instalar-DNS; Pausa }
            "3" { Configurar-DNS; Pausa }
            "4" {
                while ($true) {
                    Dibujar-Menu-Dominios
                    $sub = Read-Host " Seleccione una opcion del sub-menu"
                    
                    switch ($sub) {
                        "1" { Listar-Dominios; Pausa }
                        "2" { Agregar-Dominio; Pausa }
                        "3" { Borrar-Dominio; Pausa }
                        "4" { Consultar-DNS; Pausa }
                        "0" { break }
                        default { Write-Host " Opcion invalida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
                    }
                    if ($sub -eq "0") { break }
                }
            }
            "5" { 
                Write-Host "Volviendo..." -ForegroundColor Gray
                return 
            }
            default { 
                Write-Host " Opcion no valida, intente de nuevo." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}