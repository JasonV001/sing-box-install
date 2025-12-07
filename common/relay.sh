#!/bin/bash

# ==================== 中转配置模块 ====================

# 中转配置文件
RELAY_CONFIG="${RELAY_DIR}/relay.json"

# 配置中转
configure_relay() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                      中转配置                             ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${PURPLE}【中转管理】${NC}"
    echo -e "    ${GREEN}1.${NC}  添加中转规则      ${YELLOW}(iptables/DNAT/Socat/Gost)${NC}"
    echo -e "    ${GREEN}2.${NC}  查看中转规则      ${YELLOW}(列表显示)${NC}"
    echo -e "    ${GREEN}3.${NC}  删除中转规则      ${YELLOW}(单个删除)${NC}"
    echo -e "    ${GREEN}4.${NC}  启用/禁用中转     ${YELLOW}(切换状态)${NC}"
    echo ""
    echo -e "    ${GREEN}0.${NC}  返回主菜单"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    
    read -p "请选择操作 [0-4]: " choice
    
    case $choice in
        1) add_relay_rule ;;
        2) view_relay_rules ;;
        3) delete_relay_rule ;;
        4) toggle_relay ;;
        0) return ;;
        *) print_error "无效的选择"; sleep 2; configure_relay ;;
    esac
}

