# ============================================================
# Archivo     : SSH-Functions.ps1
# Descripcion : Instalacion y configuracion de OpenSSH en Windows
# Practica    : 4 – SSH y Refactorizacion Modular
# Depende de  : Utils-Functions.ps1
# ============================================================

# ── Instalar OpenSSH Server via Windows Capability ──────────
function Install-OpenSSHServer {
    Write-Info "Verificando OpenSSH Server..."
    $cap = Get-WindowsCapability -Online | Where-Object { $_.Name -like "OpenSSH.Server*" }
    if ($cap.State -eq "Installed") {
        Write-Warn "OpenSSH Server ya esta instalado."
    } else {
        Write-Info "Instalando OpenSSH Server (puede tardar)..."
        Add-WindowsCapability -Online -Name $cap.Name | Out-Null
        Write-Ok "OpenSSH Server instalado."
        Registrar-Log "OpenSSH Server instalado."
    }
}

# ── Habilitar el servicio sshd ───────────────────────────────
function Enable-SSHService {
    Write-Info "Habilitando servicio sshd con inicio automatico..."
    Enable-WinService -ServiceName "sshd" -StartType "Automatic"
}

# ── Regla de Firewall para puerto 22 ────────────────────────
function Set-SSHFirewallRule {
    Write-Info "Configurando regla de Firewall para SSH (Puerto 22/TCP)..."
    $regla = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
    if ($regla) {
        Set-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -Enabled True
        Write-Warn "Regla existente habilitada."
    } else {
        New-NetFirewallRule `
            -Name        "OpenSSH-Server-In-TCP" `
            -DisplayName "OpenSSH Server (sshd) Puerto 22" `
            -Description "Permite conexiones SSH entrantes en el puerto 22" `
            -Enabled     True `
            -Direction   Inbound `
            -Protocol    TCP `
            -Action      Allow `
            -LocalPort   22 | Out-Null
        Write-Ok "Regla de Firewall creada: Puerto 22/TCP habilitado."
    }
    Registrar-Log "Firewall SSH – Puerto 22 abierto."
}

# ── Establecer PowerShell como shell por defecto para SSH ───
function Set-SSHDefaultShell {
    Write-Info "Configurando PowerShell como shell por defecto para SSH..."
    $pwsh = (Get-Command powershell.exe).Source
    $key  = "HKLM:\SOFTWARE\OpenSSH"
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty -Path $key -Name "DefaultShell" -Value $pwsh
    Write-Ok "Shell SSH por defecto: $pwsh"
}

# ── Mostrar datos de conexión ────────────────────────────────
function Show-SSHConnectionInfo {
    Write-Sep
    $ip      = Get-LocalIP
    $usuario = $env:USERNAME
    Write-Ok "SSH listo. Datos de conexion:"
    Write-Host ""
    Write-Host "   IP Servidor  :  $ip"     -ForegroundColor Green
    Write-Host "   Puerto       :  22"       -ForegroundColor Green
    Write-Host "   Usuario      :  $usuario" -ForegroundColor Green
    Write-Host "   Comando SSH  :  ssh ${usuario}@${ip}" -ForegroundColor Green
    Write-Sep
    Registrar-Log "SSH configurado. IP=$ip Usuario=$usuario"
}

# ── Proceso completo SSH ─────────────────────────────────────
function Configurar-ModuloSSH {
    Write-Sep
    Write-Info "=== MODULO SSH – INSTALACION Y CONFIGURACION (Windows) ==="
    Write-Sep
    Install-OpenSSHServer
    Enable-SSHService
    Set-SSHFirewallRule
    Set-SSHDefaultShell
    Show-SSHConnectionInfo
}