#!/bin/bash

# ==================== Cloudflare Argo 隧道配置模块 ====================

ARGO_DIR="/opt/argo"
ARGO_CONFIG="${ARGO_DIR}/config.yml"

# 配置Argo隧道
configure_argo() {
    clear
    echo -e "${CYAN}═══════════════════ Argo 隧道配置 ═══════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC}  安装 Argo 隧道 (Quick Tunnel - 临时域名)"
    echo -e "  ${GREEN}2.${NC}  安装 Argo 隧道 (Token 认证)"
    echo -e "  ${GREEN}3.${NC}  安装 Argo 隧道 (JSON 认证)"
    echo -e "  ${GREEN}4.${NC}  查看 Argo 状态"
    echo -e "  ${GREEN}5.${NC}  刷新域名和节点链接"
    echo -e "  ${GREEN}6.${NC}  重启 Argo 服务"
    echo -e "  ${GREEN}7.${NC}  卸载 Argo 隧道"
    echo -e "  ${GREEN}0.${NC}  返回主菜单"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    
    read -p "请选择操作 [0-7]: " choice
    
    case $choice in
        1) install_argo_quick ;;
        2) install_argo_token ;;
        3) install_argo_json ;;
        4) view_argo_status ;;
        5) refresh_argo_domain ;;
        6) restart_argo ;;
        7) uninstall_argo ;;
        0) return ;;
        *) print_error "无效的选择"; sleep 2; configure_argo ;;
    esac
}

# 安装cloudflared
install_cloudflared() {
    # 检查是否已安装
    if command -v cloudflared &>/dev/null; then
        local version=$(cloudflared --version 2>&1 | head -1 || echo "unknown")
        print_success "cloudflared 已安装 (${version})"
        return 0
    fi
    
    # 检查是否已存在但未在 PATH 中
    if [[ -f "${ARGO_DIR}/cloudflared" ]]; then
        chmod +x "${ARGO_DIR}/cloudflared"
        ln -sf "${ARGO_DIR}/cloudflared" /usr/local/bin/cloudflared
        print_success "cloudflared 已存在，已添加到 PATH"
        return 0
    fi
    
    if [[ -f "/usr/local/bin/cloudflared" ]]; then
        chmod +x /usr/local/bin/cloudflared
        print_success "cloudflared 已存在"
        return 0
    fi
    
    print_info "安装 cloudflared..."
    
    local arch=$(uname -m)
    local download_url
    
    case $arch in
        x86_64|amd64)
            download_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
            ;;
        aarch64|arm64)
            download_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
            ;;
        armv7l)
            download_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm"
            ;;
        i386|i686)
            download_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-386"
            ;;
        *)
            print_error "不支持的架构: $arch"
            return 1
            ;;
    esac
    
    mkdir -p "${ARGO_DIR}"
    print_info "下载 cloudflared..."
    wget -qO "${ARGO_DIR}/cloudflared" "$download_url" || { print_error "下载失败"; return 1; }
    chmod +x "${ARGO_DIR}/cloudflared"
    ln -sf "${ARGO_DIR}/cloudflared" /usr/local/bin/cloudflared
    
    print_success "cloudflared 安装完成"
}

