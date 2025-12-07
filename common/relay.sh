#!/bin/bash

# ==================== 中转配置模块 ====================

# 中转配置文件
RELAY_CONFIG="${RELAY_DIR}/relay.json"

# 配置中转
configure_relay() {
    clear
    echo -e "${CYAN}═══════════════════ 中转配置 ═══════════════════${NC}"
    echo ""
    echo "  ${GREEN}1.${NC}  添加中转规则"
    echo "  ${GREEN}2.${NC}  查看中转规则"
    echo "  ${GREEN}3.${NC}  删除中转规则"
    echo "  ${GREEN}4.${NC}  启用/禁用中转"
    echo "  ${GREEN}0.${NC}  返回主菜单"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    
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
    
    # 选择中转类型
    echo "请选择中转类型："
    echo "1) 端口转发 (iptables)"
    echo "2) DNAT 转发"
    echo "3) Socat 转发"
    echo "4) Gost 转发"
    read -p "请选择 [1-4]: " relay_type
    
    case $relay_type in
        1) add_iptables_relay ;;
        2) add_dnat_relay ;;
        3) add_socat_relay ;;
        4) add_gost_relay ;;
        *) print_error "无效的选择"; return ;;
    esac
}

# iptables 端口转发
add_iptables_relay() {
    print_info "配置 iptables 端口转发"
    
    read -p "请输入本地监听端口: " local_port
    read -p "请输入目标IP地址: " target_ip
    read -p "请输入目标端口: " target_port
    read -p "请选择协议 [tcp/udp/both] (默认both): " protocol
    protocol=${protocol:-both}
    
    # 检查端口是否被占用
    if ss -tuln | grep -q ":$local_port "; then
        print_error "端口 $local_port 已被占用"
        return 1
    fi
    
    # 添加转发规则
    if [[ "$protocol" == "both" || "$protocol" == "tcp" ]]; then
        iptables -t nat -A PREROUTING -p tcp --dport $local_port -j DNAT --to-destination ${target_ip}:${target_port}
        iptables -t nat -A POSTROUTING -p tcp -d $target_ip --dport $target_port -j MASQUERADE
        print_success "TCP 转发规则已添加"
    fi
    
    if [[ "$protocol" == "both" || "$protocol" == "udp" ]]; then
        iptables -t nat -A PREROUTING -p udp --dport $local_port -j DNAT --to-destination ${target_ip}:${target_port}
        iptables -t nat -A POSTROUTING -p udp -d $target_ip --dport $target_port -j MASQUERADE
        print_success "UDP 转发规则已添加"
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
    print_info "配置 DNAT 转发"
    
    read -p "请输入本地监听端口: " local_port
    read -p "请输入目标IP地址: " target_ip
    read -p "请输入目标端口: " target_port
    
    # 启用IP转发
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p > /dev/null 2>&1
    
    # 添加DNAT规则
    iptables -t nat -A PREROUTING -p tcp --dport $local_port -j DNAT --to-destination ${target_ip}:${target_port}
    iptables -t nat -A PREROUTING -p udp --dport $local_port -j DNAT --to-destination ${target_ip}:${target_port}
    iptables -t nat -A POSTROUTING -j MASQUERADE
    
    save_relay_rule "dnat" "$local_port" "$target_ip" "$target_port" "both"
    
    print_success "DNAT 转发配置完成"
    read -p "按回车键继续..."
}

# Socat 转发
add_socat_relay() {
    print_info "配置 Socat 转发"
    
    # 检查socat是否安装
    if ! command -v socat &>/dev/null; then
        print_info "安装 socat..."
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            if [[ "$ID" =~ (debian|ubuntu) ]]; then
                apt-get install -y socat
            elif [[ "$ID" =~ (centos|rhel|rocky|almalinux|fedora) ]]; then
                yum install -y socat
            fi
        fi
    else
        print_success "socat 已安装"
    fi
    
    read -p "请输入本地监听端口: " local_port
    read -p "请输入目标IP地址: " target_ip
    read -p "请输入目标端口: " target_port
    read -p "请选择协议 [tcp/udp] (默认tcp): " protocol
    protocol=${protocol:-tcp}
    
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
    systemctl enable socat-relay-${local_port}
    systemctl start socat-relay-${local_port}
    
    save_relay_rule "socat" "$local_port" "$target_ip" "$target_port" "$protocol"
    
    print_success "Socat 转发配置完成"
    read -p "按回车键继续..."
}

# Gost 转发
add_gost_relay() {
    print_info "配置 Gost 转发"
    
    # 检查gost是否安装
    if ! command -v gost &>/dev/null; then
        print_info "安装 gost..."
        install_gost
    fi
    
    read -p "请输入本地监听端口: " local_port
    read -p "请输入目标地址 (格式: ip:port): " target_addr
    
    # 创建gost配置
    cat > /etc/gost/relay-${local_port}.json << EOF
{
  "ServeNodes": [
    "tcp://:${local_port}"
  ],
  "ChainNodes": [
    "tcp://${target_addr}"
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

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable gost-relay-${local_port}
    systemctl start gost-relay-${local_port}
    
    save_relay_rule "gost" "$local_port" "${target_addr%:*}" "${target_addr#*:}" "tcp"
    
    print_success "Gost 转发配置完成"
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
        print_success "Gost 已存在"
        return 0
    fi
    
    print_info "安装 Gost..."
    
    local arch=$(uname -m)
    local gost_arch
    
    case $arch in
        x86_64) gost_arch="linux-amd64" ;;
        aarch64) gost_arch="linux-arm64" ;;
        *) print_error "不支持的架构: $arch"; return 1 ;;
    esac
    
    local latest_version=$(curl -s https://api.github.com/repos/ginuerzh/gost/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
    if [[ -z "$latest_version" ]]; then
        print_error "无法获取 Gost 版本信息"
        return 1
    fi
    
    local download_url="https://github.com/ginuerzh/gost/releases/download/${latest_version}/gost-${gost_arch}-${latest_version#v}.gz"
    
    print_info "下载 Gost ${latest_version}..."
    wget -qO gost.gz "$download_url" || { print_error "下载失败"; return 1; }
    gunzip gost.gz
    chmod +x gost
    mv gost /usr/local/bin/
    mkdir -p /etc/gost
    
    print_success "Gost 安装完成"
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