# 添加中转规则
add_relay_rule() {
    clear
    print_info "添加中转规则"
    echo ""
    
    # 检测容器环境
    local in_container=false
    local virt_type=""
    if command -v systemd-detect-virt &>/dev/null; then
        virt_type=$(systemd-detect-virt 2>/dev/null)
        if [[ "$virt_type" =~ (docker|podman|lxc|container) ]]; then
            in_container=true
        fi
    fi
    
    # 如果在容器中，显示警告
    if [[ "$in_container" == true ]]; then
        echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║                    ⚠ 容器环境检测                         ║${NC}"
        echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}检测到当前运行在容器环境中: ${virt_type}${NC}"
        echo ""
        echo -e "${RED}注意: iptables 和 DNAT 在容器中无法使用！${NC}"
        echo ""
        echo -e "${CYAN}原因:${NC}"
        echo "  • 容器没有 CAP_NET_ADMIN 权限"
        echo "  • 无法加载内核模块"
        echo "  • 无法修改宿主机网络规则"
        echo ""
        echo -e "${GREEN}推荐使用:${NC}"
        echo "  • Socat 转发 (选项 3) - 应用层转发，容器中可用"
        echo "  • Gost 转发 (选项 4) - 功能强大，容器中可用"
        echo ""
        echo -e "${YELLOW}如果必须使用 iptables:${NC}"
        echo "  1. 在宿主机上配置 iptables"
        echo "  2. 或以特权模式运行容器: --privileged --cap-add=NET_ADMIN"
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        read -p "按回车键继续..."
        clear
        print_info "添加中转规则"
        echo ""
    fi
    
    echo -e "${CYAN}═══════════════════ 中转类型详细说明 ═══════════════════${NC}"
    echo ""
    
    # 如果在容器中，标记 iptables 和 DNAT 不可用
    if [[ "$in_container" == true ]]; then
        echo -e "${GREEN}【1】iptables 端口转发${NC} ${RED}[容器中不可用]${NC}"
    else
        echo -e "${GREEN}【1】iptables 端口转发${NC}"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${YELLOW}工作原理:${NC}"
    echo "    • 在 Linux 内核层面进行数据包转发"
    echo "    • 使用 PREROUTING 链修改目标地址"
    echo "    • 使用 POSTROUTING 链进行源地址伪装"
    echo ""
    echo -e "  ${YELLOW}技术特点:${NC}"
    echo "    • 性能最高 (内核级转发,几乎无性能损耗)"
    echo "    • 支持 TCP 和 UDP 协议"
    echo "    • 自动处理连接状态跟踪"
    echo "    • 规则持久化保存"
    echo ""
    echo -e "  ${YELLOW}适用场景:${NC}"
    echo "    ✓ 高流量转发 (游戏服务器、视频流)"
    echo "    ✓ 低延迟要求 (实时通信、在线游戏)"
    echo "    ✓ 简单端口映射 (1对1转发)"
    echo "    ✓ 同时转发 TCP 和 UDP"
    echo ""
    echo -e "  ${YELLOW}配置示例:${NC}"
    echo "    场景: 将本地 8443 端口转发到远程服务器"
    echo "    本地: 1.2.3.4:8443 (中转服务器)"
    echo "    目标: 5.6.7.8:443 (实际服务)"
    echo "    效果: 访问 1.2.3.4:8443 → 自动转发到 5.6.7.8:443"
    echo ""
    echo -e "  ${YELLOW}注意事项:${NC}"
    echo "    ⚠ 需要 root 权限"
    echo "    ⚠ 规则重启后需要重新加载"
    echo "    ⚠ 防火墙规则可能冲突"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [[ "$in_container" == true ]]; then
        echo -e "${GREEN}【2】DNAT 转发${NC} ${RED}[容器中不可用]${NC}"
    else
        echo -e "${GREEN}【2】DNAT 转发${NC}"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${YELLOW}工作原理:${NC}"
    echo "    • 目标网络地址转换 (Destination NAT)"
    echo "    • 修改数据包的目标 IP 和端口"
    echo "    • 自动启用 IP 转发功能"
    echo "    • 添加 MASQUERADE 规则处理返回流量"
    echo ""
    echo -e "  ${YELLOW}技术特点:${NC}"
    echo "    • 支持多目标转发"
    echo "    • 可以配置负载均衡"
    echo "    • 自动处理双向流量"
    echo "    • 支持跨网段转发"
    echo ""
    echo -e "  ${YELLOW}适用场景:${NC}"
    echo "    ✓ 多服务器中转 (分流到不同后端)"
    echo "    ✓ 负载均衡 (多个目标服务器)"
    echo "    ✓ 跨网段访问 (内网穿透)"
    echo "    ✓ 复杂网络拓扑"
    echo ""
    echo -e "  ${YELLOW}配置示例:${NC}"
    echo "    场景: 中转服务器分流到多个后端"
    echo "    中转: 1.2.3.4:8080"
    echo "    后端1: 5.6.7.8:80"
    echo "    后端2: 9.10.11.12:80"
    echo "    效果: 自动分配流量到不同后端"
    echo ""
    echo -e "  ${YELLOW}注意事项:${NC}"
    echo "    ⚠ 会修改系统 IP 转发设置"
    echo "    ⚠ 需要正确配置路由"
    echo "    ⚠ 可能影响其他网络服务"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "${GREEN}【3】Socat 转发${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${YELLOW}工作原理:${NC}"
    echo "    • 应用层数据流转发工具"
    echo "    • 建立两个数据流之间的双向通道"
    echo "    • 支持多种协议和地址类型"
    echo "    • 可以进行协议转换和加密"
    echo ""
    echo -e "  ${YELLOW}技术特点:${NC}"
    echo "    • 支持 TCP/UDP/Unix Socket"
    echo "    • 可以添加 SSL/TLS 加密层"
    echo "    • 支持 IPv4/IPv6 双栈"
    echo "    • 自动重连机制"
    echo "    • 灵活的选项配置"
    echo ""
    echo -e "  ${YELLOW}适用场景:${NC}"
    echo "    ✓ 需要协议转换 (TCP ↔ UDP)"
    echo "    ✓ 添加加密层 (明文 → TLS)"
    echo "    ✓ IPv4/IPv6 转换"
    echo "    ✓ Unix Socket 转发"
    echo "    ✓ 调试和测试"
    echo ""
    echo -e "  ${YELLOW}配置示例:${NC}"
    echo "    基础转发: TCP 1.2.3.4:8080 → 5.6.7.8:80"
    echo "    UDP转发: UDP 1.2.3.4:53 → 8.8.8.8:53"
    echo "    加密转发: TCP 1.2.3.4:443 → TLS 5.6.7.8:443"
    echo "    IPv6转发: IPv6 [::]:8080 → IPv4 5.6.7.8:80"
    echo ""
    echo -e "  ${YELLOW}高级选项:${NC}"
    echo "    • fork: 支持多个并发连接"
    echo "    • reuseaddr: 允许端口快速重用"
    echo "    • keepalive: 保持连接活跃"
    echo "    • nodelay: 禁用 Nagle 算法 (降低延迟)"
    echo ""
    echo -e "  ${YELLOW}注意事项:${NC}"
    echo "    ⚠ 性能略低于内核级转发"
    echo "    ⚠ 需要安装 socat 软件包"
    echo "    ⚠ 进程崩溃会中断转发"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "${GREEN}【4】Gost 转发${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${YELLOW}工作原理:${NC}"
    echo "    • 功能强大的代理工具"
    echo "    • 支持多种代理协议"
    echo "    • 可以构建代理链"
    echo "    • 支持流量加密和混淆"
    echo ""
    echo -e "  ${YELLOW}支持协议:${NC}"
    echo "    • HTTP/HTTPS 代理"
    echo "    • SOCKS4/SOCKS5 代理"
    echo "    • Shadowsocks/ShadowsocksR"
    echo "    • TCP/UDP 端口转发"
    echo "    • TLS/KCP/QUIC 加密传输"
    echo "    • WebSocket/mWS 流量混淆"
    echo ""
    echo -e "  ${YELLOW}核心功能:${NC}"
    echo "    • 代理链: 串联多个代理节点"
    echo "    • 加密传输: TLS/KCP/QUIC"
    echo "    • 流量混淆: WebSocket/HTTP2"
    echo "    • 用户认证: 用户名密码验证"
    echo "    • 负载均衡: 多节点分流"
    echo "    • 故障转移: 自动切换节点"
    echo ""
    echo -e "  ${YELLOW}适用场景:${NC}"
    echo "    ✓ 复杂代理链 (多级跳转)"
    echo "    ✓ 协议转换 (HTTP → SOCKS5 → SS)"
    echo "    ✓ 加密传输 (添加 TLS 层)"
    echo "    ✓ 流量混淆 (伪装成 HTTPS)"
    echo "    ✓ 需要认证的代理"
    echo "    ✓ 多节点负载均衡"
    echo ""
    echo -e "  ${YELLOW}配置示例:${NC}"
    echo "    1. 简单转发:"
    echo "       本地 1.2.3.4:8080 → 目标 5.6.7.8:80"
    echo ""
    echo "    2. SOCKS5 代理:"
    echo "       本地 1.2.3.4:1080 (SOCKS5) → 目标 5.6.7.8:1080"
    echo "       支持用户名密码认证"
    echo ""
    echo "    3. HTTP 代理:"
    echo "       本地 1.2.3.4:8080 (HTTP) → 目标 5.6.7.8:80"
    echo "       可以添加认证和加密"
    echo ""
    echo "    4. 加密转发:"
    echo "       本地 1.2.3.4:443 → TLS → 目标 5.6.7.8:443"
    echo "       自动添加 TLS 加密层"
    echo ""
    echo "    5. 代理链:"
    echo "       客户端 → Gost1 → Gost2 → Gost3 → 目标"
    echo "       多级代理跳转"
    echo ""
    echo -e "  ${YELLOW}性能对比:${NC}"
    echo "    • 简单转发: 性能接近 socat"
    echo "    • 加密转发: 略有性能损耗"
    echo "    • 代理链: 每增加一级损耗 5-10%"
    echo ""
    echo -e "  ${YELLOW}注意事项:${NC}"
    echo "    ⚠ 需要下载安装 Gost 程序"
    echo "    ⚠ 配置相对复杂"
    echo "    ⚠ 内存占用较高"
    echo "    ⚠ 加密会增加 CPU 负载"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "${PURPLE}═══════════════════ 选择建议 ═══════════════════${NC}"
    echo ""
    if [[ "$in_container" == true ]]; then
        echo -e "  ${YELLOW}容器环境推荐${NC} → 选择 Gost (功能强大) 或 Socat (简单)"
        echo -e "  ${RED}不推荐${NC} → iptables/DNAT (容器中无法使用)"
    else
        echo -e "  ${GREEN}性能优先${NC} → 选择 iptables (内核级转发)"
        echo -e "  ${GREEN}简单易用${NC} → 选择 socat (配置简单)"
        echo -e "  ${GREEN}功能丰富${NC} → 选择 Gost (支持加密混淆)"
        echo -e "  ${GREEN}负载均衡${NC} → 选择 DNAT (多目标分流)"
    fi
    echo ""
    echo -e "${PURPLE}═══════════════════════════════════════════════${NC}"
    echo ""
    
    read -p "请选择中转类型 [1-4]: " relay_type
    
    case $relay_type in
        1) 
            if [[ "$in_container" == true ]]; then
                print_error "iptables 在容器环境中无法使用"
                echo ""
                echo -e "${YELLOW}请选择 Socat (3) 或 Gost (4)${NC}"
                sleep 3
                add_relay_rule
                return
            fi
            add_iptables_relay
            ;;
        2) 
            if [[ "$in_container" == true ]]; then
                print_error "DNAT 在容器环境中无法使用"
                echo ""
                echo -e "${YELLOW}请选择 Socat (3) 或 Gost (4)${NC}"
                sleep 3
                add_relay_rule
                return
            fi
            add_dnat_relay
            ;;
        3) add_socat_relay ;;
        4) add_gost_relay ;;
        *) print_error "无效的选择"; sleep 2; return ;;
    esac
}