# Quick Tunnel (临时域名)
install_argo_quick() {
    clear
    print_info "安装 Argo Quick Tunnel"
    echo ""
    
    # 检查是否已经安装
    if systemctl is-active --quiet argo-quick; then
        print_warning "检测到 Argo Quick Tunnel 已在运行"
        echo ""
        echo "当前配置:"
        local current_port=$(grep "ExecStart.*--url.*localhost:" /etc/systemd/system/argo-quick.service 2>/dev/null | grep -oP 'localhost:\K[0-9]+')
        if [[ -n "$current_port" ]]; then
            echo "  本地端口: ${current_port}"
        fi
        
        # 尝试获取当前域名
        if [[ -f "${ARGO_DIR}/argo.log" ]]; then
            local current_domain=$(grep -oP 'https://\K[^/]+\.trycloudflare\.com' "${ARGO_DIR}/argo.log" | tail -1)
            if [[ -n "$current_domain" ]]; then
                echo "  临时域名: ${current_domain}"
            fi
        fi
        
        echo ""
        echo "请选择操作:"
        echo "  1. 重新配置（停止并重新安装）"
        echo "  2. 查看状态"
        echo "  3. 刷新域名"
        echo "  0. 返回"
        echo ""
        read -p "请选择 [0-3]: " action_choice
        
        case $action_choice in
            1)
                print_info "停止现有服务..."
                systemctl stop argo-quick
                systemctl disable argo-quick 2>/dev/null
                ;;
            2)
                view_argo_status
                return 0
                ;;
            3)
                refresh_argo_domain
                return 0
                ;;
            0)
                return 0
                ;;
            *)
                print_error "无效的选择"
                sleep 2
                return 1
                ;;
        esac
    elif [[ -f /etc/systemd/system/argo-quick.service ]]; then
        print_warning "检测到 Argo Quick Tunnel 服务文件已存在但未运行"
        read -p "是否重新配置? [Y/n]: " reconfig
        if [[ "$reconfig" =~ ^[Nn]$ ]]; then
            print_info "取消安装"
            sleep 2
            return 0
        fi
        systemctl disable argo-quick 2>/dev/null
    fi
    
    echo ""
    install_cloudflared || return 1
    echo ""
    
    read -p "请输入本地服务端口 (默认443): " local_port
    local_port=${local_port:-443}
    
    read -p "请选择IP版本 [4/6] (默认4): " ip_version
    ip_version=${ip_version:-4}
    
    # 清空旧日志
    > "${ARGO_DIR}/argo.log" 2>/dev/null
    
    # 创建systemd服务
    print_info "创建服务配置..."
    cat > /etc/systemd/system/argo-quick.service << EOF
[Unit]
Description=Cloudflare Argo Quick Tunnel
After=network.target

[Service]
Type=simple
ExecStart=${ARGO_DIR}/cloudflared tunnel --edge-ip-version ${ip_version} --no-autoupdate --url http://localhost:${local_port}
Restart=always
RestartSec=10
StandardOutput=append:${ARGO_DIR}/argo.log
StandardError=append:${ARGO_DIR}/argo.log

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable argo-quick 2>/dev/null
    systemctl start argo-quick
    
    print_success "Argo Quick Tunnel 已启动"
    print_info "等待获取临时域名..."
    
    # 等待服务启动并获取域名（最多等待30秒）
    local temp_domain=""
    local wait_time=0
    local max_wait=30
    
    while [[ -z "$temp_domain" && $wait_time -lt $max_wait ]]; do
        sleep 2
        wait_time=$((wait_time + 2))
        
        # 尝试从日志中获取域名
        if [[ -f "${ARGO_DIR}/argo.log" ]]; then
            temp_domain=$(grep -oP 'https://\K[^/]+\.trycloudflare\.com' "${ARGO_DIR}/argo.log" | tail -1)
        fi
        
        if [[ -z "$temp_domain" ]]; then
            echo -n "."
        fi
    done
    echo ""
    
    if [[ -n "$temp_domain" ]]; then
        print_success "临时域名: ${temp_domain}"
        echo "$temp_domain" > "${ARGO_DIR}/domain.txt"
        
        # 生成节点链接
        generate_argo_node_link "$temp_domain" "$local_port"
        
        # 保存到文件
        mkdir -p "${LINK_DIR}"
        cat > "${LINK_DIR}/argo_quick_${local_port}.txt" << EOF
========================================
Argo Quick Tunnel 信息
========================================
本地端口: ${local_port}
临时域名: ${temp_domain}
完整地址: https://${temp_domain}

节点链接:
$(cat "${LINK_DIR}/argo_node_${local_port}.txt" 2>/dev/null || echo "未生成节点链接")

注意: 临时域名会在重启后变化
日志文件: ${ARGO_DIR}/argo.log

