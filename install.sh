#!/bin/bash

# ==================== 一键安装脚本 ====================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="/opt/sing-box-script"
REPO_URL="https://github.com/JasonV001/sing-box-install"

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Sing-box 模块化脚本 - 一键安装                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误: 此脚本必须以 root 权限运行${NC}"
    exit 1
fi

# 检测系统
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    OS="${NAME}"
else
    echo -e "${RED}错误: 无法检测系统${NC}"
    exit 1
fi

echo -e "${GREEN}检测到系统: ${OS}${NC}"

# 检查并安装依赖
echo -e "${CYAN}检查依赖...${NC}"

# 定义必需的依赖
REQUIRED_DEPS=("curl" "wget" "jq")
MISSING_DEPS=()

# 检查哪些依赖缺失
for dep in "${REQUIRED_DEPS[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        MISSING_DEPS+=("$dep")
        echo -e "${YELLOW}  缺少: $dep${NC}"
    else
        echo -e "${GREEN}  已安装: $dep${NC}"
    fi
done

# 只安装缺失的依赖
if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo -e "${CYAN}安装缺失的依赖: ${MISSING_DEPS[*]}${NC}"
    
    if [[ "$ID" =~ (debian|ubuntu) ]]; then
        apt-get update -qq
        apt-get install -y "${MISSING_DEPS[@]}"
    elif [[ "$ID" =~ (centos|rhel|rocky|almalinux|fedora) ]]; then
        yum install -y "${MISSING_DEPS[@]}"
    else
        echo -e "${YELLOW}警告: 未知系统，请手动安装: ${MISSING_DEPS[*]}${NC}"
    fi
else
    echo -e "${GREEN}所有依赖已安装${NC}"
fi

# 创建安装目录
echo -e "${CYAN}创建安装目录...${NC}"
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

# 下载脚本文件
echo -e "${CYAN}下载脚本文件...${NC}"

# GitHub raw 文件基础 URL
BASE_URL="https://raw.githubusercontent.com/JasonV001/sing-box-install/main"

# 创建目录结构
mkdir -p common protocols

# 下载核心脚本
echo -e "${CYAN}下载核心脚本...${NC}"
wget -q "${BASE_URL}/yb_new.sh" -O yb_new.sh || { echo -e "${RED}下载 yb_new.sh 失败${NC}"; exit 1; }
wget -q "${BASE_URL}/test.sh" -O test.sh || echo -e "${YELLOW}test.sh 下载失败，跳过${NC}"

# 下载通用模块
echo -e "${CYAN}下载通用模块...${NC}"
for module in install relay argo view service uninstall; do
    wget -q "${BASE_URL}/common/${module}.sh" -O "common/${module}.sh" || echo -e "${YELLOW}common/${module}.sh 下载失败${NC}"
done

# 下载协议模块
echo -e "${CYAN}下载协议模块...${NC}"
protocols=(
    "SOCKS" "HTTP" "AnyTLS" "TUIC" "Juicity" "Hysteria2"
    "VLESS" "VLESS-Vision-REALITY" "Trojan" "VMess"
    "ShadowTLS" "Shadowsocks" "TEMPLATE"
)

for proto in "${protocols[@]}"; do
    wget -q "${BASE_URL}/protocols/${proto}.sh" -O "protocols/${proto}.sh" || echo -e "${YELLOW}protocols/${proto}.sh 下载失败${NC}"
done

# 下载文档（可选）
echo -e "${CYAN}下载文档...${NC}"
wget -q "${BASE_URL}/README.md" -O README.md 2>/dev/null || true
wget -q "${BASE_URL}/QUICK_START.md" -O QUICK_START.md 2>/dev/null || true

echo -e "${GREEN}文件下载完成${NC}"

# 设置权限
echo -e "${CYAN}设置权限...${NC}"
chmod +x yb_new.sh
chmod +x common/*.sh
chmod +x protocols/*.sh 2>/dev/null || true

# 创建软链接
echo -e "${CYAN}创建快捷命令...${NC}"
ln -sf "${INSTALL_DIR}/yb_new.sh" /usr/local/bin/sb
chmod +x /usr/local/bin/sb

# 完成
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    安装完成！                              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}使用方法:${NC}"
echo -e "  ${GREEN}sb${NC}          - 运行主脚本"
echo -e "  ${GREEN}sb -h${NC}       - 查看帮助"
echo ""
echo -e "${CYAN}脚本位置:${NC} ${INSTALL_DIR}"
echo ""
echo -e "${YELLOW}首次使用请运行: ${GREEN}sb${NC}"
echo ""