# iptables 端口转发
add_iptables_relay() {
    # 检查 root 权限
    if [[ $EUID -ne 0 ]]; then
        clear
        print_error "iptables 转发需要 root 权限"
        echo ""
        echo -e "${YELLOW}请使用以下方式之一运行脚本:${NC}"
        echo "  1. sudo bash $0"
        echo "  2. su root 后运行"
        echo ""
        read -p "按回车键返回..."
        return 1
    fi
    
    clear
    print_info "配置 iptables 端口转发"
    echo ""
    echo -e "${CYAN}配置说明:${NC}"
    echo "iptables 会将本地端口的流量转发到目标服务器"
    echo ""
    echo -e "${YELLOW}示例场景:${NC}"
    echo "本地服务器: 1.2.3.4 (中转服务器)"
    echo "目标服务器: 5.6.7.8:443 (实际服务)"
    echo "配置后: 访问 1.2.3.4:8443 → 自动转发到 5.6.7.8:443"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""
    
    read -p "请输入本地监听端口 (如: 8443): " local_port
    if [[ -z "$local_port" ]]; then
        print_error "端口不能为空"
        sleep 2
        return 1
    fi
    
    read -p "请输入目标IP地址 (如: 5.6.7.8): " target_ip
    if [[ -z "$target_ip" ]]; then
        print_error "目标IP不能为空"
        sleep 2
        return 1
    fi
    
    read -p "请输入目标端口 (如: 443): " target_port
    if [[ -z "$target_port" ]]; then
        print_error "目标端口不能为空"
        sleep 2
        return 1
    fi
    
    echo ""
    echo "请选择转发协议:"
    echo "  tcp  - 仅转发 TCP 流量"
    echo "  udp  - 仅转发 UDP 流量"
    echo "  both - 同时转发 TCP 和 UDP (推荐)"
    read -p "协议 [tcp/udp/both] (默认both): " protocol
    protocol=${protocol:-both}
    
    # 检查并安装 iptables
    if ! command -v iptables &>/dev/null; then
        print_warning "检测到 iptables 未安装"
        read -p "是否现在安装 iptables? [Y/n]: " install_iptables
        if [[ "$install_iptables" =~ ^[Nn]$ ]]; then
            print_info "取消安装"
            sleep 2
            return 1
        fi
        
        print_info "正在安装 iptables..."
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            if [[ "$ID" =~ (debian|ubuntu) ]]; then
                apt-get update -qq && apt-get install -y iptables
            elif [[ "$ID" =~ (centos|rhel|rocky|almalinux|fedora) ]]; then
                yum install -y iptables iptables-services
                systemctl enable iptables 2>/dev/null
            fi
        fi
        
        if command -v iptables &>/dev/null; then
            print_success "iptables 安装完成"
            echo ""
            print_info "继续配置 iptables 转发规则..."
            sleep 1
        else
            print_error "iptables 安装失败"
            read -p "按回车键继续..."
            return 1
        fi
    fi
    
    # 检查 iptables 是否可用（测试权限）
    if ! iptables -L -n &>/dev/null; then
        print_warning "检测到 iptables 权限问题"
        echo ""
        echo -e "${YELLOW}可能的原因:${NC}"
        echo "  1. nf_tables 后端权限问题"
        echo "  2. 容器环境限制"
        echo "  3. SELinux/AppArmor 限制"
        echo ""
        
        # 尝试切换到 legacy 模式
        if command -v iptables-legacy &>/dev/null; then
            print_info "尝试切换到 iptables-legacy 模式..."
            if update-alternatives --set iptables /usr/sbin/iptables-legacy &>/dev/null; then
                print_success "已切换到 iptables-legacy"
                
                # 再次测试
                if iptables -L -n &>/dev/null; then
                    print_success "iptables 现在可以正常使用"
                else
                    print_error "切换后仍然无法使用 iptables"
                    echo ""
                    echo -e "${YELLOW}请检查:${NC}"
                    echo "  1. 是否在容器中运行（需要特权模式）"
                    echo "  2. SELinux 状态: getenforce"
                    echo "  3. 内核模块: lsmod | grep ip_tables"
                    echo ""
                    read -p "按回车键返回..."
                    return 1
                fi
            else
                print_warning "无法切换到 legacy 模式"
            fi
        else
            print_error "iptables-legacy 不可用"
            echo ""
            echo -e "${YELLOW}请手动解决权限问题:${NC}"
            echo "  1. 检查是否在容器中: systemd-detect-virt"
            echo "  2. 检查 SELinux: getenforce"
            echo "  3. 尝试: modprobe ip_tables"
            echo ""
            read -p "按回车键返回..."
            return 1
        fi
    fi
    
    echo ""
    
    # 检查端口是否被占用
    if ss -tuln | grep -q ":$local_port "; then
        print_error "端口 $local_port 已被占用"
        return 1
    fi
    
    # 启用 IP 转发
    if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
        print_info "启用 IP 转发..."
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        sysctl -p > /dev/null 2>&1
    fi
    
    # 添加转发规则
    if [[ "$protocol" == "both" || "$protocol" == "tcp" ]]; then
        if iptables -t nat -A PREROUTING -p tcp --dport "$local_port" -j DNAT --to-destination "${target_ip}:${target_port}" && \
           iptables -t nat -A POSTROUTING -p tcp -d "$target_ip" --dport "$target_port" -j MASQUERADE; then
            print_success "TCP 转发规则已添加"
        else
            print_error "TCP 转发规则添加失败"
            return 1
        fi
    fi
    
    if [[ "$protocol" == "both" || "$protocol" == "udp" ]]; then
        if iptables -t nat -A PREROUTING -p udp --dport "$local_port" -j DNAT --to-destination "${target_ip}:${target_port}" && \
           iptables -t nat -A POSTROUTING -p udp -d "$target_ip" --dport "$target_port" -j MASQUERADE; then
            print_success "UDP 转发规则已添加"
        else
            print_error "UDP 转发规则添加失败"
            return 1
        fi
    fi
    
    # 保存规则
    save_relay_rule "iptables" "$local_port" "$target_ip" "$target_port" "$protocol"
    
    # 持久化iptables规则
    if command -v netfilter-persistent &>/dev/null; then
        netfilter-persistent save
    elif command -v iptables-save &>/dev/null; then
        iptables-save > /etc/iptables/rules.v4
    fi
    
    print_success "中转规则配置完成"
    read -p "按回车键继续..."
}

