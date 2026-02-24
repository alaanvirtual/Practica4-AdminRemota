function Obtener-IP {
    param([string]$iface)
    $addr = Get-NetIPAddress -InterfaceAlias $iface -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike "169.*" }
    if (-not $addr) {
        Write-Host " No se pudo obtener IP para la interfaz '$iface'." -ForegroundColor Red
        return $null
    }
    return $addr.IPAddress
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
        Install-WindowsFeature -Name DNS -IncludeManagementTools -ErrorAction Stop | Out-Null
        Start-Service DNS
        Write-Host " DNS instalado y servicio iniciado correctamente." -ForegroundColor Green
    } catch {
        Write-Host " Error al instalar: $_" -ForegroundColor Red
    }
}

function Configurar-DNS {
    Write-Host ">>> Configuracion de Forwarders" -ForegroundColor Cyan
    $forward = Read-Host " Ingrese IP del Forwarder (ej: 8.8.8.8)"
    if ([string]::IsNullOrWhiteSpace($forward)) {
        Write-Host " No se ingreso ninguna IP." -ForegroundColor Red
        return
    }
    Write-Host " Aplicando configuracion..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    try {
        Set-DnsServerForwarder -IPAddress ([string[]]$forward) -PassThru -ErrorAction Stop | Out-Null
        Write-Host " Forwarder configurado (Set-DnsServerForwarder)" -ForegroundColor Green
    } catch {
        try {
            Add-DnsServerForwarder -IPAddress $forward -ErrorAction Stop
            Write-Host " Forwarder configurado (Add-DnsServerForwarder)" -ForegroundColor Green
        } catch {
            Write-Host " Error al configurar Forwarder: $_" -ForegroundColor Red
        }
    }
    Restart-Service DNS
}

function Listar-Dominios {
    Write-Host "=== LISTA DE ZONAS CONFIGURADAS ===" -ForegroundColor Cyan
    $zonas = Get-DnsServerZone -ErrorAction SilentlyContinue
    if ($zonas) {
        $zonas | Select-Object ZoneName, ZoneType | Format-Table -AutoSize
    } else {
        Write-Host " (No hay zonas configuradas)" -ForegroundColor Gray
    }
}

function Agregar-Dominio {
    Write-Host ">>> Agregar Nueva Zona" -ForegroundColor Cyan
    $dom = Read-Host " Nombre del dominio"
    if ([string]::IsNullOrWhiteSpace($dom)) { return }

    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    if (-not $adapters) {
        Write-Host " No hay adaptadores de red activos." -ForegroundColor Red
        return
    }
    Write-Host " Interfaces disponibles:" -ForegroundColor Yellow
    foreach ($a in $adapters) { Write-Host "   - $($a.Name)" }

    $iface = Read-Host " Interfaz"
    $ip = Obtener-IP $iface
    if (-not $ip) { return }

    $www = Read-Host " Agregar 'www'? (s/n)"
    try {
        Add-DnsServerPrimaryZone -Name $dom -ZoneFile "$dom.dns" -ErrorAction Stop
        Add-DnsServerResourceRecordA -Name "@"   -ZoneName $dom -IPv4Address $ip -ErrorAction SilentlyContinue
        Add-DnsServerResourceRecordA -Name "ns"  -ZoneName $dom -IPv4Address $ip -ErrorAction SilentlyContinue
        if ($www.Trim().ToLower() -eq "s") {
            Add-DnsServerResourceRecordA -Name "www" -ZoneName $dom -IPv4Address $ip -ErrorAction SilentlyContinue
        }
        Restart-Service DNS
        Write-Host " Dominio '$dom' agregado exitosamente." -ForegroundColor Green
    } catch {
        Write-Host " Error: $_" -ForegroundColor Red
    }
}

function Borrar-Dominio {
    Listar-Dominios
    $dom = Read-Host " Dominio a eliminar"
    if ([string]::IsNullOrWhiteSpace($dom)) { return }
    try {
        Remove-DnsServerZone -Name $dom -Force -ErrorAction Stop
        Restart-Service DNS
        Write-Host " Dominio '$dom' eliminado correctamente." -ForegroundColor Green
    } catch {
        Write-Host " Error: $_" -ForegroundColor Red
    }
}

function Consultar-DNS {
    $dom = Read-Host " Dominio a consultar"
    if ([string]::IsNullOrWhiteSpace($dom)) { return }
    try {
        Resolve-DnsName $dom -ErrorAction Stop | Format-Table -AutoSize
    } catch {
        Write-Host " Error de resolucion: $_" -ForegroundColor Red
    }
}

function Dibujar-Menu-Dominios {
    Clear-Host
    Write-Host "--- GESTION DE ZONAS Y DOMINIOS ---" -ForegroundColor Green
    Write-Host "1. Listar dominios"
    Write-Host "2. Agregar dominio"
    Write-Host "3. Eliminar dominio"
    Write-Host "4. Probar resolucion"
    Write-Host "0. Volver"
}

function Iniciar-MenuDNS {
    # BUG FIX: En PowerShell, 'break' dentro de switch rompe el while padre.
    # Se usa una variable $salir para controlar el flujo correctamente.
    $salir = $false
    while (-not $salir) {
        Clear-Host
        Write-Host "--- ADMINISTRADOR DNS ---" -ForegroundColor Cyan
        Write-Host "1. Verificar estado"
        Write-Host "2. Instalar rol"
        Write-Host "3. Configurar Forwarders"
        Write-Host "4. Gestion de Dominios >>"
        Write-Host "0. Volver"
        $op = (Read-Host " Seleccion").Trim()
        switch ($op) {
            "1" { Verificar-DNS; Pausa }
            "2" { Instalar-DNS;  Pausa }
            "3" { Configurar-DNS; Pausa }
            "4" {
                $salirSub = $false
                while (-not $salirSub) {
                    Dibujar-Menu-Dominios
                    $sub = (Read-Host " Seleccion sub-menu").Trim()
                    switch ($sub) {
                        "1" { Listar-Dominios;  Pausa }
                        "2" { Agregar-Dominio;  Pausa }
                        "3" { Borrar-Dominio;   Pausa }
                        "4" { Consultar-DNS;    Pausa }
                        "0" { $salirSub = $true }
                        default { Write-Host " Opcion no valida." -ForegroundColor Yellow; Pausa }
                    }
                }
            }
            "0" { $salir = $true }
            default { Write-Host " Opcion no valida." -ForegroundColor Yellow; Pausa }
        }
    }
}