#!/bin/bash

# ==================== TUIC V5 协议配置模块 ====================

configure_tuic() {
    clear
    print_info "配置 TUIC V5 节点"
    echo ""
    
    read -p "请输入监听端口 (默认443): " tuic_port
    tuic_port=${tuic_port:-443}
    
    if ss -tuln | grep -q ":$tuic_port "; then
        print_error "端口 $tuic_port 已被占用"
        return 1
    fi
    
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    local password=$(openssl rand -hex 16)
    
    print_success "UUID: ${uuid}"
    print_success "密码: ${password}"
    
    read -p "请输入域名 (默认example.com): " tuic_domain
    tuic_domain=${tuic_domain:-example.com}
    
    # 生成自签证书
    local cert_dir="${CERT_DIR}/${tuic_domain}"
    mkdir -p "$cert_dir"
    openssl req -x509 -nodes -newkey rsa:2048 -days 36500 \
        -keyout "${cert_dir}/private.key" \
        -out "${cert_dir}/cert.pem" \
        -subj "/CN=${tuic_domain}" >/dev/null 2>&1
    
    print_success "证书生成完成"
    
    # 生成配置
    generate_tuic_config "$tuic_port" "$uuid" "$password" "$tuic_domain"
    
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        print_success "TUIC V5 节点配置完成"
        generate_tuic_link "$tuic_port" "$uuid" "$password" "$tuic_domain"
    else
        print_error "服务启动失败"
        return 1
    fi
    
    read -p "按回车键继续..."
}

generate_tuic_config() {
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
    
    local tuic_inbound=$(cat <<EOF
{
  "type": "tuic",
  "tag": "tuic-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [
    {
      "uuid": "${uuid}",
      "password": "${password}"
    }
  ],
  "congestion_control": "bbr",
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
    jq ".inbounds += [$tuic_inbound]" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    print_success "配置已生成"
}

generate_tuic_link() {
    local port=$1
    local uuid=$2
    local password=$3
    local domain=$4
    
    local link="tuic://${uuid}:${password}@${SERVER_IP}:${port}?congestion_control=bbr&alpn=h3&sni=${domain}#TUIC-${SERVER_IP}"
    
    mkdir -p "${LINK_DIR}"
    local link_file="${LINK_DIR}/tuic_${port}.txt"
    
    cat > "$link_file" << EOF
========================================
TUIC V5 节点信息
========================================
服务器: ${SERVER_IP}
端口: ${port}
UUID: ${uuid}
密码: ${password}
SNI: ${domain}
拥塞控制: BBR

分享链接:
${link}

Clash Meta 配置:
proxies:
  - name: TUIC-${SERVER_IP}
    type: tuic
    server: ${SERVER_IP}
    port: ${port}
    uuid: ${uuid}
    password: ${password}
    alpn: [h3]
    sni: ${domain}
    skip-cert-verify: true
    congestion-controller: bbr

========================================
EOF
    
    echo ""
    print_success "节点信息已保存到: ${link_file}"
    echo ""
    cat "$link_file"
}

delete_tuic() {
    local port=$1
    local config_file="${CONFIG_DIR}/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "配置文件不存在"
        return 1
    fi
    
    local temp_file=$(mktemp)
    jq "del(.inbounds[] | select(.tag == \"tuic-in-${port}\"))" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    rm -f "${LINK_DIR}/tuic_${port}.txt"
    
    systemctl restart sing-box
    
    print_success "TUIC 节点已删除"
}
