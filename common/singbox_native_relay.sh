#!/bin/bash

# ==================== Sing-box 原生代理链模块 ====================
# 功能: 在服务器上部署代理服务，供客户端使用

# 配置文件
NATIVE_RELAY_CONFIG="${CONFIG_DIR}/native_relay.conf"
NATIVE_RELAY_TYPE=""  # socks5, http, shadowsocks

# 检查是否已配置原生代理链
check_native_relay() {
    if [[ -f "$NATIVE_RELAY_CONFIG" ]]; then
        NATIVE_RELAY_TYPE=$(grep "^TYPE=" "$NATIVE_RELAY_CONFIG" | cut -d'=' -f2)
        return 0
    fi
    return 1
}

# 配置 Sing-box 原生代理链
configure_native_relay() {
    # 获取服务器 IP（如果未设置）
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(curl -s4m5 ifconfig.me 2>/dev/null || curl -s4m5 api.ipify.org 2>/dev/null)
    fi
    
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              Sing-box 原生代理链配置                      ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}说明:${NC}"
    echo "  在服务器上部署代理服务（SOCKS5/HTTP/Shadowsocks）"
    echo "  供客户端（如 NekoBox）连接使用，实现代理链功能"
    echo ""
    echo -e "${CYAN}工作流程:${NC}"
    echo "  客户端 → 本服务器代理 → 目标服务器"
    echo ""
    echo -e "${CYAN}适用场景:${NC}"
    echo "  • 使用 NekoBox/v2rayN 等客户端"
    echo "  • 需要在客户端配置代理链"
    echo "  • 服务器作为中转节点"
    echo ""
    echo -e "${CYAN}与独立工具中转的区别:${NC}"
    echo "  • 独立工具中转: 端口转发，透明代理"
    echo "  • 原生代理链: 服务器代理，需客户端配置"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # 检查是否已有配置
    if check_native_relay; then
        echo -e "${YELLOW}当前已配置原生代理链:${NC}"
        echo "  类型: ${NATIVE_RELAY_TYPE}"
        echo ""
        read -p "是否删除现有配置? [y/N]: " remove_existing
        if [[ "$remove_existing" =~ ^[Yy]$ ]]; then
            remove_native_relay
        else
            return
        fi
    fi
    
    echo -e "${GREEN}请选择代理类型:${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC}  SOCKS5 代理      ${YELLOW}(推荐 - 通用性最好)${NC}"
    echo -e "  ${GREEN}2.${NC}  HTTP 代理        ${YELLOW}(简单易用)${NC}"
    echo -e "  ${GREEN}3.${NC}  Shadowsocks      ${YELLOW}(加密传输)${NC}"
    echo ""
    echo -e "  ${GREEN}0.${NC}  返回"
    echo ""
    
    read -p "请选择 [0-3]: " relay_type
    
    case $relay_type in
        1) setup_socks5_relay ;;
        2) setup_http_relay ;;
        3) setup_shadowsocks_relay ;;
        0) return ;;
        *) print_error "无效的选择"; sleep 2; configure_native_relay ;;
    esac
}

