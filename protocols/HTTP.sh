#!/bin/bash

# ==================== HTTP 协议配置模块 ====================

# 配置 HTTP
configure_http() {
    clear
    print_info "配置 HTTP 代理节点"
    echo ""
    
    # 输入端口
    read -p "请输入监听端口 (默认8080): " http_port
    http_port=${http_port:-8080}
    
    # 检查端口占用
    if ss -tuln | grep -q ":$http_port "; then
        print_error "端口 $http_port 已被占用"
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
    generate_http_config "$http_port" "$username" "$password"
    
    # 重启服务
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        print_success "HTTP 代理节点配置完成"
        generate_http_link "$http_port" "$username" "$password"
    else
        print_error "服务启动失败，请检查配置"
        return 1
    fi
    
    read -p "按回车键继续..."
}

# 生成 HTTP 配置
generate_http_config() {
    local port=$1
    local username=$2
    local password=$3
    
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
    
    local http_inbound
    if [[ -n "$username" && -n "$password" ]]; then
        http_inbound=$(cat <<EOF
{
  "type": "http",
  "tag": "http-in-${port}",
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
        http_inbound=$(cat <<EOF
{
  "type": "http",
  "tag": "http-in-${port}",
  "listen": "::",
  "listen_port": ${port}
}
EOF
)
    fi
    
    local temp_file=$(mktemp)
    jq ".inbounds += [$http_inbound]" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    print_success "配置已生成"
}

# 生成分享链接
generate_http_link() {
    local port=$1
    local username=$2
    local password=$3
    
    local link
    if [[ -n "$username" && -n "$password" ]]; then
        link="http://${username}:${password}@${SERVER_IP}:${port}"
    else
        link="http://${SERVER_IP}:${port}"
    fi
    
    mkdir -p "${LINK_DIR}"
    local link_file="${LINK_DIR}/http_${port}.txt"
    
    cat > "$link_file" << EOF
========================================
HTTP 代理节点信息
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

代理地址:
${link}

浏览器配置:
HTTP 代理: ${SERVER_IP}
端口: ${port}
EOF
    
    if [[ -n "$username" && -n "$password" ]]; then
        cat >> "$link_file" << EOF
用户名: ${username}
密码: ${password}
EOF
    fi
    
    cat >> "$link_file" << EOF

Clash 配置:
proxies:
  - name: HTTP-${SERVER_IP}
    type: http
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

# 删除 HTTP 节点
delete_http() {
    local port=$1
    local config_file="${CONFIG_DIR}/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "配置文件不存在"
        return 1
    fi
    
    local temp_file=$(mktemp)
    jq "del(.inbounds[] | select(.tag == \"http-in-${port}\"))" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    rm -f "${LINK_DIR}/http_${port}.txt"
    
    systemctl restart sing-box
    
    print_success "HTTP 节点已删除"
}
