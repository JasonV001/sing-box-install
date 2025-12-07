#!/bin/bash

# ==================== Trojan 系列协议配置模块 ====================
# 支持: TCP, WebSocket, gRPC, HTTPUpgrade, TCP+TLS, H2C+TLS, gRPC+TLS, WebSocket+TLS, HTTPUpgrade+TLS

configure_trojan() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                   Trojan 协议配置                         ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${PURPLE}【基础传输】${NC}"
    echo -e "    ${GREEN}1.${NC}  Trojan+TCP          ${YELLOW}(直连)${NC}"
    echo -e "    ${GREEN}2.${NC}  Trojan+WebSocket    ${YELLOW}(WS)${NC}"
    echo -e "    ${GREEN}3.${NC}  Trojan+gRPC         ${YELLOW}(HTTP/2)${NC}"
    echo -e "    ${GREEN}4.${NC}  Trojan+HTTPUpgrade  ${YELLOW}(HTTP 升级)${NC}"
    echo ""
    echo -e "  ${PURPLE}【TLS 加密】${NC}"
    echo -e "    ${GREEN}5.${NC}  Trojan+TCP+TLS      ${YELLOW}(TLS 直连 - 推荐)${NC}"
    echo -e "    ${GREEN}6.${NC}  Trojan+WebSocket+TLS ${YELLOW}(TLS+WS)${NC}"
    echo -e "    ${GREEN}7.${NC}  Trojan+gRPC+TLS     ${YELLOW}(TLS+gRPC)${NC}"
    echo ""
    echo -e "    ${GREEN}0.${NC}  返回"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    
    read -p "请选择 Trojan 变体 [0-7]: " trojan_type
    
    case $trojan_type in
        1) configure_trojan_tcp ;;
        2) configure_trojan_ws ;;
        3) configure_trojan_grpc ;;
        4) configure_trojan_httpupgrade ;;
        5) configure_trojan_tcp_tls ;;
        6) configure_trojan_ws_tls ;;
        7) configure_trojan_grpc_tls ;;
        0) return ;;
        *) print_error "无效的选择"; sleep 2; configure_trojan ;;
    esac
}

# Trojan+TCP
configure_trojan_tcp() {
    clear
    print_info "配置 Trojan+TCP 节点"
    
    read -p "请输入监听端口 (默认443): " port
    port=${port:-443}
    
    local password=$(openssl rand -hex 16)
    print_success "密码: ${password}"
    
    local config_file="${CONFIG_DIR}/config.json"
    [[ ! -f "$config_file" ]] && create_base_config
    
    local inbound=$(cat <<EOF
{
  "type": "trojan",
  "tag": "trojan-tcp-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [{"password": "${password}"}]
}
EOF
)
    
    jq ".inbounds += [$inbound]" "$config_file" > /tmp/config.tmp && mv /tmp/config.tmp "$config_file"
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        local link="trojan://${password}@${SERVER_IP}:${port}#Trojan-TCP-${SERVER_IP}"
        mkdir -p "${LINK_DIR}"
        echo -e "Trojan+TCP\n服务器: ${SERVER_IP}\n端口: ${port}\n密码: ${password}\n\n${link}" > "${LINK_DIR}/trojan_tcp_${port}.txt"
        print_success "配置完成"
        cat "${LINK_DIR}/trojan_tcp_${port}.txt"
    fi
    
    read -p "按回车键继续..."
}

# Trojan+WebSocket
configure_trojan_ws() {
    clear
    print_info "配置 Trojan+WebSocket 节点"
    
    read -p "请输入监听端口 (默认443): " port
    port=${port:-443}
    
    local password=$(openssl rand -hex 16)
    local path="/$(openssl rand -hex 4)"
    print_success "密码: ${password}"
    print_success "Path: ${path}"
    
    local config_file="${CONFIG_DIR}/config.json"
    [[ ! -f "$config_file" ]] && create_base_config
    
    local inbound=$(cat <<EOF
{
  "type": "trojan",
  "tag": "trojan-ws-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [{"password": "${password}"}],
  "transport": {"type": "ws", "path": "${path}"}
}
EOF
)
    
    jq ".inbounds += [$inbound]" "$config_file" > /tmp/config.tmp && mv /tmp/config.tmp "$config_file"
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        local link="trojan://${password}@${SERVER_IP}:${port}?type=ws&path=${path}#Trojan-WS-${SERVER_IP}"
        mkdir -p "${LINK_DIR}"
        echo -e "Trojan+WebSocket\n服务器: ${SERVER_IP}\n端口: ${port}\n密码: ${password}\nPath: ${path}\n\n${link}" > "${LINK_DIR}/trojan_ws_${port}.txt"
        print_success "配置完成"
        cat "${LINK_DIR}/trojan_ws_${port}.txt"
    fi
    
    read -p "按回车键继续..."
}

