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
    
    # 检查并创建 VLESS+WS 节点
    check_and_create_vless_ws_node "$local_port"
    
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
    echo ""
    
    # 检查本地端口是否有服务
    print_info "检查本地端口 ${local_port} 是否有服务运行..."
    sleep 2
    
    if ! ss -tuln | grep -q ":${local_port} "; then
        print_warning "本地端口 ${local_port} 没有服务运行"
        echo ""
        echo -e "${YELLOW}Argo 隧道需要本地端口有服务才能正常工作${NC}"
        echo ""
        echo "请选择操作:"
        echo "  1. 继续获取域名（稍后配置 Sing-box）"
        echo "  2. 现在配置 Sing-box"
        echo "  0. 取消"
        echo ""
        read -p "请选择 [0-2]: " port_choice
        
        case $port_choice in
            1)
                print_info "继续获取域名..."
                ;;
            2)
                print_info "跳转到 Sing-box 配置..."
                echo ""
                read -p "按回车键继续..."
                # 返回主菜单，用户可以选择配置节点
                return 0
                ;;
            0)
                print_info "取消安装"
                systemctl stop argo-quick
                systemctl disable argo-quick 2>/dev/null
                rm -f /etc/systemd/system/argo-quick.service
                systemctl daemon-reload
                sleep 2
                return 1
                ;;
            *)
                print_error "无效的选择"
                sleep 2
                return 1
                ;;
        esac
    else
        print_success "本地端口 ${local_port} 有服务运行"
    fi
    
    echo ""
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

# 生成 Argo 节点链接（增强版）
generate_argo_node_link() {
    local domain=$1
    local local_port=$2
    
    # 检查本地端口对应的协议配置
    local config_file="${CONFIG_DIR}/config.json"
    
    # 默认值
    local protocol="vless"
    local uuid=""
    local password=""
    local tag="Port${local_port}"
    
    if [[ -f "$config_file" ]]; then
        # 查找对应端口的inbound配置
        local inbound=$(jq -r ".inbounds[] | select(.listen_port == $local_port)" "$config_file" 2>/dev/null)
        
        if [[ -n "$inbound" ]]; then
            protocol=$(echo "$inbound" | jq -r '.type')
            tag=$(echo "$inbound" | jq -r '.tag')
            
            case $protocol in
                vless)
                    uuid=$(echo "$inbound" | jq -r '.users[0].uuid // empty')
                    ;;
                vmess)
                    uuid=$(echo "$inbound" | jq -r '.users[0].uuid // empty')
                    ;;
                trojan)
                    password=$(echo "$inbound" | jq -r '.users[0].password // empty')
                    ;;
            esac
        fi
    fi
    
    # 如果没有找到配置，生成新的 UUID 并给出详细提示
    if [[ -z "$uuid" && -z "$password" ]]; then
        uuid=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null)
        
        echo ""
        print_warning "未找到端口 $local_port 的 Sing-box 配置"
        echo ""
        echo -e "${YELLOW}═══════════════════ 重要提示 ═══════════════════${NC}"
        echo ""
        echo "Argo 隧道已启动，已为您生成通用节点链接（TLS + 非TLS）"
        echo ""
        echo -e "${CYAN}生成的链接包括:${NC}"
        echo "  ✓ TLS 链接 (443端口) - 推荐使用"
        echo "  ✓ 非 TLS 链接 (80端口) - 备用"
        echo "  ✓ CF 优选 IP 链接 - 可能更快"
        echo "  ✓ 多个备用端口选项"
        echo ""
        echo -e "${CYAN}下一步操作:${NC}"
        echo ""
        echo "1. 配置 Sing-box (使用生成的 UUID):"
        echo "   bash yb_new.sh"
        echo "   选择: 2. 配置节点"
        echo "   选择: 7. VLESS 系列 (推荐)"
        echo ""
        echo "2. 使用以下配置:"
        echo "   端口: ${local_port}"
        echo "   UUID: ${uuid}"
        echo "   传输: WebSocket"
        echo "   路径: /"
        echo ""
        echo "3. 配置完成后可刷新节点链接:"
        echo "   bash yb_new.sh"
        echo "   选择: 5. 配置 Argo 隧道"
        echo "   选择: 5. 刷新域名和节点链接"
        echo ""
        echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
        echo ""
        
        print_success "已生成 UUID: ${uuid}"
        print_info "节点链接已生成，请查看下方详细信息"
        echo ""
    fi
    
    # 生成完整的节点链接文件
    mkdir -p "${LINK_DIR}"
    
    case $protocol in
        vless)
            generate_vless_links "$domain" "$uuid" "$tag" "$local_port"
            ;;
        vmess)
            generate_vmess_links "$domain" "$uuid" "$tag" "$local_port"
            ;;
        trojan)
            generate_trojan_links "$domain" "$password" "$tag" "$local_port"
            ;;
        *)
            print_warning "协议 $protocol 暂不支持 Argo 隧道"
            echo "https://${domain}" > "${LINK_DIR}/argo_node_${local_port}.txt"
            ;;
    esac
}

