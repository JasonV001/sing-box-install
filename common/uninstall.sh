#!/bin/bash

# ==================== 卸载模块 ====================

# 卸载主菜单
uninstall_menu() {
    clear
    echo -e "${CYAN}═══════════════════ 卸载选项 ═══════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC}  单独卸载 (选择要卸载的项目)"
    echo -e "  ${RED}2.${NC}  完全卸载 (删除所有内容)"
    echo -e "  ${GREEN}0.${NC}  返回主菜单"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    
    read -p "请选择 [0-2]: " choice
    
    case $choice in
        1) uninstall_selective ;;
        2) uninstall_all ;;
        0) return ;;
        *) print_error "无效的选择"; sleep 2; uninstall_menu ;;
    esac
}

# 单独卸载
uninstall_selective() {
    clear
    echo -e "${CYAN}═══════════════════ 单独卸载 ═══════════════════${NC}"
    echo ""
    echo -e "${YELLOW}请选择要卸载的项目 (可多选，用空格分隔):${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC}  Sing-box 程序"
    echo -e "  ${GREEN}2.${NC}  所有配置文件"
    echo -e "  ${GREEN}3.${NC}  所有证书文件"
    echo -e "  ${GREEN}4.${NC}  所有节点信息"
    echo -e "  ${GREEN}5.${NC}  中转配置"
    echo -e "  ${GREEN}6.${NC}  Argo 隧道"
    echo -e "  ${GREEN}0.${NC}  返回"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}示例: 输入 '1 5 6' 将卸载 Sing-box程序、中转配置和Argo隧道${NC}"
    echo ""
    
    read -p "请输入选项 (用空格分隔): " selections
    
    if [[ "$selections" == "0" ]]; then
        uninstall_menu
        return
    fi
    
    # 确认卸载
    echo ""
    echo -e "${YELLOW}即将卸载以下项目:${NC}"
    for sel in $selections; do
        case $sel in
            1) echo "  - Sing-box 程序" ;;
            2) echo "  - 所有配置文件" ;;
            3) echo "  - 所有证书文件" ;;
            4) echo "  - 所有节点信息" ;;
            5) echo "  - 中转配置" ;;
            6) echo "  - Argo 隧道" ;;
        esac
    done
    echo ""
    
    read -p "确认卸载? 输入 'yes' 继续: " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_info "取消卸载"
        sleep 2
        uninstall_menu
        return
    fi
    
    echo ""
    print_warning "开始卸载..."
    echo ""
    
    # 执行卸载
    for sel in $selections; do
        case $sel in
            1) uninstall_singbox_program ;;
            2) uninstall_config_files ;;
            3) uninstall_certificates ;;
            4) uninstall_node_info ;;
            5) uninstall_relay_config ;;
            6) uninstall_argo_tunnel ;;
        esac
    done
    
    echo ""
    print_success "选定项目卸载完成！"
    echo ""
    read -p "按回车键继续..."
    uninstall_menu
}

# 1. 卸载 Sing-box 程序
uninstall_singbox_program() {
    print_info "[1/6] 卸载 Sing-box 程序..."
    
    # 停止服务
    systemctl stop sing-box 2>/dev/null
    systemctl disable sing-box 2>/dev/null
    
    # 删除服务文件
    rm -f /etc/systemd/system/sing-box.service
    
    # 删除程序文件
    rm -f /usr/local/bin/sing-box
    
    systemctl daemon-reload
    
    print_success "Sing-box 程序已卸载"
}

# 2. 卸载所有配置文件
uninstall_config_files() {
    print_info "[2/6] 卸载所有配置文件..."
    
    # 备份配置
    if [[ -f "${CONFIG_DIR}/config.json" ]]; then
        local backup_file="${CONFIG_DIR}/config.json.bak.$(date +%Y%m%d_%H%M%S)"
        cp "${CONFIG_DIR}/config.json" "$backup_file" 2>/dev/null
        print_info "配置已备份到: $backup_file"
    fi
    
    # 删除配置目录
    rm -rf "${CONFIG_DIR}"
    
    print_success "所有配置文件已删除"
}

# 3. 卸载所有证书文件
uninstall_certificates() {
    print_info "[3/6] 卸载所有证书文件..."
    
    # 备份证书
    if [[ -d "${CERT_DIR}" ]]; then
        local backup_dir="${CERT_DIR}.bak.$(date +%Y%m%d_%H%M%S)"
        cp -r "${CERT_DIR}" "$backup_dir" 2>/dev/null
        print_info "证书已备份到: $backup_dir"
    fi
    
    # 删除证书目录
    rm -rf "${CERT_DIR}/sing-box"*
    
    print_success "所有证书文件已删除"
}

