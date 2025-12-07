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
# 获取脚本真实路径(处理软链接)
if [[ -L "${BASH_SOURCE[0]}" ]]; then
    # 如果是软链接,获取真实路径
    SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
else
    SCRIPT_PATH="${BASH_SOURCE[0]}"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
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
        if [[ $? -eq 0 ]]; then
            return 0
        else
            print_error "加载协议模块 ${protocol}.sh 失败"
            read -p "按回车键继续..."
            return 1
        fi
    else
        print_error "协议模块不存在: ${module_file}"
        print_info "PROTOCOLS_DIR=${PROTOCOLS_DIR}"
        read -p "按回车键继续..."
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
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                        主菜单                             ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${PURPLE}【系统管理】${NC}"
    echo -e "    ${GREEN}1.${NC}  安装 Sing-box"
    echo -e "    ${GREEN}2.${NC}  更新证书"
    echo ""
    echo -e "  ${PURPLE}【节点管理】${NC}"
    echo -e "    ${GREEN}3.${NC}  配置节点"
    echo -e "    ${GREEN}4.${NC}  查看节点信息"
    echo -e "    ${GREEN}5.${NC}  节点管理"
    echo ""
    echo -e "  ${PURPLE}【高级功能】${NC}"
    echo -e "    ${GREEN}6.${NC}  配置中转"
    echo -e "    ${GREEN}7.${NC}  配置 Argo 隧道"
    echo ""
    echo -e "  ${PURPLE}【服务管理】${NC}"
    echo -e "    ${GREEN}8.${NC}  管理服务"
    echo -e "    ${GREEN}9.${NC}  卸载"
    echo ""
    echo -e "    ${GREEN}0.${NC}  退出"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
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
        1) 
            if load_protocol_module "SOCKS"; then
                configure_socks
            fi
            show_protocol_menu
            ;;
        2) 
            if load_protocol_module "HTTP"; then
                configure_http
            fi
            show_protocol_menu
            ;;
        3) 
            if load_protocol_module "AnyTLS"; then
                configure_anytls
            fi
            show_protocol_menu
            ;;
        4) 
            if load_protocol_module "TUIC"; then
                configure_tuic
            fi
            show_protocol_menu
            ;;
        5) 
            if load_protocol_module "Juicity"; then
                configure_juicity
            fi
            show_protocol_menu
            ;;
        6) 
            if load_protocol_module "Hysteria2"; then
                configure_hysteria2
            fi
            show_protocol_menu
            ;;
        7) 
            if load_protocol_module "VLESS"; then
                configure_vless
            fi
            show_protocol_menu
            ;;
        8) 
            if load_protocol_module "Trojan"; then
                configure_trojan
            fi
            show_protocol_menu
            ;;
        9) 
            if load_protocol_module "VMess"; then
                configure_vmess
            fi
            show_protocol_menu
            ;;
        10) 
            if load_protocol_module "ShadowTLS"; then
                configure_shadowtls
            fi
            show_protocol_menu
            ;;
        11) 
            if load_protocol_module "Shadowsocks"; then
                configure_shadowsocks
            fi
            show_protocol_menu
            ;;
        0) 
            return 
            ;;
        *) 
            print_error "无效的选择"
            sleep 2
            show_protocol_menu
            ;;
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

# ==================== 安装证书工具 ====================
install_acme_tools() {
    # 安装 socat
    if ! command -v socat &>/dev/null; then
        print_info "安装 socat..."
        if command -v apt-get &>/dev/null; then
            apt-get update -qq && apt-get install -y socat
        elif command -v yum &>/dev/null; then
            yum install -y socat
        fi
    fi
    
    # 安装 crontab
    if ! command -v crontab &>/dev/null; then
        print_info "安装 crontab..."
        if command -v apt-get &>/dev/null; then
            apt-get install -y cron
        elif command -v yum &>/dev/null; then
            yum install -y cronie
        fi
        systemctl enable cron 2>/dev/null || systemctl enable crond 2>/dev/null
        systemctl start cron 2>/dev/null || systemctl start crond 2>/dev/null
    fi
    
    # 安装 acme.sh
    if [[ ! -f ~/.acme.sh/acme.sh ]]; then
        print_info "安装 acme.sh..."
        curl -s https://get.acme.sh | sh -s email=admin@example.com --force
        source ~/.bashrc 2>/dev/null || source ~/.profile 2>/dev/null
    fi
    
    # 验证安装
    if [[ -f ~/.acme.sh/acme.sh ]]; then
        print_success "证书工具已就绪"
        return 0
    else
        print_error "acme.sh 安装失败"
        return 1
    fi
}