# DNAT 转发
add_dnat_relay() {
    # 检查 root 权限
    if [[ $EUID -ne 0 ]]; then
        clear
        print_error "DNAT 转发需要 root 权限"
        echo ""
        echo -e "${YELLOW}请使用以下方式之一运行脚本:${NC}"
        echo "  1. sudo bash $0"
        echo "  2. su root 后运行"
        echo ""
        read -p "按回车键返回..."
        return 1
    fi
    
    clear
    print_info "配置 DNAT 转发"
    echo ""
    echo -e "${CYAN}配置说明:${NC}"
    echo "DNAT (目标地址转换) 可以将流量转发到不同的目标服务器"
    echo "会自动启用 IP 转发功能 (net.ipv4.ip_forward=1)"
    echo ""
    echo -e "${YELLOW}示例场景:${NC}"
    echo "中转服务器: 1.2.3.4"
    echo "目标服务器: 5.6.7.8:443"
    echo "配置后: 1.2.3.4:8443 → 5.6.7.8:443"
    echo ""
    echo -e "${YELLOW}注意事项:${NC}"
    echo "- 需要 root 权限"
    echo "- 会修改系统 iptables 规则"
    echo "- 自动添加 MASQUERADE 规则"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""
    
    read -p "请输入本地监听端口: " local_port
    read -p "请输入目标IP地址: " target_ip
    read -p "请输入目标端口: " target_port
    
    # 检查并安装 iptables
    if ! command -v iptables &>/dev/null; then
        print_warning "检测到 iptables 未安装"
        read -p "是否现在安装 iptables? [Y/n]: " install_iptables
        if [[ "$install_iptables" =~ ^[Nn]$ ]]; then
            print_info "取消安装"
            sleep 2
            return 1
        fi
        
        print_info "正在安装 iptables..."
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            if [[ "$ID" =~ (debian|ubuntu) ]]; then
                apt-get update -qq && apt-get install -y iptables
            elif [[ "$ID" =~ (centos|rhel|rocky|almalinux|fedora) ]]; then
                yum install -y iptables iptables-services
                systemctl enable iptables 2>/dev/null
            fi
        fi
        
        if ! command -v iptables &>/dev/null; then
            print_error "iptables 安装失败"
            read -p "按回车键继续..."
            return 1
        fi
        print_success "iptables 安装完成"
        echo ""
        print_info "继续配置 DNAT 转发规则..."
        sleep 1
    fi
    
    # 检查 iptables 是否可用（测试权限）
    if ! iptables -L -n &>/dev/null; then
        print_warning "检测到 iptables 权限问题"
        echo ""
        
        # 尝试切换到 legacy 模式
        if command -v iptables-legacy &>/dev/null; then
            print_info "尝试切换到 iptables-legacy 模式..."
            if update-alternatives --set iptables /usr/sbin/iptables-legacy &>/dev/null; then
                print_success "已切换到 iptables-legacy"
                
                # 再次测试
                if ! iptables -L -n &>/dev/null; then
                    print_error "切换后仍然无法使用 iptables"
                    read -p "按回车键返回..."
                    return 1
                fi
            fi
        else
            print_error "无法解决 iptables 权限问题"
            read -p "按回车键返回..."
            return 1
        fi
    fi
    
    echo ""
    
    # 启用IP转发
    if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
        print_info "启用 IP 转发..."
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        sysctl -p > /dev/null 2>&1
    fi
    
    # 添加DNAT规则
    if ! iptables -t nat -A PREROUTING -p tcp --dport "$local_port" -j DNAT --to-destination "${target_ip}:${target_port}"; then
        print_error "TCP DNAT 规则添加失败"
        return 1
    fi
    
    if ! iptables -t nat -A PREROUTING -p udp --dport "$local_port" -j DNAT --to-destination "${target_ip}:${target_port}"; then
        print_error "UDP DNAT 规则添加失败"
        return 1
    fi
    iptables -t nat -A POSTROUTING -j MASQUERADE
    
    save_relay_rule "dnat" "$local_port" "$target_ip" "$target_port" "both"
    
    print_success "DNAT 转发配置完成"
    read -p "按回车键继续..."
}

