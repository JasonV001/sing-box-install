#!/bin/bash

# ==================== 节点查看模块 ====================

# 查看所有节点
view_nodes() {
    clear
    echo -e "${CYAN}═══════════════════ 节点信息 ═══════════════════${NC}"
    echo ""
    
    local config_file="${CONFIG_DIR}/config.json"
    local has_nodes=false
    
    # 收集所有节点信息
    declare -A node_types
    declare -a node_list
    
    # 检查 Sing-box 节点
    if [[ -f "$config_file" ]]; then
        local inbound_count=$(jq '.inbounds | length' "$config_file" 2>/dev/null || echo "0")
        
        if [[ "$inbound_count" -gt 0 ]]; then
            has_nodes=true
            
            # 遍历所有inbounds，按协议分类
            while IFS='|' read -r type tag port; do
                # 统计每种协议的数量
                if [[ -z "${node_types[$type]}" ]]; then
                    node_types[$type]=1
                else
                    node_types[$type]=$((${node_types[$type]} + 1))
                fi
                
                # 保存节点信息
                node_list+=("$type|$tag|$port|singbox")
            done < <(jq -r '.inbounds[] | "\(.type)|\(.tag)|\(.listen_port)"' "$config_file")
        fi
    fi
    
    # 检查 Argo 隧道节点
    if [[ -d "${LINK_DIR}" ]]; then
        local argo_count=0
        while IFS= read -r argo_file; do
            [[ -z "$argo_file" ]] && continue
            local filename=$(basename "$argo_file")
            
            if [[ "$filename" =~ argo_(quick|token|json)_([0-9]+)\.txt ]]; then
                local argo_type="${BASH_REMATCH[1]}"
                local port="${BASH_REMATCH[2]}"
                node_list+=("argo|$argo_type|$port|argo")
                ((argo_count++))
            fi
        done < <(find "${LINK_DIR}" -name "argo_*.txt" ! -name "argo_node_*.txt" 2>/dev/null)
        
        if [[ $argo_count -gt 0 ]]; then
            has_nodes=true
            node_types["argo"]=$argo_count
        fi
    fi
    
    if [[ "$has_nodes" == false ]]; then
        print_warning "暂无配置的节点"
        echo ""
        read -p "按回车键继续..."
        return
    fi
    
    # 显示节点分类菜单
    local menu_index=1
    declare -A menu_map
    
    # SOCKS 节点
    if [[ -n "${node_types[socks]}" ]]; then
        echo -e "  ${GREEN}[$menu_index]${NC}  SOCKS 节点 (${node_types[socks]} 个)"
        menu_map[$menu_index]="socks"
        ((menu_index++))
    fi
    
    # Shadowsocks 节点
    if [[ -n "${node_types[shadowsocks]}" ]]; then
        echo -e "  ${GREEN}[$menu_index]${NC}  Shadowsocks 节点 (${node_types[shadowsocks]} 个)"
        menu_map[$menu_index]="shadowsocks"
        ((menu_index++))
    fi
    
    # VLESS 节点
    if [[ -n "${node_types[vless]}" ]]; then
        echo -e "  ${GREEN}[$menu_index]${NC}  VLESS 节点 (${node_types[vless]} 个)"
        menu_map[$menu_index]="vless"
        ((menu_index++))
    fi
    
    # VMess 节点
    if [[ -n "${node_types[vmess]}" ]]; then
        echo -e "  ${GREEN}[$menu_index]${NC}  VMess 节点 (${node_types[vmess]} 个)"
        menu_map[$menu_index]="vmess"
        ((menu_index++))
    fi
    
    # Trojan 节点
    if [[ -n "${node_types[trojan]}" ]]; then
        echo -e "  ${GREEN}[$menu_index]${NC}  Trojan 节点 (${node_types[trojan]} 个)"
        menu_map[$menu_index]="trojan"
        ((menu_index++))
    fi
    
    # Hysteria2 节点
    if [[ -n "${node_types[hysteria2]}" ]]; then
        echo -e "  ${GREEN}[$menu_index]${NC}  Hysteria2 节点 (${node_types[hysteria2]} 个)"
        menu_map[$menu_index]="hysteria2"
        ((menu_index++))
    fi
    
    # TUIC 节点
    if [[ -n "${node_types[tuic]}" ]]; then
        echo -e "  ${GREEN}[$menu_index]${NC}  TUIC 节点 (${node_types[tuic]} 个)"
        menu_map[$menu_index]="tuic"
        ((menu_index++))
    fi
    
    # Juicity 节点
    if [[ -n "${node_types[juicity]}" ]]; then
        echo -e "  ${GREEN}[$menu_index]${NC}  Juicity 节点 (${node_types[juicity]} 个)"
        menu_map[$menu_index]="juicity"
        ((menu_index++))
    fi
    
    # Argo 隧道节点
    if [[ -n "${node_types[argo]}" ]]; then
        echo -e "  ${GREEN}[$menu_index]${NC}  Argo 隧道节点 (${node_types[argo]} 个)"
        menu_map[$menu_index]="argo"
        ((menu_index++))
    fi
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}A.${NC}  查看所有节点链接"
    echo -e "  ${GREEN}B.${NC}  导出所有链接"
    echo -e "  ${GREEN}C.${NC}  生成订阅链接"
    echo -e "  ${GREEN}D.${NC}  查看配置文件路径"
    echo -e "  ${GREEN}0.${NC}  返回主菜单"
    echo ""
    
    read -p "请选择 [1-$((menu_index-1))/A-D/0]: " choice
    
    case $choice in
        [1-9]|[1-9][0-9])
            if [[ -n "${menu_map[$choice]}" ]]; then
                view_protocol_nodes "${menu_map[$choice]}" "${node_list[@]}"
            else
                print_error "无效的选择"
                sleep 2
                view_nodes
            fi
            ;;
        [Aa]) view_all_node_links ;;
        [Bb]) export_all_links ;;
        [Cc]) generate_subscription ;;
        [Dd]) view_config_paths ;;
        0) return ;;
        *) print_error "无效的选择"; sleep 2; view_nodes ;;
    esac
}