# ==================== 更新证书 ====================
update_certificate() {
    clear
    echo -e "${CYAN}═══════════════════ 更新证书 ═══════════════════${NC}"
    echo ""
    
    echo "请选择证书申请方式："
    echo "  1. 自动申请证书（使用 acme.sh）"
    echo "  2. 使用 CloudFlare API 申请"
    echo "  3. 手动指定证书路径"
    echo "  4. 续期现有证书"
    echo "  5. 删除证书"
    echo "  0. 返回"
    echo ""
    read -p "请选择 [0-5]: " cert_choice
    
    case $cert_choice in
        1)
            apply_certificate_auto
            ;;
        2)
            apply_certificate_cf
            ;;
        3)
            set_certificate_manual
            ;;
        4)
            renew_certificate
            ;;
        5)
            delete_certificate
            ;;
        0)
            return
            ;;
        *)
            print_error "无效的选择"
            sleep 2
            update_certificate
            ;;
    esac
    
    echo ""
    read -p "按回车键继续..."
}

# 自动申请证书
apply_certificate_auto() {
    clear
    echo -e "${CYAN}═══════════════════ 自动申请证书 ═══════════════════${NC}"
    echo ""
    
    read -p "请输入域名: " domain
    
    if [[ -z "$domain" ]]; then
        print_error "域名不能为空"
        return 1
    fi
    
    local certificate_path="/etc/ssl/private/${domain}.crt"
    local private_key_path="/etc/ssl/private/${domain}.key"
    local ca_servers=("letsencrypt" "zerossl")
    
    print_info "申请证书: ${domain}"
    echo ""
    
    # 安装 crontab（如果不存在）
    if ! command -v crontab &>/dev/null; then
        print_info "安装 crontab..."
        if command -v apt-get &>/dev/null; then
            apt-get update -qq && apt-get install -y cron
        elif command -v yum &>/dev/null; then
            yum install -y cronie
        fi
        systemctl enable cron 2>/dev/null || systemctl enable crond 2>/dev/null
        systemctl start cron 2>/dev/null || systemctl start crond 2>/dev/null
    fi
    
    # 安装 acme.sh
    if ! command -v acme.sh &>/dev/null && [[ ! -f ~/.acme.sh/acme.sh ]]; then
        print_info "安装 acme.sh..."
        curl -s https://get.acme.sh | sh -s email=admin@${domain} --force
        
        # 重新加载环境变量
        source ~/.bashrc 2>/dev/null || source ~/.profile 2>/dev/null
    fi
    
    # 设置 acme.sh 路径
    if [[ -f ~/.acme.sh/acme.sh ]]; then
        ACME_SH=~/.acme.sh/acme.sh
    else
        print_error "acme.sh 安装失败"
        return 1
    fi
    
    # 停止可能占用 80 端口的服务
    print_info "检查端口占用..."
    local need_restart=false
    if ss -tuln | grep -q ":80 "; then
        print_warning "端口 80 被占用，尝试临时停止 sing-box..."
        systemctl stop sing-box 2>/dev/null
        need_restart=true
        sleep 2
    fi
    
    # 尝试从多个 CA 申请证书
    local success=false
    for ca_server in "${ca_servers[@]}"; do
        print_info "从 ${ca_server} 申请证书..."
        
        $ACME_SH --set-default-ca --server "$ca_server"
        
        # 使用 standalone 模式，HTTP-01 验证
        if $ACME_SH --issue -d "$domain" --standalone --httpport 80 -k ec-256 --force 2>&1 | tee /tmp/acme_output.log; then
            print_success "证书申请成功"
            
            # 安装证书
            print_info "安装证书..."
            $ACME_SH --install-cert -d "$domain" --ecc \
                --key-file "$private_key_path" \
                --fullchain-file "$certificate_path"
            
            print_success "证书已安装"
            echo "  证书路径: ${certificate_path}"
            echo "  私钥路径: ${private_key_path}"
            
            success=true
            break
        else
            print_warning "从 ${ca_server} 申请失败"
            
            # 显示错误信息
            if grep -q "Verify error" /tmp/acme_output.log; then
                echo ""
                print_error "域名验证失败"
                echo "  可能原因："
                echo "  1. 域名未正确解析到本服务器"
                echo "  2. 防火墙阻止了 80 端口"
                echo "  3. 80 端口被其他服务占用"
            fi
            
            echo ""
            read -p "是否尝试下一个 CA? [Y/n]: " try_next
            if [[ "$try_next" =~ ^[Nn]$ ]]; then
                break
            fi
        fi
    done
    
    rm -f /tmp/acme_output.log
    
    # 恢复服务
    if [[ "$need_restart" == "true" ]]; then
        print_info "重启 sing-box 服务..."
        systemctl start sing-box
    fi
    
    if [[ "$success" == "false" ]]; then
        print_error "证书申请失败"
        echo ""
        print_info "可能的原因:"
        echo "  1. 域名未正确解析到本服务器"
        echo "  2. 防火墙阻止了 80 端口"
        echo "  3. 端口 80 被其他服务占用"
        echo ""
        print_info "请检查后重试，或使用其他方式申请证书"
        return 1
    fi
}



