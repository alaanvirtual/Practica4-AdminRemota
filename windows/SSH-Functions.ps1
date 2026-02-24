function Verificar-SSH {
    $ssh = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Server*' }
    if ($ssh) {
        Write-Host " Estado OpenSSH Server: $($ssh.State)" -ForegroundColor Cyan
        if ($ssh.State -eq 'Installed') {
            Get-Service sshd -ErrorAction SilentlyContinue | Select-Object Status, Name, DisplayName | Format-Table -AutoSize
        }
    } else {
        Write-Host " OpenSSH Server no encontrado en las capacidades del sistema." -ForegroundColor Red
    }
}

function Instalar-SSH {
    try {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction Stop | Out-Null
        Start-Service sshd -ErrorAction Stop
        Set-Service -Name sshd -StartupType Automatic
        # Habilitar regla de firewall solo si existe; si no, crearla
        $rule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
        if ($rule) {
            Enable-NetFirewallRule -Name 'OpenSSH-Server-In-TCP'
        } else {
            New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' `
                -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
        }
        Write-Host " SSH instalado, servicio iniciado y firewall configurado." -ForegroundColor Green
    } catch {
        Write-Host " Error: $_" -ForegroundColor Red
    }
}

function Iniciar-MenuSSH {
    # BUG FIX: En PowerShell, 'break' dentro de switch rompe el while padre.
    # Se usa una variable $salir para controlar el flujo correctamente.
    $salir = $false
    while (-not $salir) {
        Clear-Host
        Write-Host "--- GESTION SSH ---" -ForegroundColor DarkCyan
        Write-Host "1. Verificar"
        Write-Host "2. Instalar"
        Write-Host "0. Volver"
        $op = (Read-Host " Seleccion").Trim()
        switch ($op) {
            "1" { Verificar-SSH; Pausa }
            "2" { Instalar-SSH;  Pausa }
            "0" { $salir = $true }
            default { Write-Host " Opcion no valida." -ForegroundColor Yellow; Pausa }
        }
    }
}