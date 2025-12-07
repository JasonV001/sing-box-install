#!/bin/bash

# ==================== ShadowTLS V3 协议配置模块 ====================

configure_shadowtls() {
    clear
    print_info "配置 ShadowTLS V3 节点"
    echo ""
    
    read -p "请输入监听端口 (默认443): " stls_port
    stls_port=${stls_port:-443}
    
    if ss -tuln | grep -q ":$stls_port "; then
        print_error "端口 $stls_port 已被占用"
        return 1
    fi
    
    # ShadowTLS 密码
    local stls_password=$(openssl rand -hex 16)
    print_success "ShadowTLS 密码: ${stls_password}"
    
    # Shadowsocks 密码
    local ss_password=$(openssl rand -base64 16)
    print_success "Shadowsocks 密码: ${ss_password}"
    
    # 握手服务器
    read -p "请输入握手服务器 (默认cloud.tencent.com): " handshake_server
    handshake_server=${handshake_server:-cloud.tencent.com}
    
    # 生成配置
    generate_shadowtls_config "$stls_port" "$stls_password" "$ss_password" "$handshake_server"
    
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        print_success "ShadowTLS V3 节点配置完成"
        generate_shadowtls_link "$stls_port" "$stls_password" "$ss_password" "$handshake_server"
    else
        print_error "服务启动失败"
        return 1
    fi
    
    read -p "按回车键继续..."
}

generate_shadowtls_config() {
    local port=$1
    local stls_password=$2
    local ss_password=$3
    local handshake_server=$4
    
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
    
    # ShadowTLS inbound
    local stls_inbound=$(cat <<EOF
{
  "type": "shadowtls",
  "tag": "shadowtls-in-${port}",
  "listen": "::",
  "listen_port": ${port},
  "version": 3,
  "users": [
    {
      "password": "${stls_password}"
    }
  ],
  "handshake": {
    "server": "${handshake_server}",
    "server_port": 443
  },
  "detour": "shadowsocks-in-${port}"
}
EOF
)
    
    # Shadowsocks inbound (内部)
    local ss_inbound=$(cat <<EOF
{
  "type": "shadowsocks",
  "tag": "shadowsocks-in-${port}",
  "listen": "127.0.0.1",
  "method": "2022-blake3-aes-128-gcm",
  "password": "${ss_password}"
}
EOF
)
    
    local temp_file=$(mktemp)
    jq ".inbounds += [$stls_inbound, $ss_inbound]" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    print_success "配置已生成"
}

generate_shadowtls_link() {
    local port=$1
    local stls_password=$2
    local ss_password=$3
    local handshake_server=$4
    
    mkdir -p "${LINK_DIR}"
    local link_file="${LINK_DIR}/shadowtls_${port}.txt"
    
    # 生成客户端配置
    local client_config="${LINK_DIR}/shadowtls_client_${port}.json"
    cat > "$client_config" << EOF
{
  "log": {"level": "info"},
  "dns": {"servers": [{"tag": "google", "address": "8.8.8.8"}]},
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "127.0.0.1",
      "listen_port": 1080,
      "sniff": true
    }
  ],
  "outbounds": [
    {
      "type": "shadowsocks",
      "tag": "ss-out",
      "method": "2022-blake3-aes-128-gcm",
      "password": "${ss_password}",
      "detour": "shadowtls-out"
    },
    {
      "type": "shadowtls",
      "tag": "shadowtls-out",
      "server": "${SERVER_IP}",
      "server_port": ${port},
      "version": 3,
      "password": "${stls_password}",
      "tls": {
        "enabled": true,
        "server_name": "${handshake_server}",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        }
      }
    }
  ]
}
EOF
    
    cat > "$link_file" << EOF
========================================
ShadowTLS V3 节点信息
========================================
服务器: ${SERVER_IP}
端口: ${port}
ShadowTLS 密码: ${stls_password}
Shadowsocks 密码: ${ss_password}
握手服务器: ${handshake_server}

客户端配置文件:
${client_config}

使用方法:
1. 下载 sing-box 客户端
2. 使用上述配置文件启动
3. 设置系统代理为 127.0.0.1:1080

注意: ShadowTLS 需要使用配置文件，不支持 URI 分享链接

========================================
EOF
    
    echo ""
    print_success "节点信息已保存到: ${link_file}"
    print_success "客户端配置已保存到: ${client_config}"
    echo ""
    cat "$link_file"
}

delete_shadowtls() {
    local port=$1
    local config_file="${CONFIG_DIR}/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "配置文件不存在"
        return 1
    fi
    
    local temp_file=$(mktemp)
    jq "del(.inbounds[] | select(.tag == \"shadowtls-in-${port}\" or .tag == \"shadowsocks-in-${port}\"))" "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    rm -f "${LINK_DIR}/shadowtls_${port}.txt"
    rm -f "${LINK_DIR}/shadowtls_client_${port}.json"
    
    systemctl restart sing-box
    
    print_success "ShadowTLS 节点已删除"
}