使用方法:
1. 确保本地服务运行在端口 ${local_port}
2. 通过 https://${temp_domain} 访问
3. 使用上方节点链接导入客户端
========================================
EOF
        echo ""
        cat "${LINK_DIR}/argo_quick_${local_port}.txt"
    else
        print_warning "等待超时，未能获取临时域名"
        echo ""
        print_info "可能的原因:"
        echo "  1. cloudflared 服务启动失败"
        echo "  2. 网络连接问题"
        echo "  3. 本地端口 ${local_port} 未运行服务"
        echo ""
        print_info "排查步骤:"
        echo "  1. 查看服务状态: systemctl status argo-quick"
        echo "  2. 查看日志: tail -f ${ARGO_DIR}/argo.log"
        echo "  3. 检查端口: ss -tuln | grep ${local_port}"
        echo ""
        print_info "手动获取域名:"
        echo "  等待几分钟后执行: grep trycloudflare.com ${ARGO_DIR}/argo.log"
        echo ""
        
        # 即使没有域名，也生成一个占位链接
        mkdir -p "${LINK_DIR}"
        cat > "${LINK_DIR}/argo_quick_${local_port}.txt" << EOF
========================================
Argo Quick Tunnel 信息
========================================
本地端口: ${local_port}
状态: 等待获取临时域名

临时域名将在服务启动后显示在日志中
日志文件: ${ARGO_DIR}/argo.log

获取域名命令:
  grep trycloudflare.com ${ARGO_DIR}/argo.log | tail -1

查看服务状态:
  systemctl status argo-quick

查看实时日志:
  tail -f ${ARGO_DIR}/argo.log
========================================
EOF
    fi
    
    echo ""
    read -p "按回车键继续..."
}

# 生成 Argo 节点链接
generate_argo_node_link() {
    local domain=$1
    local local_port=$2
    
    # Argo 隧道说明:
    # - Argo 提供 HTTPS (443端口) 访问
    # - 自动提供 TLS 加密
    # - 使用 WebSocket 传输
    
    # 检查本地端口对应的协议配置
    local config_file="${CONFIG_DIR}/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        print_warning "配置文件不存在，生成通用 VLESS+WS+TLS 节点链接"
        local new_uuid=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null)
        
        # Argo 隧道使用 443 端口，自带 TLS
        local link="vless://${new_uuid}@${domain}:443?encryption=none&security=tls&sni=${domain}&type=ws&host=${domain}&path=%2F#Argo-Port${local_port}"
        echo "$link" > "${LINK_DIR}/argo_node_${local_port}.txt"
        
        print_success "已生成 VLESS+WS+TLS 节点链接"
        print_info "注意: 请在 Sing-box 中配置端口 ${local_port} 的 VLESS 服务"
        print_info "UUID: ${new_uuid}"
        echo ""
        echo -e "${GREEN}节点链接:${NC}"
        echo "$link"
        return 0
    fi
    
    # 查找对应端口的inbound配置
    local inbound=$(jq -r ".inbounds[] | select(.listen_port == $local_port)" "$config_file" 2>/dev/null)
    
    if [[ -z "$inbound" ]]; then
        print_warning "未找到端口 $local_port 的配置，生成通用 VLESS+WS+TLS 节点链接"
        local new_uuid=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null)
        
        # Argo 隧道使用 443 端口，自带 TLS
        local link="vless://${new_uuid}@${domain}:443?encryption=none&security=tls&sni=${domain}&type=ws&host=${domain}&path=%2F#Argo-Port${local_port}"
        echo "$link" > "${LINK_DIR}/argo_node_${local_port}.txt"
        
        print_success "已生成 VLESS+WS+TLS 节点链接"
        print_info "注意: 请在 Sing-box 中配置端口 ${local_port} 的 VLESS 服务"
        print_info "UUID: ${new_uuid}"
        echo ""
        echo -e "${GREEN}节点链接:${NC}"
        echo "$link"
        return 0
    fi
    
    local protocol=$(echo "$inbound" | jq -r '.type')
    local tag=$(echo "$inbound" | jq -r '.tag')
    
    # 根据协议生成链接
    # Argo 隧道: 域名:443 + TLS + WebSocket
    case $protocol in
        vless)
            local uuid=$(echo "$inbound" | jq -r '.users[0].uuid // empty')
            if [[ -n "$uuid" ]]; then
                # VLESS + WebSocket + TLS (Argo 提供)
                local link="vless://${uuid}@${domain}:443?encryption=none&security=tls&sni=${domain}&type=ws&host=${domain}&path=%2F#Argo-${tag}"
                echo "$link" > "${LINK_DIR}/argo_node_${local_port}.txt"
                
                print_success "已生成 VLESS+WS+TLS 节点链接"
                echo ""
                echo -e "${GREEN}节点链接:${NC}"
                echo "$link"
            fi
            ;;
        trojan)
            local password=$(echo "$inbound" | jq -r '.users[0].password // empty')
            if [[ -n "$password" ]]; then
                # Trojan + WebSocket + TLS (Argo 提供)
                local link="trojan://${password}@${domain}:443?security=tls&sni=${domain}&type=ws&host=${domain}&path=%2F#Argo-${tag}"
                echo "$link" > "${LINK_DIR}/argo_node_${local_port}.txt"
                
                print_success "已生成 Trojan+WS+TLS 节点链接"
                echo ""
                echo -e "${GREEN}节点链接:${NC}"
                echo "$link"
            fi
            ;;
        vmess)
            local uuid=$(echo "$inbound" | jq -r '.users[0].uuid // empty')
            if [[ -n "$uuid" ]]; then
                # VMess + WebSocket + TLS (Argo 提供)
                local vmess_json=$(cat <<EOF
{
  "v": "2",
  "ps": "Argo-${tag}",
  "add": "${domain}",
  "port": "443",
  "id": "${uuid}",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "${domain}",
  "path": "/",
  "tls": "tls",
  "sni": "${domain}"
}
EOF
)
                local link="vmess://$(echo -n "$vmess_json" | base64 -w 0)"
                echo "$link" > "${LINK_DIR}/argo_node_${local_port}.txt"
                
                print_success "已生成 VMess+WS+TLS 节点链接"
                echo ""
                echo -e "${GREEN}节点链接:${NC}"
                echo "$link"
            fi
            ;;
        *)
            print_warning "协议 $protocol 暂不支持 Argo 隧道"
            print_info "Argo 隧道支持: VLESS, VMess, Trojan (需配合 WebSocket)"
            echo "https://${domain}" > "${LINK_DIR}/argo_node_${local_port}.txt"
            ;;
    esac
}

