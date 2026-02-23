#!/bin/bash
# ============================================================
# Archivo     : dns_functions.sh
# Descripción : Instalación y configuración de BIND9
# Práctica    : 4 – SSH y Refactorización Modular
# Depende de  : utils_functions.sh
# ============================================================

INTERFAZ_DNS="ens34"
DOMINIO_DNS="reprobados.com"
ZONA_FILE="/etc/bind/db.${DOMINIO_DNS}"
CONF_LOCAL="/etc/bind/named.conf.local"
LOG_DNS="/var/log/dns_gestion.log"

# ── Verificar/asignar IP de la interfaz ─────────────────────
verificar_ip_fija_dns() {
    msg_info "Verificando IP en $INTERFAZ_DNS..."
    IP_DNS=$(ip -4 addr show "$INTERFAZ_DNS" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

    if [[ -z "$IP_DNS" ]]; then
        msg_warn "No se detectó IP en $INTERFAZ_DNS."
        read -p " ${YELLOW}Ingrese la IP manualmente:${RESET} " IP_DNS
        ip addr add "$IP_DNS/24" dev "$INTERFAZ_DNS" 2>/dev/null
        ip link set "$INTERFAZ_DNS" up 2>/dev/null
        registrar_log "DNS – IP asignada manualmente: $IP_DNS"
        msg_ok "IP temporal asignada: $IP_DNS"
    else
        msg_ok "IP detectada en $INTERFAZ_DNS: ${BOLD}$IP_DNS${RESET}"
    fi
}

# ── Instalar BIND9 (idempotente) ─────────────────────────────
instalar_bind() {
    if dpkg -l 2>/dev/null | grep -q "^ii  bind9 "; then
        msg_ok "BIND9 ya está instalado."
    else
        msg_warn "Instalando BIND9 y utilerías (puede tardar)..."
        apt-get update -y -qq >/dev/null 2>&1
        for pkg in bind9 bind9utils bind9-doc; do
            instalar_paquete "$pkg"
        done
        registrar_log "BIND9 instalado."
    fi
}

# ── Registrar zona en named.conf.local ──────────────────────
registrar_zona_bind() {
    if ! grep -q "zone \"$DOMINIO_DNS\"" "$CONF_LOCAL" 2>/dev/null; then
        hacer_backup "$CONF_LOCAL"
        cat >> "$CONF_LOCAL" <<EOF

zone "$DOMINIO_DNS" {
    type master;
    file "$ZONA_FILE";
};
EOF
        msg_ok "Zona '$DOMINIO_DNS' añadida a named.conf.local."
    else
        msg_info "Zona '$DOMINIO_DNS' ya declarada en named.conf.local."
    fi
}

# ── Crear archivo de zona (db.dominio) ──────────────────────
crear_archivo_zona() {
    hacer_backup "$ZONA_FILE"
    msg_info "Creando archivo de zona: $ZONA_FILE"
    cat > "$ZONA_FILE" <<EOF
;
; BIND data file for $DOMINIO_DNS
;
\$TTL    604800
@       IN      SOA     ns1.$DOMINIO_DNS. root.$DOMINIO_DNS. (
                              $(date +%Y%m%d01)  ; Serial
                              604800             ; Refresh
                               86400             ; Retry
                             2419200             ; Expire
                              604800 )           ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMINIO_DNS.
@       IN      A       $IP_DNS
ns1     IN      A       $IP_DNS
www     IN      A       $IP_DNS
EOF
    registrar_log "DNS – Zona $DOMINIO_DNS configurada -> $IP_DNS"
    msg_ok "Archivo de zona creado."
}

# ── Validar sintaxis y probar resolución ─────────────────────
validar_configuracion_dns() {
    echo ""
    msg_info "Ejecutando pruebas de validación DNS..."
    if named-checkconf >/dev/null 2>&1; then
        msg_ok "Sintaxis BIND9: CORRECTA"
    else
        msg_error "Error de sintaxis en BIND9:"
        named-checkconf
        return 1
    fi

    sleep 2
    local resultado
    resultado=$(nslookup "$DOMINIO_DNS" 127.0.0.1 2>/dev/null \
                | grep "Address:" | tail -n1 | awk '{print $2}')
    if [[ "$resultado" == "$IP_DNS" ]]; then
        msg_ok "Resolución exitosa: $DOMINIO_DNS → $resultado"
    else
        msg_error "Fallo en resolución. Se obtuvo: '$resultado' (esperado: $IP_DNS)"
        msg_warn "Verifica que el puerto 53 no esté bloqueado."
    fi
}

# ── Mostrar contenido del archivo de zona ───────────────────
mostrar_estado_zona() {
    separador
    msg_info "=== CONTENIDO DE LA ZONA ($ZONA_FILE) ==="
    if [[ -f "$ZONA_FILE" ]]; then
        grep -v "^;" "$ZONA_FILE" | grep -v "^$"
    else
        msg_error "El archivo de zona no existe aún."
    fi
    separador
}

# ── Configuración completa DNS ───────────────────────────────
configurar_modulo_dns() {
    separador
    msg_info "=== MÓDULO DNS – INSTALACIÓN Y CONFIGURACIÓN ==="
    separador
    verificar_ip_fija_dns
    instalar_bind
    registrar_zona_bind
    crear_archivo_zona
    habilitar_servicio "bind9"
    validar_configuracion_dns
    msg_ok "Servidor DNS BIND9 configurado y activo."
    registrar_log "DNS módulo completo – Dominio: $DOMINIO_DNS IP: $IP_DNS"
}

# ── Reconfigurar IP del servidor DNS ────────────────────────
reconfigurar_ip_dns() {
    read -p " ${YELLOW}Nueva IP para los registros DNS:${RESET} " IP_DNS
    crear_archivo_zona
    habilitar_servicio "bind9"
    validar_configuracion_dns
}