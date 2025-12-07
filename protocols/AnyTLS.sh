#!/bin/bash

# ==================== AnyTLS 协议配置模块 ====================

# 配置 AnyTLS
configure_anytls() {
    clear
    print_info "配置 AnyTLS 节点"
    echo ""
    
    # 输入端口
    read -p "请输入监听端口 (默认443): " anytls_port
    anytls_port=${anytls_port:-443}
    
    # 检查端口占用
    if ss -tuln | grep -q ":$anytls_port "; then
        print_error "端口 $anytls_port 已被占用"
        return 1
    fi
    
    # 生成密码
    local password=$(openssl rand -hex 16)
    print_success "密码: ${password}"
    
    # 输入域名
    read -p "请输入域名 (默认example.com): " anytls_domain
    anytls_domain=${anytls_domain:-example.com}
    
    # 生成自签证书
    generate_self_signed_cert "$anytls_domain"
    
    # 生成配置
    generate_anytls_config "$anytls_port" "$password" "$anytls_domain"
    
    # 重启服务
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        print_success "AnyTLS 节点配置完成"
        generate_anytls_link "$anytls_port" "$password" "$anytls_domain"
    else
        print_error "服务启动失败，请检查配置"
        return 1
    fi
    
    read -p "按回车键继续..."
}

# 生成自签证书
generate_self_signed_cert() {
    local domain=$1
    local cert_dir="${CERT_DIR}/${domain}"
    
    mkdir -p "$cert_dir"
    
    print_info "生成自签证书..."
    
    openssl req -x509 -nodes -newkey rsa:2048 -days 36500 \
        -keyout "${cert_dir}/private.key" \
        -out "${cert_dir}/cert.pem" \
        -subj "/C=US/ST=California/L=Los Angeles/O=Example Inc/CN=${domain}" \
        >/dev/null 2>&1
    
    print_success "证书生成完成"
}

# 生成 AnyTLS 配置
generate_anytls_config() {
    local port=$1
    local password=$2
    local domain=$3
    local cert_dir="${CERT_DIR}/${domain}"
    
    local config_file="${CONFIG_DIR}/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << 'EOF'
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
    
    local anytls_inbound=$(cat <<EOF
{
  "type": "anytls",
  "tag": "anytls-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [{"password": "${password}"}],
  "padding_scheme": [],
  "tls": {
    "enabled": true,
    "server_name": "${domain}",
    "certificate_path": "${cert_dir}/cert.pem",
    "key_path": "${cert_dir}/private.key"
  }
}
EOF
)
    
    local temp_file=$(mktemp)
    jq ".inbounds += [$anytls_inbound]" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    print_success "配置已生成"
}

# 生成分享链接
generate_anytls_link() {
    local port=$1
    local password=$2
    local domain=$3
    
    local link="anytls://${password}@${SERVER_IP}:${port}?security=tls&fp=chrome&insecure=1&sni=${domain}&type=tcp#AnyTLS-${SERVER_IP}"
    
    mkdir -p "${LINK_DIR}"
    local link_file="${LINK_DIR}/anytls_${port}.txt"
    
    cat > "$link_file" << EOF
========================================
AnyTLS 节点信息
========================================
服务器: ${SERVER_IP}
端口: ${port}
密码: ${password}
SNI: ${domain}
自签证书: ${domain}

分享链接:
${link}

Clash Meta 配置:
proxies:
  - name: AnyTLS-${SERVER_IP}
    type: anytls
    server: ${SERVER_IP}
    port: ${port}
    password: ${password}
    sni: ${domain}
    skip-cert-verify: true
    client-fingerprint: chrome

========================================
EOF
    
    echo ""
    print_success "节点信息已保存到: ${link_file}"
    echo ""
    cat "$link_file"
}

# 删除 AnyTLS 节点
delete_anytls() {
    local port=$1
    local config_file="${CONFIG_DIR}/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "配置文件不存在"
        return 1
    fi
    
    local temp_file=$(mktemp)
    jq "del(.inbounds[] | select(.tag == \"anytls-in-${port}\"))" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    rm -f "${LINK_DIR}/anytls_${port}.txt"
    
    systemctl restart sing-box
    
    print_success "AnyTLS 节点已删除"
}
