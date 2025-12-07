#!/bin/bash

# ==================== VLESS 系列协议配置模块 ====================
# 支持的变体:
# 1. VLESS+TCP
# 2. VLESS+WebSocket  
# 3. VLESS+gRPC
# 4. VLESS+HTTPUpgrade
# 5. VLESS+Vision+REALITY
# 6. VLESS+H2C+REALITY
# 7. VLESS+gRPC+REALITY

# 主配置函数
configure_vless() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    VLESS 协议配置                         ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${PURPLE}【基础传输】${NC}"
    echo -e "    ${GREEN}1.${NC}  VLESS+TCP          ${YELLOW}(直连)${NC}"
    echo -e "    ${GREEN}2.${NC}  VLESS+WebSocket    ${YELLOW}(WS - 推荐)${NC}"
    echo -e "    ${GREEN}3.${NC}  VLESS+gRPC         ${YELLOW}(HTTP/2)${NC}"
    echo -e "    ${GREEN}4.${NC}  VLESS+HTTPUpgrade  ${YELLOW}(HTTP 升级)${NC}"
    echo ""
    echo -e "  ${PURPLE}【REALITY 协议】${NC}"
    echo -e "    ${GREEN}5.${NC}  VLESS+Vision+REALITY    ${YELLOW}(最新 - 推荐)${NC}"
    echo -e "    ${GREEN}6.${NC}  VLESS+H2C+REALITY       ${YELLOW}(HTTP/2)${NC}"
    echo -e "    ${GREEN}7.${NC}  VLESS+gRPC+REALITY      ${YELLOW}(gRPC)${NC}"
    echo ""
    echo -e "    ${GREEN}0.${NC}  返回"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    
    read -p "请选择 VLESS 变体 [0-7]: " vless_type
    
    case $vless_type in
        1) configure_vless_tcp ;;
        2) configure_vless_ws ;;
        3) configure_vless_grpc ;;
        4) configure_vless_httpupgrade ;;
        5) configure_vless_vision_reality ;;
        6) configure_vless_h2c_reality ;;
        7) configure_vless_grpc_reality ;;
        0) return ;;
        *) print_error "无效的选择"; sleep 2; configure_vless ;;
    esac
}


# ==================== VLESS+TCP ====================
configure_vless_tcp() {
    clear
    print_info "配置 VLESS+TCP 节点"
    echo ""
    
    read -p "请输入监听端口 (默认443): " port
    port=${port:-443}
    
    if ss -tuln | grep -q ":$port "; then
        print_error "端口 $port 已被占用"
        return 1
    fi
    
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    print_success "UUID: ${uuid}"
    
    generate_vless_tcp_config "$port" "$uuid"
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        print_success "VLESS+TCP 节点配置完成"
        generate_vless_tcp_link "$port" "$uuid"
    else
        print_error "服务启动失败"
        return 1
    fi
    
    read -p "按回车键继续..."
}

generate_vless_tcp_config() {
    local port=$1
    local uuid=$2
    local config_file="${CONFIG_DIR}/config.json"
    
    [[ ! -f "$config_file" ]] && create_base_config
    
    local inbound=$(cat <<EOF
{
  "type": "vless",
  "tag": "vless-tcp-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [{"uuid": "${uuid}"}]
}
EOF
)
    
    local temp_file=$(mktemp)
    jq ".inbounds += [$inbound]" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    print_success "配置已生成"
}

generate_vless_tcp_link() {
    local port=$1
    local uuid=$2
    local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&type=tcp#VLESS-TCP-${SERVER_IP}"
    
    mkdir -p "${LINK_DIR}"
    cat > "${LINK_DIR}/vless_tcp_${port}.txt" << EOF
========================================
VLESS+TCP 节点信息
========================================
服务器: ${SERVER_IP}
端口: ${port}
UUID: ${uuid}

分享链接:
${link}

Clash Meta 配置:
proxies:
  - name: VLESS-TCP-${SERVER_IP}
    type: vless
    server: ${SERVER_IP}
    port: ${port}
    uuid: ${uuid}
    network: tcp
    udp: true
========================================
EOF
    
    print_success "节点信息已保存"
    cat "${LINK_DIR}/vless_tcp_${port}.txt"
}


