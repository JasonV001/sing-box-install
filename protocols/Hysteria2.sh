#!/bin/bash

# ==================== Hysteria2 协议配置模块 ====================

# 配置 Hysteria2
configure_hysteria2() {
    clear
    print_info "配置 Hysteria2 节点"
    echo ""
    
    # 输入端口
    read -p "请输入监听端口 (默认443): " hy2_port
    hy2_port=${hy2_port:-443}
    
    # 检查端口占用
    if ss -tuln | grep -q ":$hy2_port "; then
        print_error "端口 $hy2_port 已被占用"
        return 1
    fi
    
    # 生成密码
    local hy2_password=$(openssl rand -hex 16)
    print_success "生成密码: ${hy2_password}"
    
    # 输入伪装域名
    read -p "请输入伪装域名 (默认bing.com): " hy2_sni
    hy2_sni=${hy2_sni:-bing.com}
    
    # 生成自签证书
    generate_self_signed_cert "$hy2_sni"
    
    # 生成配置
    generate_hysteria2_config "$hy2_port" "$hy2_password" "$hy2_sni"
    
    # 重启服务
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        print_success "Hysteria2 节点配置完成"
        
        # 生成分享链接
        generate_hysteria2_link "$hy2_port" "$hy2_password" "$hy2_sni"
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

# 生成 Hysteria2 配置
generate_hysteria2_config() {
    local port=$1
    local password=$2
    local sni=$3
    local cert_dir="${CERT_DIR}/${sni}"
    
    # 读取现有配置
    local config_file="${CONFIG_DIR}/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        # 创建基础配置
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
    
    # 添加 Hysteria2 inbound
    local hy2_inbound=$(cat <<EOF
{
  "type": "hysteria2",
  "tag": "hy2-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [
    {
      "password": "${password}"
    }
  ],
  "tls": {
    "enabled": true,
    "alpn": ["h3"],
    "server_name": "${sni}",
    "certificate_path": "${cert_dir}/cert.pem",
    "key_path": "${cert_dir}/private.key"
  }
}
EOF
)
    
    # 使用jq添加到配置
    local temp_file=$(mktemp)
    jq ".inbounds += [$hy2_inbound]" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    print_success "配置已生成"
}

# 生成分享链接
generate_hysteria2_link() {
    local port=$1
    local password=$2
    local sni=$3
    
    local link="hysteria2://${password}@${SERVER_IP}:${port}?insecure=1&sni=${sni}#Hysteria2-${SERVER_IP}"
    
    mkdir -p "${LINK_DIR}"
    local link_file="${LINK_DIR}/hysteria2_${port}.txt"
    
    cat > "$link_file" << EOF
========================================
Hysteria2 节点信息
========================================
服务器: ${SERVER_IP}
端口: ${port}
密码: ${password}
SNI: ${sni}

分享链接:
${link}

Clash 配置:
proxies:
  - name: Hysteria2-${SERVER_IP}
    type: hysteria2
    server: ${SERVER_IP}
    port: ${port}
    password: ${password}
    sni: ${sni}
    skip-cert-verify: true

========================================
EOF
    
    echo ""
    print_success "节点信息已保存到: ${link_file}"
    echo ""
    cat "$link_file"
}

# 删除 Hysteria2 节点
delete_hysteria2() {
    local port=$1
    local config_file="${CONFIG_DIR}/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "配置文件不存在"
        return 1
    fi
    
    # 删除对应的inbound
    local temp_file=$(mktemp)
    jq "del(.inbounds[] | select(.tag == \"hy2-in-${port}\"))" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    # 删除链接文件
    rm -f "${LINK_DIR}/hysteria2_${port}.txt"
    
    # 重启服务
    systemctl restart sing-box
    
    print_success "Hysteria2 节点已删除"
}
