#!/bin/bash

# ==================== 一键安装脚本 ====================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="/opt/sing-box-script"
REPO_URL="https://github.com/your-repo/sing-box-modular"

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

# 安装依赖
echo -e "${CYAN}安装依赖...${NC}"

if [[ "$ID" =~ (debian|ubuntu) ]]; then
    apt-get update -qq
    apt-get install -y curl wget git jq
elif [[ "$ID" =~ (centos|rhel|rocky|almalinux|fedora) ]]; then
    yum install -y curl wget git jq
else
    echo -e "${YELLOW}警告: 未知系统，尝试继续...${NC}"
fi

# 创建安装目录
echo -e "${CYAN}创建安装目录...${NC}"
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

# 下载脚本文件
echo -e "${CYAN}下载脚本文件...${NC}"

# 如果有git仓库，使用git clone
if [[ -n "$REPO_URL" ]] && git ls-remote "$REPO_URL" &>/dev/null; then
    git clone "$REPO_URL" .
else
    # 否则手动创建文件结构
    mkdir -p common protocols
    
    # 这里可以添加从其他源下载文件的逻辑
    echo -e "${YELLOW}注意: 请手动将脚本文件放置到 ${INSTALL_DIR}${NC}"
fi

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