# ==================== VLESS+WebSocket ====================
configure_vless_ws() {
    clear
    print_info "配置 VLESS+WebSocket 节点"
    
    read -p "请输入监听端口 (默认443): " port
    port=${port:-443}
    
    if ss -tuln | grep -q ":$port "; then
        print_error "端口 $port 已被占用"
        return 1
    fi
    
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    local path="/$(openssl rand -hex 4)"
    print_success "UUID: ${uuid}"
    print_success "Path: ${path}"
    
    generate_vless_ws_config "$port" "$uuid" "$path"
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        print_success "VLESS+WebSocket 节点配置完成"
        generate_vless_ws_link "$port" "$uuid" "$path"
    fi
    
    read -p "按回车键继续..."
}

generate_vless_ws_config() {
    local port=$1
    local uuid=$2
    local path=$3
    local config_file="${CONFIG_DIR}/config.json"
    
    [[ ! -f "$config_file" ]] && create_base_config
    
    local inbound=$(cat <<EOF
{
  "type": "vless",
  "tag": "vless-ws-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [{"uuid": "${uuid}"}],
  "transport": {
    "type": "ws",
    "path": "${path}"
  }
}
EOF
)
    
    jq ".inbounds += [$inbound]" "$config_file" > /tmp/config.tmp && mv /tmp/config.tmp "$config_file"
    print_success "配置已生成"
}

generate_vless_ws_link() {
    local port=$1
    local uuid=$2
    local path=$3
    local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&type=ws&path=${path}#VLESS-WS-${SERVER_IP}"
    
    mkdir -p "${LINK_DIR}"
    cat > "${LINK_DIR}/vless_ws_${port}.txt" << EOF
========================================
VLESS+WebSocket 节点信息
========================================
服务器: ${SERVER_IP}
端口: ${port}
UUID: ${uuid}
Path: ${path}

分享链接:
${link}
========================================
EOF
    
    cat "${LINK_DIR}/vless_ws_${port}.txt"
}

# ==================== VLESS+HTTPUpgrade ====================
configure_vless_httpupgrade() {
    clear
    print_info "配置 VLESS+HTTPUpgrade 节点"
    
    read -p "请输入监听端口 (默认443): " port
    port=${port:-443}
    
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    local path="/$(openssl rand -hex 4)"
    print_success "UUID: ${uuid}"
    print_success "Path: ${path}"
    
    generate_vless_httpupgrade_config "$port" "$uuid" "$path"
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        print_success "VLESS+HTTPUpgrade 节点配置完成"
        generate_vless_httpupgrade_link "$port" "$uuid" "$path"
    fi
    
    read -p "按回车键继续..."
}

generate_vless_httpupgrade_config() {
    local port=$1
    local uuid=$2
    local path=$3
    local config_file="${CONFIG_DIR}/config.json"
    
    [[ ! -f "$config_file" ]] && create_base_config
    
    local inbound=$(cat <<EOF
{
  "type": "vless",
  "tag": "vless-httpupgrade-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [{"uuid": "${uuid}"}],
  "transport": {
    "type": "httpupgrade",
    "path": "${path}"
  }
}
EOF
)
    
    jq ".inbounds += [$inbound]" "$config_file" > /tmp/config.tmp && mv /tmp/config.tmp "$config_file"
}

generate_vless_httpupgrade_link() {
    local port=$1
    local uuid=$2
    local path=$3
    local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&type=httpupgrade&path=${path}#VLESS-HTTPUpgrade-${SERVER_IP}"
    
    mkdir -p "${LINK_DIR}"
    cat > "${LINK_DIR}/vless_httpupgrade_${port}.txt" << EOF
========================================
VLESS+HTTPUpgrade 节点信息
========================================
服务器: ${SERVER_IP}
端口: ${port}
UUID: ${uuid}
Path: ${path}

分享链接:
${link}
========================================
EOF
    
    cat "${LINK_DIR}/vless_httpupgrade_${port}.txt"
}

