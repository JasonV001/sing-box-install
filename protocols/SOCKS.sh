#!/bin/bash

# ==================== SOCKS 协议配置模块 ====================

# 配置 SOCKS
configure_socks() {
    clear
    print_info "配置 SOCKS5 节点"
    echo ""
    
    # 输入端口
    read -p "请输入监听端口 (默认1080): " socks_port
    socks_port=${socks_port:-1080}
    
    # 检查端口占用
    if ss -tuln | grep -q ":$socks_port "; then
        print_error "端口 $socks_port 已被占用"
        return 1
    fi
    
    # 是否启用认证
    read -p "是否启用用户认证? [Y/n]: " enable_auth
    enable_auth=${enable_auth:-Y}
    
    local username=""
    local password=""
    
    if [[ "$enable_auth" =~ ^[Yy]$ ]]; then
        read -p "请输入用户名 (默认随机生成): " username
        if [[ -z "$username" ]]; then
            username="user_$(openssl rand -hex 4)"
        fi
        
        read -p "请输入密码 (默认随机生成): " password
        if [[ -z "$password" ]]; then
            password=$(openssl rand -hex 16)
        fi
        
        print_success "用户名: ${username}"
        print_success "密码: ${password}"
    fi
    
    # 生成配置
    generate_socks_config "$socks_port" "$username" "$password"
    
    # 重启服务
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        print_success "SOCKS5 节点配置完成"
        
        # 生成分享链接
        generate_socks_link "$socks_port" "$username" "$password"
    else
        print_error "服务启动失败，请检查配置"
        return 1
    fi
    
    read -p "按回车键继续..."
}

# 生成 SOCKS 配置
generate_socks_config() {
    local port=$1
    local username=$2
    local password=$3
    
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
    
    # 构建 SOCKS inbound
    local socks_inbound
    if [[ -n "$username" && -n "$password" ]]; then
        socks_inbound=$(cat <<EOF
{
  "type": "socks",
  "tag": "socks-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [
    {
      "username": "${username}",
      "password": "${password}"
    }
  ]
}
EOF
)
    else
        socks_inbound=$(cat <<EOF
{
  "type": "socks",
  "tag": "socks-in-${port}",
  "listen": "::",
  "listen_port": ${port}
}
EOF
)
    fi
    
    # 添加到配置
    local temp_file=$(mktemp)
    jq ".inbounds += [$socks_inbound]" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    print_success "配置已生成"
}

# 生成分享链接
generate_socks_link() {
    local port=$1
    local username=$2
    local password=$3
    
    local link
    if [[ -n "$username" && -n "$password" ]]; then
        link="socks5://${username}:${password}@${SERVER_IP}:${port}#SOCKS5-${SERVER_IP}"
    else
        link="socks5://${SERVER_IP}:${port}#SOCKS5-${SERVER_IP}"
    fi
    
    mkdir -p "${LINK_DIR}"
    local link_file="${LINK_DIR}/socks_${port}.txt"
    
    cat > "$link_file" << EOF
========================================
SOCKS5 节点信息
========================================
服务器: ${SERVER_IP}
端口: ${port}
EOF
    
    if [[ -n "$username" && -n "$password" ]]; then
        cat >> "$link_file" << EOF
用户名: ${username}
密码: ${password}
EOF
    else
        echo "认证: 无" >> "$link_file"
    fi
    
    cat >> "$link_file" << EOF

分享链接:
${link}

Clash 配置:
proxies:
  - name: SOCKS5-${SERVER_IP}
    type: socks5
    server: ${SERVER_IP}
    port: ${port}
EOF
    
    if [[ -n "$username" && -n "$password" ]]; then
        cat >> "$link_file" << EOF
    username: ${username}
    password: ${password}
EOF
    fi
    
    cat >> "$link_file" << EOF

========================================
EOF
    
    echo ""
    print_success "节点信息已保存到: ${link_file}"
    echo ""
    cat "$link_file"
}

# 删除 SOCKS 节点
delete_socks() {
    local port=$1
    local config_file="${CONFIG_DIR}/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "配置文件不存在"
        return 1
    fi
    
    local temp_file=$(mktemp)
    jq "del(.inbounds[] | select(.tag == \"socks-in-${port}\"))" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    rm -f "${LINK_DIR}/socks_${port}.txt"
    
    systemctl restart sing-box
    
    print_success "SOCKS5 节点已删除"
}