# Token 认证
install_argo_token() {
    clear
    print_info "安装 Argo Tunnel (Token 认证)"
    echo ""
    
    # 检查是否已经安装
    if systemctl is-active --quiet argo-tunnel; then
        print_warning "检测到 Argo Tunnel 已在运行"
        echo ""
        read -p "是否重新配置? [y/N]: " reconfig
        if [[ ! "$reconfig" =~ ^[Yy]$ ]]; then
            print_info "取消安装"
            sleep 2
            return 0
        fi
        systemctl stop argo-tunnel
        systemctl disable argo-tunnel 2>/dev/null
    elif [[ -f /etc/systemd/system/argo-tunnel.service ]]; then
        print_warning "检测到 Argo Tunnel 服务文件已存在但未运行"
        read -p "是否重新配置? [Y/n]: " reconfig
        if [[ "$reconfig" =~ ^[Nn]$ ]]; then
            print_info "取消安装"
            sleep 2
            return 0
        fi
        systemctl disable argo-tunnel 2>/dev/null
    fi
    
    echo ""
    install_cloudflared || return 1
    
    echo ""
    echo "请访问 Cloudflare Zero Trust 控制台创建隧道并获取 Token"
    echo "https://one.dash.cloudflare.com/"
    echo ""
    read -p "请输入 Argo Token: " argo_token
    
    if [[ -z "$argo_token" ]]; then
        print_error "Token 不能为空"
        return 1
    fi
    
    read -p "请输入绑定的域名: " tunnel_domain
    read -p "请输入本地服务端口 (默认443): " local_port
    local_port=${local_port:-443}
    
    # 创建systemd服务
    print_info "创建服务配置..."
    cat > /etc/systemd/system/argo-tunnel.service << EOF
[Unit]
Description=Cloudflare Argo Tunnel
After=network.target

[Service]
Type=simple
ExecStart=${ARGO_DIR}/cloudflared tunnel --edge-ip-version auto run --token ${argo_token}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable argo-tunnel 2>/dev/null
    systemctl start argo-tunnel
    
    # 保存token和域名
    echo "$argo_token" > "${ARGO_DIR}/token.txt"
    echo "$tunnel_domain" > "${ARGO_DIR}/domain.txt"
    chmod 600 "${ARGO_DIR}/token.txt"
    
    # 生成节点链接
    if [[ -n "$tunnel_domain" ]]; then
        generate_argo_node_link "$tunnel_domain" "$local_port"
        
        # 保存信息
        mkdir -p "${LINK_DIR}"
        cat > "${LINK_DIR}/argo_token_${local_port}.txt" << EOF
========================================
Argo Tunnel (Token) 信息
========================================
域名: ${tunnel_domain}
本地端口: ${local_port}
完整地址: https://${tunnel_domain}

节点链接:
$(cat "${LINK_DIR}/argo_node_${local_port}.txt" 2>/dev/null || echo "未生成节点链接")

使用方法:
1. 确保本地服务运行在端口 ${local_port}
2. 通过 https://${tunnel_domain} 访问
3. 使用上方节点链接导入客户端
========================================
EOF
        echo ""
        cat "${LINK_DIR}/argo_token_${local_port}.txt"
    fi
    
    print_success "Argo Tunnel (Token) 已启动"
    echo ""
    read -p "按回车键继续..."
}