# 生成 VLESS 链接
generate_vless_links() {
    local domain=$1
    local uuid=$2
    local tag=$3
    local port=$4
    
    # 直连链接
    local link_direct="vless://${uuid}@${domain}:443?encryption=none&security=tls&sni=${domain}&type=ws&host=${domain}&path=%2F#Argo-${tag}"
    
    # CF 优选 IP 链接
    local link_cf="vless://${uuid}@www.visa.com.sg:443?encryption=none&security=tls&sni=${domain}&type=ws&host=${domain}&path=%2F#Argo-${tag}-CF"
    
    # 非 TLS 链接
    local link_notls="vless://${uuid}@${domain}:80?encryption=none&security=none&type=ws&host=${domain}&path=%2F#Argo-${tag}-NoTLS"
    
    # 保存到文件
    cat > "${LINK_DIR}/argo_node_${port}.txt" << EOF
========================================
Argo VLESS 节点链接
========================================

【直连链接】(推荐 - 最稳定)
${link_direct}

【CF 优选 IP】(可能更快)
${link_cf}

【备用端口】(TLS)
443 (推荐), 2053, 2083, 2087, 2096, 8443

【非 TLS 链接】(80端口)
${link_notls}

【备用端口】(非TLS)
80, 8080, 8880, 2052, 2082, 2086, 2095

========================================
使用说明
========================================

1. 直连链接:
   - 最稳定可靠
   - 直接使用 Argo 域名
   - 推荐日常使用

2. CF 优选 IP:
   - 使用 www.visa.com.sg 作为连接地址
   - 可能获得更快的速度
   - 需要客户端支持 SNI

3. 备用端口:
   - 如果 443 端口被限制，可尝试其他端口
   - TLS 端口: 443, 2053, 2083, 2087, 2096, 8443
   - 非 TLS 端口: 80, 8080, 8880, 2052, 2082, 2086, 2095

4. 非 TLS 链接:
   - 使用 80 端口，不加密传输
   - 如果无法使用，请检查 CF 设置
   - 关闭 "始终使用 HTTPS" 选项
   - 设置位置: SSL/TLS → 边缘证书

========================================
配置信息
========================================

协议: VLESS
UUID: ${uuid}
域名: ${domain}
本地端口: ${port}
传输: WebSocket
路径: /
TLS: 由 Argo 提供

========================================
EOF
    
    print_success "已生成 VLESS 节点链接"
    echo ""
    echo -e "${GREEN}【直连链接】${NC}"
    echo "$link_direct"
    echo ""
    echo -e "${CYAN}【CF 优选 IP】${NC}"
    echo "$link_cf"
    echo ""
    print_info "完整信息已保存到: ${LINK_DIR}/argo_node_${port}.txt"
}

