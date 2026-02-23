# ============================================================
# Archivo     : DHCP-Functions.ps1
# Descripcion : Instalacion y configuracion de DHCP en Windows
# Practica    : 4 – SSH y Refactorizacion Modular
# Depende de  : Utils-Functions.ps1
# ============================================================

# ── Calcular utilidades de IP ────────────────────────────────
function ConvertTo-UInt32IP([string]$IP) {
    $b = ([System.Net.IPAddress]::Parse($IP)).GetAddressBytes()
    [Array]::Reverse($b)
    return [BitConverter]::ToUInt32($b, 0)
}
function ConvertFrom-UInt32IP([UInt32]$Val) {
    $b = [BitConverter]::GetBytes($Val); [Array]::Reverse($b)
    return ([System.Net.IPAddress]::new($b)).ToString()
}
function Get-NextIP([string]$IP) {
    return (ConvertFrom-UInt32IP ([UInt32]((ConvertTo-UInt32IP $IP) + 1)))
}
function Get-DefaultMask([string]$IP) {
    $a = [int]($IP.Split('.')[0]); $b = [int]($IP.Split('.')[1])
    if ($a -eq 10)                              { return "255.0.0.0" }
    if ($a -eq 172 -and $b -ge 16 -and $b -le 31) { return "255.255.0.0" }
    return "255.255.255.0"
}
function Get-NetworkAddress([string]$IP, [string]$Mask) {
    $ipN   = ConvertTo-UInt32IP $IP
    $maskN = ConvertTo-UInt32IP $Mask
    return (ConvertFrom-UInt32IP ([UInt32]($ipN -band $maskN)))
}

# ── Verificar si DHCP está instalado ─────────────────────────
function Test-DHCPInstalled {
    $f = Get-WindowsFeature -Name DHCP -ErrorAction SilentlyContinue
    return ($f -and $f.Installed)
}

# ── Instalar rol DHCP ────────────────────────────────────────
function Install-DHCPRole {
    if (Test-DHCPInstalled) {
        Write-Warn "Rol DHCP Server ya esta instalado."
        return
    }
    Write-Info "Instalando DHCP Server..."
    Install-WindowsFeature -Name DHCP -IncludeManagementTools -Restart:$false | Out-Null
    Get-NetFirewallRule -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayGroup -like "*DHCP*" } |
        Set-NetFirewallRule -Enabled True -ErrorAction SilentlyContinue | Out-Null
    Enable-WinService -ServiceName "DHCPServer"
    Write-Ok "Rol DHCP instalado y servicio iniciado."
    Registrar-Log "Rol DHCP instalado."
}

# ── Seleccionar interfaz de red ──────────────────────────────
function Select-NetworkAdapter {
    $adapters = @(Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Sort-Object Name)
    if ($adapters.Count -eq 0) { throw "No hay adaptadores de red activos." }
    Write-Host ""
    Write-Host "Interfaces de red disponibles:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $adapters.Count; $i++) {
        Write-Host ("  [{0}] {1}  (Alias: {2})" -f ($i+1), $adapters[$i].InterfaceDescription, $adapters[$i].Name)
    }
    while ($true) {
        $sel = (Read-Host "  Elige el numero de la interfaz").Trim()
        if ($sel -match '^\d+$') {
            $idx = [int]$sel - 1
            if ($idx -ge 0 -and $idx -lt $adapters.Count) { return $adapters[$idx].Name }
        }
        Write-Warn "Seleccion invalida."
    }
}

# ── Configurar IP estática en interfaz ───────────────────────
function Set-StaticIPOnAdapter([string]$Alias, [string]$IP, [string]$Mask) {
    $prefix = ($Mask -split '\.' | ForEach-Object { [Convert]::ToString([int]$_, 2) } | 
               ForEach-Object { $_ -replace '0','' } | Measure-Object -Sum -Property Length).Sum
    
    Set-NetIPInterface -InterfaceAlias $Alias -AddressFamily IPv4 -Dhcp Disabled | Out-Null
    $existing = Get-NetIPAddress -InterfaceAlias $Alias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.IPAddress -notlike "169.254.*" -and $_.IPAddress -ne $IP }
    foreach ($x in $existing) {
        Remove-NetIPAddress -InterfaceAlias $Alias -IPAddress $x.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
    }
    $has = Get-NetIPAddress -InterfaceAlias $Alias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
           Where-Object { $_.IPAddress -eq $IP }
    if (-not $has) {
        New-NetIPAddress -InterfaceAlias $Alias -IPAddress $IP -PrefixLength $prefix | Out-Null
    }
    Write-Ok "IP estatica $IP/$prefix asignada en '$Alias'."
}

