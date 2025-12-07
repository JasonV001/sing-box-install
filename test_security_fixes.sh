#!/bin/bash

# 安全修复测试脚本

echo "================================"
echo "安全修复测试脚本"
echo "================================"
echo ""

# 加载验证函数
source common/validation.sh

# 测试计数器
total_tests=0
passed_tests=0
failed_tests=0

# 测试函数
run_test() {
    local test_name=$1
    local test_command=$2
    local expected_result=$3
    
    ((total_tests++))
    echo -n "测试 $total_tests: $test_name ... "
    
    if eval "$test_command"; then
        if [[ "$expected_result" == "pass" ]]; then
            echo "✓ 通过"
            ((passed_tests++))
        else
            echo "✗ 失败（预期失败但通过了）"
            ((failed_tests++))
        fi
    else
        if [[ "$expected_result" == "fail" ]]; then
            echo "✓ 通过（正确拒绝）"
            ((passed_tests++))
        else
            echo "✗ 失败（预期通过但失败了）"
            ((failed_tests++))
        fi
    fi
}

echo "1. 域名验证测试"
echo "----------------"
run_test "正常域名" "validate_domain 'example.com'" "pass"
run_test "子域名" "validate_domain 'sub.example.com'" "pass"
run_test "命令注入" "validate_domain 'example.com; rm -rf /'" "fail"
run_test "路径遍历" "validate_domain '../etc/passwd'" "fail"
run_test "空域名" "validate_domain ''" "fail"
run_test "特殊字符" "validate_domain 'exam\$ple.com'" "fail"
run_test "连续点" "validate_domain 'example..com'" "fail"
run_test "以点开头" "validate_domain '.example.com'" "fail"
run_test "以点结尾" "validate_domain 'example.com.'" "fail"
echo ""

echo "2. 端口验证测试"
echo "----------------"
run_test "正常端口" "validate_port '443'" "pass"
run_test "最小端口" "validate_port '1'" "pass"
run_test "最大端口" "validate_port '65535'" "pass"
run_test "端口为0" "validate_port '0'" "fail"
run_test "端口超限" "validate_port '65536'" "fail"
run_test "负数端口" "validate_port '-1'" "fail"
run_test "非数字端口" "validate_port 'abc'" "fail"
run_test "空端口" "validate_port ''" "fail"
echo ""

echo "3. IP 地址验证测试"
echo "----------------"
run_test "正常 IPv4" "validate_ip '192.168.1.1'" "pass"
run_test "回环地址" "validate_ip '127.0.0.1'" "pass"
run_test "IPv4 超限" "validate_ip '256.1.1.1'" "fail"
run_test "IPv6 地址" "validate_ip '::1'" "pass"
run_test "非法 IP" "validate_ip 'abc.def.ghi.jkl'" "fail"
run_test "空 IP" "validate_ip ''" "fail"
echo ""

echo "4. UUID 验证测试"
echo "----------------"
run_test "正常 UUID" "validate_uuid '550e8400-e29b-41d4-a716-446655440000'" "pass"
run_test "大写 UUID" "validate_uuid '550E8400-E29B-41D4-A716-446655440000'" "pass"
run_test "错误格式" "validate_uuid '550e8400-e29b-41d4-a716'" "fail"
run_test "非法字符" "validate_uuid '550e8400-e29b-41d4-a716-44665544000g'" "fail"
run_test "空 UUID" "validate_uuid ''" "fail"
echo ""

echo "5. 临时文件安全测试"
echo "----------------"
temp_file=$(create_secure_temp)
if [[ -f "$temp_file" ]]; then
    perms=$(stat -c "%a" "$temp_file" 2>/dev/null || stat -f "%A" "$temp_file" 2>/dev/null)
    if [[ "$perms" == "600" ]]; then
        echo "✓ 临时文件权限正确 (600)"
        ((passed_tests++))
    else
        echo "✗ 临时文件权限错误 ($perms)"
        ((failed_tests++))
    fi
    ((total_tests++))
    rm -f "$temp_file"
else
    echo "✗ 临时文件创建失败"
    ((failed_tests++))
    ((total_tests++))
fi
echo ""

echo "================================"
echo "测试结果汇总"
echo "================================"
echo "总测试数: $total_tests"
echo "通过: $passed_tests"
echo "失败: $failed_tests"
echo ""

if [[ $failed_tests -eq 0 ]]; then
    echo "✓ 所有测试通过！"
    exit 0
else
    echo "✗ 有 $failed_tests 个测试失败"
    exit 1
fi