# Socat 转发
add_socat_relay() {
    clear
    print_info "配置 Socat 转发"
    echo ""
    echo -e "${CYAN}配置说明:${NC}"
    echo "Socat 是一个强大的网络工具,支持多种协议转换"
    echo "可以在应用层进行流量转发和协议转换"
    echo ""
    echo -e "${YELLOW}特点:${NC}"
    echo "- 支持 TCP/UDP 协议"
    echo "- 可以添加 SSL/TLS 加密"
    echo "- 支持 IPv4/IPv6"
    echo "- 自动重连机制"
    echo ""
    echo -e "${YELLOW}示例场景:${NC}"
    echo "转发 TCP: 1.2.3.4:8080 → 5.6.7.8:80"
    echo "转发 UDP: 1.2.3.4:53 → 8.8.8.8:53"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""
    
    # 检查socat是否安装
    if ! command -v socat &>/dev/null; then
        print_warning "检测到 socat 未安装"
        read -p "是否现在安装 socat? [Y/n]: " install_socat
        if [[ "$install_socat" =~ ^[Nn]$ ]]; then
            print_info "取消安装"
            sleep 2
            return 1
        fi
        
        print_info "正在安装 socat..."
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            if [[ "$ID" =~ (debian|ubuntu) ]]; then
                apt-get update -qq && apt-get install -y socat
            elif [[ "$ID" =~ (centos|rhel|rocky|almalinux|fedora) ]]; then
                yum install -y socat
            fi
        fi
        
        if command -v socat &>/dev/null; then
            print_success "socat 安装完成"
        else
            print_error "socat 安装失败"
            read -p "按回车键继续..."
            return 1
        fi
    else
        print_success "socat 已安装"
    fi
    echo ""
    
    read -p "请输入本地监听端口 (如: 8080): " local_port
    if [[ -z "$local_port" ]]; then
        print_error "端口不能为空"
        sleep 2
        return 1
    fi
    
    read -p "请输入目标IP地址 (如: 1.2.3.4): " target_ip
    if [[ -z "$target_ip" ]]; then
        print_error "目标IP不能为空"
        sleep 2
        return 1
    fi
    
    read -p "请输入目标端口 (如: 80): " target_port
    if [[ -z "$target_port" ]]; then
        print_error "目标端口不能为空"
        sleep 2
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}请选择转发协议:${NC}"
    echo "  ${GREEN}tcp${NC} - TCP 协议 (适合大多数情况，如 HTTP/HTTPS)"
    echo "  ${GREEN}udp${NC} - UDP 协议 (适合 DNS、游戏、视频流等)"
    echo ""
    read -p "协议 [tcp/udp] (默认tcp): " protocol
    protocol=${protocol:-tcp}
    
    # 验证协议
    if [[ ! "$protocol" =~ ^(tcp|udp)$ ]]; then
        print_error "无效的协议，必须是 tcp 或 udp"
        sleep 2
        return 1
    fi
    
    # 创建systemd服务
    cat > /etc/systemd/system/socat-relay-${local_port}.service << EOF
[Unit]
Description=Socat Relay Service - Port ${local_port}
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/socat ${protocol}-LISTEN:${local_port},fork,reuseaddr ${protocol}:${target_ip}:${target_port}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable socat-relay-${local_port} 2>&1
    systemctl start socat-relay-${local_port}
    
    # 检查服务状态
    sleep 1
    if systemctl is-active --quiet socat-relay-${local_port}; then
        print_success "Socat 转发服务已启动"
    else
        print_error "Socat 转发服务启动失败"
        echo ""
        print_info "查看日志: journalctl -u socat-relay-${local_port} -n 50"
        read -p "按回车键继续..."
        return 1
    fi
    
    save_relay_rule "socat" "$local_port" "$target_ip" "$target_port" "$protocol"
    
    echo ""
    print_success "Socat 转发配置完成"
    echo ""
    echo -e "${CYAN}配置信息:${NC}"
    echo "  本地端口: ${local_port}"
    echo "  目标地址: ${target_ip}:${target_port}"
    echo "  转发协议: ${protocol}"
    echo "  服务名称: socat-relay-${local_port}"
    echo ""
    echo -e "${CYAN}管理命令:${NC}"
    echo "  查看状态: systemctl status socat-relay-${local_port}"
    echo "  查看日志: journalctl -u socat-relay-${local_port} -f"
    echo "  重启服务: systemctl restart socat-relay-${local_port}"
    echo "  停止服务: systemctl stop socat-relay-${local_port}"
    echo ""
    echo -e "${CYAN}测试连接:${NC}"
    if [[ "$protocol" == "tcp" ]]; then
        echo "  telnet 127.0.0.1 ${local_port}"
        echo "  nc -zv 127.0.0.1 ${local_port}"
    else
        echo "  nc -u 127.0.0.1 ${local_port}"
    fi
    echo ""
    read -p "按回车键继续..."
}

