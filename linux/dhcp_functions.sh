#!/bin/bash
# ============================================================
# Archivo     : dhcp_functions.sh
# Descripción : Instalación y configuración de isc-dhcp-server
# Práctica    : 4 – SSH y Refactorización Modular
# Depende de  : utils_functions.sh
# ============================================================

INTERFAZ_DHCP="ens34"   # Ajusta si tu interfaz es diferente

# ── Configurar IP estática en la interfaz ───────────────────
configurar_red_servidor_dhcp() {
    local ip="$1"
    msg_info "Asignando IP estática $ip en $INTERFAZ_DHCP..."
    ip addr flush dev "$INTERFAZ_DHCP" 2>/dev/null
    ip addr add "$ip/24" dev "$INTERFAZ_DHCP"
    ip link set "$INTERFAZ_DHCP" up
    registrar_log "IP estática DHCP configurada: $ip en $INTERFAZ_DHCP"
    msg_ok "IP $ip asignada en $INTERFAZ_DHCP."
}

# ── Instalar isc-dhcp-server ─────────────────────────────────
instalar_dhcp() {
    msg_info "Actualizando repositorios..."
    apt-get update -y -qq >/dev/null 2>&1
    instalar_paquete "isc-dhcp-server"
}

# ── Escribir dhcpd.conf ──────────────────────────────────────
# Parámetros: ambito seg_net pool_inicio pool_fin [gateway] [dns1] [dns2]
escribir_config_dhcp() {
    local ambito="$1" seg_net="$2" pool_inicio="$3" pool_fin="$4"
    local gateway="$5" dns1="$6" dns2="$7"
    local cfg="/etc/dhcp/dhcpd.conf"

    hacer_backup "$cfg"
    msg_info "Escribiendo $cfg..."

    {
        echo "# AMBITO:$ambito"
        echo "authoritative;"
        echo "default-lease-time 28800;"
        echo "max-lease-time 28800;"
        echo ""
        echo "option domain-name \"$seg_net\";"
        echo ""
        echo "subnet $seg_net netmask 255.255.255.0 {"
        echo "  range $pool_inicio $pool_fin;"
        [[ -n "$gateway" ]] && validar_ip "$gateway" && echo "  option routers $gateway;"
        if [[ -n "$dns1" ]] && validar_ip "$dns1"; then
            local dns_line="  option domain-name-servers $dns1"
            [[ -n "$dns2" ]] && validar_ip "$dns2" && dns_line="$dns_line, $dns2"
            echo "${dns_line};"
        fi
        echo "}"
    } > "$cfg"

    # Asignar interfaz
    sed -i "s/INTERFACESv4=\".*\"/INTERFACESv4=\"$INTERFAZ_DHCP\"/" /etc/default/isc-dhcp-server

    # Crear archivo de leases si no existe
    mkdir -p /var/lib/dhcp
    touch /var/lib/dhcp/dhcpd.leases
    chmod 644 /var/lib/dhcp/dhcpd.leases

    msg_ok "dhcpd.conf generado correctamente."
    registrar_log "Scope DHCP: $ambito | Red: $seg_net | Rango: $pool_inicio-$pool_fin"
}

# ── Pedir datos al usuario e instalar todo ───────────────────
configurar_modulo_dhcp() {
    separador
    msg_info "=== MÓDULO DHCP – INSTALACIÓN Y CONFIGURACIÓN ==="
    separador

    instalar_dhcp

    echo ""
    read -p " ${CYAN}Nombre del ámbito:${RESET} " ambito
    read -p " ${CYAN}IP del servidor (inicio rango, ej: 192.168.1.1):${RESET} " IPI
    read -p " ${CYAN}IP final del rango (ej: 192.168.1.100):${RESET} "          IPF

    if ! validar_ip "$IPI" || ! validar_ip "$IPF"; then
        msg_error "IPs inválidas. Abortando."; return 1
    fi
    if ! validar_rango "$IPI" "$IPF"; then
        msg_error "El rango es inválido (misma subred y inicio < fin)."; return 1
    fi

    # Calcular red y pool
    local SEG_PREFIX; SEG_PREFIX=$(echo "$IPI" | cut -d. -f1-3)
    local SEG_NET="${SEG_PREFIX}.0"
    local ULTIMO_OCTETO; ULTIMO_OCTETO=$(echo "$IPI" | cut -d. -f4)
    local POOL_I="${SEG_PREFIX}.$((ULTIMO_OCTETO + 1))"

    read -p " ${CYAN}Gateway (Enter para omitir):${RESET} " GW
    read -p " ${CYAN}DNS primario (Enter para omitir):${RESET} " DNS1
    local DNS2=""
    [[ -n "$DNS1" ]] && read -p " ${CYAN}DNS secundario (Enter para omitir):${RESET} " DNS2

    configurar_red_servidor_dhcp "$IPI"
    escribir_config_dhcp "$ambito" "$SEG_NET" "$POOL_I" "$IPF" "$GW" "$DNS1" "$DNS2"
    habilitar_servicio "isc-dhcp-server"

    echo ""
    msg_ok "Servidor DHCP configurado."
    echo "   ${GREEN}Segmento :${RESET} $SEG_NET"
    echo "   ${GREEN}Rango    :${RESET} $POOL_I – $IPF"
    [[ -n "$GW"   ]] && echo "   ${GREEN}Gateway  :${RESET} $GW"
    [[ -n "$DNS1" ]] && echo "   ${GREEN}DNS      :${RESET} $DNS1 $DNS2"
}

