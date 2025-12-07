#!/bin/bash

# ==================== VMess 系列协议配置模块 ====================

configure_vmess() {
    clear
    echo -e "${CYAN}═══════════════════ VMess 协议配置 ═══════════════════${NC}"
    echo ""
    echo "  ${GREEN}1.${NC}  VMess+TCP"
    echo "  ${GREEN}2.${NC}  VMess+WebSocket"
    echo "  ${GREEN}3.${NC}  VMess+gRPC"
    echo "  ${GREEN}4.${NC}  VMess+TCP+TLS"
    echo "  ${GREEN}5.${NC}  VMess+WebSocket+TLS"
    echo "  ${GREEN}6.${NC}  VMess+gRPC+TLS"
    echo "  ${GREEN}0.${NC}  返回"
    echo ""
    
    read -p "请选择 VMess 变体 [0-6]: " vmess_type
    
    case $vmess_type in
        1) configure_vmess_tcp ;;
        2) configure_vmess_ws ;;
        3) configure_vmess_grpc ;;
        4) configure_vmess_tcp_tls ;;
        5) configure_vmess_ws_tls ;;
        6) configure_vmess_grpc_tls ;;
        0) return ;;
        *) print_error "无效的选择"; sleep 2; configure_vmess ;;
    esac
}

configure_vmess_tcp() {
    clear
    print_info "配置 VMess+TCP 节点"
    
    read -p "请输入监听端口 (默认10086): " port
    port=${port:-10086}
    
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    print_success "UUID: ${uuid}"
    
    local config_file="${CONFIG_DIR}/config.json"
    [[ ! -f "$config_file" ]] && create_base_config
    
    local inbound=$(cat <<EOF
{
  "type": "vmess",
  "tag": "vmess-tcp-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [{"uuid": "${uuid}", "alterId": 0}]
}
EOF
)
    
    jq ".inbounds += [$inbound]" "$config_file" > /tmp/config.tmp && mv /tmp/config.tmp "$config_file"
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        local vmess_json="{\"v\":\"2\",\"ps\":\"VMess-TCP-${SERVER_IP}\",\"add\":\"${SERVER_IP}\",\"port\":\"${port}\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"none\",\"host\":\"\",\"path\":\"\",\"tls\":\"\"}"
        local link="vmess://$(echo -n "$vmess_json" | base64 -w0)"
        mkdir -p "${LINK_DIR}"
        echo -e "VMess+TCP\nUUID: ${uuid}\n\n${link}" > "${LINK_DIR}/vmess_tcp_${port}.txt"
        print_success "配置完成"
        cat "${LINK_DIR}/vmess_tcp_${port}.txt"
    fi
    
    read -p "按回车键继续..."
}

configure_vmess_ws() {
    clear
    print_info "配置 VMess+WebSocket 节点"
    
    read -p "请输入监听端口 (默认10086): " port
    port=${port:-10086}
    
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    local path="/$(openssl rand -hex 4)"
    print_success "UUID: ${uuid}"
    print_success "Path: ${path}"
    
    local config_file="${CONFIG_DIR}/config.json"
    [[ ! -f "$config_file" ]] && create_base_config
    
    local inbound=$(cat <<EOF
{
  "type": "vmess",
  "tag": "vmess-ws-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [{"uuid": "${uuid}", "alterId": 0}],
  "transport": {"type": "ws", "path": "${path}"}
}
EOF
)
    
    jq ".inbounds += [$inbound]" "$config_file" > /tmp/config.tmp && mv /tmp/config.tmp "$config_file"
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        local vmess_json="{\"v\":\"2\",\"ps\":\"VMess-WS-${SERVER_IP}\",\"add\":\"${SERVER_IP}\",\"port\":\"${port}\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"\",\"path\":\"${path}\",\"tls\":\"\"}"
        local link="vmess://$(echo -n "$vmess_json" | base64 -w0)"
        mkdir -p "${LINK_DIR}"
        echo -e "VMess+WebSocket\nUUID: ${uuid}\nPath: ${path}\n\n${link}" > "${LINK_DIR}/vmess_ws_${port}.txt"
        print_success "配置完成"
        cat "${LINK_DIR}/vmess_ws_${port}.txt"
    fi
    
    read -p "按回车键继续..."
}

create_base_config() {
    cat > "${CONFIG_DIR}/config.json" << 'EOF'
{
  "log": {"level": "info"},
  "inbounds": [],
  "outbounds": [{"type": "direct", "tag": "direct"}]
}
EOF
}