# Trojan+gRPC
configure_trojan_grpc() {
    clear
    print_info "配置 Trojan+gRPC 节点"
    
    read -p "请输入监听端口 (默认443): " port
    port=${port:-443}
    
    local password=$(openssl rand -hex 16)
    local service_name="grpc$(openssl rand -hex 4)"
    print_success "密码: ${password}"
    print_success "Service Name: ${service_name}"
    
    local config_file="${CONFIG_DIR}/config.json"
    [[ ! -f "$config_file" ]] && create_base_config
    
    local inbound=$(cat <<EOF
{
  "type": "trojan",
  "tag": "trojan-grpc-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [{"password": "${password}"}],
  "transport": {"type": "grpc", "service_name": "${service_name}"}
}
EOF
)
    
    jq ".inbounds += [$inbound]" "$config_file" > /tmp/config.tmp && mv /tmp/config.tmp "$config_file"
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        local link="trojan://${password}@${SERVER_IP}:${port}?type=grpc&serviceName=${service_name}#Trojan-gRPC-${SERVER_IP}"
        mkdir -p "${LINK_DIR}"
        echo -e "Trojan+gRPC\n服务器: ${SERVER_IP}\n端口: ${port}\n密码: ${password}\nService: ${service_name}\n\n${link}" > "${LINK_DIR}/trojan_grpc_${port}.txt"
        print_success "配置完成"
        cat "${LINK_DIR}/trojan_grpc_${port}.txt"
    fi
    
    read -p "按回车键继续..."
}

# Trojan+HTTPUpgrade
configure_trojan_httpupgrade() {
    clear
    print_info "配置 Trojan+HTTPUpgrade 节点"
    
    read -p "请输入监听端口 (默认443): " port
    port=${port:-443}
    
    local password=$(openssl rand -hex 16)
    local path="/$(openssl rand -hex 4)"
    print_success "密码: ${password}"
    print_success "Path: ${path}"
    
    local config_file="${CONFIG_DIR}/config.json"
    [[ ! -f "$config_file" ]] && create_base_config
    
    local inbound=$(cat <<EOF
{
  "type": "trojan",
  "tag": "trojan-httpupgrade-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [{"password": "${password}"}],
  "transport": {"type": "httpupgrade", "path": "${path}"}
}
EOF
)
    
    jq ".inbounds += [$inbound]" "$config_file" > /tmp/config.tmp && mv /tmp/config.tmp "$config_file"
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        local link="trojan://${password}@${SERVER_IP}:${port}?type=httpupgrade&path=${path}#Trojan-HTTPUpgrade-${SERVER_IP}"
        mkdir -p "${LINK_DIR}"
        echo -e "Trojan+HTTPUpgrade\n服务器: ${SERVER_IP}\n端口: ${port}\n密码: ${password}\nPath: ${path}\n\n${link}" > "${LINK_DIR}/trojan_httpupgrade_${port}.txt"
        print_success "配置完成"
        cat "${LINK_DIR}/trojan_httpupgrade_${port}.txt"
    fi
    
    read -p "按回车键继续..."
}

# Trojan+TLS
configure_trojan_tcp_tls() {
    clear
    print_info "配置 Trojan+TCP+TLS 节点"
    
    read -p "请输入监听端口 (默认443): " port
    port=${port:-443}
    
    read -p "请输入域名 (默认example.com): " domain
    domain=${domain:-example.com}
    
    local password=$(openssl rand -hex 16)
    print_success "密码: ${password}"
    
    # 生成证书
    local cert_dir="${CERT_DIR}/${domain}"
    mkdir -p "$cert_dir"
    openssl req -x509 -nodes -newkey rsa:2048 -days 36500 \
        -keyout "${cert_dir}/private.key" \
        -out "${cert_dir}/cert.pem" \
        -subj "/CN=${domain}" >/dev/null 2>&1
    
    local config_file="${CONFIG_DIR}/config.json"
    [[ ! -f "$config_file" ]] && create_base_config
    
    local inbound=$(cat <<EOF
{
  "type": "trojan",
  "tag": "trojan-tls-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [{"password": "${password}"}],
  "tls": {
    "enabled": true,
    "server_name": "${domain}",
    "certificate_path": "${cert_dir}/cert.pem",
    "key_path": "${cert_dir}/private.key"
  }
}
EOF
)
    
    jq ".inbounds += [$inbound]" "$config_file" > /tmp/config.tmp && mv /tmp/config.tmp "$config_file"
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        local link="trojan://${password}@${SERVER_IP}:${port}?security=tls&sni=${domain}#Trojan-TLS-${SERVER_IP}"
        mkdir -p "${LINK_DIR}"
        echo -e "Trojan+TLS\n服务器: ${SERVER_IP}\n端口: ${port}\n密码: ${password}\nSNI: ${domain}\n\n${link}" > "${LINK_DIR}/trojan_tls_${port}.txt"
        print_success "配置完成"
        cat "${LINK_DIR}/trojan_tls_${port}.txt"
    fi
    
    read -p "按回车键继续..."
}

