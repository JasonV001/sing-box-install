#!/bin/bash

# ==================== VLESS+Vision+REALITY 协议配置模块 ====================

# 配置 VLESS+Vision+REALITY
configure_vless_reality() {
    clear
    print_info "配置 VLESS+Vision+REALITY 节点"
    echo ""
    
    # 输入端口
    read -p "请输入监听端口 (默认443): " vless_port
    vless_port=${vless_port:-443}
    
    # 检查端口占用
    if ss -tuln | grep -q ":$vless_port "; then
        print_error "端口 $vless_port 已被占用"
        return 1
    fi
    
    # 生成UUID
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    print_success "UUID: ${uuid}"
    
    # 输入伪装域名
    read -p "请输入伪装域名 (默认itunes.apple.com): " reality_sni
    reality_sni=${reality_sni:-itunes.apple.com}
    
    # 生成Reality密钥对
    print_info "生成 Reality 密钥对..."
    local keys=$(sing-box generate reality-keypair 2>/dev/null)
    local private_key=$(echo "$keys" | grep "PrivateKey" | awk '{print $2}')
    local public_key=$(echo "$keys" | grep "PublicKey" | awk '{print $2}')
    
    if [[ -z "$private_key" || -z "$public_key" ]]; then
        print_error "密钥生成失败"
        return 1
    fi
    
    print_success "Private Key: ${private_key}"
    print_success "Public Key: ${public_key}"
    
    # 生成Short ID
    local short_id=$(openssl rand -hex 8)
    print_success "Short ID: ${short_id}"
    
    # 生成配置
    generate_vless_reality_config "$vless_port" "$uuid" "$reality_sni" "$private_key" "$public_key" "$short_id"
    
    # 重启服务
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        print_success "VLESS+Vision+REALITY 节点配置完成"
        
        # 生成分享链接
        generate_vless_reality_link "$vless_port" "$uuid" "$reality_sni" "$public_key" "$short_id"
    else
        print_error "服务启动失败，请检查配置"
        return 1
    fi
    
    read -p "按回车键继续..."
}

# 生成 VLESS+Reality 配置
generate_vless_reality_config() {
    local port=$1
    local uuid=$2
    local sni=$3
    local private_key=$4
    local public_key=$5
    local short_id=$6
    
    local config_file="${CONFIG_DIR}/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ]
}
EOF
    fi
    
    # 构建 VLESS Reality inbound
    local vless_inbound=$(cat <<EOF
{
  "type": "vless",
  "tag": "vless-reality-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [
    {
      "uuid": "${uuid}",
      "flow": "xtls-rprx-vision"
    }
  ],
  "tls": {
    "enabled": true,
    "server_name": "${sni}",
    "reality": {
      "enabled": true,
      "handshake": {
        "server": "${sni}",
        "server_port": 443
      },
      "private_key": "${private_key}",
      "short_id": ["${short_id}"]
    }
  }
}
EOF
)
    
    # 添加到配置
    local temp_file=$(mktemp)
    jq ".inbounds += [$vless_inbound]" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    print_success "配置已生成"
}

# 生成分享链接
generate_vless_reality_link() {
    local port=$1
    local uuid=$2
    local sni=$3
    local public_key=$4
    local short_id=$5
    
    local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp#VLESS-Reality-${SERVER_IP}"
    
    mkdir -p "${LINK_DIR}"
    local link_file="${LINK_DIR}/vless_reality_${port}.txt"
    
    cat > "$link_file" << EOF
========================================
VLESS+Vision+REALITY 节点信息
========================================
服务器: ${SERVER_IP}
端口: ${port}
UUID: ${uuid}
Flow: xtls-rprx-vision
SNI: ${sni}
Public Key: ${public_key}
Short ID: ${short_id}

分享链接:
${link}

Clash Meta 配置:
proxies:
  - name: VLESS-Reality-${SERVER_IP}
    type: vless
    server: ${SERVER_IP}
    port: ${port}
    uuid: ${uuid}
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    servername: ${sni}
    reality-opts:
      public-key: ${public_key}
      short-id: ${short_id}
    client-fingerprint: chrome

V2rayN 配置:
{
  "add": "${SERVER_IP}",
  "port": "${port}",
  "id": "${uuid}",
  "flow": "xtls-rprx-vision",
  "net": "tcp",
  "type": "none",
  "security": "reality",
  "sni": "${sni}",
  "fp": "chrome",
  "pbk": "${public_key}",
  "sid": "${short_id}",
  "ps": "VLESS-Reality-${SERVER_IP}"
}

========================================
EOF
    
    echo ""
    print_success "节点信息已保存到: ${link_file}"
    echo ""
    cat "$link_file"
}

# 删除 VLESS Reality 节点
delete_vless_reality() {
    local port=$1
    local config_file="${CONFIG_DIR}/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "配置文件不存在"
        return 1
    fi
    
    local temp_file=$(mktemp)
    jq "del(.inbounds[] | select(.tag == \"vless-reality-in-${port}\"))" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    rm -f "${LINK_DIR}/vless_reality_${port}.txt"
    
    systemctl restart sing-box
    
    print_success "VLESS+Vision+REALITY 节点已删除"
}