# 查看指定协议的节点
view_protocol_nodes() {
    local protocol=$1
    shift
    local node_list=("$@")
    
    clear
    
    case $protocol in
        socks) echo -e "${CYAN}═══════════════════ SOCKS 节点 ═══════════════════${NC}" ;;
        shadowsocks) echo -e "${CYAN}═══════════════════ Shadowsocks 节点 ═══════════════════${NC}" ;;
        vless) echo -e "${CYAN}═══════════════════ VLESS 节点 ═══════════════════${NC}" ;;
        vmess) echo -e "${CYAN}═══════════════════ VMess 节点 ═══════════════════${NC}" ;;
        trojan) echo -e "${CYAN}═══════════════════ Trojan 节点 ═══════════════════${NC}" ;;
        hysteria2) echo -e "${CYAN}═══════════════════ Hysteria2 节点 ═══════════════════${NC}" ;;
        tuic) echo -e "${CYAN}═══════════════════ TUIC 节点 ═══════════════════${NC}" ;;
        juicity) echo -e "${CYAN}═══════════════════ Juicity 节点 ═══════════════════${NC}" ;;
        argo) echo -e "${CYAN}═══════════════════ Argo 隧道节点 ═══════════════════${NC}" ;;
    esac
    echo ""
    
    local node_index=1
    
    for node_info in "${node_list[@]}"; do
        IFS='|' read -r type tag port source <<< "$node_info"
        
        if [[ "$protocol" == "argo" && "$type" == "argo" ]]; then
            # Argo 节点
            echo -e "${GREEN}[$node_index]${NC} Argo Tunnel - ${tag^}"
            echo ""
            
            local argo_file="${LINK_DIR}/argo_${tag}_${port}.txt"
            if [[ -f "$argo_file" ]]; then
                local domain=$(grep -E "临时域名:|域名:" "$argo_file" | head -1 | awk '{print $2}')
                echo "  端口: ${port}"
                [[ -n "$domain" ]] && echo "  域名: ${domain}"
                echo ""
                
                # 显示节点链接
                local node_link_file="${LINK_DIR}/argo_node_${port}.txt"
                if [[ -f "$node_link_file" ]]; then
                    echo -e "${CYAN}  【直连链接】${NC}"
                    grep "【直连链接】" -A 1 "$node_link_file" | tail -1 | sed 's/^/    /'
                    echo ""
                    
                    echo -e "${CYAN}  【CF 优选 IP】${NC}"
                    grep "【CF 优选 IP】" -A 1 "$node_link_file" | tail -1 | sed 's/^/    /'
                    echo ""
                    
                    echo -e "${CYAN}  【非 TLS 链接】${NC}"
                    grep "【非 TLS 链接】" -A 1 "$node_link_file" | tail -1 | sed 's/^/    /'
                    echo ""
                fi
            fi
            
            ((node_index++))
            
        elif [[ "$type" == "$protocol" && "$source" == "singbox" ]]; then
            # Sing-box 节点
            echo -e "${GREEN}[$node_index]${NC} ${tag}"
            echo ""
            echo "  端口: ${port}"
            
            # 查找链接文件
            local link_file=$(find "${LINK_DIR}" -name "*_${port}.txt" ! -name "argo_*" 2>/dev/null | head -1)
            if [[ -f "$link_file" ]]; then
                echo ""
                # 提取分享链接
                local share_link=$(grep -E "^(vmess|vless|trojan|ss|hysteria2|socks5|tuic|juicity)://" "$link_file" | head -1)
                if [[ -n "$share_link" ]]; then
                    echo -e "${CYAN}  节点链接:${NC}"
                    echo "    $share_link"
                fi
            fi
            echo ""
            
            ((node_index++))
        fi
    done
    
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC}  查看详细配置文件"
    echo -e "  ${GREEN}2.${NC}  查看完整链接信息"
    echo -e "  ${GREEN}0.${NC}  返回"
    echo ""
    
    read -p "请选择 [0-2]: " sub_choice
    
    case $sub_choice in
        1) view_protocol_config "$protocol" ;;
        2) view_protocol_links "$protocol" ;;
        0) view_nodes ;;
        *) print_error "无效的选择"; sleep 2; view_protocol_nodes "$protocol" "${node_list[@]}" ;;
    esac
}