# JSON 认证
install_argo_json() {
    clear
    print_info "安装 Argo Tunnel (JSON 认证)"
    echo ""
    
    # 检查是否已经安装
    if systemctl is-active --quiet argo-tunnel; then
        print_warning "检测到 Argo Tunnel 已在运行"
        echo ""
        read -p "是否重新配置? [y/N]: " reconfig
        if [[ ! "$reconfig" =~ ^[Yy]$ ]]; then
            print_info "取消安装"
            sleep 2
            return 0
        fi
        systemctl stop argo-tunnel
        systemctl disable argo-tunnel 2>/dev/null
    elif [[ -f /etc/systemd/system/argo-tunnel.service ]]; then
        print_warning "检测到 Argo Tunnel 服务文件已存在但未运行"
        read -p "是否重新配置? [Y/n]: " reconfig
        if [[ "$reconfig" =~ ^[Nn]$ ]]; then
            print_info "取消安装"
            sleep 2
            return 0
        fi
        systemctl disable argo-tunnel 2>/dev/null
    fi
    
    echo ""
    install_cloudflared || return 1
    
    echo ""
    echo "请先在 Cloudflare 控制台创建隧道并下载 JSON 凭证文件"
    echo "或者访问: https://fscarmen.cloudflare.now.cc 获取 JSON"
    echo ""
    read -p "请输入隧道名称: " tunnel_name
    read -p "请输入隧道 UUID: " tunnel_uuid
    read -p "请输入本地服务端口: " local_port
    read -p "请输入绑定的域名: " tunnel_domain
    
    if [[ -z "$tunnel_name" || -z "$tunnel_uuid" || -z "$local_port" || -z "$tunnel_domain" ]]; then
        print_error "所有字段都不能为空"
        return 1
    fi
    
    # 创建凭证文件
    mkdir -p ~/.cloudflared
    cat > ~/.cloudflared/${tunnel_uuid}.json << EOF
{
  "AccountTag": "",
  "TunnelSecret": "",
  "TunnelID": "${tunnel_uuid}",
  "TunnelName": "${tunnel_name}"
}
EOF
    
    print_warning "请手动编辑 ~/.cloudflared/${tunnel_uuid}.json 填入完整的 JSON 内容"
    read -p "编辑完成后按回车继续..."
    
    # 创建配置文件
    cat > "${ARGO_CONFIG}" << EOF
tunnel: ${tunnel_uuid}
credentials-file: /root/.cloudflared/${tunnel_uuid}.json

ingress:
  - hostname: ${tunnel_domain}
    service: http://localhost:${local_port}
  - service: http_status:404
EOF
    
    # 创建systemd服务
    cat > /etc/systemd/system/argo-tunnel.service << EOF
[Unit]
Description=Cloudflare Argo Tunnel
After=network.target

[Service]
Type=simple
ExecStart=${ARGO_DIR}/cloudflared tunnel --edge-ip-version auto --config ${ARGO_CONFIG} run ${tunnel_name}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable argo-tunnel 2>/dev/null
    systemctl start argo-tunnel
    
    # 生成节点链接
    generate_argo_node_link "$tunnel_domain" "$local_port"
    
    # 保存信息
    mkdir -p "${LINK_DIR}"
    cat > "${LINK_DIR}/argo_json_${local_port}.txt" << EOF
========================================
Argo Tunnel (JSON) 信息
========================================
隧道名称: ${tunnel_name}
隧道 UUID: ${tunnel_uuid}
域名: ${tunnel_domain}
本地端口: ${local_port}
完整地址: https://${tunnel_domain}

节点链接:
$(cat "${LINK_DIR}/argo_node_${local_port}.txt" 2>/dev/null || echo "未生成节点链接")

配置文件: ${ARGO_CONFIG}
凭证文件: ~/.cloudflared/${tunnel_uuid}.json

使用方法:
1. 确保本地服务运行在端口 ${local_port}
2. 通过 https://${tunnel_domain} 访问
3. 使用上方节点链接导入客户端
========================================
EOF
    
    print_success "Argo Tunnel (JSON) 已启动"
    echo ""
    cat "${LINK_DIR}/argo_json_${local_port}.txt"
    echo ""
    read -p "按回车键继续..."
}