# Trojan+WebSocket+TLS
configure_trojan_ws_tls() {
    clear
    print_info "配置 Trojan+WebSocket+TLS 节点"
    
    read -p "请输入监听端口 (默认443): " port
    port=${port:-443}
    
    read -p "请输入域名 (默认example.com): " domain
    domain=${domain:-example.com}
    
    local password=$(openssl rand -hex 16)
    local path="/$(openssl rand -hex 4)"
    print_success "密码: ${password}"
    print_success "Path: ${path}"
    
    # 生成证书
    local cert_dir="${CERT_DIR}/${domain}"
    mkdir -p "$cert_dir"
    openssl req -x509 -nodes -newkey rsa:2048 -days 36500 \
        -keyout "${cert_dir}/private.key" \
        -out "${cert_dir}/cert.pem" \
        -subj "/CN=${domain}" >/dev/null 2>&1
    
    local config_file="${CONFIG_DIR}/config.json"
    [[ ! -f "$config_file" ]] && create_base_config
    
    local inbound=$(cat <<EOF
{
  "type": "trojan",
  "tag": "trojan-ws-tls-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [{"password": "${password}"}],
  "transport": {"type": "ws", "path": "${path}"},
  "tls": {
    "enabled": true,
    "server_name": "${domain}",
    "certificate_path": "${cert_dir}/cert.pem",
    "key_path": "${cert_dir}/private.key"
  }
}
EOF
)
    
    jq ".inbounds += [$inbound]" "$config_file" > /tmp/config.tmp && mv /tmp/config.tmp "$config_file"
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        local link="trojan://${password}@${SERVER_IP}:${port}?security=tls&sni=${domain}&type=ws&path=${path}#Trojan-WS-TLS-${SERVER_IP}"
        mkdir -p "${LINK_DIR}"
        echo -e "Trojan+WS+TLS\n服务器: ${SERVER_IP}\n端口: ${port}\n密码: ${password}\nSNI: ${domain}\nPath: ${path}\n\n${link}" > "${LINK_DIR}/trojan_ws_tls_${port}.txt"
        print_success "配置完成"
        cat "${LINK_DIR}/trojan_ws_tls_${port}.txt"
    fi
    
    read -p "按回车键继续..."
}

# Trojan+gRPC+TLS
configure_trojan_grpc_tls() {
    clear
    print_info "配置 Trojan+gRPC+TLS 节点"
    
    read -p "请输入监听端口 (默认443): " port
    port=${port:-443}
    
    read -p "请输入域名 (默认example.com): " domain
    domain=${domain:-example.com}
    
    local password=$(openssl rand -hex 16)
    local service_name="grpc$(openssl rand -hex 4)"
    print_success "密码: ${password}"
    print_success "Service Name: ${service_name}"
    
    # 生成证书
    local cert_dir="${CERT_DIR}/${domain}"
    mkdir -p "$cert_dir"
    openssl req -x509 -nodes -newkey rsa:2048 -days 36500 \
        -keyout "${cert_dir}/private.key" \
        -out "${cert_dir}/cert.pem" \
        -subj "/CN=${domain}" >/dev/null 2>&1
    
    local config_file="${CONFIG_DIR}/config.json"
    [[ ! -f "$config_file" ]] && create_base_config
    
    local inbound=$(cat <<EOF
{
  "type": "trojan",
  "tag": "trojan-grpc-tls-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [{"password": "${password}"}],
  "transport": {"type": "grpc", "service_name": "${service_name}"},
  "tls": {
    "enabled": true,
    "server_name": "${domain}",
    "certificate_path": "${cert_dir}/cert.pem",
    "key_path": "${cert_dir}/private.key"
  }
}
EOF
)
    
    jq ".inbounds += [$inbound]" "$config_file" > /tmp/config.tmp && mv /tmp/config.tmp "$config_file"
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        local link="trojan://${password}@${SERVER_IP}:${port}?security=tls&sni=${domain}&type=grpc&serviceName=${service_name}#Trojan-gRPC-TLS-${SERVER_IP}"
        mkdir -p "${LINK_DIR}"
        echo -e "Trojan+gRPC+TLS\n服务器: ${SERVER_IP}\n端口: ${port}\n密码: ${password}\nSNI: ${domain}\nService: ${service_name}\n\n${link}" > "${LINK_DIR}/trojan_grpc_tls_${port}.txt"
        print_success "配置完成"
        cat "${LINK_DIR}/trojan_grpc_tls_${port}.txt"
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