# 查看协议配置文件
view_protocol_config() {
    local protocol=$1
    
    clear
    echo -e "${CYAN}═══════════════════ 配置文件 ═══════════════════${NC}"
    echo ""
    
    local config_file="${CONFIG_DIR}/config.json"
    
    if [[ "$protocol" == "argo" ]]; then
        echo "Argo 配置文件位置:"
        echo ""
        [[ -f /etc/systemd/system/argo-quick.service ]] && echo "  Quick Tunnel: /etc/systemd/system/argo-quick.service"
        [[ -f /etc/systemd/system/argo-tunnel.service ]] && echo "  Token/JSON: /etc/systemd/system/argo-tunnel.service"
        [[ -f "${ARGO_DIR}/config.yml" ]] && echo "  配置文件: ${ARGO_DIR}/config.yml"
        [[ -f "${ARGO_DIR}/token.txt" ]] && echo "  Token: ${ARGO_DIR}/token.txt"
        echo ""
    else
        echo "Sing-box 配置文件: ${config_file}"
        echo ""
        echo -e "${CYAN}${protocol} 节点配置:${NC}"
        echo ""
        jq ".inbounds[] | select(.type == \"$protocol\")" "$config_file" 2>/dev/null || echo "无配置"
    fi
    
    echo ""
    read -p "按回车键返回..."
    view_nodes
}