# ==================== VLESS+gRPC ====================
configure_vless_grpc() {
    clear
    print_info "配置 VLESS+gRPC 节点"
    
    read -p "请输入监听端口 (默认443): " port
    port=${port:-443}
    
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    local service_name="grpc$(openssl rand -hex 4)"
    print_success "UUID: ${uuid}"
    print_success "Service Name: ${service_name}"
    
    generate_vless_grpc_config "$port" "$uuid" "$service_name"
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        print_success "VLESS+gRPC 节点配置完成"
        generate_vless_grpc_link "$port" "$uuid" "$service_name"
    fi
    
    read -p "按回车键继续..."
}

generate_vless_grpc_config() {
    local port=$1
    local uuid=$2
    local service_name=$3
    local config_file="${CONFIG_DIR}/config.json"
    
    [[ ! -f "$config_file" ]] && create_base_config
    
    local inbound=$(cat <<EOF
{
  "type": "vless",
  "tag": "vless-grpc-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [{"uuid": "${uuid}"}],
  "transport": {
    "type": "grpc",
    "service_name": "${service_name}"
  }
}
EOF
)
    
    jq ".inbounds += [$inbound]" "$config_file" > /tmp/config.tmp && mv /tmp/config.tmp "$config_file"
}

generate_vless_grpc_link() {
    local port=$1
    local uuid=$2
    local service_name=$3
    local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&type=grpc&serviceName=${service_name}#VLESS-gRPC-${SERVER_IP}"
    
    mkdir -p "${LINK_DIR}"
    cat > "${LINK_DIR}/vless_grpc_${port}.txt" << EOF
========================================
VLESS+gRPC 节点信息
========================================
服务器: ${SERVER_IP}
端口: ${port}
UUID: ${uuid}
Service Name: ${service_name}

分享链接:
${link}
========================================
EOF
    
    cat "${LINK_DIR}/vless_grpc_${port}.txt"
}

# ==================== VLESS+Vision+REALITY ====================
configure_vless_vision_reality() {
    clear
    print_info "配置 VLESS+Vision+REALITY 节点"
    echo ""
    
    read -p "请输入监听端口 (默认443): " port
    port=${port:-443}
    
    if ss -tuln | grep -q ":$port "; then
        print_error "端口 $port 已被占用"
        return 1
    fi
    
    read -p "请输入目标域名 (默认www.apple.com): " dest_domain
    dest_domain=${dest_domain:-www.apple.com}
    
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    
    # 生成Reality密钥对
    print_info "生成 Reality 密钥对..."
    local keys=$(sing-box generate reality-keypair 2>/dev/null)
    local private_key=$(echo "$keys" | grep "PrivateKey" | awk '{print $2}')
    local public_key=$(echo "$keys" | grep "PublicKey" | awk '{print $2}')
    
    if [[ -z "$private_key" || -z "$public_key" ]]; then
        print_error "密钥生成失败,请确保 sing-box 版本支持 REALITY"
        return 1
    fi
    
    local short_id=$(openssl rand -hex 8)
    
    print_success "UUID: ${uuid}"
    print_success "Public Key: ${public_key}"
    print_success "Short ID: ${short_id}"
    
    generate_vless_vision_reality_config "$port" "$uuid" "$dest_domain" "$private_key" "$short_id"
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        print_success "VLESS+Vision+REALITY 节点配置完成"
        generate_vless_vision_reality_link "$port" "$uuid" "$dest_domain" "$public_key" "$short_id"
    else
        print_error "服务启动失败"
        return 1
    fi
    
    read -p "按回车键继续..."
}