# 查看Argo状态
view_argo_status() {
    clear
    print_info "Argo 隧道状态"
    echo ""
    
    if systemctl is-active --quiet argo-quick; then
        print_success "Argo Quick Tunnel 运行中"
        
        # 尝试从日志获取最新域名
        if [[ -f "${ARGO_DIR}/argo.log" ]]; then
            local domain=$(grep -oP 'https://\K[^/]+\.trycloudflare\.com' "${ARGO_DIR}/argo.log" | tail -1)
            if [[ -n "$domain" ]]; then
                echo -e "  临时域名: ${GREEN}${domain}${NC}"
                echo "$domain" > "${ARGO_DIR}/domain.txt"
                
                # 显示完整链接
                echo -e "  完整地址: ${GREEN}https://${domain}${NC}"
                
                # 检查是否有节点链接
                local port=$(grep "ExecStart.*--url.*localhost:" /etc/systemd/system/argo-quick.service | grep -oP 'localhost:\K[0-9]+')
                if [[ -n "$port" && -f "${LINK_DIR}/argo_node_${port}.txt" ]]; then
                    echo ""
                    echo -e "${CYAN}节点链接:${NC}"
                    cat "${LINK_DIR}/argo_node_${port}.txt"
                fi
            else
                print_warning "未能从日志中获取域名"
                echo -e "  日志文件: ${ARGO_DIR}/argo.log"
            fi
        elif [[ -f "${ARGO_DIR}/domain.txt" ]]; then
            local domain=$(cat "${ARGO_DIR}/domain.txt")
            echo -e "  临时域名: ${GREEN}${domain}${NC}"
        else
            print_warning "未找到域名信息"
        fi
    elif systemctl is-active --quiet argo-tunnel; then
        print_success "Argo Tunnel 运行中"
        if [[ -f "${ARGO_CONFIG}" ]]; then
            local domain=$(grep "hostname:" "${ARGO_CONFIG}" | awk '{print $2}')
            echo -e "  域名: ${GREEN}${domain}${NC}"
        fi
    else
        print_warning "Argo 隧道未运行"
    fi
    
    echo ""
    echo -e "${CYAN}详细状态:${NC}"
    systemctl status argo-quick 2>/dev/null || systemctl status argo-tunnel 2>/dev/null || echo "未安装"
    
    echo ""
    echo -e "${CYAN}最近日志:${NC}"
    if [[ -f "${ARGO_DIR}/argo.log" ]]; then
        tail -10 "${ARGO_DIR}/argo.log"
    else
        echo "无日志文件"
    fi
    
    echo ""
    read -p "按回车键继续..."
}

