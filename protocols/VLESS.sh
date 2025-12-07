#!/bin/bash

# ==================== VLESS 系列协议配置模块 ====================
# 支持的变体:
# 1. VLESS+TCP
# 2. VLESS+WebSocket  
# 3. VLESS+gRPC
# 4. VLESS+HTTPUpgrade
# 5. VLESS+Vision+REALITY (已在单独文件)
# 6. VLESS+H2C+REALITY
# 7. VLESS+gRPC+REALITY

# 主配置函数
configure_vless() {
    clear
    echo -e "${CYAN}═══════════════════ VLESS 协议配置 ═══════════════════${NC}"
    echo ""
    echo "  ${GREEN}1.${NC}  VLESS+TCP"
    echo "  ${GREEN}2.${NC}  VLESS+WebSocket"
    echo "  ${GREEN}3.${NC}  VLESS+gRPC"
    echo "  ${GREEN}4.${NC}  VLESS+HTTPUpgrade"
    echo "  ${GREEN}5.${NC}  VLESS+H2C+REALITY"
    echo "  ${GREEN}6.${NC}  VLESS+gRPC+REALITY"
    echo "  ${GREEN}0.${NC}  返回"
    echo ""
    
    read -p "请选择 VLESS 变体 [0-6]: " vless_type
    
    case $vless_type in
        1) configure_vless_tcp ;;
        2) configure_vless_ws ;;
        3) configure_vless_grpc ;;
        4) configure_vless_httpupgrade ;;
        5) configure_vless_h2c_reality ;;
        6) configure_vless_grpc_reality ;;
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
