#!/bin/bash

# ==================== Shadowsocks 协议配置模块 ====================

configure_shadowsocks() {
    clear
    print_info "配置 Shadowsocks 节点"
    echo ""
    
    read -p "请输入监听端口 (默认8388): " ss_port
    ss_port=${ss_port:-8388}
    
    if ss -tuln | grep -q ":$ss_port "; then
        print_error "端口 $ss_port 已被占用"
        return 1
    fi
    
    # 选择加密方式
    echo "请选择加密方式:"
    echo "1) 2022-blake3-aes-128-gcm (推荐)"
    echo "2) 2022-blake3-aes-256-gcm"
    echo "3) aes-128-gcm"
    echo "4) aes-256-gcm"
    echo "5) chacha20-ietf-poly1305"
    read -p "请选择 [1-5] (默认1): " method_choice
    method_choice=${method_choice:-1}
    
    case $method_choice in
        1) method="2022-blake3-aes-128-gcm"; pass_len=16 ;;
        2) method="2022-blake3-aes-256-gcm"; pass_len=32 ;;
        3) method="aes-128-gcm"; pass_len=16 ;;
        4) method="aes-256-gcm"; pass_len=32 ;;
        5) method="chacha20-ietf-poly1305"; pass_len=32 ;;
        *) method="2022-blake3-aes-128-gcm"; pass_len=16 ;;
    esac
    
    # 生成密码
    if [[ "$method" =~ ^2022 ]]; then
        password=$(openssl rand -base64 $pass_len)
    else
        password=$(openssl rand -hex $pass_len)
    fi
    
    print_success "加密方式: ${method}"
    print_success "密码: ${password}"
    
    # 生成配置
    generate_shadowsocks_config "$ss_port" "$method" "$password"
    
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        print_success "Shadowsocks 节点配置完成"
        generate_shadowsocks_link "$ss_port" "$method" "$password"
    else
        print_error "服务启动失败"
        return 1
    fi
    
    read -p "按回车键继续..."
}

generate_shadowsocks_config() {
    local port=$1
    local method=$2
    local password=$3
    
    local config_file="${CONFIG_DIR}/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << 'EOF'
{
  "log": {"level": "info", "timestamp": true},
  "inbounds": [],
  "outbounds": [
    {"type": "direct", "tag": "direct"},
    {"type": "block", "tag": "block"}
  ]
}
EOF
    fi
    
    local ss_inbound=$(cat <<EOF
{
  "type": "shadowsocks",
  "tag": "ss-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "method": "${method}",
  "password": "${password}"
}
EOF
)
    
    local temp_file=$(mktemp)
    jq ".inbounds += [$ss_inbound]" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    print_success "配置已生成"
}

generate_shadowsocks_link() {
    local port=$1
    local method=$2
    local password=$3
    
    # 生成 SS URI
    local userinfo=$(echo -n "${method}:${password}" | base64 -w0)
    local link="ss://${userinfo}@${SERVER_IP}:${port}#SS-${SERVER_IP}"
    
    mkdir -p "${LINK_DIR}"
    local link_file="${LINK_DIR}/shadowsocks_${port}.txt"
    
    cat > "$link_file" << EOF
========================================
Shadowsocks 节点信息
========================================
服务器: ${SERVER_IP}
端口: ${port}
加密方式: ${method}
密码: ${password}

分享链接:
${link}

Clash 配置:
proxies:
  - name: SS-${SERVER_IP}
    type: ss
    server: ${SERVER_IP}
    port: ${port}
    cipher: ${method}
    password: ${password}

SIP002 URI:
ss://${userinfo}@${SERVER_IP}:${port}

========================================
EOF
    
    echo ""
    print_success "节点信息已保存到: ${link_file}"
    echo ""
    cat "$link_file"
}

delete_shadowsocks() {
    local port=$1
    local config_file="${CONFIG_DIR}/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "配置文件不存在"
        return 1
    fi
    
    local temp_file=$(mktemp)
    jq "del(.inbounds[] | select(.tag == \"ss-in-${port}\"))" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    rm -f "${LINK_DIR}/shadowsocks_${port}.txt"
    
    systemctl restart sing-box
    
    print_success "Shadowsocks 节点已删除"
}
