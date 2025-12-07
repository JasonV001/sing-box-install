#!/bin/bash

# ==================== 节点查看模块 ====================

# 查看所有节点
view_nodes() {
    clear
    echo -e "${CYAN}═══════════════════ 节点信息 ═══════════════════${NC}"
    echo ""
    
    local config_file="${CONFIG_DIR}/config.json"
    local has_nodes=false
    
    # 检查 Sing-box 节点
    if [[ -f "$config_file" ]]; then
        local inbound_count=$(jq '.inbounds | length' "$config_file" 2>/dev/null || echo "0")
        
        if [[ "$inbound_count" -gt 0 ]]; then
            has_nodes=true
            echo -e "${GREEN}【Sing-box 节点】${NC}"
            echo ""
            
            # 遍历所有inbounds
            local index=1
            jq -r '.inbounds[] | "\(.type)|\(.tag)|\(.listen_port)"' "$config_file" | while IFS='|' read -r type tag port; do
                echo -e "${CYAN}[$index]${NC} ${GREEN}$type${NC}"
                echo "    标签: $tag"
                echo "    端口: $port"
                
                # 查找对应的链接文件
                local link_files=$(find "${LINK_DIR}" -name "*_${port}.txt" ! -name "argo_*" 2>/dev/null)
                if [[ -n "$link_files" ]]; then
                    echo "    链接文件: $link_files"
                fi
                
                echo ""
                ((index++))
            done
        fi
    fi
    
    # 检查 Argo 隧道节点
    if [[ -d "${LINK_DIR}" ]]; then
        local argo_links=$(find "${LINK_DIR}" -name "argo_*.txt" 2>/dev/null)
        if [[ -n "$argo_links" ]]; then
            has_nodes=true
            echo -e "${GREEN}【Argo 隧道节点】${NC}"
            echo ""
            
            local argo_index=1
            for argo_file in $argo_links; do
                local filename=$(basename "$argo_file")
                echo -e "${CYAN}[A$argo_index]${NC} ${GREEN}Argo Tunnel${NC}"
                
                # 提取域名和端口信息
                if [[ "$filename" =~ argo_quick_([0-9]+)\.txt ]]; then
                    local port="${BASH_REMATCH[1]}"
                    local domain=$(grep "临时域名:" "$argo_file" | awk '{print $2}')
                    echo "    类型: Quick Tunnel (临时域名)"
                    echo "    端口: $port"
                    if [[ -n "$domain" ]]; then
                        echo "    域名: $domain"
                    fi
                elif [[ "$filename" =~ argo_token_([0-9]+)\.txt ]]; then
                    local port="${BASH_REMATCH[1]}"
                    local domain=$(grep "域名:" "$argo_file" | head -1 | awk '{print $2}')
                    echo "    类型: Token 认证"
                    echo "    端口: $port"
                    if [[ -n "$domain" ]]; then
                        echo "    域名: $domain"
                    fi
                elif [[ "$filename" =~ argo_json_([0-9]+)\.txt ]]; then
                    local port="${BASH_REMATCH[1]}"
                    local domain=$(grep "域名:" "$argo_file" | head -1 | awk '{print $2}')
                    echo "    类型: JSON 认证"
                    echo "    端口: $port"
                    if [[ -n "$domain" ]]; then
                        echo "    域名: $domain"
                    fi
                fi
                
                echo "    链接文件: $argo_file"
                
                # 显示节点链接
                local node_link_file="${LINK_DIR}/argo_node_${port}.txt"
                if [[ -f "$node_link_file" ]]; then
                    echo "    节点链接: $(cat "$node_link_file")"
                fi
                
                echo ""
                ((argo_index++))
            done
        fi
    fi
    
    if [[ "$has_nodes" == false ]]; then
        print_warning "暂无配置的节点"
        read -p "按回车键继续..."
        return
    fi
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC}  查看详细配置"
    echo -e "  ${GREEN}2.${NC}  查看分享链接"
    echo -e "  ${GREEN}3.${NC}  导出所有链接"
    echo -e "  ${GREEN}4.${NC}  生成订阅链接"
    echo -e "  ${GREEN}0.${NC}  返回主菜单"
    echo ""
    
    read -p "请选择操作 [0-4]: " choice
    
    case $choice in
        1) view_node_config ;;
        2) view_node_links ;;
        3) export_all_links ;;
        4) generate_subscription ;;
        0) return ;;
        *) print_error "无效的选择"; sleep 2; view_nodes ;;
    esac
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
