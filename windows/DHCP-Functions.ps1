function Convertir-AUInt32IPv4 {
    param([string]$Ip)
    $b = ([System.Net.IPAddress]::Parse($Ip)).GetAddressBytes()
    [Array]::Reverse($b)
    return [BitConverter]::ToUInt32($b, 0)
}

function Convertir-DeUInt32IPv4 {
    param([UInt32]$Value)
    $b = [BitConverter]::GetBytes($Value)
    [Array]::Reverse($b)
    return ([System.Net.IPAddress]::new($b)).ToString()
}

function Obtener-DireccionDeRed {
    param([string]$Ip, [string]$Mask)
    $ipN   = Convertir-AUInt32IPv4 $Ip
    $maskN = Convertir-AUInt32IPv4 $Mask
    return (Convertir-DeUInt32IPv4 ([UInt32]($ipN -band $maskN)))
}

function Obtener-MascaraDeInterfaz {
    param([string]$Ip)
    $startN = Convertir-AUInt32IPv4 $Ip
    $adapters = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike "169.*" -and $_.IPAddress -ne "127.0.0.1" }
    foreach ($a in $adapters) {
        $prefix = $a.PrefixLength
        $maskN  = [UInt32](([UInt64]0xFFFFFFFF -shl (32 - $prefix)) -band 0xFFFFFFFF)
        $maskStr = Convertir-DeUInt32IPv4 $maskN
        $netN   = [UInt32]((Convertir-AUInt32IPv4 $a.IPAddress) -band $maskN)
        $inputN = [UInt32]($startN -band $maskN)
        if ($netN -eq $inputN) {
            return $maskStr
        }
    }
    return $null
}

function Iniciar-Monitoreo {
    Write-Host " Monitoreo activo. Presiona CTRL+C para salir." -ForegroundColor DarkCyan
    Start-Sleep -Seconds 1
    while ($true) {
        Clear-Host
        Write-Host "=== MONITOREO DHCP === $(Get-Date -Format 'HH:mm:ss') === (CTRL+C para salir)" -ForegroundColor Cyan

        Write-Host "`n--- AMBITOS CONFIGURADOS ---" -ForegroundColor Yellow
        $scopes = Get-DhcpServerv4Scope -ErrorAction SilentlyContinue
        if ($scopes) {
            $scopes | Select-Object Name, ScopeId, SubnetMask, StartRange, EndRange, State |
                Format-Table -AutoSize
        } else {
            Write-Host " (Sin ambitos configurados)" -ForegroundColor Gray
        }

        Write-Host "--- CLIENTES CONECTADOS ---" -ForegroundColor Yellow
        $leases = @()
        if ($scopes) {
            foreach ($s in $scopes) {
                $leases += Get-DhcpServerv4Lease -ScopeId $s.ScopeId -ErrorAction SilentlyContinue
            }
        }
        if ($leases.Count -gt 0) {
            $leases | Select-Object IPAddress, ClientId, HostName, AddressState, LeaseExpiryTime |
                Format-Table -AutoSize
        } else {
            Write-Host " (Sin clientes conectados aun)" -ForegroundColor Gray
        }

        Start-Sleep -Seconds 5
    }
}

