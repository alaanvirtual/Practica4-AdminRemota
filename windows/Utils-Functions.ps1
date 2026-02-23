function Verificar-Administrador {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Error: Necesitas ejecutar este script como Administrador." -ForegroundColor Red
        Pausa
        exit
    }
}

function Validar-IP {
    param([string]$IP)
    if ($IP -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') {
        return $true
    } else {
        return $false
    }
}

function Instalar-Paquete {
    param([string]$NombreRol)
    Write-Host ">>> Instalando $NombreRol..." -ForegroundColor Cyan
    try {
        Install-WindowsFeature -Name $NombreRol -IncludeManagementTools -ErrorAction Stop
        Write-Host " $NombreRol instalado correctamente." -ForegroundColor Green
    } catch {
        Write-Host " Error al instalar: $_" -ForegroundColor Red
    }
}

function Pausa {
    Write-Host ""
    Write-Host "  [ Presiona ENTER para continuar ]" -ForegroundColor DarkGray -NoNewline
    Read-Host " " | Out-Null
}