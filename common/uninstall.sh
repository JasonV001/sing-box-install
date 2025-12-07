#!/bin/bash

# ==================== 卸载模块 ====================

# 完全卸载
uninstall_all() {
    clear
    echo -e "${RED}═══════════════════ 卸载确认 ═══════════════════${NC}"
    echo ""
    echo -e "${YELLOW}警告: 此操作将完全卸载 Sing-box 及所有配置！${NC}"
    echo ""
    echo "将删除以下内容:"
    echo "  - Sing-box 程序"
    echo "  - 所有配置文件"
    echo "  - 所有证书文件"
    echo "  - 所有节点信息"
    echo "  - 中转配置"
    echo "  - Argo 隧道"
    echo ""
    
    read -p "确认卸载? 输入 'yes' 继续: " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_info "取消卸载"
        sleep 2
        return
    fi
    
    print_warning "开始卸载..."
    echo ""
    
    # 停止服务
    print_info "停止服务..."
    systemctl stop sing-box 2>/dev/null
    systemctl stop argo-quick 2>/dev/null
    systemctl stop argo-tunnel 2>/dev/null
    
    # 禁用服务
    print_info "禁用服务..."
    systemctl disable sing-box 2>/dev/null
    systemctl disable argo-quick 2>/dev/null
    systemctl disable argo-tunnel 2>/dev/null
    
    # 删除服务文件
    print_info "删除服务文件..."
    rm -f /etc/systemd/system/sing-box.service
    rm -f /etc/systemd/system/argo-quick.service
    rm -f /etc/systemd/system/argo-tunnel.service
    rm -f /etc/systemd/system/socat-relay-*.service
    rm -f /etc/systemd/system/gost-relay-*.service
    
    systemctl daemon-reload
    
    # 删除程序文件
    print_info "删除程序文件..."
    rm -f /usr/local/bin/sing-box
    rm -f /usr/local/bin/cloudflared
    rm -f /usr/local/bin/gost
    
    # 删除配置目录
    print_info "删除配置文件..."
    rm -rf "${CONFIG_DIR}"
    rm -rf "${CERT_DIR}"
    rm -rf "${ARGO_DIR}"
    rm -rf "${RELAY_DIR}"
    rm -rf ~/.cloudflared
    rm -rf /etc/gost
    
    # 清理iptables规则
    print_info "清理防火墙规则..."
    if [[ -f "${RELAY_DIR}/relay.json" ]]; then
        # 读取所有中转规则并清理
        jq -r '.[] | select(.type == "iptables" or .type == "dnat") | .local_port' "${RELAY_DIR}/relay.json" 2>/dev/null | while read -r port; do
            iptables -t nat -D PREROUTING -p tcp --dport $port -j DNAT 2>/dev/null
            iptables -t nat -D PREROUTING -p udp --dport $port -j DNAT 2>/dev/null
        done
    fi
    
    # 保存iptables规则
    if command -v netfilter-persistent &>/dev/null; then
        netfilter-persistent save
    elif command -v iptables-save &>/dev/null; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null
    fi
    
    # 删除脚本目录
    print_info "删除脚本文件..."
    if [[ -n "$SCRIPT_DIR" && "$SCRIPT_DIR" != "/" ]]; then
        rm -rf "${SCRIPT_DIR}/protocols"
        rm -rf "${SCRIPT_DIR}/common"
    fi
    
    print_success "卸载完成！"
    echo ""
    echo "感谢使用 Sing-box 一键脚本"
    echo ""
    
    exit 0
}

# 部分卸载
uninstall_partial() {
    clear
    echo -e "${CYAN}═══════════════════ 部分卸载 ═══════════════════${NC}"
    echo ""
    echo "  ${GREEN}1.${NC}  仅卸载 Sing-box (保留配置)"
    echo "  ${GREEN}2.${NC}  仅卸载 Argo 隧道"
    echo "  ${GREEN}3.${NC}  仅清理中转规则"
    echo "  ${GREEN}4.${NC}  清理所有节点配置"
    echo "  ${GREEN}0.${NC}  返回"
    echo ""
    
    read -p "请选择 [0-4]: " choice
    
    case $choice in
        1) uninstall_singbox_only ;;
        2) uninstall_argo_only ;;
        3) clean_relay_rules ;;
        4) clean_all_nodes ;;
        0) return ;;
        *) print_error "无效的选择"; sleep 2; uninstall_partial ;;
    esac
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
