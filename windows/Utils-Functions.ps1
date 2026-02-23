# ============================================================
# Archivo     : Utils-Functions.ps1
# Descripcion : Funciones utilitarias reutilizables (Windows)
# Practica    : 4 – SSH y Refactorizacion Modular
# Carga con   : . .\lib\Utils-Functions.ps1
# ============================================================

# ── Mensajes con color ───────────────────────────────────────
function Write-Ok    { param([string]$Msg) Write-Host " ✔  $Msg" -ForegroundColor Green }
function Write-Err   { param([string]$Msg) Write-Host " ✘  $Msg" -ForegroundColor Red }
function Write-Info  { param([string]$Msg) Write-Host " ➤  $Msg" -ForegroundColor Cyan }
function Write-Warn  { param([string]$Msg) Write-Host " ⚠  $Msg" -ForegroundColor Yellow }
function Write-Sep   { Write-Host ("─" * 55) -ForegroundColor Cyan }

function Pausa-Enter {
    Write-Host ""
    Read-Host " [ Presiona ENTER para continuar ]" | Out-Null
}

# ── Verificar que corre como Administrador ───────────────────
function Test-Administrator {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Err "Ejecuta PowerShell COMO ADMINISTRADOR."
        exit 1
    }
    Write-Ok "Permisos de Administrador verificados."
}

# ── Leer respuesta S/N ───────────────────────────────────────
function Leer-SiNo([string]$Prompt, [bool]$DefaultSi = $true) {
    $sufijo = if ($DefaultSi) { "[S/n]" } else { "[s/N]" }
    while ($true) {
        $r = (Read-Host "$Prompt $sufijo").Trim()
        if ([string]::IsNullOrWhiteSpace($r)) { return $DefaultSi }
        if ($r -match '^(s|si|y|yes)$') { return $true }
        if ($r -match '^(n|no)$')        { return $false }
        Write-Host "Responde S o N."
    }
}

# ── Validar IPv4 ─────────────────────────────────────────────
function Test-IPv4Address([string]$IP) {
    if ([string]::IsNullOrWhiteSpace($IP)) { return $false }
    $addr = $null
    if (-not [System.Net.IPAddress]::TryParse($IP, [ref]$addr)) { return $false }
    if ($addr.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { return $false }
    if ($IP -eq "0.0.0.0" -or $IP -eq "255.255.255.255") { return $false }
    return $true
}

# ── Leer IPv4 con validación ─────────────────────────────────
function Leer-IPv4([string]$Prompt) {
    while ($true) {
        $ip = (Read-Host $Prompt).Trim()
        if (Test-IPv4Address $ip) { return $ip }
        Write-Warn "IP invalida, intenta de nuevo."
    }
}

function Leer-IPv4Opcional([string]$Prompt) {
    while ($true) {
        $ip = (Read-Host "$Prompt (Enter para omitir)").Trim()
        if ([string]::IsNullOrWhiteSpace($ip)) { return $null }
        if (Test-IPv4Address $ip) { return $ip }
        Write-Warn "IP invalida."
    }
}

# ── Backup de archivo ────────────────────────────────────────
function Backup-ConfigFile([string]$FilePath) {
    if (Test-Path $FilePath) {
        $ts  = Get-Date -Format "yyyyMMdd_HHmmss"
        Copy-Item $FilePath "$FilePath.bak_$ts"
        Write-Ok "Backup creado: $FilePath.bak_$ts"
    }
}

# ── Habilitar e iniciar servicio de Windows ──────────────────
function Enable-WinService([string]$ServiceName, [string]$StartType = "Automatic") {
    try {
        Set-Service  -Name $ServiceName -StartupType $StartType -ErrorAction Stop
        Start-Service -Name $ServiceName -ErrorAction Stop
        $st = (Get-Service -Name $ServiceName).Status
        if ($st -eq "Running") {
            Write-Ok "Servicio '$ServiceName' iniciado ($StartType)."
        } else {
            Write-Err "Servicio '$ServiceName' – estado inesperado: $st"
        }
    } catch {
        Write-Err "Error al gestionar '$ServiceName': $_"
    }
}

# ── Estado de un servicio ────────────────────────────────────
function Test-WinService([string]$ServiceName) {
    try {
        $s = Get-Service -Name $ServiceName -ErrorAction Stop
        if ($s.Status -eq "Running") {
            Write-Ok "  '$ServiceName': ACTIVO"
        } else {
            Write-Warn "  '$ServiceName': $($s.Status)"
        }
    } catch {
        Write-Err "  '$ServiceName': NO encontrado"
    }
}

# ── IP local del servidor ────────────────────────────────────
function Get-LocalIP {
    (Get-NetIPAddress -AddressFamily IPv4 |
     Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and
                    $_.IPAddress -notlike "169.254.*" } |
     Select-Object -First 1).IPAddress
}

# ── Log persistente ──────────────────────────────────────────
$LOG_WIN = "C:\practica4_log.txt"
function Registrar-Log([string]$Msg) {
    $linea = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Msg"
    Add-Content -Path $LOG_WIN -Value $linea -Encoding UTF8
}