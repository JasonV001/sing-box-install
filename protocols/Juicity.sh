#!/bin/bash

# ==================== Juicity 协议配置模块 ====================

configure_juicity() {
    clear
    print_info "配置 Juicity 节点"
    echo ""
    
    read -p "请输入监听端口 (默认443): " juicity_port
    juicity_port=${juicity_port:-443}
    
    if ss -tuln | grep -q ":$juicity_port "; then
        print_error "端口 $juicity_port 已被占用"
        return 1
    fi
    
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    local password=$(openssl rand -hex 16)
    
    print_success "UUID: ${uuid}"
    print_success "密码: ${password}"
    
    read -p "请输入域名 (默认example.com): " juicity_domain
    juicity_domain=${juicity_domain:-example.com}
    
    # 生成自签证书
    local cert_dir="${CERT_DIR}/${juicity_domain}"
    mkdir -p "$cert_dir"
    openssl req -x509 -nodes -newkey rsa:2048 -days 36500 \
        -keyout "${cert_dir}/private.key" \
        -out "${cert_dir}/cert.pem" \
        -subj "/CN=${juicity_domain}" >/dev/null 2>&1
    
    print_success "证书生成完成"
    
    # 生成配置
    generate_juicity_config "$juicity_port" "$uuid" "$password" "$juicity_domain"
    
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        print_success "Juicity 节点配置完成"
        generate_juicity_link "$juicity_port" "$uuid" "$password" "$juicity_domain"
    else
        print_error "服务启动失败"
        return 1
    fi
    
    read -p "按回车键继续..."
}

generate_juicity_config() {
    local port=$1
    local uuid=$2
    local password=$3
    local domain=$4
    local cert_dir="${CERT_DIR}/${domain}"
    
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
    
    local juicity_inbound=$(cat <<EOF
{
  "type": "hysteria2",
  "tag": "juicity-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [
    {
      "password": "${password}"
    }
  ],
  "tls": {
    "enabled": true,
    "server_name": "${domain}",
    "alpn": ["h3"],
    "certificate_path": "${cert_dir}/cert.pem",
    "key_path": "${cert_dir}/private.key"
  }
}
EOF
)
    
    local temp_file=$(mktemp)
    jq ".inbounds += [$juicity_inbound]" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    print_success "配置已生成"
}

generate_juicity_link() {
    local port=$1
    local uuid=$2
    local password=$3
    local domain=$4
    
    local link="juicity://${uuid}:${password}@${SERVER_IP}:${port}?sni=${domain}#Juicity-${SERVER_IP}"
    
    mkdir -p "${LINK_DIR}"
    local link_file="${LINK_DIR}/juicity_${port}.txt"
    
    cat > "$link_file" << EOF
========================================
Juicity 节点信息
========================================
服务器: ${SERVER_IP}
端口: ${port}
UUID: ${uuid}
密码: ${password}
SNI: ${domain}

分享链接:
${link}

客户端配置:
{
  "server": "${SERVER_IP}:${port}",
  "uuid": "${uuid}",
  "password": "${password}",
  "sni": "${domain}",
  "allow_insecure": true
}

========================================
EOF
    
    echo ""
    print_success "节点信息已保存到: ${link_file}"
    echo ""
    cat "$link_file"
}

delete_juicity() {
    local port=$1
    local config_file="${CONFIG_DIR}/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "配置文件不存在"
        return 1
    fi
    
    local temp_file=$(mktemp)
    jq "del(.inbounds[] | select(.tag == \"juicity-in-${port}\"))" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    rm -f "${LINK_DIR}/juicity_${port}.txt"
    
    systemctl restart sing-box
    
    print_success "Juicity 节点已删除"
}
