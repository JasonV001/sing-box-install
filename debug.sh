#!/bin/bash

# ==================== 调试脚本 ====================
# 用于诊断 sing-box 脚本问题

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Sing-box 脚本调试工具${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# 检查脚本位置
if [[ -L "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
else
    SCRIPT_PATH="${BASH_SOURCE[0]}"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

echo -e "${CYAN}1. 脚本位置:${NC}"
echo "   当前脚本: ${BASH_SOURCE[0]}"
if [[ -L "${BASH_SOURCE[0]}" ]]; then
    echo "   真实路径: $SCRIPT_PATH"
fi
echo "   脚本目录: $SCRIPT_DIR"
echo ""

# 检查主脚本
echo -e "${CYAN}2. 主脚本:${NC}"
if [[ -f "$SCRIPT_DIR/yb_new.sh" ]]; then
    echo -e "   ${GREEN}✓${NC} yb_new.sh 存在"
    ls -lh "$SCRIPT_DIR/yb_new.sh"
else
    echo -e "   ${RED}✗${NC} yb_new.sh 不存在"
fi
echo ""

# 检查 common 目录
echo -e "${CYAN}3. 通用模块目录:${NC}"
if [[ -d "$SCRIPT_DIR/common" ]]; then
    echo -e "   ${GREEN}✓${NC} common/ 目录存在"
    echo "   文件列表:"
    ls -lh "$SCRIPT_DIR/common/"
else
    echo -e "   ${RED}✗${NC} common/ 目录不存在"
fi
echo ""

# 检查 protocols 目录
echo -e "${CYAN}4. 协议模块目录:${NC}"
if [[ -d "$SCRIPT_DIR/protocols" ]]; then
    echo -e "   ${GREEN}✓${NC} protocols/ 目录存在"
    echo "   文件列表:"
    ls -lh "$SCRIPT_DIR/protocols/"
else
    echo -e "   ${RED}✗${NC} protocols/ 目录不存在"
fi
echo ""

# 检查软链接
echo -e "${CYAN}5. 快捷命令:${NC}"
if [[ -L "/usr/local/bin/sb" ]]; then
    echo -e "   ${GREEN}✓${NC} /usr/local/bin/sb 软链接存在"
    ls -lh /usr/local/bin/sb
    echo "   指向: $(readlink -f /usr/local/bin/sb)"
else
    echo -e "   ${RED}✗${NC} /usr/local/bin/sb 软链接不存在"
fi
echo ""

# 检查配置目录
echo -e "${CYAN}6. 配置目录:${NC}"
CONFIG_DIR="/usr/local/etc/sing-box"
if [[ -d "$CONFIG_DIR" ]]; then
    echo -e "   ${GREEN}✓${NC} $CONFIG_DIR 存在"
    if [[ -f "$CONFIG_DIR/config.json" ]]; then
        echo -e "   ${GREEN}✓${NC} config.json 存在"
        ls -lh "$CONFIG_DIR/config.json"
    else
        echo -e "   ${YELLOW}!${NC} config.json 不存在"
    fi
else
    echo -e "   ${YELLOW}!${NC} $CONFIG_DIR 不存在"
fi
echo ""

# 检查 sing-box
echo -e "${CYAN}7. Sing-box 程序:${NC}"
if command -v sing-box &>/dev/null; then
    echo -e "   ${GREEN}✓${NC} sing-box 已安装"
    sing-box version 2>&1 | head -3
else
    echo -e "   ${YELLOW}!${NC} sing-box 未安装"
fi
echo ""

# 检查依赖
echo -e "${CYAN}8. 必需依赖:${NC}"
deps=("curl" "wget" "jq" "systemctl" "openssl")
for dep in "${deps[@]}"; do
    if command -v "$dep" &>/dev/null; then
        echo -e "   ${GREEN}✓${NC} $dep"
    else
        echo -e "   ${RED}✗${NC} $dep (缺失)"
    fi
done
echo ""

# 检查权限
echo -e "${CYAN}9. 权限检查:${NC}"
if [[ $EUID -eq 0 ]]; then
    echo -e "   ${GREEN}✓${NC} 以 root 权限运行"
else
    echo -e "   ${RED}✗${NC} 未以 root 权限运行"
fi
echo ""

# 测试模块加载
echo -e "${CYAN}10. 测试模块加载:${NC}"
if [[ -f "$SCRIPT_DIR/common/install.sh" ]]; then
    if source "$SCRIPT_DIR/common/install.sh" 2>/dev/null; then
        echo -e "   ${GREEN}✓${NC} common/install.sh 可以加载"
    else
        echo -e "   ${RED}✗${NC} common/install.sh 加载失败"
    fi
else
    echo -e "   ${RED}✗${NC} common/install.sh 不存在"
fi

if [[ -f "$SCRIPT_DIR/protocols/SOCKS.sh" ]]; then
    if source "$SCRIPT_DIR/protocols/SOCKS.sh" 2>/dev/null; then
        echo -e "   ${GREEN}✓${NC} protocols/SOCKS.sh 可以加载"
    else
        echo -e "   ${RED}✗${NC} protocols/SOCKS.sh 加载失败"
    fi
else
    echo -e "   ${RED}✗${NC} protocols/SOCKS.sh 不存在"
fi
echo ""

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}诊断完成${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# 提供修复建议
echo -e "${YELLOW}修复建议:${NC}"
echo ""

if [[ ! -d "$SCRIPT_DIR/common" ]] || [[ ! -d "$SCRIPT_DIR/protocols" ]]; then
    echo "1. 重新安装脚本:"
    echo "   bash <(curl -sSL https://raw.githubusercontent.com/JasonV001/sing-box-install/main/install.sh)"
    echo ""
fi

if [[ ! -L "/usr/local/bin/sb" ]]; then
    echo "2. 创建软链接:"
    echo "   ln -sf $SCRIPT_DIR/yb_new.sh /usr/local/bin/sb"
    echo "   chmod +x /usr/local/bin/sb"
    echo ""
fi

if [[ $EUID -ne 0 ]]; then
    echo "3. 使用 root 权限运行:"
    echo "   sudo bash debug.sh"
    echo ""
fi

echo "如果问题仍然存在,请提供以上诊断信息以获取帮助。"
echo ""