# Gost 转发
add_gost_relay() {
    clear
    print_info "配置 Gost 转发"
    echo ""
    echo -e "${CYAN}配置说明:${NC}"
    echo "Gost 是一个功能强大的代理工具,支持多种协议和加密方式"
    echo "可以构建复杂的代理链,支持流量混淆和加密"
    echo ""
    echo -e "${YELLOW}主要特点:${NC}"
    echo "- 支持多种协议: HTTP/HTTPS/SOCKS4/SOCKS5/SS/SSR"
    echo "- 支持代理链: 可以串联多个代理节点"
    echo "- 支持加密: TLS/KCP/QUIC 等加密传输"
    echo "- 支持混淆: WebSocket/mWS 等流量混淆"
    echo "- 支持认证: 用户名密码认证"
    echo ""
    echo -e "${YELLOW}使用场景:${NC}"
    echo "1. 简单转发: TCP/UDP 端口转发"
    echo "2. 协议转换: HTTP → SOCKS5, SOCKS5 → SS 等"
    echo "3. 加密传输: 添加 TLS 加密层"
    echo "4. 代理链: 多级代理跳转"
    echo ""
    echo -e "${YELLOW}配置示例:${NC}"
    echo "基础转发: 1.2.3.4:8080 → 5.6.7.8:80"
    echo "SOCKS5代理: 1.2.3.4:1080 → socks5://5.6.7.8:1080"
    echo "加密转发: 1.2.3.4:443 → tls://5.6.7.8:443"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""
    
    # 检查gost是否安装
    # 先检查 /usr/local/bin/gost
    if [[ -x "/usr/local/bin/gost" ]]; then
        local gost_version=$(/usr/local/bin/gost -V 2>&1 | head -n1)
        print_success "Gost 已安装: ${gost_version}"
    elif command -v gost &>/dev/null; then
        local gost_version=$(gost -V 2>&1 | head -n1)
        print_success "Gost 已安装: ${gost_version}"
    else
        print_warning "检测到 Gost 未安装"
        read -p "是否现在安装 Gost? [Y/n]: " install_gost_confirm
        if [[ "$install_gost_confirm" =~ ^[Nn]$ ]]; then
            print_info "取消安装"
            sleep 2
            return 1
        fi
        
        print_info "正在安装 Gost..."
        install_gost
        if [[ $? -ne 0 ]]; then
            print_error "Gost 安装失败"
            read -p "按回车键继续..."
            return 1
        fi
        print_success "Gost 安装完成"
    fi
    echo ""
    
    read -p "请输入本地监听端口 (如: 8080): " local_port
    if [[ -z "$local_port" ]]; then
        print_error "端口不能为空"
        sleep 2
        return 1
    fi
    
    # 检查端口是否被占用
    if ss -tuln | grep -q ":$local_port "; then
        print_error "端口 $local_port 已被占用"
        read -p "按回车键继续..."
        return 1
    fi
    
    echo ""
    echo "请选择转发模式:"
    echo "  1 - 简单转发 (TCP)"
    echo "  2 - SOCKS5 代理"
    echo "  3 - HTTP 代理"
    echo "  4 - 加密转发 (TLS)"
    read -p "模式 [1-4] (默认1): " relay_mode
    relay_mode=${relay_mode:-1}
    
    echo ""
    read -p "请输入目标IP地址 (如: 5.6.7.8): " target_ip
    if [[ -z "$target_ip" ]]; then
        print_error "目标IP不能为空"
        sleep 2
        return 1
    fi
    
    read -p "请输入目标端口 (如: 80): " target_port
    if [[ -z "$target_port" ]]; then
        print_error "目标端口不能为空"
        sleep 2
        return 1
    fi
    
    local target_addr="${target_ip}:${target_port}"
    local serve_node
    local chain_node
    
    case $relay_mode in
        1)
            # 简单TCP转发
            serve_node="tcp://:${local_port}"
            chain_node="tcp://${target_addr}"
            ;;
        2)
            # SOCKS5代理
            serve_node="socks5://:${local_port}"
            chain_node="tcp://${target_addr}"
            echo ""
            read -p "是否需要认证? [y/N]: " need_auth
            if [[ "$need_auth" =~ ^[Yy]$ ]]; then
                read -p "用户名: " username
                read -p "密码: " password
                serve_node="socks5://${username}:${password}@:${local_port}"
            fi
            ;;
        3)
            # HTTP代理
            serve_node="http://:${local_port}"
            chain_node="tcp://${target_addr}"
            echo ""
            read -p "是否需要认证? [y/N]: " need_auth
            if [[ "$need_auth" =~ ^[Yy]$ ]]; then
                read -p "用户名: " username
                read -p "密码: " password
                serve_node="http://${username}:${password}@:${local_port}"
            fi
            ;;
        4)
            # TLS加密转发
            serve_node="tcp://:${local_port}"
            chain_node="tls://${target_addr}"
            echo ""
            print_info "TLS 加密需要目标服务器支持 TLS"
            ;;
        *)
            print_error "无效的模式"
            sleep 2
            return 1
            ;;
    esac
    
    # 创建gost配置目录
    mkdir -p /etc/gost
    
    # 创建gost配置
    cat > /etc/gost/relay-${local_port}.json << EOF
{
  "ServeNodes": [
    "${serve_node}"
  ],
  "ChainNodes": [
    "${chain_node}"
  ]
}
EOF
    
    # 创建systemd服务
    cat > /etc/systemd/system/gost-relay-${local_port}.service << EOF
[Unit]
Description=Gost Relay Service - Port ${local_port}
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost -C /etc/gost/relay-${local_port}.json
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable gost-relay-${local_port}
    systemctl start gost-relay-${local_port}
    
    # 检查服务状态
    sleep 2
    if systemctl is-active --quiet gost-relay-${local_port}; then
        print_success "Gost 转发服务已启动"
    else
        print_error "Gost 转发服务启动失败"
        echo ""
        print_info "查看日志: journalctl -u gost-relay-${local_port} -n 50"
        read -p "按回车键继续..."
        return 1
    fi
    
    save_relay_rule "gost" "$local_port" "$target_ip" "$target_port" "tcp"
    
    echo ""
    print_success "Gost 转发配置完成"
    echo ""
    echo -e "${CYAN}配置信息:${NC}"
    echo "  本地端口: ${local_port}"
    echo "  目标地址: ${target_addr}"
    echo "  转发模式: $(case $relay_mode in 1) echo "简单转发";; 2) echo "SOCKS5代理";; 3) echo "HTTP代理";; 4) echo "TLS加密";; esac)"
    echo "  配置文件: /etc/gost/relay-${local_port}.json"
    echo "  服务名称: gost-relay-${local_port}"
    echo ""
    echo -e "${CYAN}管理命令:${NC}"
    echo "  查看状态: systemctl status gost-relay-${local_port}"
    echo "  查看日志: journalctl -u gost-relay-${local_port} -f"
    echo "  重启服务: systemctl restart gost-relay-${local_port}"
    echo "  停止服务: systemctl stop gost-relay-${local_port}"
    echo ""
    echo -e "${CYAN}测试连接:${NC}"
    case $relay_mode in
        1)
            echo "  telnet 127.0.0.1 ${local_port}"
            ;;
        2)
            echo "  curl -x socks5://127.0.0.1:${local_port} http://ip-api.com/json"
            ;;
        3)
            echo "  curl -x http://127.0.0.1:${local_port} http://ip-api.com/json"
            ;;
    esac
    echo ""
    read -p "按回车键继续..."
}

