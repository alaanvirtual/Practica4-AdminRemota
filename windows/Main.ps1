# ============================================================
# Archivo     : Main.ps1 - CORRECCIÓN DE VARIABLES
# ============================================================
$BASE_PATH = $PSScriptRoot

function Import-Library ([string]$Name) {
    $FullPath = Join-Path $BASE_PATH $Name
    
    if (Test-Path $FullPath) {
        try {
            $Content = Get-Content $FullPath -Raw -Encoding UTF8
            Invoke-Expression $Content
        } catch {
            # Se usan llaves ${} para que el : no rompa la variable
            Write-Warning "Error al cargar ${Name}: $_"
        }
    }
}

Import-Library "Utils-Functions.ps1"
Import-Library "SSH-Functions.ps1"
Import-Library "DHCP-Functions.ps1"
Import-Library "DNS-Functions.ps1"

$ErrorActionPreference = "Continue"

if (Get-Command Test-Administrator -ErrorAction SilentlyContinue) {
    Test-Administrator
}

# --- Menú Principal ---
$main_loop = $true
while ($main_loop) {
    Clear-Host
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "   ADMINISTRADOR DE SERVIDORES WINDOWS        " -ForegroundColor Yellow
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "1. SSH | 2. DHCP | 4. Estado | 0. Salir"
    $op = (Read-Host " Seleccione").Trim()
    
    switch ($op) {
        "1" { if (Get-Command Configurar-ModuloSSH -ErrorAction SilentlyContinue) { Configurar-ModuloSSH }; Pausa-Enter }
        "2" { Write-Host "Modulo DHCP seleccionado"; Pausa-Enter }
        "4" { 
            if (Get-Command Test-WinService -ErrorAction SilentlyContinue) {
                Test-WinService "sshd"
                Test-WinService "DHCPServer"
            }
            Pausa-Enter 
        }
        "0" { $main_loop = $false; exit 0 }
    }
}