# ── Configurar scope DHCP ────────────────────────────────────
function Configure-DHCPScope {
    if (-not (Test-DHCPInstalled)) { throw "DHCP Server NO esta instalado. Instala primero." }
    Import-Module DhcpServer -ErrorAction Stop

    Write-Host ""
    Write-Sep
    Write-Info "Configuracion del ambito (scope) DHCP:"
    Write-Sep

    $scopeName = (Read-Host "  Nombre del ambito").Trim()
    if ([string]::IsNullOrWhiteSpace($scopeName)) { $scopeName = "Scope-Principal" }

    $startIP  = Leer-IPv4 "  IP inicial del rango (ej: 192.168.1.1)"
    $mask     = Get-DefaultMask $startIP
    Write-Info "Mascara calculada: $mask"

    $endIP    = Leer-IPv4 "  IP final del rango (ej: 192.168.1.100)"
    $poolStart = Get-NextIP $startIP

    $gateway  = Leer-IPv4Opcional "  Gateway"
    $dns1     = Leer-IPv4Opcional "  DNS primario"
    $dns2     = $null
    if ($dns1) { $dns2 = Leer-IPv4Opcional "  DNS secundario" }

    $leaseSec = 0
    while ($leaseSec -le 0) {
        $raw = (Read-Host "  Tiempo de concesion en segundos (ej: 28800)").Trim()
        if ($raw -match '^\d+$') { $leaseSec = [int]$raw }
    }
    $leaseDuration = New-TimeSpan -Seconds $leaseSec

    $iface     = Select-NetworkAdapter
    Set-StaticIPOnAdapter -Alias $iface -IP $startIP -Mask $mask

    $scopeNet  = [System.Net.IPAddress]::Parse((Get-NetworkAddress $startIP $mask))
    $existing  = Get-DhcpServerv4Scope -ErrorAction SilentlyContinue |
                 Where-Object { $_.ScopeId -eq $scopeNet }
    if ($existing) {
        $overwrite = Leer-SiNo "Ya existe el ambito $($scopeNet). Reemplazar?" $false
        if (-not $overwrite) { return }
        Remove-DhcpServerv4Scope -ScopeId $scopeNet -Force -ErrorAction SilentlyContinue
    }

    Add-DhcpServerv4Scope -Name $scopeName -StartRange $poolStart -EndRange $endIP -SubnetMask $mask | Out-Null
    Set-DhcpServerv4Scope -ScopeId $scopeNet -State Active -LeaseDuration $leaseDuration | Out-Null

    if ($gateway) { Set-DhcpServerv4OptionValue -ScopeId $scopeNet -Router $gateway | Out-Null }
    $dnsList = @(); if ($dns1) { $dnsList += $dns1 }; if ($dns2) { $dnsList += $dns2 }
    if ($dnsList) { Set-DhcpServerv4OptionValue -ScopeId $scopeNet -DnsServer $dnsList -Force | Out-Null }

    Restart-Service -Name DHCPServer -Force
    Write-Ok "Ambito '$scopeName' configurado y activo."
    Write-Host ""
    Write-Host "   Red      : $scopeNet" -ForegroundColor Green
    Write-Host "   Rango    : $poolStart – $endIP" -ForegroundColor Green
    if ($gateway)     { Write-Host "   Gateway  : $gateway"        -ForegroundColor Green }
    if ($dnsList)     { Write-Host "   DNS      : $($dnsList -join ', ')" -ForegroundColor Green }
    Registrar-Log "DHCP Scope: $scopeName Red: $scopeNet Rango: $poolStart-$endIP"
}

# ── Eliminar un scope ────────────────────────────────────────
function Remove-DHCPScope {
    if (-not (Test-DHCPInstalled)) { Write-Warn "DHCP no instalado."; return }
    Import-Module DhcpServer -ErrorAction Stop
    $scopes = @(Get-DhcpServerv4Scope -ErrorAction SilentlyContinue)
    if ($scopes.Count -eq 0) { Write-Warn "No hay ambitos para eliminar."; return }

    Write-Host ""
    for ($i=0; $i -lt $scopes.Count; $i++) {
        $s = $scopes[$i]
        Write-Host ("  [{0}]  {1}  |  {2}  |  {3}" -f ($i+1), $s.ScopeId, $s.Name, $s.State)
    }
    Write-Host "  [0]  Cancelar"
    while ($true) {
        $sel = (Read-Host "  Numero").Trim()
        if ($sel -eq "0") { return }
        if ($sel -match '^\d+$') {
            $idx = [int]$sel - 1
            if ($idx -ge 0 -and $idx -lt $scopes.Count) {
                $t = $scopes[$idx]
                if (Leer-SiNo "Confirmar eliminar ambito $($t.ScopeId)?" $false) {
                    Remove-DhcpServerv4Scope -ScopeId $t.ScopeId -Force
                    Restart-Service DHCPServer -Force
                    Write-Ok "Ambito $($t.ScopeId) eliminado."
                    Registrar-Log "DHCP Scope eliminado: $($t.ScopeId)"
                }
                return
            }
        }
        Write-Warn "Seleccion invalida."
    }
}

# ── Monitoreo / leases activos ───────────────────────────────
function Show-DHCPMonitor {
    if (-not (Test-DHCPInstalled)) { Write-Warn "DHCP no instalado."; return }
    Import-Module DhcpServer -ErrorAction Stop
    Write-Sep
    Write-Info "=== MONITOREO DHCP – AMBITOS Y LEASES ==="
    $scopes = Get-DhcpServerv4Scope -ErrorAction SilentlyContinue
    if (-not $scopes) { Write-Warn "No hay ambitos configurados."; return }

    $scopes | Select-Object Name, ScopeId, StartRange, EndRange, State | Format-Table -AutoSize
    foreach ($s in $scopes) {
        Write-Host "--- Leases activos: $($s.Name) ($($s.ScopeId)) ---" -ForegroundColor Yellow
        $leases = Get-DhcpServerv4Lease -ScopeId $s.ScopeId -ErrorAction SilentlyContinue
        if ($leases) {
            $leases | Select-Object IPAddress, ClientId, HostName, AddressState | Format-Table -AutoSize
        } else {
            Write-Warn "Sin leases activos en este ambito."
        }
    }
}

# ── Estado del sistema DHCP ──────────────────────────────────
function Show-DHCPStatus {
    Write-Sep
    Write-Info "=== ESTADO DEL SISTEMA DHCP ==="
    $installed = Test-DHCPInstalled
    if ($installed) {
        Write-Ok "Rol DHCP Server: INSTALADO"
        Test-WinService "DHCPServer"
    } else {
        Write-Warn "Rol DHCP Server: NO INSTALADO"
    }
}