# 配置 SOCKS5 代理
setup_socks5_relay() {
    clear
    print_info "配置 SOCKS5 代理"
    echo ""
    
    echo -e "${CYAN}SOCKS5 代理说明:${NC}"
    echo "  • 支持 TCP 和 UDP"
    echo "  • 兼容性最好"
    echo "  • 可以设置用户认证"
    echo ""
    
    read -p "监听端口 [1080]: " port
    port=${port:-1080}
    
    # 检查端口占用
    if ss -tuln | grep -q ":$port "; then
        print_error "端口 $port 已被占用"
        read -p "按回车键继续..."
        configure_native_relay
        return
    fi
    
    echo ""
    read -p "是否启用认证? [Y/n]: " enable_auth
    enable_auth=${enable_auth:-Y}
    
    local username=""
    local password=""
    
    if [[ "$enable_auth" =~ ^[Yy]$ ]]; then
        read -p "用户名 [user]: " username
        username=${username:-user}
        
        read -p "密码 [$(openssl rand -hex 8)]: " password
        password=${password:-$(openssl rand -hex 8)}
    fi
    
    # 安装 Gost
    if ! command -v gost &>/dev/null && [[ ! -f /usr/local/bin/gost ]]; then
        print_info "正在安装 Gost..."
        if [[ -f "${SCRIPT_DIR}/common/relay.sh" ]]; then
            source "${SCRIPT_DIR}/common/relay.sh"
            install_gost
        else
            print_error "无法找到 Gost 安装模块"
            read -p "按回车键继续..."
            return
        fi
    fi
    
    # 创建 systemd 服务
    local gost_cmd="/usr/local/bin/gost -L "
    
    if [[ "$enable_auth" =~ ^[Yy]$ ]]; then
        gost_cmd+="socks5://${username}:${password}@:${port}"
    else
        gost_cmd+="socks5://:${port}"
    fi
    
    cat > /etc/systemd/system/singbox-native-relay.service << EOF
[Unit]
Description=Sing-box Native Relay - SOCKS5
After=network.target

[Service]
Type=simple
ExecStart=${gost_cmd}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable singbox-native-relay
    systemctl start singbox-native-relay
    
    # 检查服务状态
    sleep 2
    if systemctl is-active --quiet singbox-native-relay; then
        print_success "SOCKS5 代理已启动"
    else
        print_error "SOCKS5 代理启动失败"
        journalctl -u singbox-native-relay -n 20
        read -p "按回车键继续..."
        return
    fi
    
    # 保存配置
    cat > "$NATIVE_RELAY_CONFIG" << EOF
TYPE=socks5
PORT=${port}
USERNAME=${username}
PASSWORD=${password}
CREATED=$(date '+%Y-%m-%d %H:%M:%S')
EOF
    
    # 显示配置信息
    clear
    print_success "SOCKS5 代理配置完成"
    echo ""
    echo -e "${CYAN}═══════════════════ 配置信息 ═══════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}服务器地址:${NC} ${SERVER_IP}"
    echo -e "  ${GREEN}监听端口:${NC} ${port}"
    echo -e "  ${GREEN}协议类型:${NC} SOCKS5"
    
    if [[ "$enable_auth" =~ ^[Yy]$ ]]; then
        echo -e "  ${GREEN}用户名:${NC} ${username}"
        echo -e "  ${GREEN}密码:${NC} ${password}"
        echo ""
        echo -e "${CYAN}客户端配置:${NC}"
        echo "  socks5://${username}:${password}@${SERVER_IP}:${port}"
    else
        echo -e "  ${GREEN}认证:${NC} 无"
        echo ""
        echo -e "${CYAN}客户端配置:${NC}"
        echo "  socks5://${SERVER_IP}:${port}"
    fi
    
    echo ""
    echo -e "${CYAN}═══════════════════ NekoBox 配置示例 ═══════════════════${NC}"
    echo ""
    echo "在 NekoBox 中添加 outbound:"
    echo ""
    cat << 'NEKO'
{
  "type": "socks",
  "tag": "relay",
  "server": "服务器IP",
  "server_port": 端口,
  "version": "5",
NEKO
    
    if [[ "$enable_auth" =~ ^[Yy]$ ]]; then
        cat << NEKO
  "username": "${username}",
  "password": "${password}"
NEKO
    fi
    
    echo "}"
    echo ""
    echo -e "${CYAN}然后在主节点配置中添加:${NC}"
    echo '  "detour": "relay"'
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}管理命令:${NC}"
    echo "  查看状态: systemctl status singbox-native-relay"
    echo "  查看日志: journalctl -u singbox-native-relay -f"
    echo "  重启服务: systemctl restart singbox-native-relay"
    echo ""
    
    read -p "按回车键继续..."
}

