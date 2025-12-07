#!/bin/bash

# ==================== Sing-box 原生代理链模块 ====================
# 功能: 使用 Sing-box 现有节点作为中转，为其他节点配置代理链
# 不需要额外的 Gost 服务，纯 Sing-box 实现

# 配置目录（如果未定义）
if [[ -z "$CONFIG_DIR" ]]; then
    CONFIG_DIR="/usr/local/etc/sing-box"
fi

# 配置文件
NATIVE_RELAY_CONFIG="${CONFIG_DIR}/native_relay.conf"

# 检查是否已配置原生代理链
check_native_relay() {
    if [[ -f "$NATIVE_RELAY_CONFIG" ]]; then
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
    echo "  使用 Sing-box 现有节点作为中转节点"
    echo "  其他节点通过中转节点访问目标服务器"
    echo "  纯 Sing-box 实现，无需额外工具"
    echo ""
    echo -e "${CYAN}工作流程:${NC}"
    echo "  客户端 → 中转节点 → 目标节点 → 互联网"
    echo ""
    echo -e "${CYAN}适用场景:${NC}"
    echo "  • 某些节点需要通过另一个节点中转"
    echo "  • 构建多级代理链"
    echo "  • 优化线路（如通过香港中转访问美国）"
    echo ""
    echo -e "${CYAN}与独立工具中转的区别:${NC}"
    echo "  • 独立工具中转: 端口转发，使用 iptables/Gost/Socat"
    echo "  • 原生代理链: Sing-box 节点间中转，纯配置实现"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # 检查是否有节点
    local config_file="${CONFIG_DIR}/config.json"
    
    # 尝试多个可能的配置文件路径
    if [[ ! -f "$config_file" ]]; then
        if [[ -f "/etc/sing-box/config.json" ]]; then
            config_file="/etc/sing-box/config.json"
            CONFIG_DIR="/etc/sing-box"
        elif [[ -f "/usr/local/etc/sing-box/config.json" ]]; then
            config_file="/usr/local/etc/sing-box/config.json"
            CONFIG_DIR="/usr/local/etc/sing-box"
        else
            print_error "Sing-box 配置文件不存在"
            echo ""
            echo -e "${YELLOW}尝试的路径:${NC}"
            echo "  • /usr/local/etc/sing-box/config.json"
            echo "  • /etc/sing-box/config.json"
            echo ""
            print_info "请先添加节点"
            echo ""
            read -p "按回车键继续..."
            return
        fi
    fi
    
    local outbound_count=$(jq '.outbounds | length' "$config_file" 2>/dev/null || echo "0")
    if [[ "$outbound_count" -eq 0 ]]; then
        print_warning "当前没有配置任何节点"
        echo ""
        print_info "请先添加节点"
        read -p "按回车键继续..."
        return
    fi
    
    # 检查是否已有配置
    if check_native_relay; then
        echo -e "${YELLOW}当前已配置原生代理链${NC}"
        echo ""
        view_native_relay_brief
        echo ""
        read -p "是否重新配置? [y/N]: " reconfig
        if [[ ! "$reconfig" =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    # 配置代理链
    configure_relay_chain
}

# 简要显示当前配置
view_native_relay_brief() {
    local config_file="${CONFIG_DIR}/config.json"
    local relay_node=$(grep "^RELAY_NODE=" "$NATIVE_RELAY_CONFIG" 2>/dev/null | cut -d'=' -f2)
    
    if [[ -n "$relay_node" ]]; then
        echo -e "  ${GREEN}中转节点:${NC} ${relay_node}"
        
        # 统计使用中转的节点数量
        local relay_count=$(jq '[.outbounds[] | select(.detour == "'"$relay_node"'")] | length' "$config_file" 2>/dev/null || echo "0")
        echo -e "  ${GREEN}使用中转的节点:${NC} ${relay_count} 个"
    fi
}

# 配置代理链
configure_relay_chain() {
    local config_file="${CONFIG_DIR}/config.json"
    
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                  配置代理链                               ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 步骤 1: 选择中转节点
    echo -e "${GREEN}步骤 1: 选择中转节点${NC}"
    echo ""
    echo "中转节点是用于转发流量的节点，其他节点将通过它访问目标"
    echo ""
    
    # 列出所有节点
    echo -e "${CYAN}当前节点列表:${NC}"
    echo ""
    
    local index=1
    declare -a node_tags
    declare -a node_types
    declare -a node_servers
    
    while IFS='|' read -r tag type server port; do
        node_tags[$index]="$tag"
        node_types[$index]="$type"
        node_servers[$index]="$server"
        
        echo -e "  ${CYAN}[$index]${NC} ${type} - ${tag}"
        echo -e "      服务器: ${server}:${port}"
        echo ""
        
        ((index++))
    done < <(jq -r '.outbounds[] | "\(.tag)|\(.type)|\(.server // "N/A")|\(.server_port // .listen_port // "N/A")"' "$config_file")
    
    if [[ $index -eq 1 ]]; then
        print_error "没有可用的节点"
        read -p "按回车键继续..."
        return
    fi
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    read -p "请选择中转节点 [1-$((index-1))]: " relay_choice
    
    if [[ ! "$relay_choice" =~ ^[0-9]+$ ]] || [[ "$relay_choice" -lt 1 ]] || [[ "$relay_choice" -ge "$index" ]]; then
        print_error "无效的选择"
        sleep 2
        return
    fi
    
    local relay_node="${node_tags[$relay_choice]}"
    
    echo ""
    print_success "已选择中转节点: ${relay_node}"
    echo ""
    
    # 步骤 2: 选择需要中转的节点
    echo -e "${GREEN}步骤 2: 选择需要中转的节点${NC}"
    echo ""
    echo "为以下节点配置通过 ${relay_node} 中转:"
    echo ""
    
    echo -e "${CYAN}可选节点:${NC}"
    echo ""
    
    local target_index=1
    declare -a target_tags
    
    for i in "${!node_tags[@]}"; do
        if [[ "${node_tags[$i]}" != "$relay_node" ]]; then
            target_tags[$target_index]="${node_tags[$i]}"
            echo -e "  ${CYAN}[$target_index]${NC} ${node_types[$i]} - ${node_tags[$i]}"
            ((target_index++))
        fi
    done
    
    echo ""
    echo -e "  ${GREEN}A.${NC}  为所有节点启用中转"
    echo -e "  ${GREEN}0.${NC}  取消"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "输入节点序号（多个用空格分隔，如: 1 2 3）或选择 A"
    read -p "请选择: " target_choice
    
    # 处理选择
    declare -a selected_nodes
    
    if [[ "$target_choice" =~ ^[Aa]$ ]]; then
        # 所有节点
        for tag in "${target_tags[@]}"; do
            selected_nodes+=("$tag")
        done
    elif [[ "$target_choice" == "0" ]]; then
        return
    else
        # 解析输入的序号
        for num in $target_choice; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -lt "$target_index" ]]; then
                selected_nodes+=("${target_tags[$num]}")
            fi
        done
    fi
    
    if [[ ${#selected_nodes[@]} -eq 0 ]]; then
        print_warning "未选择任何节点"
        sleep 2
        return
    fi
    
    # 应用配置
    echo ""
    print_info "正在应用配置..."
    
    local temp_file=$(mktemp)
    cp "$config_file" "$temp_file"
    
    # 为选中的节点添加 detour
    for tag in "${selected_nodes[@]}"; do
        jq ".outbounds |= map(if .tag == \"$tag\" then . + {\"detour\": \"$relay_node\"} else . end)" "$temp_file" > "${temp_file}.tmp"
        mv "${temp_file}.tmp" "$temp_file"
    done
    
    # 备份原配置
    cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 应用新配置
    mv "$temp_file" "$config_file"
    
    # 保存配置信息
    cat > "$NATIVE_RELAY_CONFIG" << EOF
RELAY_NODE=${relay_node}
TARGET_NODES=${selected_nodes[*]}
CREATED=$(date '+%Y-%m-%d %H:%M:%S')
EOF
    
    # 重启 Sing-box
    print_info "重启 Sing-box 服务..."
    if systemctl restart sing-box; then
        print_success "配置已应用"
    else
        print_error "Sing-box 重启失败"
        echo ""
        print_info "正在恢复备份..."
        cp "${config_file}.backup.$(date +%Y%m%d)_"* "$config_file" 2>/dev/null
        systemctl restart sing-box
        read -p "按回车键继续..."
        return
    fi
    
    # 显示配置结果
    clear
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                  配置完成                                 ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}代理链配置:${NC}"
    echo ""
    echo -e "  ${GREEN}中转节点:${NC} ${relay_node}"
    echo -e "  ${GREEN}使用中转的节点:${NC}"
    for tag in "${selected_nodes[@]}"; do
        echo "    • $tag"
    done
    echo ""
    
    echo -e "${CYAN}工作流程:${NC}"
    echo "  客户端 → ${relay_node} → 目标节点 → 互联网"
    echo ""
    
    echo -e "${CYAN}配置文件:${NC}"
    echo "  ${config_file}"
    echo "  备份: ${config_file}.backup.*"
    echo ""
    
    echo -e "${YELLOW}注意:${NC}"
    echo "  • 确保中转节点 ${relay_node} 可以正常连接"
    echo "  • 中转会增加延迟，但可能改善连接质量"
    echo "  • 可以随时在菜单中修改或删除配置"
    echo ""
    
    read -p "按回车键继续..."
}

# 查看原生代理链配置
view_native_relay() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                  原生代理链配置                           ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if ! check_native_relay; then
        print_warning "未配置原生代理链"
        echo ""
        read -p "按回车键继续..."
        return
    fi
    
    # 读取配置
    local relay_node=$(grep "^RELAY_NODE=" "$NATIVE_RELAY_CONFIG" | cut -d'=' -f2)
    local target_nodes=$(grep "^TARGET_NODES=" "$NATIVE_RELAY_CONFIG" | cut -d'=' -f2)
    local created=$(grep "^CREATED=" "$NATIVE_RELAY_CONFIG" | cut -d'=' -f2)
    
    echo -e "${GREEN}中转节点:${NC} ${relay_node}"
    echo -e "${GREEN}创建时间:${NC} ${created}"
    echo ""
    
    echo -e "${CYAN}使用中转的节点:${NC}"
    for tag in $target_nodes; do
        echo "  • $tag"
    done
    echo ""
    
    # 显示实际配置状态
    local config_file="${CONFIG_DIR}/config.json"
    if [[ -f "$config_file" ]]; then
        echo -e "${CYAN}当前配置状态:${NC}"
        echo ""
        
        jq -r '.outbounds[] | select(.detour) | "  • \(.tag) → \(.detour)"' "$config_file"
        
        echo ""
    fi
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
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
    
    # 从 Sing-box 配置中移除所有 detour
    local config_file="${CONFIG_DIR}/config.json"
    if [[ -f "$config_file" ]]; then
        print_info "恢复 Sing-box 节点配置..."
        
        # 备份
        cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
        
        local temp_file=$(mktemp)
        
        # 移除所有 detour 字段
        jq '.outbounds |= map(del(.detour))' "$config_file" > "$temp_file"
        mv "$temp_file" "$config_file"
        
        # 重启 sing-box
        systemctl restart sing-box 2>/dev/null
        print_success "Sing-box 配置已恢复"
    fi
    
    # 删除配置文件
    rm -f "$NATIVE_RELAY_CONFIG"
    
    print_success "原生代理链配置已删除"
}
