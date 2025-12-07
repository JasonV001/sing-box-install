#!/bin/bash

# ==================== Cloudflare Argo 隧道配置模块 ====================

ARGO_DIR="/opt/argo"
ARGO_CONFIG="${ARGO_DIR}/config.yml"

# 配置Argo隧道
configure_argo() {
    clear
    echo -e "${CYAN}═══════════════════ Argo 隧道配置 ═══════════════════${NC}"
    echo ""
    echo "  ${GREEN}1.${NC}  安装 Argo 隧道 (Quick Tunnel - 临时域名)"
    echo "  ${GREEN}2.${NC}  安装 Argo 隧道 (Token 认证)"
    echo "  ${GREEN}3.${NC}  安装 Argo 隧道 (JSON 认证)"
    echo "  ${GREEN}4.${NC}  查看 Argo 状态"
    echo "  ${GREEN}5.${NC}  重启 Argo 服务"
    echo "  ${GREEN}6.${NC}  卸载 Argo 隧道"
    echo "  ${GREEN}0.${NC}  返回主菜单"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    
    read -p "请选择操作 [0-6]: " choice
    
    case $choice in
        1) install_argo_quick ;;
        2) install_argo_token ;;
        3) install_argo_json ;;
        4) view_argo_status ;;
        5) restart_argo ;;
        6) uninstall_argo ;;
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
    
    install_cloudflared || return 1
    
    read -p "请输入本地服务端口 (默认443): " local_port
    local_port=${local_port:-443}
    
    read -p "请选择IP版本 [4/6] (默认4): " ip_version
    ip_version=${ip_version:-4}
    
    # 创建systemd服务
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
    systemctl enable argo-quick
    systemctl start argo-quick
    
    print_success "Argo Quick Tunnel 已启动"
    print_info "等待获取临时域名..."
    sleep 5
    
    # 获取临时域名
    local temp_domain=$(grep -oP 'https://\K[^/]+\.trycloudflare\.com' "${ARGO_DIR}/argo.log" | tail -1)
    
    if [[ -n "$temp_domain" ]]; then
        print_success "临时域名: ${temp_domain}"
        echo "$temp_domain" > "${ARGO_DIR}/domain.txt"
    else
        print_warning "未能获取临时域名，请查看日志: ${ARGO_DIR}/argo.log"
    fi
    
    read -p "按回车键继续..."
}

# Token 认证
install_argo_token() {
    clear
    print_info "安装 Argo Tunnel (Token 认证)"
    
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
    
    # 创建systemd服务
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
    systemctl enable argo-tunnel
    systemctl start argo-tunnel
    
    # 保存token
    echo "$argo_token" > "${ARGO_DIR}/token.txt"
    chmod 600 "${ARGO_DIR}/token.txt"
    
    print_success "Argo Tunnel (Token) 已启动"
    read -p "按回车键继续..."
}

# JSON 认证
install_argo_json() {
    clear
    print_info "安装 Argo Tunnel (JSON 认证)"
    
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
    systemctl enable argo-tunnel
    systemctl start argo-tunnel
    
    print_success "Argo Tunnel (JSON) 已启动"
    print_info "域名: ${tunnel_domain}"
    read -p "按回车键继续..."
}

# 查看Argo状态
view_argo_status() {
    clear
    print_info "Argo 隧道状态"
    echo ""
    
    if systemctl is-active --quiet argo-quick; then
        print_success "Argo Quick Tunnel 运行中"
        if [[ -f "${ARGO_DIR}/domain.txt" ]]; then
            local domain=$(cat "${ARGO_DIR}/domain.txt")
            echo -e "  临时域名: ${GREEN}${domain}${NC}"
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
    echo "详细状态:"
    systemctl status argo-quick 2>/dev/null || systemctl status argo-tunnel 2>/dev/null || echo "未安装"
    
    echo ""
    read -p "按回车键继续..."
}

# 重启Argo
restart_argo() {
    print_info "重启 Argo 服务..."
    
    if systemctl is-active --quiet argo-quick; then
        systemctl restart argo-quick
        print_success "Argo Quick Tunnel 已重启"
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
