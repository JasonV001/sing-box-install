#!/bin/bash

# ==================== [协议名称] 协议配置模块 ====================
# 
# 说明: 这是一个协议模块开发模板
# 使用方法:
#   1. 复制此文件并重命名为协议名称，如 VMess-TCP.sh
#   2. 替换所有 [协议名称] 为实际协议名称
#   3. 替换所有 protocol 为实际协议标识符（小写，用下划线）
#   4. 实现各个函数的具体逻辑
#   5. 测试功能是否正常
#
# 必须实现的函数:
#   - configure_protocol()      配置节点
#   - generate_protocol_config() 生成配置
#   - generate_protocol_link()   生成分享链接
#   - delete_protocol()          删除节点

# ==================== 配置函数 ====================
configure_protocol() {
    clear
    print_info "配置 [协议名称] 节点"
    echo ""
    
    # ========== 步骤1: 输入参数 ==========
    
    # 端口配置
    read -p "请输入监听端口 (默认443): " protocol_port
    protocol_port=${protocol_port:-443}
    
    # 检查端口占用
    if ss -tuln | grep -q ":$protocol_port "; then
        print_error "端口 $protocol_port 已被占用"
        return 1
    fi
    
    # UUID/密码配置（根据协议选择）
    # 示例1: UUID
    # local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    # print_success "UUID: ${uuid}"
    
    # 示例2: 密码
    # local password=$(openssl rand -hex 16)
    # print_success "密码: ${password}"
    
    # 域名配置（如果需要）
    # read -p "请输入域名 (默认example.com): " protocol_domain
    # protocol_domain=${protocol_domain:-example.com}
    
    # 其他参数...
    
    # ========== 步骤2: 生成必要的文件 ==========
    
    # 如果需要证书
    # generate_self_signed_cert "$protocol_domain"
    
    # 如果需要密钥对
    # generate_keypair
    
    # ========== 步骤3: 生成配置 ==========
    
    generate_protocol_config "$protocol_port" # 传递必要的参数
    
    # ========== 步骤4: 重启服务 ==========
    
    systemctl restart sing-box
    
    # ========== 步骤5: 检查服务状态并生成链接 ==========
    
    if systemctl is-active --quiet sing-box; then
        print_success "[协议名称] 节点配置完成"
        
        # 生成分享链接
        generate_protocol_link "$protocol_port" # 传递必要的参数
    else
        print_error "服务启动失败，请检查配置"
        echo ""
        echo "查看错误日志:"
        journalctl -u sing-box -n 20 --no-pager
        return 1
    fi
    
    echo ""
    read -p "按回车键继续..."
}

