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
    $startN  = Convertir-AUInt32IPv4 $Ip
    $adapters = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike "169.*" -and $_.IPAddress -ne "127.0.0.1" }
    foreach ($a in $adapters) {
        $prefix  = $a.PrefixLength
        # Calculo seguro sin shift: construir mascara bit a bit via Int64
        $maskLong = [Int64]0
        for ($b = 0; $b -lt $prefix; $b++) {
            $maskLong = $maskLong -bor ([Int64]1 -shl (31 - $b))
        }
        $maskN   = [UInt32]($maskLong -band 0xFFFFFFFF)
        $maskStr = Convertir-DeUInt32IPv4 $maskN
        $netN    = [UInt32]((Convertir-AUInt32IPv4 $a.IPAddress) -band $maskN)
        $inputN  = [UInt32]($startN -band $maskN)
        if ($netN -eq $inputN) { return $maskStr }
    }
    return $null
}

function Iniciar-Monitoreo {
    $salirMonitoreo = $false
    Write-Host " Monitoreo activo. Presiona Q para volver al menu." -ForegroundColor DarkCyan
    Start-Sleep -Seconds 1
    while (-not $salirMonitoreo) {
        Clear-Host
        Write-Host "=== MONITOREO DHCP === $(Get-Date -Format 'HH:mm:ss') === (Q para volver)" -ForegroundColor Cyan

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

        Write-Host "`n Actualizando en 5s... (Q + ENTER para volver al menu)" -ForegroundColor DarkGray

        # Esperar 5s pero revisando si el usuario presiono Q
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        while ($timer.Elapsed.TotalSeconds -lt 5) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.KeyChar -eq 'q' -or $key.KeyChar -eq 'Q') {
                    $salirMonitoreo = $true
                    break
                }
            }
            Start-Sleep -Milliseconds 200
        }
    }
}

function Configurar-Ambito {
    Write-Host ">>> CONFIGURANDO AMBITO DHCP" -ForegroundColor Cyan

    # --- 1. Datos basicos del scope ---
    $name  = Read-Host " Nombre del ambito"
    $start = Read-Host " IP Inicial"
    $end   = Read-Host " IP Final"

    # --- 2. Mascara automatica ---
    $maskAuto = Obtener-MascaraDeInterfaz $start
    if ($maskAuto) {
        Write-Host " Mascara detectada automaticamente: $maskAuto" -ForegroundColor DarkGreen
        $maskInput = Read-Host " Mascara (ENTER para usar $maskAuto)"
        $mask = if ([string]::IsNullOrWhiteSpace($maskInput)) { $maskAuto } else { $maskInput }
    } else {
        $mask = Read-Host " Mascara (ej: 255.255.255.0)"
    }

    # --- 3. Gateway y DNS opcionales ---
    $gw   = Read-Host " Gateway   (ENTER para omitir)"
    $dns1 = Read-Host " DNS Primario   (ENTER para omitir)"
    $dns2 = Read-Host " DNS Secundario (ENTER para omitir)"

    # --- 4. Seleccion de adaptador ---
    Write-Host "`n Adaptadores de red disponibles:" -ForegroundColor Yellow
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    if (-not $adapters) {
        Write-Host " No hay adaptadores activos." -ForegroundColor Red
        return
    }
    $i = 1
    $listaAdapters = @()
    foreach ($a in $adapters) {
        $ipObj = Get-NetIPAddress -InterfaceAlias $a.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike "169.*" } |
            Select-Object -First 1
        $ipInfo = if ($ipObj -and ($ipObj.PSObject.Properties.Name -contains 'IPAddress')) { $ipObj.IPAddress } else { "sin IP" }
        Write-Host "  $i) $($a.Name)  [$ipInfo]" -ForegroundColor White
        $listaAdapters += $a.Name
        $i++
    }
    $selNum = (Read-Host " Selecciona el numero del adaptador para este scope").Trim()
    $selIdx = [int]$selNum - 1
    if ($selIdx -lt 0 -or $selIdx -ge $listaAdapters.Count) {
        Write-Host " Seleccion invalida." -ForegroundColor Red
        return
    }
    $ifaceSeleccionada = $listaAdapters[$selIdx]
    Write-Host " Adaptador seleccionado: $ifaceSeleccionada" -ForegroundColor Cyan

    # --- 5. Calcular ID de red y crear scope ---
    try {
        $id = Obtener-DireccionDeRed $start $mask
    } catch {
        Write-Host " Error calculando direccion de red: $_" -ForegroundColor Red
        return
    }

    try {
        # --- 5.1 Asignar IP del servidor en el adaptador seleccionado ---
        Write-Host " Configurando IP $start en $ifaceSeleccionada..." -ForegroundColor Yellow
        # Quitar IPs anteriores en esa interfaz (excepto APIPA que se van solas)
        $ipsActuales = Get-NetIPAddress -InterfaceAlias $ifaceSeleccionada -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike "169.*" -and $_.IPAddress -ne "127.0.0.1" }
        foreach ($ipVieja in $ipsActuales) {
            Remove-NetIPAddress -InterfaceAlias $ifaceSeleccionada -IPAddress $ipVieja.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
        }
        # Convertir mascara a PrefixLength
        $maskBits = Convertir-AUInt32IPv4 $mask
        $prefix = 0
        for ($b = 31; $b -ge 0; $b--) {
            if ($maskBits -band ([UInt32]1 -shl $b)) { $prefix++ }
        }
        # Asignar la nueva IP al adaptador seleccionado
        New-NetIPAddress -InterfaceAlias $ifaceSeleccionada -IPAddress $start -PrefixLength $prefix -ErrorAction Stop | Out-Null
        Write-Host " IP $start asignada a $ifaceSeleccionada correctamente." -ForegroundColor Green

        if (Get-DhcpServerv4Scope -ScopeId $id -ErrorAction SilentlyContinue) {
            Remove-DhcpServerv4Scope -ScopeId $id -Force
            Write-Host " Scope existente eliminado." -ForegroundColor Yellow
        }

        Add-DhcpServerv4Scope -Name $name -StartRange $start -EndRange $end `
            -SubnetMask $mask -State Active -ErrorAction Stop

        # --- 6. Excluir la IP del servidor (IP inicial) del scope ---
        Add-DhcpServerv4ExclusionRange -ScopeId $id -StartRange $start -EndRange $start -ErrorAction SilentlyContinue
        Write-Host " IP del servidor $start excluida automaticamente del scope." -ForegroundColor Yellow

        # --- 7. Gateway y DNS ---
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
        Write-Host "`n Ambito '$name' ($id) en adaptador '$ifaceSeleccionada' configurado exitosamente." -ForegroundColor Green

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