generate_vless_vision_reality_config() {
    local port=$1
    local uuid=$2
    local dest=$3
    local private_key=$4
    local short_id=$5
    local config_file="${CONFIG_DIR}/config.json"
    
    [[ ! -f "$config_file" ]] && create_base_config
    
    local inbound=$(cat <<EOF
{
  "type": "vless",
  "tag": "vless-vision-reality-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [{"uuid": "${uuid}", "flow": "xtls-rprx-vision"}],
  "tls": {
    "enabled": true,
    "server_name": "${dest}",
    "reality": {
      "enabled": true,
      "handshake": {
        "server": "${dest}",
        "server_port": 443
      },
      "private_key": "${private_key}",
      "short_id": ["${short_id}"]
    }
  }
}
EOF
)
    
    jq ".inbounds += [$inbound]" "$config_file" > /tmp/config.tmp && mv /tmp/config.tmp "$config_file"
}

generate_vless_vision_reality_link() {
    local port=$1
    local uuid=$2
    local dest=$3
    local public_key=$4
    local short_id=$5
    local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${dest}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp#VLESS-Vision-REALITY-${SERVER_IP}"
    
    mkdir -p "${LINK_DIR}"
    cat > "${LINK_DIR}/vless_vision_reality_${port}.txt" << EOF
========================================
VLESS+Vision+REALITY 节点信息
========================================
服务器: ${SERVER_IP}
端口: ${port}
UUID: ${uuid}
Flow: xtls-rprx-vision
目标域名: ${dest}
Public Key: ${public_key}
Short ID: ${short_id}

分享链接:
${link}

Clash Meta 配置:
proxies:
  - name: VLESS-Vision-REALITY-${SERVER_IP}
    type: vless
    server: ${SERVER_IP}
    port: ${port}
    uuid: ${uuid}
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    servername: ${dest}
    reality-opts:
      public-key: ${public_key}
      short-id: ${short_id}
    client-fingerprint: chrome
========================================
EOF
    
    cat "${LINK_DIR}/vless_vision_reality_${port}.txt"
}

# ==================== VLESS+H2C+REALITY ====================
configure_vless_h2c_reality() {
    clear
    print_info "配置 VLESS+H2C+REALITY 节点"
    
    read -p "请输入监听端口 (默认443): " port
    port=${port:-443}
    
    read -p "请输入目标域名 (默认www.microsoft.com): " dest_domain
    dest_domain=${dest_domain:-www.microsoft.com}
    
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    local private_key=$(sing-box generate reality-keypair | grep "PrivateKey" | awk '{print $2}')
    local public_key=$(sing-box generate reality-keypair | grep "PublicKey" | awk '{print $2}')
    local short_id=$(openssl rand -hex 8)
    
    print_success "UUID: ${uuid}"
    print_success "Public Key: ${public_key}"
    print_success "Short ID: ${short_id}"
    
    generate_vless_h2c_reality_config "$port" "$uuid" "$dest_domain" "$private_key" "$short_id"
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        print_success "VLESS+H2C+REALITY 节点配置完成"
        generate_vless_h2c_reality_link "$port" "$uuid" "$dest_domain" "$public_key" "$short_id"
    fi
    
    read -p "按回车键继续..."
}

generate_vless_h2c_reality_config() {
    local port=$1
    local uuid=$2
    local dest=$3
    local private_key=$4
    local short_id=$5
    local config_file="${CONFIG_DIR}/config.json"
    
    [[ ! -f "$config_file" ]] && create_base_config
    
    local inbound=$(cat <<EOF
{
  "type": "vless",
  "tag": "vless-h2c-reality-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [{"uuid": "${uuid}", "flow": ""}],
  "transport": {"type": "http"},
  "tls": {
    "enabled": true,
    "server_name": "${dest}",
    "reality": {
      "enabled": true,
      "handshake": {
        "server": "${dest}",
        "server_port": 443
      },
      "private_key": "${private_key}",
      "short_id": ["${short_id}"]
    }
  }
}
EOF
)
    
    jq ".inbounds += [$inbound]" "$config_file" > /tmp/config.tmp && mv /tmp/config.tmp "$config_file"
}

