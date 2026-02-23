#!/bin/bash
# ============================================================
# Archivo     : utils_functions.sh
# Descripción : Funciones utilitarias reutilizables
# Práctica    : 4 – SSH y Refactorización Modular
# Carga con   : source ./lib/utils_functions.sh
# ============================================================

# ── Colores ─────────────────────────────────────────────────
BOLD=$(tput bold 2>/dev/null);  RESET=$(tput sgr0 2>/dev/null)
RED=$(tput setaf 1 2>/dev/null);     GREEN=$(tput setaf 2 2>/dev/null)
YELLOW=$(tput setaf 3 2>/dev/null);  BLUE=$(tput setaf 4 2>/dev/null)
MAGENTA=$(tput setaf 5 2>/dev/null); CYAN=$(tput setaf 6 2>/dev/null)
WHITE=$(tput setaf 7 2>/dev/null)

# ── Mensajes ────────────────────────────────────────────────
msg_info()  { echo -e "${BLUE} ➤ ${RESET} $1"; }
msg_ok()    { echo -e "${GREEN} ✔ ${RESET} $1"; }
msg_warn()  { echo -e "${YELLOW} ⚠ ${RESET} $1"; }
msg_error() { echo -e "${RED} ✘ ${RESET} $1"; }
separador() { echo "${CYAN}──────────────────────────────────────────────────────${RESET}"; }
pause()     { echo ""; read -p "${MAGENTA} [ Presiona Enter para continuar ]${RESET}"; }

header() {
    clear
    echo "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
    echo "${CYAN}║         ADMINISTRADOR DE SERVIDORES – PRÁCTICA 4    ║${RESET}"
    echo "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

# ── Verificar root ───────────────────────────────────────────
verificar_root() {
    if [[ $EUID -ne 0 ]]; then
        msg_error "Ejecuta el script como root:  sudo bash main.sh"
        exit 1
    fi
    msg_ok "Permisos de root verificados."
}

# ── Instalar paquete (idempotente) ───────────────────────────
# Uso: instalar_paquete isc-dhcp-server
instalar_paquete() {
    local pkg="$1"
    if dpkg -l 2>/dev/null | grep -q "^ii  $pkg "; then
        msg_warn "Paquete '$pkg' ya instalado. Omitiendo."
    else
        msg_info "Instalando '$pkg'..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" >/dev/null 2>&1 \
            && msg_ok "'$pkg' instalado." \
            || { msg_error "Fallo al instalar '$pkg'."; exit 1; }
    fi
}

# ── Validar formato IPv4 ─────────────────────────────────────
# Retorna 0=ok, 1=inválida
validar_ip() {
    [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS='.' read -ra o <<< "$1"
    for oct in "${o[@]}"; do (( oct >= 0 && oct <= 255 )) || return 1; done
    return 0
}

# ── Validar rango inicio < fin (mismo /24) ───────────────────
validar_rango() {
    local r1; r1=$(echo "$1" | cut -d. -f1-3)
    local r2; r2=$(echo "$2" | cut -d. -f1-3)
    [[ "$r1" == "$r2" ]] && \
    [[ "$(echo "$1" | cut -d. -f4)" -lt "$(echo "$2" | cut -d. -f4)" ]]
}

# ── Backup de archivo ────────────────────────────────────────
hacer_backup() {
    local f="$1"
    [[ -f "$f" ]] && cp "$f" "${f}.bak_$(date +%Y%m%d_%H%M%S)" && msg_ok "Backup: ${f}.bak"
}

# ── Habilitar + iniciar servicio systemd ─────────────────────
habilitar_servicio() {
    local svc="$1"
    systemctl enable  "$svc" >/dev/null 2>&1
    systemctl restart "$svc" >/dev/null 2>&1
    systemctl is-active --quiet "$svc" \
        && msg_ok "Servicio '$svc' activo y habilitado en el arranque." \
        || { msg_error "El servicio '$svc' no pudo iniciarse."; exit 1; }
}

# ── Estado de un servicio ────────────────────────────────────
verificar_servicio() {
    local svc="$1"
    systemctl is-active --quiet "$svc" \
        && msg_ok "  '$svc': ${GREEN}ACTIVO${RESET}" \
        || msg_warn " '$svc': ${RED}INACTIVO / NO INSTALADO${RESET}"
}

# ── Log persistente ──────────────────────────────────────────
LOG_GENERAL="/var/log/practica4_acciones.log"
registrar_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_GENERAL" >/dev/null
}