# ==================== 生成配置函数 ====================
generate_protocol_config() {
    local port=$1
    # 其他参数...
    
    local config_file="${CONFIG_DIR}/config.json"
    
    # ========== 步骤1: 确保基础配置存在 ==========
    
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
    
    # ========== 步骤2: 构建 inbound JSON ==========
    
    # 根据协议类型构建不同的 inbound
    # 以下是几个常见协议的示例:
    
    # 示例1: VLESS (无TLS)
    # local protocol_inbound=$(cat <<EOF
# {
#   "type": "vless",
#   "tag": "vless-in-${port}",
#   "listen": "::",
#   "listen_port": ${port},
#   "users": [
#     {
#       "uuid": "${uuid}",
#       "flow": ""
#     }
#   ]
# }
# EOF
# )
    
    # 示例2: VLESS (带TLS)
    # local protocol_inbound=$(cat <<EOF
# {
#   "type": "vless",
#   "tag": "vless-tls-in-${port}",
#   "listen": "::",
#   "listen_port": ${port},
#   "users": [
#     {
#       "uuid": "${uuid}"
#     }
#   ],
#   "tls": {
#     "enabled": true,
#     "server_name": "${domain}",
#     "certificate_path": "${CERT_DIR}/${domain}/cert.pem",
#     "key_path": "${CERT_DIR}/${domain}/private.key"
#   }
# }
# EOF
# )
    
    # 示例3: VMess (WebSocket)
    # local protocol_inbound=$(cat <<EOF
# {
#   "type": "vmess",
#   "tag": "vmess-ws-in-${port}",
#   "listen": "::",
#   "listen_port": ${port},
#   "users": [
#     {
#       "uuid": "${uuid}",
#       "alterId": 0
#     }
#   ],
#   "transport": {
#     "type": "ws",
#     "path": "/${path}"
#   }
# }
# EOF
# )
    
    # 示例4: Trojan
    # local protocol_inbound=$(cat <<EOF
# {
#   "type": "trojan",
#   "tag": "trojan-in-${port}",
#   "listen": "::",
#   "listen_port": ${port},
#   "users": [
#     {
#       "password": "${password}"
#     }
#   ],
#   "tls": {
#     "enabled": true,
#     "server_name": "${domain}",
#     "certificate_path": "${CERT_DIR}/${domain}/cert.pem",
#     "key_path": "${CERT_DIR}/${domain}/private.key"
#   }
# }
# EOF
# )
    
    # TODO: 在这里实现你的协议 inbound JSON
    local protocol_inbound=$(cat <<EOF
{
  "type": "协议类型",
  "tag": "protocol-in-${port}",
  "listen": "::",
  "listen_port": ${port}
}
EOF
)
    
    # ========== 步骤3: 添加到配置文件 ==========
    
    local temp_file=$(mktemp)
    jq ".inbounds += [$protocol_inbound]" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    print_success "配置已生成"
}

# ==================== 生成分享链接函数 ====================
generate_protocol_link() {
    local port=$1
    # 其他参数...
    
    # ========== 步骤1: 构建分享链接 ==========
    
    # 不同协议的链接格式不同，以下是几个示例:
    
    # 示例1: VLESS
    # local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&security=none&type=tcp#VLESS-${SERVER_IP}"
    
    # 示例2: VLESS (WebSocket)
    # local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&security=none&type=ws&path=${path}#VLESS-WS-${SERVER_IP}"
    
    # 示例3: VMess
    # local vmess_json=$(cat <<EOF
# {
#   "v": "2",
#   "ps": "VMess-${SERVER_IP}",
#   "add": "${SERVER_IP}",
#   "port": "${port}",
#   "id": "${uuid}",
#   "aid": "0",
#   "net": "tcp",
#   "type": "none",
#   "host": "",
#   "path": "",
#   "tls": ""
# }
# EOF
# )
    # local link="vmess://$(echo -n "$vmess_json" | base64 -w 0)"
    
    # 示例4: Trojan
    # local link="trojan://${password}@${SERVER_IP}:${port}?security=tls&sni=${domain}#Trojan-${SERVER_IP}"
    
    # 示例5: Hysteria2
    # local link="hysteria2://${password}@${SERVER_IP}:${port}?insecure=1&sni=${domain}#Hysteria2-${SERVER_IP}"
    
    # TODO: 在这里实现你的协议分享链接
    local link="protocol://${SERVER_IP}:${port}#Protocol-${SERVER_IP}"
    
    # ========== 步骤2: 创建链接文件 ==========
    
    mkdir -p "${LINK_DIR}"
    local link_file="${LINK_DIR}/protocol_${port}.txt"
    
    cat > "$link_file" << EOF
========================================
[协议名称] 节点信息
========================================
服务器: ${SERVER_IP}
端口: ${port}

分享链接:
${link}

EOF
    
    # ========== 步骤3: 添加 Clash 配置（可选） ==========
    
    # 示例: VLESS
    # cat >> "$link_file" << EOF
# Clash Meta 配置:
# proxies:
#   - name: VLESS-${SERVER_IP}
#     type: vless
#     server: ${SERVER_IP}
#     port: ${port}
#     uuid: ${uuid}
#     network: tcp
#     udp: true
# EOF
    
    # 示例: VMess
    # cat >> "$link_file" << EOF
# Clash 配置:
# proxies:
#   - name: VMess-${SERVER_IP}
#     type: vmess
#     server: ${SERVER_IP}
#     port: ${port}
#     uuid: ${uuid}
#     alterId: 0
#     cipher: auto
# EOF
    
    # 示例: Trojan
    # cat >> "$link_file" << EOF
# Clash 配置:
# proxies:
#   - name: Trojan-${SERVER_IP}
#     type: trojan
#     server: ${SERVER_IP}
#     port: ${port}
#     password: ${password}
#     sni: ${domain}
# EOF
    
    # TODO: 在这里添加你的协议 Clash 配置
    cat >> "$link_file" << EOF
Clash 配置:
proxies:
  - name: Protocol-${SERVER_IP}
    type: protocol
    server: ${SERVER_IP}
    port: ${port}

EOF
    
    # ========== 步骤4: 添加其他客户端配置（可选） ==========
    
    cat >> "$link_file" << EOF
========================================
EOF
    
    # ========== 步骤5: 显示信息 ==========
    
    echo ""
    print_success "节点信息已保存到: ${link_file}"
    echo ""
    cat "$link_file"
}