generate_vless_h2c_reality_link() {
    local port=$1
    local uuid=$2
    local dest=$3
    local public_key=$4
    local short_id=$5
    local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&flow=&security=reality&sni=${dest}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=http#VLESS-H2C-REALITY-${SERVER_IP}"
    
    mkdir -p "${LINK_DIR}"
    cat > "${LINK_DIR}/vless_h2c_reality_${port}.txt" << EOF
========================================
VLESS+H2C+REALITY 节点信息
========================================
服务器: ${SERVER_IP}
端口: ${port}
UUID: ${uuid}
目标域名: ${dest}
Public Key: ${public_key}
Short ID: ${short_id}

分享链接:
${link}
========================================
EOF
    
    cat "${LINK_DIR}/vless_h2c_reality_${port}.txt"
}

# ==================== VLESS+gRPC+REALITY ====================
configure_vless_grpc_reality() {
    clear
    print_info "配置 VLESS+gRPC+REALITY 节点"
    
    read -p "请输入监听端口 (默认443): " port
    port=${port:-443}
    
    read -p "请输入目标域名 (默认www.microsoft.com): " dest_domain
    dest_domain=${dest_domain:-www.microsoft.com}
    
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    local service_name="grpc$(openssl rand -hex 4)"
    local private_key=$(sing-box generate reality-keypair | grep "PrivateKey" | awk '{print $2}')
    local public_key=$(sing-box generate reality-keypair | grep "PublicKey" | awk '{print $2}')
    local short_id=$(openssl rand -hex 8)
    
    print_success "UUID: ${uuid}"
    print_success "Service Name: ${service_name}"
    print_success "Public Key: ${public_key}"
    print_success "Short ID: ${short_id}"
    
    generate_vless_grpc_reality_config "$port" "$uuid" "$dest_domain" "$service_name" "$private_key" "$short_id"
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        print_success "VLESS+gRPC+REALITY 节点配置完成"
        generate_vless_grpc_reality_link "$port" "$uuid" "$dest_domain" "$service_name" "$public_key" "$short_id"
    fi
    
    read -p "按回车键继续..."
}

generate_vless_grpc_reality_config() {
    local port=$1
    local uuid=$2
    local dest=$3
    local service_name=$4
    local private_key=$5
    local short_id=$6
    local config_file="${CONFIG_DIR}/config.json"
    
    [[ ! -f "$config_file" ]] && create_base_config
    
    local inbound=$(cat <<EOF
{
  "type": "vless",
  "tag": "vless-grpc-reality-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [{"uuid": "${uuid}", "flow": ""}],
  "transport": {
    "type": "grpc",
    "service_name": "${service_name}"
  },
  "tls": {
    "enabled": true,
    "server_name": "${dest}",
    "reality": {
      "enabled": true,
      "handshake": {
        "server": "${dest}",
        "server_port": 443
      },
      "private_key": "${private_key}",
      "short_id": ["${short_id}"]
    }
  }
}
EOF
)
    
    jq ".inbounds += [$inbound]" "$config_file" > /tmp/config.tmp && mv /tmp/config.tmp "$config_file"
}

generate_vless_grpc_reality_link() {
    local port=$1
    local uuid=$2
    local dest=$3
    local service_name=$4
    local public_key=$5
    local short_id=$6
    local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&flow=&security=reality&sni=${dest}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=grpc&serviceName=${service_name}#VLESS-gRPC-REALITY-${SERVER_IP}"
    
    mkdir -p "${LINK_DIR}"
    cat > "${LINK_DIR}/vless_grpc_reality_${port}.txt" << EOF
========================================
VLESS+gRPC+REALITY 节点信息
========================================
服务器: ${SERVER_IP}
端口: ${port}
UUID: ${uuid}
Service Name: ${service_name}
目标域名: ${dest}
Public Key: ${public_key}
Short ID: ${short_id}

分享链接:
${link}
========================================
EOF
    
    cat "${LINK_DIR}/vless_grpc_reality_${port}.txt"
}

# 创建基础配置
create_base_config() {
    cat > "${CONFIG_DIR}/config.json" << 'EOF'
{
  "log": {"level": "info", "timestamp": true},
  "inbounds": [],
  "outbounds": [
    {"type": "direct", "tag": "direct"},
    {"type": "block", "tag": "block"}
  ]
}
EOF
}