# 配置 HTTP 代理
setup_http_relay() {
    clear
    print_info "配置 HTTP 代理"
    echo ""
    
    echo -e "${CYAN}HTTP 代理说明:${NC}"
    echo "  • 支持 HTTP/HTTPS"
    echo "  • 配置简单"
    echo "  • 可以设置用户认证"
    echo ""
    
    read -p "监听端口 [8080]: " port
    port=${port:-8080}
    
    if ss -tuln | grep -q ":$port "; then
        print_error "端口 $port 已被占用"
        read -p "按回车键继续..."
        configure_native_relay
        return
    fi
    
    echo ""
    read -p "是否启用认证? [Y/n]: " enable_auth
    enable_auth=${enable_auth:-Y}
    
    local username=""
    local password=""
    
    if [[ "$enable_auth" =~ ^[Yy]$ ]]; then
        read -p "用户名 [user]: " username
        username=${username:-user}
        
        read -p "密码 [$(openssl rand -hex 8)]: " password
        password=${password:-$(openssl rand -hex 8)}
    fi
    
    # 安装 Gost
    if ! command -v gost &>/dev/null && [[ ! -f /usr/local/bin/gost ]]; then
        print_info "正在安装 Gost..."
        if [[ -f "${SCRIPT_DIR}/common/relay.sh" ]]; then
            source "${SCRIPT_DIR}/common/relay.sh"
            install_gost
        else
            print_error "无法找到 Gost 安装模块"
            read -p "按回车键继续..."
            return
        fi
    fi
    
    # 创建 systemd 服务
    local gost_cmd="/usr/local/bin/gost -L "
    
    if [[ "$enable_auth" =~ ^[Yy]$ ]]; then
        gost_cmd+="http://${username}:${password}@:${port}"
    else
        gost_cmd+="http://:${port}"
    fi
    
    cat > /etc/systemd/system/singbox-native-relay.service << EOF
[Unit]
Description=Sing-box Native Relay - HTTP
After=network.target

[Service]
Type=simple
ExecStart=${gost_cmd}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable singbox-native-relay
    systemctl start singbox-native-relay
    
    sleep 2
    if systemctl is-active --quiet singbox-native-relay; then
        print_success "HTTP 代理已启动"
    else
        print_error "HTTP 代理启动失败"
        journalctl -u singbox-native-relay -n 20
        read -p "按回车键继续..."
        return
    fi
    
    # 保存配置
    cat > "$NATIVE_RELAY_CONFIG" << EOF
TYPE=http
PORT=${port}
USERNAME=${username}
PASSWORD=${password}
CREATED=$(date '+%Y-%m-%d %H:%M:%S')
EOF
    
    # 显示配置信息
    clear
    print_success "HTTP 代理配置完成"
    echo ""
    echo -e "${CYAN}═══════════════════ 配置信息 ═══════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}服务器地址:${NC} ${SERVER_IP}"
    echo -e "  ${GREEN}监听端口:${NC} ${port}"
    echo -e "  ${GREEN}协议类型:${NC} HTTP"
    
    if [[ "$enable_auth" =~ ^[Yy]$ ]]; then
        echo -e "  ${GREEN}用户名:${NC} ${username}"
        echo -e "  ${GREEN}密码:${NC} ${password}"
        echo ""
        echo -e "${CYAN}客户端配置:${NC}"
        echo "  http://${username}:${password}@${SERVER_IP}:${port}"
    else
        echo -e "  ${GREEN}认证:${NC} 无"
        echo ""
        echo -e "${CYAN}客户端配置:${NC}"
        echo "  http://${SERVER_IP}:${port}"
    fi
    
    echo ""
    echo -e "${CYAN}═══════════════════ NekoBox 配置示例 ═══════════════════${NC}"
    echo ""
    echo "在 NekoBox 中添加 outbound:"
    echo ""
    cat << 'NEKO'
{
  "type": "http",
  "tag": "relay",
  "server": "服务器IP",
  "server_port": 端口,
NEKO
    
    if [[ "$enable_auth" =~ ^[Yy]$ ]]; then
        cat << NEKO
  "username": "${username}",
  "password": "${password}"
NEKO
    fi
    
    echo "}"
    echo ""
    
    read -p "按回车键继续..."
}

# 配置 Shadowsocks 代理
setup_shadowsocks_relay() {
    clear
    print_info "配置 Shadowsocks 代理"
    echo ""
    
    echo -e "${CYAN}Shadowsocks 代理说明:${NC}"
    echo "  • 加密传输"
    echo "  • 支持多种加密方法"
    echo "  • 适合需要加密的场景"
    echo ""
    
    read -p "监听端口 [8388]: " port
    port=${port:-8388}
    
    if ss -tuln | grep -q ":$port "; then
        print_error "端口 $port 已被占用"
        read -p "按回车键继续..."
        configure_native_relay
        return
    fi
    
    echo ""
    read -p "密码 [$(openssl rand -hex 16)]: " password
    password=${password:-$(openssl rand -hex 16)}
    
    echo ""
    echo "加密方法:"
    echo "  1. aes-256-gcm (推荐)"
    echo "  2. chacha20-ietf-poly1305"
    echo "  3. 2022-blake3-aes-256-gcm"
    read -p "选择 [1-3, 默认1]: " method_choice
    
    case $method_choice in
        2) method="chacha20-ietf-poly1305" ;;
        3) method="2022-blake3-aes-256-gcm" ;;
        *) method="aes-256-gcm" ;;
    esac
    
    # 安装 Gost
    if ! command -v gost &>/dev/null && [[ ! -f /usr/local/bin/gost ]]; then
        print_info "正在安装 Gost..."
        if [[ -f "${SCRIPT_DIR}/common/relay.sh" ]]; then
            source "${SCRIPT_DIR}/common/relay.sh"
            install_gost
        else
            print_error "无法找到 Gost 安装模块"
            read -p "按回车键继续..."
            return
        fi
    fi
    
    # 创建 systemd 服务
    cat > /etc/systemd/system/singbox-native-relay.service << EOF
