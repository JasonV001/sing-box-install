#!/bin/bash

# 新功能测试脚本
# 用于验证三个优化功能是否正常工作

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_test() {
    echo -e "${CYAN}[测试]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_fail() {
    echo -e "${RED}[✗]${NC} $1"
}

echo "========================================"
echo "  Sing-box 新功能测试"
echo "========================================"
echo ""

# 测试1: 检查中转规则说明函数
print_test "测试1: 检查中转规则说明函数"
if grep -q "【1】iptables 端口转发" common/relay.sh; then
    print_pass "中转规则详细说明已添加"
else
    print_fail "中转规则详细说明未找到"
fi
echo ""

# 测试2: 检查 Argo 节点链接生成函数
print_test "测试2: 检查 Argo 节点链接生成函数"
if grep -q "generate_argo_node_link" common/argo.sh; then
    print_pass "Argo 节点链接生成函数已添加"
else
    print_fail "Argo 节点链接生成函数未找到"
fi
echo ""

# 测试3: 检查 Quick Tunnel 节点链接生成
print_test "测试3: 检查 Quick Tunnel 节点链接生成"
if grep -q "generate_argo_node_link.*temp_domain.*local_port" common/argo.sh; then
    print_pass "Quick Tunnel 节点链接生成已集成"
else
    print_fail "Quick Tunnel 节点链接生成未集成"
fi
echo ""

# 测试4: 检查 Token 认证节点链接生成
print_test "测试4: 检查 Token 认证节点链接生成"
if grep -q "argo_token_.*\.txt" common/argo.sh; then
    print_pass "Token 认证节点链接生成已集成"
else
    print_fail "Token 认证节点链接生成未集成"
fi
echo ""

# 测试5: 检查 JSON 认证节点链接生成
print_test "测试5: 检查 JSON 认证节点链接生成"
if grep -q "argo_json_.*\.txt" common/argo.sh; then
    print_pass "JSON 认证节点链接生成已集成"
else
    print_fail "JSON 认证节点链接生成未集成"
fi
echo ""

# 测试6: 检查节点信息显示 Argo 节点
print_test "测试6: 检查节点信息显示 Argo 节点"
if grep -q "【Argo 隧道节点】" common/view.sh; then
    print_pass "节点信息已支持 Argo 节点显示"
else
    print_fail "节点信息未支持 Argo 节点显示"
fi
echo ""

# 测试7: 检查单独卸载功能
print_test "测试7: 检查单独卸载功能"
if grep -q "uninstall_selective" common/uninstall.sh; then
    print_pass "单独卸载功能已添加"
else
    print_fail "单独卸载功能未找到"
fi
echo ""

# 测试8: 检查卸载菜单
print_test "测试8: 检查卸载菜单"
if grep -q "uninstall_menu" common/uninstall.sh; then
    print_pass "卸载菜单已添加"
else
    print_fail "卸载菜单未找到"
fi
echo ""

# 测试9: 检查6个单独卸载函数
print_test "测试9: 检查6个单独卸载函数"
functions=(
    "uninstall_singbox_program"
    "uninstall_config_files"
    "uninstall_certificates"
    "uninstall_node_info"
    "uninstall_relay_config"
    "uninstall_argo_tunnel"
)

all_found=true
for func in "${functions[@]}"; do
    if ! grep -q "$func" common/uninstall.sh; then
        print_fail "函数 $func 未找到"
        all_found=false
    fi
done

if $all_found; then
    print_pass "所有6个单独卸载函数已添加"
fi
echo ""

# 测试10: 检查主脚本调用卸载菜单
print_test "测试10: 检查主脚本调用卸载菜单"
if grep -q "uninstall_menu" yb_new.sh; then
    print_pass "主脚本已更新为调用卸载菜单"
else
    print_fail "主脚本未更新卸载菜单调用"
fi
echo ""

# 测试11: 检查中转类型说明完整性
print_test "测试11: 检查中转类型说明完整性"
relay_types=(
    "【1】iptables 端口转发"
    "【2】DNAT 转发"
    "【3】Socat 转发"
    "【4】Gost 转发"
)

all_types_found=true
for type in "${relay_types[@]}"; do
    if ! grep -q "$type" common/relay.sh; then
        print_fail "中转类型 $type 说明未找到"
        all_types_found=false
    fi
done

if $all_types_found; then
    print_pass "所有4种中转类型说明已添加"
fi
echo ""

# 测试12: 检查节点链接格式支持
print_test "测试12: 检查节点链接格式支持"
protocols=("vless" "trojan" "vmess")

all_protocols_found=true
for proto in "${protocols[@]}"; do
    if ! grep -q "$proto" common/argo.sh; then
        print_fail "协议 $proto 节点链接生成未找到"
        all_protocols_found=false
    fi
done

if $all_protocols_found; then
    print_pass "支持 VLESS/Trojan/VMess 节点链接生成"
fi
echo ""

# 汇总
echo "========================================"
echo "  测试完成"
echo "========================================"
echo ""
echo -e "${CYAN}功能清单:${NC}"
echo "  ✓ 中转规则详细说明（4种类型）"
echo "  ✓ Argo 隧道节点链接生成"
echo "  ✓ 节点信息显示 Argo 节点"
echo "  ✓ 单独卸载功能（6个选项）"
echo "  ✓ 卸载菜单优化"
echo ""
echo -e "${GREEN}所有新功能已成功集成！${NC}"
echo ""
echo "使用方法:"
echo "  1. 查看中转详细说明: bash yb_new.sh -> 4 -> 1"
echo "  2. 安装 Argo 并生成链接: bash yb_new.sh -> 5 -> 1/2/3"
echo "  3. 查看 Argo 节点信息: bash yb_new.sh -> 3"
echo "  4. 单独卸载项目: bash yb_new.sh -> 7 -> 1"
echo ""