# 安装gost
install_gost() {
    # 检查是否已安装
    if command -v gost &>/dev/null; then
        print_success "Gost 已安装"
        return 0
    fi
    
    # 检查是否已存在但未在 PATH 中
    if [[ -f "/usr/local/bin/gost" ]]; then
        chmod +x /usr/local/bin/gost
        if /usr/local/bin/gost -V &>/dev/null; then
            print_success "Gost 已存在"
            return 0
        fi
    fi
    
    print_info "安装 Gost..."
    
    # 检测系统架构
    local arch=$(uname -m)
    local gost_arch
    
    case $arch in
        x86_64) gost_arch="linux-amd64" ;;
        aarch64|arm64) gost_arch="linux-arm64" ;;
        armv7l) gost_arch="linux-armv7" ;;
        *) 
            print_error "不支持的架构: $arch"
            echo ""
            echo "支持的架构: x86_64, aarch64, armv7l"
            return 1
            ;;
    esac
    
    # 获取最新版本
    print_info "检查最新版本..."
    local latest_version=$(curl -s --connect-timeout 10 https://api.github.com/repos/ginuerzh/gost/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")' 2>/dev/null)
    
    # 如果获取失败，使用备用版本
    if [[ -z "$latest_version" ]]; then
        print_warning "无法获取最新版本，使用备用版本"
        latest_version="v2.11.5"
    else
        print_success "最新版本: $latest_version"
    fi
    
    local version="$latest_version"
    local version_num="${version#v}"
    
    # 根据版本号确定文件格式
    # v2.12.0+ 使用新格式: gost_2.12.0_linux_amd64.tar.gz
    # v2.11.x 使用旧格式: gost-linux-amd64-2.11.5.gz
    local filename
    local is_tarball=false
    
    # 简单判断：v2.12.0+ 使用新格式，其他使用旧格式
    # 使用字符串比较避免算术错误
    case "$version_num" in
        2.1[2-9].*|2.[2-9]*.*|[3-9].*.*|[1-9][0-9].*.*)
            # 新格式 (v2.12.0+)
            filename="gost_${version_num}_${gost_arch}.tar.gz"
            is_tarball=true
            ;;
        *)
            # 旧格式 (v2.11.x 及更早)
            filename="gost-${gost_arch}-${version_num}.gz"
            is_tarball=false
            ;;
    esac
    
    # 定义多个下载源
    local download_urls=(
        "https://github.com/ginuerzh/gost/releases/download/${version}/${filename}"
        "https://ghproxy.com/https://github.com/ginuerzh/gost/releases/download/${version}/${filename}"
        "https://mirror.ghproxy.com/https://github.com/ginuerzh/gost/releases/download/${version}/${filename}"
    )
    
    print_info "下载 Gost ${version}..."
    
    local download_success=false
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || return 1
    
    # 尝试每个下载源
    for url in "${download_urls[@]}"; do
        local source_name=$(echo "$url" | cut -d'/' -f3)
        echo "  尝试: $source_name"
        echo "  URL: $url"
        
        # 尝试下载，显示详细错误
        if wget --timeout=30 --tries=2 -O "$filename" "$url" 2>&1 | grep -v "^--"; then
            if [[ -f "$filename" ]]; then
                local file_size=$(stat -f%z "$filename" 2>/dev/null || stat -c%s "$filename" 2>/dev/null)
                if [[ $file_size -gt 1000 ]]; then
                    print_success "下载成功 (${file_size} 字节)"
                    download_success=true
                    break
                else
                    print_warning "文件太小 (${file_size} 字节)，可能下载失败"
                    rm -f "$filename"
                fi
            else
                print_warning "下载后文件不存在"
            fi
        else
            print_warning "下载失败"
        fi
        echo ""
    done
    
    if [[ "$download_success" != true ]]; then
        print_error "所有下载源都失败了"
        cd - >/dev/null
        rm -rf "$temp_dir"
        echo ""
        echo -e "${YELLOW}手动安装方法:${NC}"
        echo "1. 访问: https://github.com/ginuerzh/gost/releases"
        echo "2. 下载: ${filename}"
        if [[ "$is_tarball" == true ]]; then
            echo "3. 解压: tar -xzf ${filename}"
            echo "4. 安装: mv gost /usr/local/bin/gost"
        else
            echo "3. 解压: gunzip ${filename}"
            echo "4. 安装: mv gost-${gost_arch}-${version_num} /usr/local/bin/gost"
        fi
        echo "5. 授权: chmod +x /usr/local/bin/gost"
        echo ""
        return 1
    fi
    
    # 解压和安装
    print_info "正在安装..."
    
    if [[ "$is_tarball" == true ]]; then
        # 新格式: tar.gz
        if tar -xzf "$filename" 2>/dev/null; then
            # tar.gz 解压后会有一个 gost 可执行文件
            if [[ -f "gost" ]]; then
                chmod +x gost
                mv gost /usr/local/bin/gost
                mkdir -p /etc/gost
                
                # 验证安装
                if /usr/local/bin/gost -V &>/dev/null; then
                    print_success "Gost 安装完成"
                    cd - >/dev/null
                    rm -rf "$temp_dir"
                    return 0
                else
                    print_error "Gost 安装后无法运行"
                    cd - >/dev/null
                    rm -rf "$temp_dir"
                    return 1
                fi
            else
                print_error "解压后未找到 gost 文件"
                cd - >/dev/null
                rm -rf "$temp_dir"
                return 1
            fi
        else
            print_error "解压失败"
            cd - >/dev/null
            rm -rf "$temp_dir"
            return 1
        fi
    else
        # 旧格式: .gz
        if gunzip "$filename" 2>/dev/null; then
            local extracted_file="${filename%.gz}"
            if [[ -f "$extracted_file" ]]; then
                chmod +x "$extracted_file"
                mv "$extracted_file" /usr/local/bin/gost
                mkdir -p /etc/gost
                
                # 验证安装
                if /usr/local/bin/gost -V &>/dev/null; then
                    print_success "Gost 安装完成"
                    cd - >/dev/null
                    rm -rf "$temp_dir"
                    return 0
                else
                    print_error "Gost 安装后无法运行"
                    cd - >/dev/null
                    rm -rf "$temp_dir"
                    return 1
                fi
            else
                print_error "解压后未找到文件"
                cd - >/dev/null
                rm -rf "$temp_dir"
                return 1
            fi
        else
            print_error "解压失败"
            cd - >/dev/null
            rm -rf "$temp_dir"
            return 1
        fi
    fi
}