# 查看协议完整链接
view_protocol_links() {
    local protocol=$1
    
    clear
    echo -e "${CYAN}═══════════════════ 完整链接信息 ═══════════════════${NC}"
    echo ""
    
    if [[ "$protocol" == "argo" ]]; then
        # 显示所有 Argo 链接文件
        for argo_file in ${LINK_DIR}/argo_node_*.txt; do
            [[ -f "$argo_file" ]] && cat "$argo_file" && echo ""
        done
    else
        # 显示指定协议的链接文件
        local config_file="${CONFIG_DIR}/config.json"
        while IFS='|' read -r type tag port; do
            if [[ "$type" == "$protocol" ]]; then
                local link_file=$(find "${LINK_DIR}" -name "*_${port}.txt" ! -name "argo_*" 2>/dev/null | head -1)
                [[ -f "$link_file" ]] && cat "$link_file" && echo ""
            fi
        done < <(jq -r '.inbounds[] | "\(.type)|\(.tag)|\(.listen_port)"' "$config_file" 2>/dev/null)
    fi
    
    echo ""
    read -p "按回车键返回..."
    view_nodes
}

# 查看所有节点链接
view_all_node_links() {
    clear
    echo -e "${CYAN}═══════════════════ 所有节点链接 ═══════════════════${NC}"
    echo ""
    
    if [[ ! -d "${LINK_DIR}" ]] || [[ -z "$(ls -A ${LINK_DIR} 2>/dev/null)" ]]; then
        print_warning "暂无生成的分享链接"
        echo ""
        read -p "按回车键继续..."
        view_nodes
        return
    fi
    
    # 显示所有链接
    for file in ${LINK_DIR}/*.txt; do
        [[ -f "$file" ]] && cat "$file" && echo ""
    done
    
    echo ""
    read -p "按回车键返回..."
    view_nodes
}

# 查看配置文件路径
view_config_paths() {
    clear
    echo -e "${CYAN}═══════════════════ 配置文件路径 ═══════════════════${NC}"
    echo ""
    
    echo -e "${GREEN}【Sing-box】${NC}"
    echo "  配置目录: ${CONFIG_DIR}"
    echo "  配置文件: ${CONFIG_DIR}/config.json"
    echo "  证书目录: ${CERT_DIR}"
    echo "  链接目录: ${LINK_DIR}"
    echo ""
    
    echo -e "${GREEN}【Argo 隧道】${NC}"
    echo "  安装目录: ${ARGO_DIR}"
    echo "  日志文件: ${ARGO_DIR}/argo.log"
    [[ -f "${ARGO_DIR}/config.yml" ]] && echo "  配置文件: ${ARGO_DIR}/config.yml"
    [[ -f "${ARGO_DIR}/token.txt" ]] && echo "  Token 文件: ${ARGO_DIR}/token.txt"
    [[ -f "${ARGO_DIR}/domain.txt" ]] && echo "  域名文件: ${ARGO_DIR}/domain.txt"
    echo ""
    
    echo -e "${GREEN}【系统服务】${NC}"
    echo "  Sing-box: /etc/systemd/system/sing-box.service"
    [[ -f /etc/systemd/system/argo-quick.service ]] && echo "  Argo Quick: /etc/systemd/system/argo-quick.service"
    [[ -f /etc/systemd/system/argo-tunnel.service ]] && echo "  Argo Tunnel: /etc/systemd/system/argo-tunnel.service"
    echo ""
    
    read -p "按回车键返回..."
    view_nodes
}

# 查看节点详细配置
view_node_config() {
    clear
    print_info "节点详细配置"
    echo ""
    
    local config_file="${CONFIG_DIR}/config.json"
    
    if command -v jq &>/dev/null; then
        jq '.' "$config_file"
    else
        cat "$config_file"
    fi
    
    echo ""
    read -p "按回车键继续..."
    view_nodes
}

# 查看节点分享链接
view_node_links() {
    clear
    print_info "节点分享链接"
    echo ""
    
    if [[ ! -d "${LINK_DIR}" ]] || [[ -z "$(ls -A ${LINK_DIR} 2>/dev/null)" ]]; then
        print_warning "暂无生成的分享链接"
        read -p "按回车键继续..."
        view_nodes
        return
    fi
    
    # 列出所有链接文件
    local files=(${LINK_DIR}/*.txt)
    local index=1
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            echo -e "${CYAN}[$index]${NC} $(basename "$file")"
            ((index++))
        fi
    done
    
    echo ""
    read -p "请选择要查看的文件序号 (0返回): " file_index
    
    if [[ "$file_index" == "0" ]]; then
        view_nodes
        return
    fi
    
    if [[ "$file_index" -ge 1 && "$file_index" -lt "$index" ]]; then
        local selected_file="${files[$((file_index-1))]}"
        clear
        cat "$selected_file"
        echo ""
        read -p "按回车键继续..."
    else
        print_error "无效的选择"
        sleep 2
    fi
    
    view_node_links
}

# 导出所有链接
export_all_links() {
    clear
    print_info "导出所有节点链接"
    echo ""
    
    if [[ ! -d "${LINK_DIR}" ]] || [[ -z "$(ls -A ${LINK_DIR} 2>/dev/null)" ]]; then
        print_warning "暂无生成的分享链接"
        read -p "按回车键继续..."
        view_nodes
        return
    fi
    
    local export_file="${CONFIG_DIR}/all_links.txt"
    
    cat > "$export_file" << EOF
========================================
所有节点分享链接
生成时间: $(date '+%Y-%m-%d %H:%M:%S')
========================================

EOF
    
    # 合并所有链接文件
    for file in ${LINK_DIR}/*.txt; do
        if [[ -f "$file" ]]; then
            cat "$file" >> "$export_file"
            echo "" >> "$export_file"
        fi
    done
    
    print_success "所有链接已导出到: ${export_file}"
    echo ""
    cat "$export_file"
    echo ""
    read -p "按回车键继续..."
    view_nodes
}

# 生成订阅链接
generate_subscription() {
    clear
    print_info "生成订阅链接"
    echo ""
    
    if [[ ! -d "${LINK_DIR}" ]] || [[ -z "$(ls -A ${LINK_DIR} 2>/dev/null)" ]]; then
        print_warning "暂无生成的分享链接"
        read -p "按回车键继续..."
        view_nodes
        return
    fi
    
    local sub_file="${CONFIG_DIR}/subscription.txt"
    
    # 提取所有分享链接
    > "$sub_file"
    
    for file in ${LINK_DIR}/*.txt; do
        if [[ -f "$file" ]]; then
            # 提取以协议开头的链接行
            grep -E '^(vmess|vless|trojan|ss|hysteria2|socks5|tuic|juicity)://' "$file" >> "$sub_file"
        fi
    done
    
    # Base64编码
    local sub_base64="${CONFIG_DIR}/subscription_base64.txt"
    base64 -w 0 "$sub_file" > "$sub_base64"
    
    print_success "订阅链接已生成"
    echo ""
    echo "原始订阅文件: ${sub_file}"
    echo "Base64订阅文件: ${sub_base64}"
    echo ""
    echo "订阅内容 (Base64):"
    cat "$sub_base64"
    echo ""
    echo ""
    print_info "使用方法:"
    echo "1. 将 Base64 内容复制到支持订阅的客户端"
    echo "2. 或者通过 HTTP 服务器提供订阅链接"
    echo ""
    read -p "按回车键继续..."
    view_nodes
}

# 查看服务状态
view_service_status() {
    clear
    print_info "Sing-box 服务状态"
    echo ""
    
    systemctl status sing-box
    
    echo ""
    echo -e "${CYAN}进程信息:${NC}"
    ps aux | grep sing-box | grep -v grep
    
    echo ""
    echo -e "${CYAN}端口监听:${NC}"
    ss -tuln | grep -E ':(443|1080|8080|10000)' || echo "无监听端口"
    
    echo ""
    read -p "按回车键继续..."
}
