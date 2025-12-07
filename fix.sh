#!/bin/bash

# ==================== 快速修复脚本 ====================
# 修复软链接路径问题

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Sing-box 脚本快速修复工具${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误: 此脚本需要 root 权限运行${NC}"
    echo "请使用: sudo bash fix.sh"
    exit 1
fi

# 检查脚本目录
if [[ ! -d "/opt/sing-box-script" ]]; then
    echo -e "${RED}错误: /opt/sing-box-script 目录不存在${NC}"
    echo "请先运行安装脚本"
    exit 1
fi

cd /opt/sing-box-script

echo -e "${CYAN}1. 备份当前脚本...${NC}"
if [[ -f "yb_new.sh" ]]; then
    cp yb_new.sh yb_new.sh.bak.$(date +%Y%m%d_%H%M%S)
    echo -e "   ${GREEN}✓${NC} 已备份到 yb_new.sh.bak.*"
else
    echo -e "   ${RED}✗${NC} yb_new.sh 不存在"
    exit 1
fi

echo ""
echo -e "${CYAN}2. 下载最新版本...${NC}"
if wget -q https://raw.githubusercontent.com/JasonV001/sing-box-install/main/yb_new.sh -O yb_new.sh.new; then
    mv yb_new.sh.new yb_new.sh
    chmod +x yb_new.sh
    echo -e "   ${GREEN}✓${NC} 下载成功"
else
    echo -e "   ${RED}✗${NC} 下载失败"
    echo "   尝试从备份恢复..."
    cp yb_new.sh.bak.* yb_new.sh 2>/dev/null
    exit 1
fi

echo ""
echo -e "${CYAN}3. 验证软链接...${NC}"
if [[ -L "/usr/local/bin/sb" ]]; then
    local target=$(readlink -f /usr/local/bin/sb)
    if [[ "$target" == "/opt/sing-box-script/yb_new.sh" ]]; then
        echo -e "   ${GREEN}✓${NC} 软链接正确"
    else
        echo -e "   ${YELLOW}!${NC} 软链接指向错误: $target"
        echo "   重新创建软链接..."
        ln -sf /opt/sing-box-script/yb_new.sh /usr/local/bin/sb
        chmod +x /usr/local/bin/sb
        echo -e "   ${GREEN}✓${NC} 软链接已修复"
    fi
else
    echo -e "   ${YELLOW}!${NC} 软链接不存在"
    echo "   创建软链接..."
    ln -sf /opt/sing-box-script/yb_new.sh /usr/local/bin/sb
    chmod +x /usr/local/bin/sb
    echo -e "   ${GREEN}✓${NC} 软链接已创建"
fi

echo ""
echo -e "${CYAN}4. 检查模块文件...${NC}"
missing_files=0

# 检查 common 模块
for module in install relay argo view service uninstall; do
    if [[ ! -f "common/${module}.sh" ]]; then
        echo -e "   ${RED}✗${NC} common/${module}.sh 缺失"
        ((missing_files++))
    fi
done

# 检查 protocols 模块
protocols=("SOCKS" "HTTP" "AnyTLS" "TUIC" "Juicity" "Hysteria2" "VLESS" "Trojan" "VMess" "ShadowTLS" "Shadowsocks")
for proto in "${protocols[@]}"; do
    if [[ ! -f "protocols/${proto}.sh" ]]; then
        echo -e "   ${RED}✗${NC} protocols/${proto}.sh 缺失"
        ((missing_files++))
    fi
done

if [[ $missing_files -gt 0 ]]; then
    echo -e "   ${YELLOW}!${NC} 发现 $missing_files 个缺失文件"
    echo ""
    read -p "是否重新下载缺失的文件? [Y/n]: " download_missing
    if [[ "$download_missing" =~ ^[Yy]?$ ]]; then
        echo ""
        echo -e "${CYAN}5. 下载缺失文件...${NC}"
        
        BASE_URL="https://raw.githubusercontent.com/JasonV001/sing-box-install/main"
        
        # 下载 common 模块
        for module in install relay argo view service uninstall; do
            if [[ ! -f "common/${module}.sh" ]]; then
                echo "   下载 common/${module}.sh..."
                wget -q "${BASE_URL}/common/${module}.sh" -O "common/${module}.sh"
                chmod +x "common/${module}.sh"
            fi
        done
        
        # 下载 protocols 模块
        for proto in "${protocols[@]}"; do
            if [[ ! -f "protocols/${proto}.sh" ]]; then
                echo "   下载 protocols/${proto}.sh..."
                wget -q "${BASE_URL}/protocols/${proto}.sh" -O "protocols/${proto}.sh"
                chmod +x "protocols/${proto}.sh"
            fi
        done
        
        echo -e "   ${GREEN}✓${NC} 文件下载完成"
    fi
else
    echo -e "   ${GREEN}✓${NC} 所有模块文件完整"
fi

echo ""
echo -e "${CYAN}6. 设置文件权限...${NC}"
chmod +x yb_new.sh
chmod +x common/*.sh 2>/dev/null
chmod +x protocols/*.sh 2>/dev/null
echo -e "   ${GREEN}✓${NC} 权限设置完成"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}修复完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}现在可以运行:${NC}"
echo -e "  ${GREEN}sb${NC}  - 启动脚本"
echo ""
echo -e "${CYAN}如果问题仍然存在,请运行:${NC}"
echo -e "  ${GREEN}bash debug.sh${NC}  - 诊断问题"
echo ""