# 4. 卸载所有节点信息
uninstall_node_info() {
    print_info "[4/6] 卸载所有节点信息..."
    
    # 删除链接文件
    rm -rf "${LINK_DIR}"
    
    # 清空配置中的inbounds
    if [[ -f "${CONFIG_DIR}/config.json" ]]; then
        local temp_file=$(mktemp)
        jq '.inbounds = []' "${CONFIG_DIR}/config.json" > "$temp_file" 2>/dev/null
        mv "$temp_file" "${CONFIG_DIR}/config.json"
        
        # 重启服务
        systemctl restart sing-box 2>/dev/null
    fi
    
    print_success "所有节点信息已删除"
}

# 5. 卸载中转配置
uninstall_relay_config() {
    print_info "[5/6] 卸载中转配置..."
    
    # 停止所有中转服务
    systemctl stop socat-relay-* 2>/dev/null
    systemctl stop gost-relay-* 2>/dev/null
    systemctl disable socat-relay-* 2>/dev/null
    systemctl disable gost-relay-* 2>/dev/null
    
    # 删除服务文件
    rm -f /etc/systemd/system/socat-relay-*.service
    rm -f /etc/systemd/system/gost-relay-*.service
    
    # 删除gost配置
    rm -rf /etc/gost
    rm -f /usr/local/bin/gost
    
    # 清理iptables规则
    if [[ -f "${RELAY_DIR}/relay.json" ]]; then
        jq -r '.[] | select(.type == "iptables" or .type == "dnat") | .local_port' "${RELAY_DIR}/relay.json" 2>/dev/null | while read -r port; do
            iptables -t nat -D PREROUTING -p tcp --dport $port -j DNAT 2>/dev/null
            iptables -t nat -D PREROUTING -p udp --dport $port -j DNAT 2>/dev/null
            iptables -t nat -D POSTROUTING -p tcp -d 0.0.0.0/0 --dport $port -j MASQUERADE 2>/dev/null
            iptables -t nat -D POSTROUTING -p udp -d 0.0.0.0/0 --dport $port -j MASQUERADE 2>/dev/null
        done
    fi
    
    # 保存iptables规则
    if command -v netfilter-persistent &>/dev/null; then
        netfilter-persistent save 2>/dev/null
    elif command -v iptables-save &>/dev/null; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null
    fi
    
    # 删除中转配置目录
    rm -rf "${RELAY_DIR}"
    
    systemctl daemon-reload
    
    print_success "中转配置已删除"
}

# 6. 卸载 Argo 隧道
uninstall_argo_tunnel() {
    print_info "[6/6] 卸载 Argo 隧道..."
    
    # 停止服务
    systemctl stop argo-quick 2>/dev/null
    systemctl stop argo-tunnel 2>/dev/null
    systemctl disable argo-quick 2>/dev/null
    systemctl disable argo-tunnel 2>/dev/null
    
    # 删除服务文件
    rm -f /etc/systemd/system/argo-quick.service
    rm -f /etc/systemd/system/argo-tunnel.service
    
    # 删除程序和配置
    rm -f /usr/local/bin/cloudflared
    rm -rf "${ARGO_DIR}"
    rm -rf ~/.cloudflared
    
    # 删除Argo节点链接
    rm -f "${LINK_DIR}"/argo_*.txt
    
    systemctl daemon-reload
    
    print_success "Argo 隧道已卸载"
}

