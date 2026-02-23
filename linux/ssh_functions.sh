#!/bin/bash
# ============================================================
# Archivo     : ssh_functions.sh
# Descripción : Instalación y configuración de OpenSSH Server
# Práctica    : 4 – SSH y Refactorización Modular
# Depende de  : utils_functions.sh
# ============================================================

# ── Instalar openssh-server ──────────────────────────────────
instalar_ssh() {
    msg_info "Actualizando repositorios..."
    apt-get update -y -qq >/dev/null 2>&1
    instalar_paquete "openssh-server"
}

# ── Configurar sshd_config de forma segura ──────────────────
configurar_ssh() {
    local cfg="/etc/ssh/sshd_config"
    hacer_backup "$cfg"
    msg_info "Aplicando configuración segura a sshd_config..."

    sed -i 's/^#*Port .*/Port 22/'                             "$cfg"
    sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/'       "$cfg"
    sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication yes/' "$cfg"
    sed -i 's/^#*MaxAuthTries .*/MaxAuthTries 4/'              "$cfg"
    sed -i 's/^#*LoginGraceTime .*/LoginGraceTime 60/'         "$cfg"

    msg_ok "Configuración SSH aplicada (puerto 22, root deshabilitado)."
}

# ── Abrir puerto 22 en UFW ───────────────────────────────────
configurar_firewall_ssh() {
    msg_info "Configurando firewall UFW para SSH..."
    if command -v ufw &>/dev/null; then
        ufw allow 22/tcp >/dev/null 2>&1
        ufw --force enable >/dev/null 2>&1
        msg_ok "Puerto 22/TCP habilitado en UFW."
    else
        msg_warn "UFW no encontrado; verifica iptables manualmente."
    fi
}

# ── Mostrar datos de conexión al terminar ────────────────────
mostrar_info_conexion_ssh() {
    local ip; ip=$(hostname -I | awk '{print $1}')
    local usuario; usuario=$(logname 2>/dev/null || echo "tu_usuario")
    separador
    msg_ok "SSH listo. Usa estos datos para conectarte:"
    echo ""
    echo "   ${GREEN}IP Servidor  :${RESET}  $ip"
    echo "   ${GREEN}Puerto       :${RESET}  22"
    echo "   ${GREEN}Usuario      :${RESET}  $usuario"
    echo "   ${GREEN}Comando      :${RESET}  ssh ${usuario}@${ip}"
    separador
    registrar_log "SSH instalado. IP=$ip Usuario=$usuario"
}

# ── Proceso completo SSH ─────────────────────────────────────
configurar_modulo_ssh() {
    separador
    msg_info "=== MÓDULO SSH – INSTALACIÓN Y CONFIGURACIÓN ==="
    separador
    instalar_ssh
    configurar_ssh
    habilitar_servicio "ssh"
    configurar_firewall_ssh
    mostrar_info_conexion_ssh
}