function Configurar-Ambito {
    Write-Host ">>> CONFIGURANDO AMBITO DHCP" -ForegroundColor Cyan
    $name  = Read-Host " Nombre del ambito"
    $start = Read-Host " IP Inicial"
    $end   = Read-Host " IP Final"

    $maskAuto = Obtener-MascaraDeInterfaz $start
    if ($maskAuto) {
        Write-Host " Mascara detectada automaticamente: $maskAuto" -ForegroundColor DarkGreen
        $maskInput = Read-Host " Mascara (ENTER para usar $maskAuto)"
        $mask = if ([string]::IsNullOrWhiteSpace($maskInput)) { $maskAuto } else { $maskInput }
    } else {
        $mask = Read-Host " Mascara (ej: 255.255.255.0)"
    }

    $gw    = Read-Host " Gateway (deja vacio para omitir)"
    $dns1  = Read-Host " DNS Primario (deja vacio para omitir)"
    $dns2  = Read-Host " DNS Secundario (deja vacio para omitir)"

    try {
        $id = Obtener-DireccionDeRed $start $mask
    } catch {
        Write-Host " Error calculando direccion de red: $_" -ForegroundColor Red
        return
    }

    try {
        if (Get-DhcpServerv4Scope -ScopeId $id -ErrorAction SilentlyContinue) {
            Remove-DhcpServerv4Scope -ScopeId $id -Force
            Write-Host " Scope existente eliminado." -ForegroundColor Yellow
        }

        Add-DhcpServerv4Scope -Name $name -StartRange $start -EndRange $end `
            -SubnetMask $mask -State Active -ErrorAction Stop

        $startN    = Convertir-AUInt32IPv4 $start
        $endN      = Convertir-AUInt32IPv4 $end
        $serverIPs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike "169.*" -and $_.IPAddress -ne "127.0.0.1" }

        foreach ($addr in $serverIPs) {
            try {
                $addrN = Convertir-AUInt32IPv4 $addr.IPAddress
                if ($addrN -ge $startN -and $addrN -le $endN) {
                    Add-DhcpServerv4ExclusionRange -ScopeId $id -StartRange $addr.IPAddress -EndRange $addr.IPAddress -ErrorAction Stop
                    Write-Host " IP del servidor $($addr.IPAddress) excluida automaticamente." -ForegroundColor Yellow
                }
            } catch {
                Write-Host " No se pudo excluir $($addr.IPAddress): $_" -ForegroundColor DarkYellow
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($gw)) {
            Set-DhcpServerv4OptionValue -ScopeId $id -Router $gw -ErrorAction Stop
        }

        $dnsList = @()
        if (-not [string]::IsNullOrWhiteSpace($dns1)) { $dnsList += $dns1 }
        if (-not [string]::IsNullOrWhiteSpace($dns2)) { $dnsList += $dns2 }
        if ($dnsList.Count -gt 0) {
            Set-DhcpServerv4OptionValue -ScopeId $id -DnsServer $dnsList -Force -ErrorAction Stop
        }

        Restart-Service DHCPServer
        Write-Host " Ambito '$name' ($id) configurado exitosamente." -ForegroundColor Green
    } catch {
        Write-Host " Error: $_" -ForegroundColor Red
    }
}

function Iniciar-MenuDHCP {
    $salir = $false
    while (-not $salir) {
        Clear-Host
        Write-Host "--- MENU GESTION DHCP ---" -ForegroundColor Blue
        Write-Host "1) Verificar instalacion"
        Write-Host "2) Instalar DHCP"
        Write-Host "3) Configurar ambito"
        Write-Host "4) Monitoreo (auto-refresh 5s)"
        Write-Host "5) Reiniciar DHCP"
        Write-Host "6) Remover ambito"
        Write-Host "0) Volver"

        $opt = (Read-Host " Seleccione").Trim()
        switch ($opt) {
            "1" {
                $feature = Get-WindowsFeature -Name DHCP
                Write-Host " DHCP Instalado: $($feature.Installed)" -ForegroundColor Cyan
                Pausa
            }
            "2" { Instalar-Paquete "DHCP"; Pausa }
            "3" { Configurar-Ambito; Pausa }
            "4" { Iniciar-Monitoreo }
            "5" {
                Restart-Service DHCPServer -Force
                Write-Host " Servicio DHCP reiniciado." -ForegroundColor Green
                Pausa
            }
            "6" {
                $id_del = (Read-Host " ID de red a borrar (ej: 192.168.1.0)").Trim()
                if (-not [string]::IsNullOrWhiteSpace($id_del)) {
                    try {
                        Remove-DhcpServerv4Scope -ScopeId $id_del -Force -ErrorAction Stop
                        Write-Host " Ambito '$id_del' eliminado." -ForegroundColor Green
                    } catch {
                        Write-Host " Error: $_" -ForegroundColor Red
                    }
                }
                Pausa
            }
            "0" { $salir = $true }
            default { Write-Host " Opcion no valida." -ForegroundColor Yellow; Pausa }
        }
    }
}