[Unit]
Description=Sing-box Native Relay - Shadowsocks
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost -L ss://${method}:${password}@:${port}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable singbox-native-relay
    systemctl start singbox-native-relay
    
    sleep 2
    if systemctl is-active --quiet singbox-native-relay; then
        print_success "Shadowsocks 代理已启动"
    else
        print_error "Shadowsocks 代理启动失败"
        journalctl -u singbox-native-relay -n 20
        read -p "按回车键继续..."
        return
    fi
    
    # 保存配置
    cat > "$NATIVE_RELAY_CONFIG" << EOF
TYPE=shadowsocks
PORT=${port}
METHOD=${method}
PASSWORD=${password}
CREATED=$(date '+%Y-%m-%d %H:%M:%S')
EOF
    
    # 生成 SS 链接
    local ss_userinfo=$(echo -n "${method}:${password}" | base64 -w0)
    local ss_link="ss://${ss_userinfo}@${SERVER_IP}:${port}#NativeRelay"
    
    # 显示配置信息
    clear
    print_success "Shadowsocks 代理配置完成"
    echo ""
    echo -e "${CYAN}═══════════════════ 配置信息 ═══════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}服务器地址:${NC} ${SERVER_IP}"
    echo -e "  ${GREEN}监听端口:${NC} ${port}"
    echo -e "  ${GREEN}加密方法:${NC} ${method}"
    echo -e "  ${GREEN}密码:${NC} ${password}"
    echo ""
    echo -e "${CYAN}分享链接:${NC}"
    echo "  ${ss_link}"
    echo ""
    
    read -p "按回车键继续..."
}

# 查看原生代理链配置
view_native_relay() {
    clear
    echo -e "${CYAN}═══════════════════ 原生代理链配置 ═══════════════════${NC}"
    echo ""
    
    if ! check_native_relay; then
        print_warning "未配置原生代理链"
        read -p "按回车键继续..."
        return
    fi
    
    # 读取配置
    local port=$(grep "^PORT=" "$NATIVE_RELAY_CONFIG" | cut -d'=' -f2)
    local username=$(grep "^USERNAME=" "$NATIVE_RELAY_CONFIG" | cut -d'=' -f2)
    local password=$(grep "^PASSWORD=" "$NATIVE_RELAY_CONFIG" | cut -d'=' -f2)
    local method=$(grep "^METHOD=" "$NATIVE_RELAY_CONFIG" | cut -d'=' -f2)
    local created=$(grep "^CREATED=" "$NATIVE_RELAY_CONFIG" | cut -d'=' -f2)
    
    echo -e "${GREEN}类型:${NC} ${NATIVE_RELAY_TYPE}"
    echo -e "${GREEN}端口:${NC} ${port}"
    
    case $NATIVE_RELAY_TYPE in
        socks5|http)
            [[ -n "$username" ]] && echo -e "${GREEN}用户名:${NC} ${username}"
            [[ -n "$password" ]] && echo -e "${GREEN}密码:${NC} ${password}"
            ;;
        shadowsocks)
            echo -e "${GREEN}加密方法:${NC} ${method}"
            echo -e "${GREEN}密码:${NC} ${password}"
            ;;
    esac
    
    echo -e "${GREEN}创建时间:${NC} ${created}"
    echo ""
    
    # 显示服务状态
    echo -e "${CYAN}服务状态:${NC}"
    systemctl status singbox-native-relay --no-pager | head -10
    echo ""
    
    read -p "按回车键继续..."
}

# 删除原生代理链
remove_native_relay() {
    if ! check_native_relay; then
        print_warning "未配置原生代理链"
        return
    fi
    
    print_info "正在删除原生代理链配置..."
    
    # 停止并删除服务
    systemctl stop singbox-native-relay 2>/dev/null
    systemctl disable singbox-native-relay 2>/dev/null
    rm -f /etc/systemd/system/singbox-native-relay.service
    systemctl daemon-reload
    
    # 删除配置文件
    rm -f "$NATIVE_RELAY_CONFIG"
    
    print_success "原生代理链配置已删除"
}
