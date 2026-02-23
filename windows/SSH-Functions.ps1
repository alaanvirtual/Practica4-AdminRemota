function Verificar-SSH {
    Write-Host ">>> Verificando OpenSSH Server..." -ForegroundColor Cyan
    $ssh = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
    if ($ssh.State -eq 'Installed') {
        Write-Host " OpenSSH Server esta INSTALADO." -ForegroundColor Green
        Get-Service sshd | Select-Object Status, Name, DisplayName | Format-Table -AutoSize
    } else {
        Write-Host " OpenSSH Server NO esta instalado." -ForegroundColor Red
    }
}

function Instalar-SSH {
    Write-Host ">>> Instalando OpenSSH Server..." -ForegroundColor Cyan
    try {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction Stop
        Start-Service sshd
        Set-Service -Name sshd -StartupType 'Automatic'
        
        Get-NetFirewallRule -Name *ssh* -ErrorAction SilentlyContinue | Enable-NetFirewallRule
        
        Write-Host " SSH instalado y configurado para iniciar automaticamente." -ForegroundColor Green
    } catch {
        Write-Host " Error al instalar SSH: $_" -ForegroundColor Red
    }
}

function Iniciar-MenuSSH {
    while ($true) {
        Clear-Host
        Write-Host "--------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host "              ADMINISTRADOR DE SERVIDOR SSH             " -ForegroundColor Yellow
        Write-Host "--------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host "   1. Verificar estado de SSH" -ForegroundColor White
        Write-Host "   2. Instalar OpenSSH Server" -ForegroundColor White
        Write-Host "   0. Volver al menu principal" -ForegroundColor White
        Write-Host "--------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host ""

        $op = Read-Host " Seleccione una opcion"
        switch ($op) {
            "1" { Verificar-SSH; Pausa }
            "2" { Instalar-SSH; Pausa }
            "0" { return }
            default { Write-Host "Opcion no valida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}