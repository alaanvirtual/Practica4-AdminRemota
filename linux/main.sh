#!/bin/bash
# ============================================================
# Archivo     : main.sh
# Descripción : Punto de entrada principal – Menú interactivo
# Práctica    : 4 – SSH y Refactorización Modular
# Uso         : sudo bash main.sh
# ============================================================
# Carga de bibliotecas de funciones (source)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/lib"

source "$LIB/utils_functions.sh"
source "$LIB/ssh_functions.sh"
source "$LIB/dhcp_functions.sh"
source "$LIB/dns_functions.sh"

verificar_root   # ← sale si no es root

# ── Submenú DHCP ────────────────────────────────────────────
menu_dhcp() {
    while true; do
        header
        echo "${GREEN}  ╔══════════════════════════════════════╗${RESET}"
        echo "${GREEN}  ║     SUBMÓDULO – SERVIDOR DHCP        ║${RESET}"
        echo "${GREEN}  ╠══════════════════════════════════════╣${RESET}"
        echo "${GREEN}  ║${RESET}  1. Estado del sistema DHCP          ${GREEN}║${RESET}"
        echo "${GREEN}  ║${RESET}  2. Instalar y configurar scope       ${GREEN}║${RESET}"
        echo "${GREEN}  ║${RESET}  3. Monitoreo de clientes (tiempo real)${GREEN}║${RESET}"
        echo "${GREEN}  ║${RESET}  4. Ver leases completos              ${GREEN}║${RESET}"
        echo "${GREEN}  ║${RESET}  0. Volver al menú principal          ${GREEN}║${RESET}"
        echo "${GREEN}  ╚══════════════════════════════════════╝${RESET}"
        echo ""
        read -p "  Opción: " sub
        case "$sub" in
            1) estado_dhcp; pause ;;
            2) configurar_modulo_dhcp; pause ;;
            3) monitoreo_dhcp ;;
            4) ver_leases_completo; pause ;;
            0) break ;;
            *) msg_error "Opción inválida."; sleep 1 ;;
        esac
    done
}

# ── Submenú DNS ─────────────────────────────────────────────
menu_dns() {
    while true; do
        header
        echo "${MAGENTA}  ╔══════════════════════════════════════╗${RESET}"
        echo "${MAGENTA}  ║     SUBMÓDULO – SERVIDOR DNS         ║${RESET}"
        echo "${MAGENTA}  ╠══════════════════════════════════════╣${RESET}"
        echo "${MAGENTA}  ║${RESET}  1. Verificar instalación y red      ${MAGENTA}║${RESET}"
        echo "${MAGENTA}  ║${RESET}  2. Instalar y configurar DNS        ${MAGENTA}║${RESET}"
        echo "${MAGENTA}  ║${RESET}  3. Reconfigurar IP del servidor      ${MAGENTA}║${RESET}"
        echo "${MAGENTA}  ║${RESET}  4. Ver estado de zona (registros)    ${MAGENTA}║${RESET}"
        echo "${MAGENTA}  ║${RESET}  0. Volver al menú principal          ${MAGENTA}║${RESET}"
        echo "${MAGENTA}  ╚══════════════════════════════════════╝${RESET}"
        echo ""
        read -p "  Opción: " sub
        case "$sub" in
            1) verificar_ip_fija_dns; instalar_bind; pause ;;
            2) configurar_modulo_dns; pause ;;
            3) reconfigurar_ip_dns; pause ;;
            4) mostrar_estado_zona; pause ;;
            0) break ;;
            *) msg_error "Opción inválida."; sleep 1 ;;
        esac
    done
}

# ── Verificar todos los servicios ───────────────────────────
estado_general() {
    separador
    msg_info "=== ESTADO GENERAL DE SERVICIOS ==="
    verificar_servicio "ssh"
    verificar_servicio "isc-dhcp-server"
    verificar_servicio "bind9"
    separador
}

# ── Menú principal ───────────────────────────────────────────
while true; do
    header
    echo "${CYAN}  ╔══════════════════════════════════════════════╗${RESET}"
    echo "${CYAN}  ║   PRÁCTICA 4 – ADMINISTRADOR DE SERVIDORES  ║${RESET}"
    echo "${CYAN}  ╠══════════════════════════════════════════════╣${RESET}"
    echo "${CYAN}  ║${RESET}  1. ${GREEN}SSH${RESET}   – Instalar y configurar acceso remoto  ${CYAN}║${RESET}"
    echo "${CYAN}  ║${RESET}  2. ${GREEN}DHCP${RESET}  – Gestión del servidor DHCP           ${CYAN}║${RESET}"
    echo "${CYAN}  ║${RESET}  3. ${GREEN}DNS${RESET}   – Gestión del servidor DNS (BIND9)     ${CYAN}║${RESET}"
    echo "${CYAN}  ║${RESET}  4. ${GREEN}Estado${RESET} – Ver todos los servicios             ${CYAN}║${RESET}"
    echo "${CYAN}  ║${RESET}  5. ${GREEN}TODO${RESET}  – Instalar SSH + DHCP + DNS            ${CYAN}║${RESET}"
    echo "${CYAN}  ║${RESET}  0. ${RED}Salir${RESET}                                        ${CYAN}║${RESET}"
    echo "${CYAN}  ╚══════════════════════════════════════════════╝${RESET}"
    echo ""
    read -p "  Seleccione una opción: " opcion

    case "$opcion" in
        1) configurar_modulo_ssh; pause ;;
        2) menu_dhcp ;;
        3) menu_dns ;;
        4) estado_general; pause ;;
        5)
            configurar_modulo_ssh
            configurar_modulo_dhcp
            configurar_modulo_dns
            pause
            ;;
        0) msg_info "Saliendo. ¡Hasta luego!"; exit 0 ;;
        *) msg_error "Opción inválida."; sleep 1 ;;
    esac
done