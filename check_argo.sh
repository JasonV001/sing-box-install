#!/bin/bash

# Argo 隧道快速诊断脚本

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════ Argo 隧道诊断 ═══════════════════${NC}"
echo ""

# 1. 检查服务状态
echo -e "${CYAN}[1] 服务状态${NC}"
if systemctl is-active --quiet argo-quick; then
    echo -e "  ${GREEN}✓${NC} Argo Quick Tunnel 运行中"
    
    # 获取端口
    port=$(grep "ExecStart.*--url.*localhost:" /etc/systemd/system/argo-quick.service | grep -oP 'localhost:\K[0-9]+')
    echo -e "  ${CYAN}→${NC} 本地端口: ${port}"
    
    # 获取域名
    if [[ -f /opt/argo/argo.log ]]; then
        domain=$(grep -oP 'https://\K[^/]+\.trycloudflare\.com' /opt/argo/argo.log | tail -1)
        if [[ -n "$domain" ]]; then
            echo -e "  ${CYAN}→${NC} 临时域名: ${domain}"
        fi
    fi
elif systemctl is-active --quiet argo-tunnel; then
    echo -e "  ${GREEN}✓${NC} Argo Tunnel 运行中"
    
    # 从服务文件获取信息
    if [[ -f /etc/systemd/system/argo-tunnel.service ]]; then
        port=$(grep "ExecStart.*localhost:" /etc/systemd/system/argo-tunnel.service | grep -oP 'localhost:\K[0-9]+' || echo "未知")
        echo -e "  ${CYAN}→${NC} 本地端口: ${port}"
    fi
    
    # 从保存的文件获取域名
    if [[ -f /opt/argo/domain.txt ]]; then
        domain=$(cat /opt/argo/domain.txt)
        echo -e "  ${CYAN}→${NC} 域名: ${domain}"
    fi
else
    echo -e "  ${RED}✗${NC} Argo 服务未运行"
    port=""
fi
echo ""

# 2. 检查本地端口
if [[ -n "$port" ]]; then
    echo -e "${CYAN}[2] 本地端口检查${NC}"
    if ss -tuln | grep -q ":${port} "; then
        echo -e "  ${GREEN}✓${NC} 端口 ${port} 有服务监听"
        ss -tuln | grep ":${port} "
    else
        echo -e "  ${RED}✗${NC} 端口 ${port} 没有服务监听"
        echo -e "  ${YELLOW}!${NC} 这会导致 Argo 连接失败 (connection refused)"
        echo ""
        echo -e "  ${CYAN}解决方法:${NC}"
        echo "    1. 启动 Sing-box: systemctl start sing-box"
        echo "    2. 检查配置: cat /usr/local/etc/sing-box/config.json"
        echo "    3. 确保有 inbound 监听端口 ${port}"
    fi
    echo ""
fi

# 3. 检查节点链接
echo -e "${CYAN}[3] 节点链接${NC}"
if [[ -d /usr/local/etc/sing-box/links ]]; then
    link_files=$(find /usr/local/etc/sing-box/links -name "argo_*.txt" 2>/dev/null)
    if [[ -n "$link_files" ]]; then
        for file in $link_files; do
            echo -e "  ${GREEN}✓${NC} 找到: $(basename "$file")"
            
            # 显示节点链接
            if [[ -f "${file/argo_/argo_node_}" ]]; then
                node_link=$(cat "${file/argo_/argo_node_}")
                echo -e "  ${CYAN}→${NC} 链接: ${node_link:0:60}..."
            fi
        done
    else
        echo -e "  ${YELLOW}!${NC} 未找到节点链接文件"
    fi
else
    echo -e "  ${RED}✗${NC} 链接目录不存在"
fi
echo ""

# 4. 检查最近错误
echo -e "${CYAN}[4] 最近错误${NC}"
if systemctl is-active --quiet argo-quick; then
    errors=$(journalctl -u argo-quick -n 5 --no-pager | grep -i "error\|refused\|failed" | tail -3)
elif systemctl is-active --quiet argo-tunnel; then
    errors=$(journalctl -u argo-tunnel -n 5 --no-pager | grep -i "error\|refused\|failed" | tail -3)
fi

if [[ -n "$errors" ]]; then
    echo -e "  ${YELLOW}!${NC} 发现错误:"
    echo "$errors" | while read line; do
        echo "    $line"
    done
    echo ""
    
    # 分析错误
    if echo "$errors" | grep -q "connection refused"; then
        echo -e "  ${CYAN}原因分析:${NC}"
        echo "    本地端口没有服务运行"
        echo ""
        echo -e "  ${CYAN}解决方法:${NC}"
        echo "    1. 启动 Sing-box: systemctl start sing-box"
        echo "    2. 检查端口: ss -tuln | grep ${port}"
        echo "    3. 查看日志: journalctl -u sing-box -n 20"
    fi
else
    echo -e "  ${GREEN}✓${NC} 没有发现错误"
fi
echo ""

# 5. 快速操作
echo -e "${CYAN}[5] 快速操作${NC}"
echo "  查看完整日志: journalctl -u argo-quick -f"
echo "  或: journalctl -u argo-tunnel -f"
echo "  重启服务: systemctl restart argo-quick"
echo "  查看节点链接: cat /usr/local/etc/sing-box/links/argo_*.txt"
echo "  刷新域名: bash yb_new.sh -> 5 -> 5"
echo ""

echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
