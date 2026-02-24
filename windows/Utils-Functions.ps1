function Verificar-Administrador {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdmin) {
        Write-Host "Error: Ejecuta PowerShell como Administrador." -ForegroundColor Red
        Pausa
        exit
    }
}

function Instalar-Paquete {
    param([string]$NombreRol)
    Write-Host ">>> Instalando $NombreRol..." -ForegroundColor Cyan
    Install-WindowsFeature -Name $NombreRol -IncludeManagementTools -Restart:$false | Out-Null
    Write-Host " $NombreRol instalado correctamente." -ForegroundColor Green
}

function Pausa {
    Write-Host ""
    Read-Host " [ Presiona ENTER para continuar ]" | Out-Null
}
