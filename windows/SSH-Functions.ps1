# ============================================================
# Biblioteca: SSH-Functions.ps1
# ============================================================

function Configurar-ModuloSSH {
    Write-Host ""
    Write-Host "=== CONFIGURANDO ACCESO REMOTO SSH ===" -ForegroundColor Cyan
    Write-Sep

    try {
        # Intenta activar el servicio si ya esta en el sistema
        Write-Host "Iniciando servicio sshd..." -ForegroundColor Gray
        Start-Service sshd -ErrorAction Stop
        Set-Service -Name sshd -StartupType 'Automatic'
        Write-Host "[OK] El servicio SSH ya esta activo y en automatico." -ForegroundColor Green
    } catch {
        # Si falla (porque no esta instalado), intenta instalarlo
        Write-Host "Instalando OpenSSH Server desde capacidades de Windows..." -ForegroundColor Yellow
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
        Start-Service sshd
        Set-Service -Name sshd -StartupType 'Automatic'
        Write-Host "[OK] Instalacion y activacion completada con exito." -ForegroundColor Green
    }
    
    Write-Sep
}