# 刷新域名和节点链接
refresh_argo_domain() {
    clear
    print_info "刷新 Argo 域名和节点链接"
    echo ""
    
    if ! systemctl is-active --quiet argo-quick; then
        print_error "Argo Quick Tunnel 未运行"
        echo ""
        print_info "请先启动 Argo Quick Tunnel"
        read -p "按回车键继续..."
        return 1
    fi
    
    # 获取端口
    local port=$(grep "ExecStart.*--url.*localhost:" /etc/systemd/system/argo-quick.service | grep -oP 'localhost:\K[0-9]+')
    
    if [[ -z "$port" ]]; then
        print_error "无法获取端口信息"
        read -p "按回车键继续..."
        return 1
    fi
    
    print_info "从日志中获取域名..."
    
    # 等待并获取域名
    local temp_domain=""
    local wait_time=0
    local max_wait=15
    
    while [[ -z "$temp_domain" && $wait_time -lt $max_wait ]]; do
        sleep 1
        wait_time=$((wait_time + 1))
        
        if [[ -f "${ARGO_DIR}/argo.log" ]]; then
            temp_domain=$(grep -oP 'https://\K[^/]+\.trycloudflare\.com' "${ARGO_DIR}/argo.log" | tail -1)
        fi
        
        if [[ -z "$temp_domain" ]]; then
            echo -n "."
        fi
    done
    echo ""
    
    if [[ -n "$temp_domain" ]]; then
        print_success "临时域名: ${temp_domain}"
        echo "$temp_domain" > "${ARGO_DIR}/domain.txt"
        
        # 重新生成节点链接
        print_info "生成节点链接..."
        generate_argo_node_link "$temp_domain" "$port"
        
        # 更新信息文件
        mkdir -p "${LINK_DIR}"
        cat > "${LINK_DIR}/argo_quick_${port}.txt" << EOF
========================================
Argo Quick Tunnel 信息
========================================
本地端口: ${port}
临时域名: ${temp_domain}
完整地址: https://${temp_domain}

节点链接:
$(cat "${LINK_DIR}/argo_node_${port}.txt" 2>/dev/null || echo "未生成节点链接")

注意: 临时域名会在重启后变化
日志文件: ${ARGO_DIR}/argo.log

使用方法:
1. 确保本地服务运行在端口 ${port}
2. 通过 https://${temp_domain} 访问
3. 使用上方节点链接导入客户端
========================================
EOF
        
        echo ""
        print_success "域名和节点链接已更新"
        echo ""
        cat "${LINK_DIR}/argo_quick_${port}.txt"
    else
        print_error "未能获取域名"
        echo ""
        print_info "请检查:"
        echo "  1. Argo 服务是否正常运行: systemctl status argo-quick"
        echo "  2. 查看日志: tail -f ${ARGO_DIR}/argo.log"
        echo "  3. 本地端口 ${port} 是否有服务运行"
    fi
    
    echo ""
    read -p "按回车键继续..."
}

# 重启Argo
restart_argo() {
    print_info "重启 Argo 服务..."
    
    if systemctl is-active --quiet argo-quick; then
        systemctl restart argo-quick
        print_success "Argo Quick Tunnel 已重启"
        
        # 重启后等待并刷新域名
        print_info "等待服务重新启动..."
        sleep 3
        
        # 调用刷新函数
        echo ""
        read -p "是否刷新域名和节点链接? [Y/n]: " refresh_confirm
        if [[ ! "$refresh_confirm" =~ ^[Nn]$ ]]; then
            refresh_argo_domain
            return
        fi
    elif systemctl is-active --quiet argo-tunnel; then
        systemctl restart argo-tunnel
        print_success "Argo Tunnel 已重启"
    else
        print_error "Argo 服务未运行"
    fi
    
    sleep 2
}

# 卸载Argo
uninstall_argo() {
    print_warning "确认卸载 Argo 隧道?"
    read -p "输入 yes 确认: " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_info "取消卸载"
        return
    fi
    
    print_info "卸载 Argo 隧道..."
    
    systemctl stop argo-quick 2>/dev/null
    systemctl stop argo-tunnel 2>/dev/null
    systemctl disable argo-quick 2>/dev/null
    systemctl disable argo-tunnel 2>/dev/null
    
    rm -f /etc/systemd/system/argo-quick.service
    rm -f /etc/systemd/system/argo-tunnel.service
    rm -rf "${ARGO_DIR}"
    rm -rf ~/.cloudflared
    rm -f /usr/local/bin/cloudflared
    
    systemctl daemon-reload
    
    print_success "Argo 隧道已卸载"
    sleep 2
}