# 保存中转规则
save_relay_rule() {
    local type=$1
    local local_port=$2
    local target_ip=$3
    local target_port=$4
    local protocol=$5
    
    mkdir -p "${RELAY_DIR}"
    
    local rule_json=$(cat <<EOF
{
  "type": "$type",
  "local_port": "$local_port",
  "target_ip": "$target_ip",
  "target_port": "$target_port",
  "protocol": "$protocol",
  "enabled": true,
  "created_at": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF
)
    
    # 如果配置文件不存在，创建空数组
    if [[ ! -f "$RELAY_CONFIG" ]]; then
        echo "[]" > "$RELAY_CONFIG"
    fi
    
    # 添加新规则
    local temp_file=$(mktemp)
    jq ". += [$rule_json]" "$RELAY_CONFIG" > "$temp_file"
    mv "$temp_file" "$RELAY_CONFIG"
}

# 查看中转规则
view_relay_rules() {
    clear
    print_info "当前中转规则"
    echo ""
    
    if [[ ! -f "$RELAY_CONFIG" ]] || [[ $(jq '. | length' "$RELAY_CONFIG") -eq 0 ]]; then
        print_warning "暂无中转规则"
        read -p "按回车键继续..."
        return
    fi
    
    echo -e "${CYAN}序号  类型      本地端口  目标地址              协议    状态${NC}"
    echo "─────────────────────────────────────────────────────────────"
    
    local index=1
    jq -r '.[] | "\(.type)|\(.local_port)|\(.target_ip):\(.target_port)|\(.protocol)|\(.enabled)"' "$RELAY_CONFIG" | while IFS='|' read -r type local_port target protocol enabled; do
        local status
        [[ "$enabled" == "true" ]] && status="${GREEN}启用${NC}" || status="${RED}禁用${NC}"
        printf "%-6s%-10s%-10s%-22s%-8s%b\n" "$index" "$type" "$local_port" "$target" "$protocol" "$status"
        ((index++))
    done
    
    echo ""
    read -p "按回车键继续..."
}

# 删除中转规则
delete_relay_rule() {
    view_relay_rules
    
    if [[ ! -f "$RELAY_CONFIG" ]] || [[ $(jq '. | length' "$RELAY_CONFIG") -eq 0 ]]; then
        return
    fi
    
    read -p "请输入要删除的规则序号 (0取消): " rule_index
    
    if [[ "$rule_index" == "0" ]]; then
        return
    fi
    
    local rule_count=$(jq '. | length' "$RELAY_CONFIG")
    if [[ "$rule_index" -lt 1 || "$rule_index" -gt "$rule_count" ]]; then
        print_error "无效的序号"
        sleep 2
        return
    fi
    
    # 获取规则信息
    local rule=$(jq ".[$((rule_index-1))]" "$RELAY_CONFIG")
    local type=$(echo "$rule" | jq -r '.type')
    local local_port=$(echo "$rule" | jq -r '.local_port')
    
    # 删除对应的转发规则
    case $type in
        iptables|dnat)
            iptables -t nat -D PREROUTING -p tcp --dport $local_port -j DNAT 2>/dev/null
            iptables -t nat -D PREROUTING -p udp --dport $local_port -j DNAT 2>/dev/null
            iptables -t nat -D POSTROUTING -j MASQUERADE 2>/dev/null
            ;;
        socat)
            systemctl stop socat-relay-${local_port}
            systemctl disable socat-relay-${local_port}
            rm -f /etc/systemd/system/socat-relay-${local_port}.service
            ;;
        gost)
            systemctl stop gost-relay-${local_port}
            systemctl disable gost-relay-${local_port}
            rm -f /etc/systemd/system/gost-relay-${local_port}.service
            rm -f /etc/gost/relay-${local_port}.json
            ;;
    esac
    
    # 从配置文件中删除
    local temp_file=$(mktemp)
    jq "del(.[$((rule_index-1))])" "$RELAY_CONFIG" > "$temp_file"
    mv "$temp_file" "$RELAY_CONFIG"
    
    print_success "中转规则已删除"
    sleep 2
}

# 启用/禁用中转
toggle_relay() {
    view_relay_rules
    
    if [[ ! -f "$RELAY_CONFIG" ]] || [[ $(jq '. | length' "$RELAY_CONFIG") -eq 0 ]]; then
        return
    fi
    
    read -p "请输入要切换状态的规则序号 (0取消): " rule_index
    
    if [[ "$rule_index" == "0" ]]; then
        return
    fi
    
    local rule_count=$(jq '. | length' "$RELAY_CONFIG")
    if [[ "$rule_index" -lt 1 || "$rule_index" -gt "$rule_count" ]]; then
        print_error "无效的序号"
        sleep 2
        return
    fi
    
    # 切换状态
    local temp_file=$(mktemp)
    jq ".[$((rule_index-1))].enabled = (.[$((rule_index-1))].enabled | not)" "$RELAY_CONFIG" > "$temp_file"
    mv "$temp_file" "$RELAY_CONFIG"
    
    print_success "状态已切换"
    sleep 2
}