# 使用 CloudFlare API 申请证书
apply_certificate_cf() {
    clear
    echo -e "${CYAN}═══════════════════ CloudFlare API 申请 ═══════════════════${NC}"
    echo ""
    
    read -p "请输入域名: " domain
    read -p "请输入 CloudFlare API Token: " CF_Token
    
    if [[ -z "$domain" || -z "$CF_Token" ]]; then
        print_error "域名和 API Token 不能为空"
        return 1
    fi
    
    export CF_Token
    
    local certificate_path="/etc/ssl/private/${domain}.crt"
    local private_key_path="/etc/ssl/private/${domain}.key"
    local ca_servers=("letsencrypt" "zerossl")
    
    print_info "使用 CloudFlare API 申请证书: ${domain}"
    echo ""
    
    # 安装证书工具
    install_acme_tools || return 1
    
    # 设置 acme.sh 路径
    local ACME_SH=~/.acme.sh/acme.sh
    
    # 尝试从多个 CA 申请证书
    local success=false
    for ca_server in "${ca_servers[@]}"; do
        print_info "从 ${ca_server} 申请证书..."
        
        $ACME_SH --set-default-ca --server "$ca_server"
        
        if $ACME_SH --issue --dns dns_cf -d "$domain" -k ec-256; then
            print_success "证书申请成功"
            
            # 安装证书
            print_info "安装证书..."
            $ACME_SH --install-cert -d "$domain" --ecc \
                --key-file "$private_key_path" \
                --fullchain-file "$certificate_path"
            
            print_success "证书已安装"
            echo "  证书路径: ${certificate_path}"
            echo "  私钥路径: ${private_key_path}"
            
            success=true
            break
        else
            print_warning "从 ${ca_server} 申请失败，尝试下一个..."
        fi
    done
    
    if [[ "$success" == "false" ]]; then
        print_error "证书申请失败"
        echo ""
        print_info "请检查 CloudFlare API Token 是否正确"
        return 1
    fi
}

# 手动指定证书路径
set_certificate_manual() {
    clear
    echo -e "${CYAN}═══════════════════ 手动指定证书 ═══════════════════${NC}"
    echo ""
    
    read -p "请输入证书文件路径 (.crt 或 .pem): " cert_path
    read -p "请输入私钥文件路径 (.key): " key_path
    
    if [[ ! -f "$cert_path" ]]; then
        print_error "证书文件不存在: ${cert_path}"
        return 1
    fi
    
    if [[ ! -f "$key_path" ]]; then
        print_error "私钥文件不存在: ${key_path}"
        return 1
    fi
    
    # 复制到标准位置
    local domain=$(basename "$cert_path" | sed 's/\.[^.]*$//')
    local target_cert="/etc/ssl/private/${domain}.crt"
    local target_key="/etc/ssl/private/${domain}.key"
    
    cp "$cert_path" "$target_cert"
    cp "$key_path" "$target_key"
    
    chmod 600 "$target_cert" "$target_key"
    
    print_success "证书已复制到标准位置"
    echo "  证书路径: ${target_cert}"
    echo "  私钥路径: ${target_key}"
}