# 生成 VMess 链接
generate_vmess_links() {
    local domain=$1
    local uuid=$2
    local tag=$3
    local port=$4
    
    # 直连链接 (TLS)
    local vmess_json_tls=$(cat <<EOF
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
    local link_direct="vmess://$(echo -n "$vmess_json_tls" | base64 -w 0)"
    
    # CF 优选 IP (TLS)
    local vmess_json_cf=$(cat <<EOF
{
  "v": "2",
  "ps": "Argo-${tag}-CF",
  "add": "www.visa.com.sg",
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
    local link_cf="vmess://$(echo -n "$vmess_json_cf" | base64 -w 0)"
    
    # 非 TLS 链接
    local vmess_json_notls=$(cat <<EOF
{
  "v": "2",
  "ps": "Argo-${tag}-NoTLS",
  "add": "${domain}",
  "port": "80",
  "id": "${uuid}",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "${domain}",
  "path": "/",
  "tls": ""
}
EOF
)
    local link_notls="vmess://$(echo -n "$vmess_json_notls" | base64 -w 0)"
    
    # 保存到文件
    cat > "${LINK_DIR}/argo_node_${port}.txt" << EOF
========================================
Argo VMess 节点链接
========================================

【直连链接】(推荐 - 最稳定)
${link_direct}

【CF 优选 IP】(可能更快)
${link_cf}

【备用端口】(TLS)
443 (推荐), 2053, 2083, 2087, 2096, 8443

【非 TLS 链接】(80端口)
${link_notls}

【备用端口】(非TLS)
80, 8080, 8880, 2052, 2082, 2086, 2095

========================================
使用说明
========================================

1. 直连链接:
   - 最稳定可靠
   - 直接使用 Argo 域名
   - 推荐日常使用

2. CF 优选 IP:
   - 使用 www.visa.com.sg 作为连接地址
   - 可能获得更快的速度
   - 需要客户端支持 SNI

3. 备用端口:
   - 如果 443 端口被限制，可尝试其他端口
   - 修改链接中的 port 字段即可

4. 非 TLS 链接:
   - 使用 80 端口，不加密传输
   - 如果无法使用，请检查 CF 设置
   - 关闭 "始终使用 HTTPS" 选项

========================================
配置信息
========================================

协议: VMess
UUID: ${uuid}
域名: ${domain}
本地端口: ${port}
传输: WebSocket
路径: /
TLS: 由 Argo 提供

========================================
EOF
    
    print_success "已生成 VMess 节点链接"
    echo ""
    echo -e "${GREEN}【直连链接】${NC}"
    echo "$link_direct"
    echo ""
    echo -e "${CYAN}【CF 优选 IP】${NC}"
    echo "$link_cf"
    echo ""
    print_info "完整信息已保存到: ${LINK_DIR}/argo_node_${port}.txt"
}

# 生成 Trojan 链接
generate_trojan_links() {
    local domain=$1
    local password=$2
    local tag=$3
    local port=$4
    
    # 直连链接
    local link_direct="trojan://${password}@${domain}:443?security=tls&sni=${domain}&type=ws&host=${domain}&path=%2F#Argo-${tag}"
    
    # CF 优选 IP 链接
    local link_cf="trojan://${password}@www.visa.com.sg:443?security=tls&sni=${domain}&type=ws&host=${domain}&path=%2F#Argo-${tag}-CF"
    
    # 非 TLS 链接
    local link_notls="trojan://${password}@${domain}:80?security=none&type=ws&host=${domain}&path=%2F#Argo-${tag}-NoTLS"
    
    # 保存到文件
    cat > "${LINK_DIR}/argo_node_${port}.txt" << EOF
========================================
Argo Trojan 节点链接
========================================

【直连链接】(推荐 - 最稳定)
${link_direct}

【CF 优选 IP】(可能更快)
${link_cf}

【备用端口】(TLS)
443 (推荐), 2053, 2083, 2087, 2096, 8443

【非 TLS 链接】(80端口)
${link_notls}

【备用端口】(非TLS)
80, 8080, 8880, 2052, 2082, 2086, 2095

========================================
使用说明
========================================

1. 直连链接:
   - 最稳定可靠
   - 直接使用 Argo 域名
   - 推荐日常使用

2. CF 优选 IP:
   - 使用 www.visa.com.sg 作为连接地址
   - 可能获得更快的速度
   - 需要客户端支持 SNI

3. 备用端口:
   - 如果 443 端口被限制，可尝试其他端口
   - TLS 端口: 443, 2053, 2083, 2087, 2096, 8443
   - 非 TLS 端口: 80, 8080, 8880, 2052, 2082, 2086, 2095

4. 非 TLS 链接:
   - 使用 80 端口，不加密传输
   - 如果无法使用，请检查 CF 设置
   - 关闭 "始终使用 HTTPS" 选项

========================================
配置信息
========================================

协议: Trojan
密码: ${password}
域名: ${domain}
本地端口: ${port}
传输: WebSocket
路径: /
TLS: 由 Argo 提供

========================================
EOF
    
    print_success "已生成 Trojan 节点链接"
    echo ""
    echo -e "${GREEN}【直连链接】${NC}"
    echo "$link_direct"
    echo ""
    echo -e "${CYAN}【CF 优选 IP】${NC}"
    echo "$link_cf"
    echo ""
    print_info "完整信息已保存到: ${LINK_DIR}/argo_node_${port}.txt"
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
    
    # 检查并创建 VLESS+WS 节点
    check_and_create_vless_ws_node "$local_port"
    
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
    
    print_success "Argo Tunnel (Token) 已启动"
    echo ""
    
    # 检查本地端口
    print_info "检查本地端口 ${local_port}..."
    sleep 2
    
    if ! ss -tuln | grep -q ":${local_port} "; then
        print_warning "本地端口 ${local_port} 没有服务运行"
        echo ""
        echo -e "${YELLOW}重要提示:${NC}"
        echo "  Argo 隧道已启动，但本地端口 ${local_port} 没有服务"
        echo "  这会导致连接失败 (connection refused)"
        echo ""
        echo -e "${CYAN}解决方法:${NC}"
        echo "  1. 配置 Sing-box 监听端口 ${local_port}"
        echo "  2. 使用命令: bash yb_new.sh -> 2 -> 选择协议"
        echo "  3. 配置完成后，使用 '刷新域名' 功能更新节点链接"
        echo ""
    else
        print_success "本地端口 ${local_port} 有服务运行"
    fi
    
    echo ""
    
    # 生成节点链接
    if [[ -n "$tunnel_domain" ]]; then
        print_info "生成节点链接..."
        echo ""
        generate_argo_node_link "$tunnel_domain" "$local_port"
        
        # 保存信息
        mkdir -p "${LINK_DIR}"
        
        # 读取生成的节点链接
        local node_link=""
        if [[ -f "${LINK_DIR}/argo_node_${local_port}.txt" ]]; then
            node_link=$(cat "${LINK_DIR}/argo_node_${local_port}.txt")
        fi
        
        cat > "${LINK_DIR}/argo_token_${local_port}.txt" << EOF
========================================
Argo Tunnel (Token) 信息
========================================
域名: ${tunnel_domain}
本地端口: ${local_port}
完整地址: https://${tunnel_domain}

节点链接:
${node_link}

使用方法:
1. 确保本地服务运行在端口 ${local_port}
2. 通过 https://${tunnel_domain} 访问
3. 使用上方节点链接导入客户端

注意事项:
- 本地端口 ${local_port} 必须有服务运行
- 如果看到 "connection refused" 错误，请先启动本地服务
- 使用命令检查: ss -tuln | grep ${local_port}
========================================
EOF
        
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
        cat "${LINK_DIR}/argo_token_${local_port}.txt"
        echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    fi
    
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
    
    # 检查并创建 VLESS+WS 节点
    check_and_create_vless_ws_node "$local_port"
    
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
    
    print_success "Argo Tunnel (JSON) 已启动"
    echo ""
    
    # 检查本地端口
    print_info "检查本地端口 ${local_port}..."
    sleep 2
    
    if ! ss -tuln | grep -q ":${local_port} "; then
        print_warning "本地端口 ${local_port} 没有服务运行"
        echo ""
        echo -e "${YELLOW}重要提示:${NC}"
        echo "  Argo 隧道已启动，但本地端口 ${local_port} 没有服务"
        echo "  这会导致连接失败 (connection refused)"
        echo ""
        echo -e "${CYAN}解决方法:${NC}"
        echo "  1. 配置 Sing-box 监听端口 ${local_port}"
        echo "  2. 使用命令: bash yb_new.sh -> 2 -> 选择协议"
        echo "  3. 配置完成后，使用 '刷新域名' 功能更新节点链接"
        echo ""
    else
        print_success "本地端口 ${local_port} 有服务运行"
    fi
    
    echo ""
    
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

# 检查并创建 VLESS+WS 节点
check_and_create_vless_ws_node() {
    local port=$1
    local config_file="${CONFIG_DIR}/config.json"
    
    echo ""
    print_info "检查端口 ${port} 的配置..."
    
    # 检查 sing-box 是否已安装
    if ! command -v sing-box &>/dev/null; then
        print_warning "未检测到 sing-box"
        echo ""
        read -p "是否现在安装 sing-box? [Y/n]: " install_sb
        if [[ ! "$install_sb" =~ ^[Nn]$ ]]; then
            source "${SCRIPT_DIR}/common/install.sh"
            install_sing_box
        else
            print_info "跳过 sing-box 安装"
            return 0
        fi
    fi
    
    # 检查配置文件是否存在
    if [[ ! -f "$config_file" ]]; then
        print_info "配置文件不存在，创建基础配置..."
        mkdir -p "${CONFIG_DIR}"
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
        print_success "基础配置已创建"
    fi
    
    # 检查端口是否已配置
    local existing_config=$(jq -r ".inbounds[] | select(.listen_port == $port)" "$config_file" 2>/dev/null)
    
    if [[ -n "$existing_config" ]]; then
        local protocol=$(echo "$existing_config" | jq -r '.type')
        local has_ws=$(echo "$existing_config" | jq -r '.transport.type // empty')
        
        if [[ "$protocol" == "vless" && "$has_ws" == "ws" ]]; then
            print_success "端口 ${port} 已配置 VLESS+WebSocket"
            local uuid=$(echo "$existing_config" | jq -r '.users[0].uuid')
            echo "  UUID: ${uuid}"
            return 0
        else
            print_warning "端口 ${port} 已被其他协议占用: ${protocol}"
            echo ""
            read -p "是否继续使用此端口? [Y/n]: " continue_port
            if [[ "$continue_port" =~ ^[Nn]$ ]]; then
                return 1
            fi
            return 0
        fi
    fi
    
    # 端口未配置，询问是否创建
    print_warning "端口 ${port} 未配置 VLESS+WebSocket 节点"
    echo ""
    echo -e "${CYAN}Argo 隧道需要本地端口运行 VLESS+WebSocket 服务${NC}"
    echo ""
    read -p "是否自动创建 VLESS+WebSocket 节点? [Y/n]: " create_node
    
    if [[ "$create_node" =~ ^[Nn]$ ]]; then
        print_info "跳过节点创建"
        echo ""
        print_warning "注意: 没有本地服务，Argo 隧道将无法正常工作"
        echo ""
        read -p "按回车键继续..."
        return 0
    fi
    
    # 创建 VLESS+WS 节点
    print_info "创建 VLESS+WebSocket 节点..."
    echo ""
    
    # 生成配置参数
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    local path="/"
    
    print_success "UUID: ${uuid}"
    print_success "Path: ${path}"
    
    # 添加到配置文件
    local inbound=$(cat <<EOF
{
  "type": "vless",
  "tag": "vless-ws-argo-${port}",
  "listen": "::",
  "listen_port": ${port},
  "users": [{"uuid": "${uuid}"}],
  "transport": {
    "type": "ws",
    "path": "${path}"
  }
}
EOF
)
    
    local temp_file=$(mktemp)
    jq ".inbounds += [$inbound]" "$config_file" > "$temp_file" && mv "$temp_file" "$config_file"
    
    print_success "配置已添加到 ${config_file}"
    
    # 重启 sing-box 服务
    print_info "重启 sing-box 服务..."
    systemctl restart sing-box
    
    sleep 2
    
    if systemctl is-active --quiet sing-box; then
        print_success "sing-box 服务已启动"
        
        # 验证端口是否监听
        if ss -tuln | grep -q ":${port} "; then
            print_success "端口 ${port} 已成功监听"
        else
            print_warning "端口 ${port} 未监听，请检查配置"
        fi
    else
        print_error "sing-box 服务启动失败"
        echo ""
        print_info "查看错误日志: journalctl -u sing-box -n 50"
        echo ""
        read -p "按回车键继续..."
        return 1
    fi
    
    # 保存节点信息
    mkdir -p "${LINK_DIR}"
    cat > "${LINK_DIR}/vless_ws_argo_${port}.txt" << EOF
========================================
VLESS+WebSocket 节点信息 (Argo)
========================================
端口: ${port}
UUID: ${uuid}
传输: WebSocket
路径: ${path}

此节点已为 Argo 隧道配置
可通过 Argo 域名访问

配置文件: ${config_file}
========================================
EOF
    
    echo ""
    print_success "VLESS+WebSocket 节点创建完成"
    echo ""
    cat "${LINK_DIR}/vless_ws_argo_${port}.txt"
    echo ""
    read -p "按回车键继续..."
}
