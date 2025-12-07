#!/bin/bash

# ==================== 主脚本 yb.sh ====================
# Sing-box 一键安装管理脚本 - 模块化版本
# 版本: 2.0
# 支持协议: SOCKS, HTTP, Hysteria2, VLESS, Trojan, VMess, Shadowsocks, TUIC, Juicity, ShadowTLS, AnyTLS
# 支持功能: 节点管理, 中转配置, Argo隧道, 链接查看

# ==================== 颜色定义 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ==================== 路径配置 ====================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTOCOLS_DIR="${SCRIPT_DIR}/protocols"
CONFIG_DIR="/usr/local/etc/sing-box"
CERT_DIR="/etc/ssl/private"
LINK_DIR="${CONFIG_DIR}/links"
RELAY_DIR="${CONFIG_DIR}/relays"

# ==================== 全局变量 ====================
SERVER_IP=""
SERVER_IPV6=""
CONFIG_FILE="${CONFIG_DIR}/config.json"

# ==================== 打印函数 ====================
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         Sing-box 一键安装管理脚本 v2.0                    ║"
    echo "║         模块化版本 - 支持多协议 + 中转 + Argo             ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ==================== 加载协议模块 ====================
load_protocol_module() {
    local protocol=$1
    local module_file="${PROTOCOLS_DIR}/${protocol}.sh"
    
    if [[ -f "$module_file" ]]; then
        source "$module_file"
        return 0
    else
        print_error "协议模块 ${protocol}.sh 不存在"
        return 1
    fi
}

# ==================== 系统检测 ====================
detect_system() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS="${NAME}"
    else
        print_error "无法检测系统"
        exit 1
    fi
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        *) print_error "不支持的架构: $ARCH"; exit 1 ;;
    esac
    
    print_success "系统: ${OS} (${ARCH})"
}

# ==================== 安装依赖 ====================
install_dependencies() {
    print_info "安装缺失的依赖..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        local OS_ID=${ID,,}
    fi
    
    # 获取缺失的依赖列表
    local missing_deps=()
    for cmd in curl wget tar socat jq git openssl; do
        if ! command -v "$cmd" &>/dev/null; then
            case $cmd in
                openssl) missing_deps+=("openssl") ;;
                *) missing_deps+=("$cmd") ;;
            esac
        fi
    done
    
    # 检查 uuidgen
    if ! command -v uuidgen &>/dev/null; then
        if [[ "$OS_ID" =~ (debian|ubuntu) ]]; then
            missing_deps+=("uuid-runtime")
        elif [[ "$OS_ID" =~ (centos|rhel|rocky|almalinux|fedora) ]]; then
            missing_deps+=("util-linux")
        fi
    fi
    
    # 检查编译工具(仅在需要编译时)
    if ! command -v gcc &>/dev/null; then
        if [[ "$OS_ID" =~ (debian|ubuntu) ]]; then
            missing_deps+=("build-essential")
        elif [[ "$OS_ID" =~ (centos|rhel|rocky|almalinux|fedora) ]]; then
            missing_deps+=("gcc-c++")
        fi
    fi
    
    # 安装缺失的依赖
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_info "需要安装: ${missing_deps[*]}"
        
        if [[ "$OS_ID" =~ (debian|ubuntu) ]]; then
            apt-get update -qq
            apt-get install -y "${missing_deps[@]}"
        elif [[ "$OS_ID" =~ (centos|rhel|rocky|almalinux|fedora) ]]; then
            yum install -y "${missing_deps[@]}"
        fi
        
        print_success "依赖安装完成"
    else
        print_success "所有依赖已安装"
    fi
}

# ==================== 获取服务器IP ====================
get_server_ip() {
    print_info "获取服务器 IP 地址..."
    
    SERVER_IP=$(curl -s4m5 ifconfig.me 2>/dev/null || curl -s4m5 api.ipify.org 2>/dev/null)
    SERVER_IPV6=$(curl -s6m5 ifconfig.me 2>/dev/null || curl -s6m5 api6.ipify.org 2>/dev/null)
    
    if [[ -n "$SERVER_IP" ]]; then
        print_success "IPv4: ${SERVER_IP}"
    fi
    if [[ -n "$SERVER_IPV6" ]]; then
        print_success "IPv6: ${SERVER_IPV6}"
    fi
    
    if [[ -z "$SERVER_IP" && -z "$SERVER_IPV6" ]]; then
        print_error "无法获取服务器 IP 地址"
        exit 1
    fi
}

# ==================== 主菜单 ====================
show_main_menu() {
    show_banner
    echo -e "${CYAN}═══════════════════ 主菜单 ═══════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC}  安装 Sing-box"
    echo -e "  ${GREEN}2.${NC}  配置节点"
    echo -e "  ${GREEN}3.${NC}  查看节点信息"
    echo -e "  ${GREEN}4.${NC}  配置中转"
    echo -e "  ${GREEN}5.${NC}  配置 Argo 隧道"
    echo -e "  ${GREEN}6.${NC}  管理服务"
    echo -e "  ${GREEN}7.${NC}  卸载"
    echo -e "  ${GREEN}0.${NC}  退出"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
}

