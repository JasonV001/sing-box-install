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
    print_info "检查并安装依赖..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        local OS_ID=${ID,,}
    fi
    
    if [[ "$OS_ID" =~ (debian|ubuntu) ]]; then
        apt-get update -qq
        apt-get install -y curl wget tar socat jq git openssl uuid-runtime build-essential
    elif [[ "$OS_ID" =~ (centos|rhel|rocky|almalinux|fedora) ]]; then
        yum install -y curl wget tar socat jq git openssl util-linux gcc-c++
    fi
    
    print_success "依赖安装完成"
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
    echo "  ${GREEN}1.${NC}  安装 Sing-box"
    echo "  ${GREEN}2.${NC}  配置节点"
    echo "  ${GREEN}3.${NC}  查看节点信息"
    echo "  ${GREEN}4.${NC}  配置中转"
    echo "  ${GREEN}5.${NC}  配置 Argo 隧道"
    echo "  ${GREEN}6.${NC}  管理服务"
    echo "  ${GREEN}7.${NC}  卸载"
    echo "  ${GREEN}0.${NC}  退出"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
}

# ==================== 协议选择菜单 ====================
show_protocol_menu() {
    clear
    echo -e "${CYAN}═══════════════════ 协议选择 ═══════════════════${NC}"
    echo ""
    echo "  ${GREEN}1.${NC}  SOCKS5"
    echo "  ${GREEN}2.${NC}  HTTP"
    echo "  ${GREEN}3.${NC}  AnyTLS"
    echo "  ${GREEN}4.${NC}  TUIC V5"
    echo "  ${GREEN}5.${NC}  Juicity"
    echo "  ${GREEN}6.${NC}  Hysteria2"
    echo "  ${GREEN}7.${NC}  VLESS 系列"
    echo "  ${GREEN}8.${NC}  Trojan 系列"
    echo "  ${GREEN}9.${NC}  VMess 系列"
    echo "  ${GREEN}10.${NC} ShadowTLS V3"
    echo "  ${GREEN}11.${NC} Shadowsocks"
    echo "  ${GREEN}0.${NC}  返回主菜单"
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

# ==================== 主程序 ====================
main() {
    # 检查root权限
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本必须以 root 权限运行"
        exit 1
    fi
    
    # 创建必要的目录
    mkdir -p "${PROTOCOLS_DIR}" "${CONFIG_DIR}" "${CERT_DIR}" "${LINK_DIR}" "${RELAY_DIR}"
    
    # 检测系统
    detect_system
    
    # 主循环
    while true; do
        show_main_menu
        read -p "请选择操作 [0-7]: " choice
        
        case $choice in
            1)
                install_dependencies
                get_server_ip
                # 调用安装sing-box函数
                source "${PROTOCOLS_DIR}/../common/install.sh"
                install_sing_box
                ;;
            2)
                show_protocol_menu
                read -p "请选择协议 [0-33]: " protocol_choice
                # 根据选择加载对应的协议模块
                ;;
            3)
                # 查看节点信息
                source "${PROTOCOLS_DIR}/../common/view.sh"
                view_nodes
                ;;
            4)
                # 配置中转
                source "${PROTOCOLS_DIR}/../common/relay.sh"
                configure_relay
                ;;
            5)
                # 配置Argo隧道
                source "${PROTOCOLS_DIR}/../common/argo.sh"
                configure_argo
                ;;
            6)
                # 管理服务
                source "${PROTOCOLS_DIR}/../common/service.sh"
                manage_service
                ;;
            7)
                # 卸载
                source "${PROTOCOLS_DIR}/../common/uninstall.sh"
                uninstall_all
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
