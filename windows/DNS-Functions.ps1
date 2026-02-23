# ============================================================
# Archivo     : DNS-Functions.ps1
# Descripcion : Instalacion y configuracion de DNS en Windows
# Practica    : 4 – SSH y Refactorizacion Modular
# Depende de  : Utils-Functions.ps1
# ============================================================

# ── Verificar si el rol DNS está instalado ───────────────────
function Test-DNSInstalled {
    $f = Get-WindowsFeature -Name DNS -ErrorAction SilentlyContinue
    return ($f -and $f.Installed)
}

# ── Instalar rol DNS ─────────────────────────────────────────
function Install-DNSRole {
    Write-Info "Verificando rol DNS Server..."
    if (Test-DNSInstalled) {
        Write-Warn "El rol DNS ya esta instalado."
        Get-Service DNS | Select-Object Status, Name, DisplayName | Format-Table -AutoSize
    } else {
        Write-Info "Instalando rol DNS Server..."
        try {
            Install-WindowsFeature -Name DNS -IncludeManagementTools -ErrorAction Stop | Out-Null
            Start-Service DNS
            Write-Ok "DNS instalado y servicio iniciado."
            Registrar-Log "Rol DNS instalado."
        } catch {
            Write-Err "Error al instalar DNS: $_"
        }
    }
}

# ── Configurar forwarders ────────────────────────────────────
function Set-DNSForwarder {
    Write-Info "Configuracion de Forwarders DNS..."
    $forward = (Read-Host "  IP del Forwarder (ej: 8.8.8.8)").Trim()
    if (-not (Test-IPv4Address $forward)) { Write-Err "IP invalida."; return }

    Write-Info "Aplicando forwarder $forward..."
    Start-Sleep -Seconds 1
    try {
        Set-DnsServerForwarder -IPAddress ([string[]]$forward) -PassThru -ErrorAction Stop | Out-Null
        Write-Ok "Forwarder configurado: $forward"
    } catch {
        try {
            Add-DnsServerForwarder -IPAddress $forward -ErrorAction Stop
            Write-Ok "Forwarder agregado: $forward"
        } catch {
            Write-Err "Error al configurar forwarder: $_"
        }
    }
    Restart-Service DNS
    Write-Ok "Servicio DNS reiniciado."
    Registrar-Log "DNS Forwarder configurado: $forward"
}

# ── Listar zonas ─────────────────────────────────────────────
function Get-DNSZones {
    Write-Sep
    Write-Info "=== ZONAS DNS CONFIGURADAS ==="
    $zonas = Get-DnsServerZone -ErrorAction SilentlyContinue
    if ($zonas) {
        $zonas | Select-Object ZoneName, ZoneType | Format-Table -AutoSize
    } else {
        Write-Warn "(No hay zonas configuradas)"
    }
}

# ── Agregar nueva zona ───────────────────────────────────────
function Add-DNSZone {
    Write-Info "Agregar Nueva Zona DNS..."
    $dom = (Read-Host "  Nombre del dominio (ej: empresa.local)").Trim()
    if ([string]::IsNullOrWhiteSpace($dom)) { Write-Err "Nombre vacio."; return }

    Write-Host ""
    Write-Host "  Interfaces disponibles:" -ForegroundColor Yellow
    $adapters = @(Get-NetAdapter | Where-Object { $_.Status -eq "Up" })
    if ($adapters.Count -eq 0) { Write-Err "No hay interfaces activas."; return }
    foreach ($a in $adapters) {
        Write-Host ("   - {0}  ({1})" -f $a.Name, $a.InterfaceDescription)
    }

    $iface = (Read-Host "  Nombre EXACTO de la interfaz").Trim()
    try {
        $ip = (Get-NetIPAddress -InterfaceAlias $iface -AddressFamily IPv4 -ErrorAction Stop |
               Where-Object { $_.IPAddress -notlike "169.*" } |
               Select-Object -First 1).IPAddress
    } catch { $ip = $null }

    if (-not $ip) { Write-Err "No se pudo obtener la IP de '$iface'."; return }
    Write-Ok "IP detectada: $ip"

    $addWww = Leer-SiNo "  Agregar registro 'www'?"

    try {
        Add-DnsServerPrimaryZone -Name $dom -ZoneFile "$dom.dns" -ErrorAction Stop
        Add-DnsServerResourceRecordA -Name "@"   -ZoneName $dom -IPv4Address $ip -ErrorAction SilentlyContinue
        Add-DnsServerResourceRecordA -Name "ns"  -ZoneName $dom -IPv4Address $ip -ErrorAction SilentlyContinue
        if ($addWww) {
            Add-DnsServerResourceRecordA -Name "www" -ZoneName $dom -IPv4Address $ip -ErrorAction SilentlyContinue
        }
        Restart-Service DNS
        Write-Ok "Dominio '$dom' agregado exitosamente (IP: $ip)."
        Registrar-Log "DNS Zona creada: $dom -> $ip"
    } catch {
        Write-Err "Error al crear zona: $_"
    }
}

# ── Eliminar zona ────────────────────────────────────────────
function Remove-DNSZone {
    Write-Info "Eliminar Zona DNS..."
    Get-DNSZones
    $dom = (Read-Host "  Nombre del dominio a eliminar").Trim()
    if ([string]::IsNullOrWhiteSpace($dom)) { return }
    if (Leer-SiNo "Confirmar eliminar '$dom'?" $false) {
        try {
            Remove-DnsServerZone -Name $dom -Force -ErrorAction Stop
            Restart-Service DNS
            Write-Ok "Zona '$dom' eliminada."
            Registrar-Log "DNS Zona eliminada: $dom"
        } catch {
            Write-Err "Error al eliminar: $_"
        }
    }
}

# ── Probar resolución DNS ────────────────────────────────────
function Test-DNSResolution {
    Write-Info "Prueba de Resolucion DNS (Resolve-DnsName)..."
    $dom = (Read-Host "  Dominio a consultar").Trim()
    if ([string]::IsNullOrWhiteSpace($dom)) { return }
    try {
        Resolve-DnsName $dom -ErrorAction Stop | Format-Table -AutoSize
    } catch {
        Write-Err "No se pudo resolver '$dom'."
    }
}

# ── Estado del sistema DNS ───────────────────────────────────
function Show-DNSStatus {
    Write-Sep
    Write-Info "=== ESTADO DEL SISTEMA DNS ==="
    if (Test-DNSInstalled) {
        Write-Ok "Rol DNS Server: INSTALADO"
        Test-WinService "DNS"
    } else {
        Write-Warn "Rol DNS Server: NO INSTALADO"
    }
}