# 续期证书
renew_certificate() {
    clear
    echo -e "${CYAN}═══════════════════ 续期证书 ═══════════════════${NC}"
    echo ""
    
    if [[ ! -f ~/.acme.sh/acme.sh ]]; then
        print_error "未找到 acme.sh，请先申请证书"
        return 1
    fi
    
    local ACME_SH=~/.acme.sh/acme.sh
    
    print_info "续期所有证书..."
    echo ""
    
    $ACME_SH --renew-all --force
    
    if [[ $? -eq 0 ]]; then
        print_success "证书续期成功"
        
        # 重启服务以加载新证书
        print_info "重启 sing-box 服务..."
        systemctl restart sing-box
        
        print_success "服务已重启"
    else
        print_error "证书续期失败"
    fi
}

# 删除证书
delete_certificate() {
    clear
    echo -e "${CYAN}═══════════════════ 删除证书 ═══════════════════${NC}"
    echo ""
    
    # 列出所有证书
    local cert_files=($(find /etc/ssl/private -name "*.crt" 2>/dev/null))
    
    if [[ ${#cert_files[@]} -eq 0 ]]; then
        print_warning "未找到任何证书文件"
        echo ""
        read -p "按回车键继续..."
        return
    fi
    
    echo -e "${GREEN}已安装的证书:${NC}"
    echo ""
    
    local index=1
    declare -A cert_map
    
    for cert_file in "${cert_files[@]}"; do
        local domain=$(basename "$cert_file" .crt)
        local key_file="/etc/ssl/private/${domain}.key"
        
        echo -e "  ${CYAN}[$index]${NC} ${domain}"
        
        # 显示证书信息
        if [[ -f "$cert_file" ]]; then
            local expiry=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
            if [[ -n "$expiry" ]]; then
                echo "      过期时间: ${expiry}"
            fi
        fi
        
        cert_map[$index]="$domain"
        ((index++))
        echo ""
    done
    
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}A.${NC}  删除所有证书"
    echo -e "  ${GREEN}0.${NC}  返回"
    echo ""
    
    read -p "请选择要删除的证书 [1-$((index-1))/A/0]: " del_choice
    
    case $del_choice in
        [Aa])
            delete_all_certificates
            ;;
        0)
            return
            ;;
        [1-9]|[1-9][0-9])
            if [[ -n "${cert_map[$del_choice]}" ]]; then
                delete_single_certificate "${cert_map[$del_choice]}"
            else
                print_error "无效的选择"
                sleep 2
            fi
            ;;
        *)
            print_error "无效的选择"
            sleep 2
            ;;
    esac
    
    delete_certificate
}

# 删除单个证书
delete_single_certificate() {
    local domain=$1
    local cert_file="/etc/ssl/private/${domain}.crt"
    local key_file="/etc/ssl/private/${domain}.key"
    
    echo ""
    print_warning "确认删除证书: ${domain}?"
    read -p "输入 yes 确认: " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        # 从 acme.sh 中删除
        if [[ -f ~/.acme.sh/acme.sh ]]; then
            print_info "从 acme.sh 中删除..."
            ~/.acme.sh/acme.sh --remove -d "$domain" 2>/dev/null
        fi
        
        # 删除证书文件
        rm -f "$cert_file" "$key_file"
        
        print_success "证书已删除"
        echo "  已删除: ${cert_file}"
        echo "  已删除: ${key_file}"
    else
        print_info "取消删除"
    fi
    
    echo ""
    read -p "按回车键继续..."
}