# ==================== 协议选择菜单 ====================
show_protocol_menu() {
    clear
    echo -e "${CYAN}═══════════════════ 协议选择 ═══════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC}  SOCKS5"
    echo -e "  ${GREEN}2.${NC}  HTTP"
    echo -e "  ${GREEN}3.${NC}  AnyTLS"
    echo -e "  ${GREEN}4.${NC}  TUIC V5"
    echo -e "  ${GREEN}5.${NC}  Juicity"
    echo -e "  ${GREEN}6.${NC}  Hysteria2"
    echo -e "  ${GREEN}7.${NC}  VLESS 系列"
    echo -e "  ${GREEN}8.${NC}  Trojan 系列"
    echo -e "  ${GREEN}9.${NC}  VMess 系列"
    echo -e "  ${GREEN}10.${NC} ShadowTLS V3"
    echo -e "  ${GREEN}11.${NC} Shadowsocks"
    echo -e "  ${GREEN}0.${NC}  返回主菜单"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    
    read -p "请选择协议 [0-11]: " protocol_choice
    
    case $protocol_choice in
        1) load_protocol_module "SOCKS" && configure_socks ;;
        2) load_protocol_module "HTTP" && configure_http ;;
        3) load_protocol_module "AnyTLS" && configure_anytls ;;
        4) load_protocol_module "TUIC" && configure_tuic ;;
        5) load_protocol_module "Juicity" && configure_juicity ;;
        6) load_protocol_module "Hysteria2" && configure_hysteria2 ;;
        7) load_protocol_module "VLESS" && configure_vless ;;
        8) load_protocol_module "Trojan" && configure_trojan ;;
        9) load_protocol_module "VMess" && configure_vmess ;;
        10) load_protocol_module "ShadowTLS" && configure_shadowtls ;;
        11) load_protocol_module "Shadowsocks" && configure_shadowsocks ;;
        0) return ;;
        *) print_error "无效的选择"; sleep 2; show_protocol_menu ;;
    esac
}

# ==================== 检查依赖 ====================
check_dependencies() {
    local missing_deps=()
    
    # 检查必需命令
    for cmd in curl wget jq systemctl openssl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_warning "缺少依赖: ${missing_deps[*]}"
        read -p "是否自动安装? [Y/n]: " install_deps
        if [[ "$install_deps" =~ ^[Yy]?$ ]]; then
            install_dependencies
        else
            print_error "缺少必需依赖，脚本退出"
            exit 1
        fi
    fi
}

# ==================== 初始化 ====================
initialize() {
    # 检查root权限
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本必须以 root 权限运行"
        print_info "请使用: sudo $0"
        exit 1
    fi
    
    # 创建必要的目录
    mkdir -p "${PROTOCOLS_DIR}" "${CONFIG_DIR}" "${CERT_DIR}" "${LINK_DIR}" "${RELAY_DIR}"
    
    # 检测系统
    detect_system
    
    # 检查依赖
    check_dependencies
    
    # 获取服务器IP
    if [[ -z "$SERVER_IP" ]]; then
        get_server_ip
    fi
}

# ==================== 主程序 ====================
main() {
    # 初始化
    initialize
    
    # 主循环
    while true; do
        show_main_menu
        read -p "请选择操作 [0-7]: " choice
        
        case $choice in
            1)
                # 安装 Sing-box
                if [[ -f "${SCRIPT_DIR}/common/install.sh" ]]; then
                    source "${SCRIPT_DIR}/common/install.sh"
                    install_sing_box
                else
                    print_error "找不到安装模块"
                fi
                ;;
            2)
                # 配置节点
                show_protocol_menu
                ;;
            3)
                # 查看节点信息
                if [[ -f "${SCRIPT_DIR}/common/view.sh" ]]; then
                    source "${SCRIPT_DIR}/common/view.sh"
                    view_nodes
                else
                    print_error "找不到查看模块"
                fi
                ;;
            4)
                # 配置中转
                if [[ -f "${SCRIPT_DIR}/common/relay.sh" ]]; then
                    source "${SCRIPT_DIR}/common/relay.sh"
                    configure_relay
                else
                    print_error "找不到中转模块"
                fi
                ;;
            5)
                # 配置Argo隧道
                if [[ -f "${SCRIPT_DIR}/common/argo.sh" ]]; then
                    source "${SCRIPT_DIR}/common/argo.sh"
                    configure_argo
                else
                    print_error "找不到Argo模块"
                fi
                ;;
            6)
                # 管理服务
                if [[ -f "${SCRIPT_DIR}/common/service.sh" ]]; then
                    source "${SCRIPT_DIR}/common/service.sh"
                    manage_service
                else
                    print_error "找不到服务管理模块"
                fi
                ;;
            7)
                # 卸载
                if [[ -f "${SCRIPT_DIR}/common/uninstall.sh" ]]; then
                    source "${SCRIPT_DIR}/common/uninstall.sh"
                    uninstall_all
                else
                    print_error "找不到卸载模块"
                fi
                ;;
            0)
                print_info "退出脚本"
                exit 0
                ;;
            *)
                print_error "无效的选择"
                sleep 2
                ;;
        esac
    done
}

# 运行主程序
main "$@"