# 完全卸载
uninstall_all() {
    clear
    echo -e "${RED}═══════════════════ 完全卸载确认 ═══════════════════${NC}"
    echo ""
    echo -e "${YELLOW}警告: 此操作将完全卸载 Sing-box 及所有配置！${NC}"
    echo ""
    echo "将删除以下所有内容:"
    echo "  ✗ Sing-box 程序"
    echo "  ✗ 所有配置文件"
    echo "  ✗ 所有证书文件"
    echo "  ✗ 所有节点信息"
    echo "  ✗ 中转配置"
    echo "  ✗ Argo 隧道"
    echo ""
    echo -e "${RED}此操作不可恢复！${NC}"
    echo ""
    
    read -p "确认完全卸载? 输入 'yes' 继续: " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_info "取消卸载"
        sleep 2
        uninstall_menu
        return
    fi
    
    echo ""
    print_warning "开始完全卸载..."
    echo ""
    
    # 执行所有卸载操作
    uninstall_singbox_program
    uninstall_relay_config
    uninstall_argo_tunnel
    uninstall_certificates
    uninstall_node_info
    uninstall_config_files
    
    # 删除脚本目录
    print_info "删除脚本文件..."
    if [[ -n "$SCRIPT_DIR" && "$SCRIPT_DIR" != "/" && "$SCRIPT_DIR" != "/root" ]]; then
        rm -rf "${SCRIPT_DIR}/protocols"
        rm -rf "${SCRIPT_DIR}/common"
    fi
    
    echo ""
    print_success "完全卸载完成！"
    echo ""
    echo "感谢使用 Sing-box 一键脚本"
    echo ""
    
    exit 0
}

# 部分卸载 (保留兼容性)
uninstall_partial() {
    uninstall_selective
}

# 仅卸载Sing-box
uninstall_singbox_only() {
    print_warning "确认卸载 Sing-box (保留配置文件)?"
    read -p "输入 yes 确认: " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_info "取消操作"
        sleep 2
        return
    fi
    
    systemctl stop sing-box
    systemctl disable sing-box
    rm -f /etc/systemd/system/sing-box.service
    rm -f /usr/local/bin/sing-box
    systemctl daemon-reload
    
    print_success "Sing-box 已卸载 (配置文件保留在 ${CONFIG_DIR})"
    sleep 2
}

# 仅卸载Argo
uninstall_argo_only() {
    print_warning "确认卸载 Argo 隧道?"
    read -p "输入 yes 确认: " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_info "取消操作"
        sleep 2
        return
    fi
    
    systemctl stop argo-quick 2>/dev/null
    systemctl stop argo-tunnel 2>/dev/null
    systemctl disable argo-quick 2>/dev/null
    systemctl disable argo-tunnel 2>/dev/null
    
    rm -f /etc/systemd/system/argo-quick.service
    rm -f /etc/systemd/system/argo-tunnel.service
    rm -f /usr/local/bin/cloudflared
    rm -rf "${ARGO_DIR}"
    rm -rf ~/.cloudflared
    
    systemctl daemon-reload
    
    print_success "Argo 隧道已卸载"
    sleep 2
}

# 清理中转规则
clean_relay_rules() {
    print_warning "确认清理所有中转规则?"
    read -p "输入 yes 确认: " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_info "取消操作"
        sleep 2
        return
    fi
    
    # 停止所有中转服务
    systemctl stop socat-relay-* 2>/dev/null
    systemctl stop gost-relay-* 2>/dev/null
    systemctl disable socat-relay-* 2>/dev/null
    systemctl disable gost-relay-* 2>/dev/null
    
    rm -f /etc/systemd/system/socat-relay-*.service
    rm -f /etc/systemd/system/gost-relay-*.service
    rm -rf /etc/gost
    
    # 清理iptables规则
    if [[ -f "${RELAY_DIR}/relay.json" ]]; then
        jq -r '.[] | .local_port' "${RELAY_DIR}/relay.json" 2>/dev/null | while read -r port; do
            iptables -t nat -D PREROUTING -p tcp --dport $port -j DNAT 2>/dev/null
            iptables -t nat -D PREROUTING -p udp --dport $port -j DNAT 2>/dev/null
        done
    fi
    
    rm -rf "${RELAY_DIR}"
    
    systemctl daemon-reload
    
    print_success "中转规则已清理"
    sleep 2
}

# 清理所有节点
clean_all_nodes() {
    print_warning "确认清理所有节点配置?"
    read -p "输入 yes 确认: " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_info "取消操作"
        sleep 2
        return
    fi
    
    # 备份当前配置
    if [[ -f "${CONFIG_DIR}/config.json" ]]; then
        cp "${CONFIG_DIR}/config.json" "${CONFIG_DIR}/config.json.bak.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # 创建空配置
    cat > "${CONFIG_DIR}/config.json" << EOF
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
    
    # 清理链接文件
    rm -rf "${LINK_DIR}"
    mkdir -p "${LINK_DIR}"
    
    # 重启服务
    systemctl restart sing-box
    
    print_success "所有节点配置已清理"
    print_info "原配置已备份到 ${CONFIG_DIR}/config.json.bak.*"
    sleep 2
}