# ── Monitoreo de clientes (leases activos) ───────────────────
monitoreo_dhcp() {
    local lf=""
    for f in /var/lib/dhcp/dhcpd.leases /var/lib/dhcpd/dhcpd.leases; do
        [[ -f "$f" ]] && lf="$f" && break
    done

    while true; do
        clear
        echo "${CYAN}══════════════════════════════════════════════════════${RESET}"
        echo "      MONITOREO DHCP (actualización cada 3 seg.)"
        echo "${CYAN}══════════════════════════════════════════════════════${RESET}"
        printf "${BOLD}%-18s %-20s %-20s %-12s${RESET}\n" "IP CLIENTE" "MAC ADDRESS" "HOSTNAME" "ESTADO"
        echo "──────────────────────────────────────────────────────"

        if [[ -z "$lf" || ! -f "$lf" ]]; then
            msg_error "Archivo de leases no encontrado."
        elif [[ ! -s "$lf" ]]; then
            msg_warn "Esperando conexiones... (archivo vacío)"
        else
            local resultado
            resultado=$(awk '
                /^lease /       { ip=$2 }
                /binding state/ { st=$3; gsub(";","",st); est=st }
                /hardware ethernet/ { mac=$3; gsub(";","",mac); m=mac }
                /client-hostname/   { h=$2; gsub("[\";]","",h); hn=(h!="")? h:"Desconocido" }
                /^}/ {
                    if(ip!="") { estado[ip]=est; macs[ip]=m; host[ip]=hn }
                    ip=""; est=""; m="N/A"; hn="Desconocido"
                }
                END { for(i in estado) if(estado[i]!="free")
                          printf "%s\t%s\t%s\tCONECTADO\n",i,macs[i],host[i] }
            ' "$lf")

            if [[ -z "$resultado" ]]; then
                msg_warn "No hay clientes conectados actualmente."
            else
                echo "$resultado" | sort -u -t $'\t' -k1,1 | \
                while IFS=$'\t' read -r ip mac hostname estado; do
                    printf "${GREEN}%-18s %-20s %-20s %-12s${RESET}\n" "$ip" "$mac" "$hostname" "$estado"
                done
                echo ""
                msg_ok "Total conectados: $(echo "$resultado" | sort -u -t $'\t' -k1,1 | wc -l)"
            fi
        fi

        echo ""
        echo "${YELLOW} [Enter] para volver al menú${RESET}"
        read -t 3 && break
    done
}

# ── Ver historial de leases completo ────────────────────────
ver_leases_completo() {
    local lf="/var/lib/dhcp/dhcpd.leases"
    [[ ! -f "$lf" ]] && lf="/var/lib/dhcpd/dhcpd.leases"
    separador
    msg_info "=== ARCHIVO DE LEASES COMPLETO ==="
    [[ -f "$lf" ]] && cat "$lf" || msg_error "Archivo no encontrado."
}

# ── Estado del sistema DHCP ──────────────────────────────────
estado_dhcp() {
    separador
    msg_info "=== ESTADO DEL SISTEMA DHCP ==="
    if dpkg -l 2>/dev/null | grep -q "^ii  isc-dhcp-server "; then
        msg_ok "isc-dhcp-server: INSTALADO"
        msg_info "Estado del servicio:"
        systemctl status isc-dhcp-server --no-pager 2>/dev/null | head -8
        if [[ -f /etc/dhcp/dhcpd.conf ]]; then
            echo ""
            msg_info "Configuración activa:"
            local IP_ACT; IP_ACT=$(ip -4 addr show "$INTERFAZ_DHCP" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
            echo "   ${GREEN}Interfaz  :${RESET} $INTERFAZ_DHCP"
            echo "   ${GREEN}IP Servidor:${RESET} ${IP_ACT:-No asignada}"
            grep -E "subnet|range|routers|domain-name-servers" /etc/dhcp/dhcpd.conf \
                | grep -v "^#" | sed 's/^/   /'
        fi
    else
        msg_warn "isc-dhcp-server: NO INSTALADO"
    fi
}