# ==================== 删除节点函数 ====================
delete_protocol() {
    local port=$1
    local config_file="${CONFIG_DIR}/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "配置文件不存在"
        return 1
    fi
    
    # 删除对应的 inbound
    local temp_file=$(mktemp)
    jq "del(.inbounds[] | select(.tag == \"protocol-in-${port}\"))" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    # 删除链接文件
    rm -f "${LINK_DIR}/protocol_${port}.txt"
    
    # 删除证书文件（如果有）
    # rm -rf "${CERT_DIR}/${domain}"
    
    # 重启服务
    systemctl restart sing-box
    
    print_success "[协议名称] 节点已删除"
}

# ==================== 辅助函数 ====================

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

# 生成密钥对（如 Reality）
generate_keypair() {
    print_info "生成密钥对..."
    
    local keys=$(sing-box generate reality-keypair 2>/dev/null)
    local private_key=$(echo "$keys" | grep "PrivateKey" | awk '{print $2}')
    local public_key=$(echo "$keys" | grep "PublicKey" | awk '{print $2}')
    
    if [[ -z "$private_key" || -z "$public_key" ]]; then
        print_error "密钥生成失败"
        return 1
    fi
    
    print_success "Private Key: ${private_key}"
    print_success "Public Key: ${public_key}"
    
    # 返回密钥（通过全局变量或其他方式）
    PROTOCOL_PRIVATE_KEY="$private_key"
    PROTOCOL_PUBLIC_KEY="$public_key"
}

# ==================== 开发提示 ====================
#
# 1. 参考 Sing-box 官方文档了解协议配置格式:
#    https://sing-box.sagernet.org/configuration/inbound/
#
# 2. 参考已完成的协议模块:
#    - protocols/SOCKS.sh
#    - protocols/Hysteria2.sh
#    - protocols/VLESS-Vision-REALITY.sh
#
# 3. 测试步骤:
#    a. 配置节点
#    b. 检查配置文件是否正确
#    c. 检查服务是否正常启动
#    d. 使用客户端测试连接
#    e. 检查分享链接是否正确
#
# 4. 常见问题:
#    - JSON 格式错误: 使用 jq 验证
#    - 端口被占用: 检查 ss -tuln
#    - 服务启动失败: 查看 journalctl -u sing-box
#    - 证书问题: 检查证书路径和权限
#
# 5. 调试技巧:
#    - 使用 set -x 开启调试模式
#    - 使用 echo 输出中间变量
#    - 使用 jq '.' 格式化 JSON
#    - 使用 sing-box check 验证配置
#
# ==================== 结束 ====================
