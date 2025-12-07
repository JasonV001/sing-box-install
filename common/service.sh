#!/bin/bash

# ==================== 服务管理模块 ====================

# 管理服务
manage_service() {
    clear
    echo -e "${CYAN}═══════════════════ 服务管理 ═══════════════════${NC}"
    echo ""
    
    # 显示当前状态
    if systemctl is-active --quiet sing-box; then
        echo -e "  Sing-box 状态: ${GREEN}运行中${NC}"
    else
        echo -e "  Sing-box 状态: ${RED}已停止${NC}"
    fi
    
    echo ""
    echo "  ${GREEN}1.${NC}  启动服务"
    echo "  ${GREEN}2.${NC}  停止服务"
    echo "  ${GREEN}3.${NC}  重启服务"
    echo "  ${GREEN}4.${NC}  查看状态"
    echo "  ${GREEN}5.${NC}  查看日志"
    echo "  ${GREEN}6.${NC}  启用开机自启"
    echo "  ${GREEN}7.${NC}  禁用开机自启"
    echo "  ${GREEN}8.${NC}  重载配置"
    echo "  ${GREEN}0.${NC}  返回主菜单"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    
    read -p "请选择操作 [0-8]: " choice
    
    case $choice in
        1) start_service ;;
        2) stop_service ;;
        3) restart_service ;;
        4) status_service ;;
        5) view_logs ;;
        6) enable_service ;;
        7) disable_service ;;
        8) reload_config ;;
        0) return ;;
        *) print_error "无效的选择"; sleep 2; manage_service ;;
    esac
}

# 启动服务
start_service() {
    print_info "启动 Sing-box 服务..."
    
    if systemctl start sing-box; then
        sleep 2
        if systemctl is-active --quiet sing-box; then
            print_success "服务启动成功"
        else
            print_error "服务启动失败"
            echo ""
            systemctl status sing-box
        fi
    else
        print_error "启动命令执行失败"
    fi
    
    sleep 3
    manage_service
}

# 停止服务
stop_service() {
    print_warning "确认停止 Sing-box 服务?"
    read -p "输入 yes 确认: " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_info "取消操作"
        sleep 2
        manage_service
        return
    fi
    
    print_info "停止 Sing-box 服务..."
    
    if systemctl stop sing-box; then
        print_success "服务已停止"
    else
        print_error "停止失败"
    fi
    
    sleep 2
    manage_service
}

# 重启服务
restart_service() {
    print_info "重启 Sing-box 服务..."
    
    if systemctl restart sing-box; then
        sleep 2
        if systemctl is-active --quiet sing-box; then
            print_success "服务重启成功"
        else
            print_error "服务重启后未正常运行"
            echo ""
            systemctl status sing-box
        fi
    else
        print_error "重启命令执行失败"
    fi
    
    sleep 3
    manage_service
}

# 查看状态
status_service() {
    clear
    print_info "Sing-box 服务状态"
    echo ""
    
    systemctl status sing-box
    
    echo ""
    echo -e "${CYAN}详细信息:${NC}"
    echo "  PID: $(pgrep -f sing-box || echo '未运行')"
    echo "  内存使用: $(ps aux | grep '[s]ing-box' | awk '{print $6/1024 " MB"}' || echo '0 MB')"
    echo "  CPU使用: $(ps aux | grep '[s]ing-box' | awk '{print $3 "%"}' || echo '0%')"
    
    echo ""
    echo -e "${CYAN}监听端口:${NC}"
    ss -tuln | grep sing-box || echo "  无监听端口"
    
    echo ""
    read -p "按回车键继续..."
    manage_service
}

# 查看日志
view_logs() {
    clear
    echo -e "${CYAN}═══════════════════ 日志查看 ═══════════════════${NC}"
    echo ""
    echo "  ${GREEN}1.${NC}  查看实时日志"
    echo "  ${GREEN}2.${NC}  查看最近100行"
    echo "  ${GREEN}3.${NC}  查看最近500行"
    echo "  ${GREEN}4.${NC}  查看错误日志"
    echo "  ${GREEN}0.${NC}  返回"
    echo ""
    
    read -p "请选择 [0-4]: " log_choice
    
    case $log_choice in
        1)
            print_info "实时日志 (Ctrl+C 退出)"
            sleep 2
            journalctl -u sing-box -f
            ;;
        2)
            clear
            journalctl -u sing-box -n 100 --no-pager
            ;;
        3)
            clear
            journalctl -u sing-box -n 500 --no-pager
            ;;
        4)
            clear
            journalctl -u sing-box -p err --no-pager
            ;;
        0)
            manage_service
            return
            ;;
        *)
            print_error "无效的选择"
            sleep 2
            ;;
    esac
    
    echo ""
    read -p "按回车键继续..."
    view_logs
}

# 启用开机自启
enable_service() {
    print_info "启用 Sing-box 开机自启..."
    
    if systemctl enable sing-box; then
        print_success "已启用开机自启"
    else
        print_error "启用失败"
    fi
    
    sleep 2
    manage_service
}

# 禁用开机自启
disable_service() {
    print_info "禁用 Sing-box 开机自启..."
    
    if systemctl disable sing-box; then
        print_success "已禁用开机自启"
    else
        print_error "禁用失败"
    fi
    
    sleep 2
    manage_service
}

# 重载配置
reload_config() {
    print_info "重载 Sing-box 配置..."
    
    # 先验证配置文件
    if sing-box check -c "${CONFIG_DIR}/config.json" >/dev/null 2>&1; then
        print_success "配置文件验证通过"
        
        if systemctl reload sing-box 2>/dev/null || systemctl restart sing-box; then
            sleep 2
            if systemctl is-active --quiet sing-box; then
                print_success "配置重载成功"
            else
                print_error "服务未正常运行"
            fi
        else
            print_error "重载失败"
        fi
    else
        print_error "配置文件验证失败"
        echo ""
        sing-box check -c "${CONFIG_DIR}/config.json"
    fi
    
    sleep 3
    manage_service
}