# 删除所有证书
delete_all_certificates() {
    echo ""
    print_warning "此操作将删除所有证书文件！"
    echo ""
    read -p "确认删除所有证书? 输入 yes 确认: " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        # 从 acme.sh 中删除所有证书
        if [[ -f ~/.acme.sh/acme.sh ]]; then
            print_info "从 acme.sh 中删除所有证书..."
            
            # 列出所有域名并删除
            for domain_dir in ~/.acme.sh/*/; do
                if [[ -d "$domain_dir" ]]; then
                    local domain=$(basename "$domain_dir")
                    if [[ "$domain" != "ca" && "$domain" != "http.header" ]]; then
                        ~/.acme.sh/acme.sh --remove -d "$domain" 2>/dev/null
                    fi
                fi
            done
        fi
        
        # 删除所有证书文件
        print_info "删除证书文件..."
        rm -f /etc/ssl/private/*.crt
        rm -f /etc/ssl/private/*.key
        
        print_success "所有证书已删除"
    else
        print_info "取消删除"
    fi
    
    echo ""
    read -p "按回车键继续..."
}

# ==================== 节点管理 ====================
manage_nodes() {
    clear
    echo -e "${CYAN}═══════════════════ 节点管理 ═══════════════════${NC}"
    echo ""
    
    local config_file="${CONFIG_DIR}/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        print_warning "配置文件不存在"
        echo ""
        read -p "按回车键继续..."
        return
    fi
    
    local inbound_count=$(jq '.inbounds | length' "$config_file" 2>/dev/null || echo "0")
    
    if [[ "$inbound_count" -eq 0 ]]; then
        print_warning "暂无配置的节点"
        echo ""
        read -p "按回车键继续..."
        return
    fi
    
    # 显示所有节点
    echo -e "${GREEN}当前节点列表:${NC}"
    echo ""
    
    local index=1
    while IFS='|' read -r type tag port; do
        echo -e "  ${CYAN}[$index]${NC} ${type} - ${tag} (端口: ${port})"
        ((index++))
    done < <(jq -r '.inbounds[] | "\(.type)|\(.tag)|\(.listen_port)"' "$config_file")
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC}  删除单个节点"
    echo -e "  ${GREEN}2.${NC}  删除全部节点"
    echo -e "  ${GREEN}0.${NC}  返回"
    echo ""
    
    read -p "请选择操作 [0-2]: " manage_choice
    
    case $manage_choice in
        1)
            delete_single_node
            ;;
        2)
            delete_all_nodes
            ;;
        0)
            return
            ;;
        *)
            print_error "无效的选择"
            sleep 2
            manage_nodes
            ;;
    esac
}

# 删除单个节点
delete_single_node() {
    clear
    echo -e "${CYAN}═══════════════════ 删除节点 ═══════════════════${NC}"
    echo ""
    
    local config_file="${CONFIG_DIR}/config.json"
    local inbound_count=$(jq '.inbounds | length' "$config_file" 2>/dev/null || echo "0")
    
    if [[ "$inbound_count" -eq 0 ]]; then
        print_warning "暂无配置的节点"
        echo ""
        read -p "按回车键继续..."
        return
    fi
    
    # 显示节点列表
    echo -e "${GREEN}请选择要删除的节点:${NC}"
    echo ""
    
    declare -a node_tags
    local index=1
    
    while IFS='|' read -r type tag port; do
        echo -e "  ${CYAN}[$index]${NC} ${type} - ${tag} (端口: ${port})"
        node_tags[$index]="$tag"
        ((index++))
    done < <(jq -r '.inbounds[] | "\(.type)|\(.tag)|\(.listen_port)"' "$config_file")
    
    echo ""
    echo -e "  ${GREEN}0.${NC}  返回"
    echo ""
    
    read -p "请选择节点序号 [0-$((index-1))]: " node_index
    
    if [[ "$node_index" == "0" ]]; then
        manage_nodes
        return
    fi
    
    if [[ "$node_index" -ge 1 && "$node_index" -lt "$index" ]]; then
        local selected_tag="${node_tags[$node_index]}"
        
        print_warning "确认删除节点: ${selected_tag}?"
        read -p "输入 yes 确认: " confirm
        
        if [[ "$confirm" == "yes" ]]; then
            # 删除节点配置
            local temp_file=$(mktemp)
            jq "del(.inbounds[] | select(.tag == \"$selected_tag\"))" "$config_file" > "$temp_file"
            mv "$temp_file" "$config_file"
            
            # 删除对应的链接文件
            local port=$(jq -r ".inbounds[] | select(.tag == \"$selected_tag\") | .listen_port" "$config_file" 2>/dev/null)
            if [[ -n "$port" ]]; then
                rm -f "${LINK_DIR}"/*_${port}.txt 2>/dev/null
            fi
            
            # 重启服务
            systemctl restart sing-box
            
            print_success "节点已删除"
        else
            print_info "取消删除"
        fi
    else
        print_error "无效的选择"
    fi
    
    echo ""
    read -p "按回车键继续..."
    manage_nodes
}

# 删除全部节点
delete_all_nodes() {
    clear
    echo -e "${CYAN}═══════════════════ 删除全部节点 ═══════════════════${NC}"
    echo ""
    
    print_warning "此操作将删除所有节点配置！"
    echo ""
    read -p "确认删除全部节点? 输入 yes 确认: " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        local config_file="${CONFIG_DIR}/config.json"
        
        # 备份配置
        cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # 清空 inbounds
        local temp_file=$(mktemp)
        jq '.inbounds = []' "$config_file" > "$temp_file"
        mv "$temp_file" "$config_file"
        
        # 删除所有链接文件
        rm -f "${LINK_DIR}"/*.txt 2>/dev/null
        
        # 重启服务
        systemctl restart sing-box
        
        print_success "所有节点已删除"
        print_info "配置已备份到: ${config_file}.backup.*"
    else
        print_info "取消删除"
    fi
    
    echo ""
    read -p "按回车键继续..."
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
        read -p "请选择操作 [0-9]: " choice
        
        case $choice in
            1)
                # 安装 Sing-box
                if [[ -f "${SCRIPT_DIR}/common/install.sh" ]]; then
                    source "${SCRIPT_DIR}/common/install.sh"
                    install_sing_box
                else
                    print_error "找不到安装模块: ${SCRIPT_DIR}/common/install.sh"
                    read -p "按回车键继续..."
                fi
                ;;
            2)
                # 更新证书
                update_certificate
                ;;
            3)
                # 配置节点
                show_protocol_menu
                ;;
            4)
                # 查看节点信息
                if [[ -f "${SCRIPT_DIR}/common/view.sh" ]]; then
                    source "${SCRIPT_DIR}/common/view.sh"
                    view_nodes
                else
                    print_error "找不到查看模块: ${SCRIPT_DIR}/common/view.sh"
                    read -p "按回车键继续..."
                fi
                ;;
            5)
                # 节点管理
                manage_nodes
                ;;
            6)
                # 配置中转
                if [[ -f "${SCRIPT_DIR}/common/relay.sh" ]]; then
                    source "${SCRIPT_DIR}/common/relay.sh"
                    configure_relay
                else
                    print_error "找不到中转模块: ${SCRIPT_DIR}/common/relay.sh"
                    read -p "按回车键继续..."
                fi
                ;;
            7)
                # 配置Argo隧道
                if [[ -f "${SCRIPT_DIR}/common/argo.sh" ]]; then
                    source "${SCRIPT_DIR}/common/argo.sh"
                    configure_argo
                else
                    print_error "找不到Argo模块: ${SCRIPT_DIR}/common/argo.sh"
                    read -p "按回车键继续..."
                fi
                ;;
            8)
                # 管理服务
                if [[ -f "${SCRIPT_DIR}/common/service.sh" ]]; then
                    source "${SCRIPT_DIR}/common/service.sh"
                    manage_service
                else
                    print_error "找不到服务管理模块: ${SCRIPT_DIR}/common/service.sh"
                    read -p "按回车键继续..."
                fi
                ;;
            9)
                # 卸载
                if [[ -f "${SCRIPT_DIR}/common/uninstall.sh" ]]; then
                    source "${SCRIPT_DIR}/common/uninstall.sh"
                    uninstall_menu
                else
                    print_error "找不到卸载模块: ${SCRIPT_DIR}/common/uninstall.sh"
                    read -p "按回车键继续..."
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
