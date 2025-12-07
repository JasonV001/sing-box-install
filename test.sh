#!/bin/bash

# ==================== 测试脚本 ====================
# 用于测试模块化脚本的各个功能

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESULTS=()

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              Sing-box 模块化脚本测试                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# 测试结果记录
pass_test() {
    local test_name=$1
    echo -e "${GREEN}[✓]${NC} $test_name"
    TEST_RESULTS+=("PASS: $test_name")
}

fail_test() {
    local test_name=$1
    local error=$2
    echo -e "${RED}[✗]${NC} $test_name"
    echo -e "${RED}    错误: $error${NC}"
    TEST_RESULTS+=("FAIL: $test_name - $error")
}

# 测试1: 检查文件结构
test_file_structure() {
    echo -e "\n${CYAN}测试1: 检查文件结构${NC}"
    
    local required_files=(
        "yb_new.sh"
        "install.sh"
        "README.md"
        "common/install.sh"
        "common/relay.sh"
        "common/argo.sh"
        "common/view.sh"
        "common/service.sh"
        "common/uninstall.sh"
        "protocols/SOCKS.sh"
        "protocols/Hysteria2.sh"
        "protocols/VLESS-Vision-REALITY.sh"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ -f "${SCRIPT_DIR}/${file}" ]]; then
            pass_test "文件存在: $file"
        else
            fail_test "文件缺失: $file" "文件不存在"
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -eq 0 ]]; then
        pass_test "所有必需文件都存在"
    else
        fail_test "文件结构检查" "缺失 ${#missing_files[@]} 个文件"
    fi
}

# 测试2: 检查脚本语法
test_script_syntax() {
    echo -e "\n${CYAN}测试2: 检查脚本语法${NC}"
    
    local script_files=(
        "yb_new.sh"
        "install.sh"
        "common/install.sh"
        "common/relay.sh"
        "common/argo.sh"
        "common/view.sh"
        "common/service.sh"
        "common/uninstall.sh"
        "protocols/SOCKS.sh"
        "protocols/Hysteria2.sh"
        "protocols/VLESS-Vision-REALITY.sh"
    )
    
    for script in "${script_files[@]}"; do
        if bash -n "${SCRIPT_DIR}/${script}" 2>/dev/null; then
            pass_test "语法正确: $script"
        else
            fail_test "语法错误: $script" "bash -n 检查失败"
        fi
    done
}

# 测试3: 检查函数定义
test_function_definitions() {
    echo -e "\n${CYAN}测试3: 检查函数定义${NC}"
    
    # 检查主脚本函数
    local main_functions=(
        "show_banner"
        "detect_system"
        "install_dependencies"
        "get_server_ip"
        "show_main_menu"
        "show_protocol_menu"
    )
    
    for func in "${main_functions[@]}"; do
        if grep -q "^${func}()" "${SCRIPT_DIR}/yb_new.sh" || grep -q "^function ${func}" "${SCRIPT_DIR}/yb_new.sh"; then
            pass_test "函数定义: $func"
        else
            fail_test "函数缺失: $func" "在 yb_new.sh 中未找到"
        fi
    done
    
    # 检查安装模块函数
    local install_functions=(
        "install_sing_box"
        "install_latest_sing_box"
        "configure_sing_box_service"
    )
    
    for func in "${install_functions[@]}"; do
        if grep -q "^${func}()" "${SCRIPT_DIR}/common/install.sh" || grep -q "^function ${func}" "${SCRIPT_DIR}/common/install.sh"; then
            pass_test "函数定义: $func"
        else
            fail_test "函数缺失: $func" "在 common/install.sh 中未找到"
        fi
    done
}

# 测试4: 检查依赖命令
test_dependencies() {
    echo -e "\n${CYAN}测试4: 检查系统依赖${NC}"
    
    local required_commands=(
        "bash"
        "curl"
        "wget"
        "jq"
        "systemctl"
    )
    
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            pass_test "命令可用: $cmd"
        else
            fail_test "命令缺失: $cmd" "请安装 $cmd"
        fi
    done
}

# 测试5: 检查配置文件格式
test_config_format() {
    echo -e "\n${CYAN}测试5: 检查配置文件格式${NC}"
    
    # 创建测试配置
    local test_config=$(cat <<'EOF'
{
  "log": {
    "level": "info"
  },
  "inbounds": [],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF
)
    
    # 验证 JSON 格式
    if echo "$test_config" | jq '.' >/dev/null 2>&1; then
        pass_test "JSON 格式验证"
    else
        fail_test "JSON 格式验证" "配置格式错误"
    fi
}

# 测试6: 检查权限
test_permissions() {
    echo -e "\n${CYAN}测试6: 检查文件权限${NC}"
    
    local executable_files=(
        "yb_new.sh"
        "install.sh"
        "test.sh"
    )
    
    for file in "${executable_files[@]}"; do
        if [[ -x "${SCRIPT_DIR}/${file}" ]]; then
            pass_test "可执行权限: $file"
        else
            fail_test "权限不足: $file" "文件不可执行"
        fi
    done
}

# 测试7: 检查文档完整性
test_documentation() {
    echo -e "\n${CYAN}测试7: 检查文档完整性${NC}"
    
    local doc_files=(
        "README.md"
        "PROJECT_SUMMARY.md"
        "QUICK_START.md"
        "COMPLETION_REPORT.md"
    )
    
    for doc in "${doc_files[@]}"; do
        if [[ -f "${SCRIPT_DIR}/${doc}" ]] && [[ -s "${SCRIPT_DIR}/${doc}" ]]; then
            local line_count=$(wc -l < "${SCRIPT_DIR}/${doc}")
            if [[ $line_count -gt 10 ]]; then
                pass_test "文档完整: $doc ($line_count 行)"
            else
                fail_test "文档过短: $doc" "只有 $line_count 行"
            fi
        else
            fail_test "文档缺失: $doc" "文件不存在或为空"
        fi
    done
}

# 测试8: 检查协议模块
test_protocol_modules() {
    echo -e "\n${CYAN}测试8: 检查协议模块${NC}"
    
    local protocol_modules=(
        "SOCKS.sh"
        "Hysteria2.sh"
        "VLESS-Vision-REALITY.sh"
    )
    
    for module in "${protocol_modules[@]}"; do
        local module_path="${SCRIPT_DIR}/protocols/${module}"
        
        if [[ -f "$module_path" ]]; then
            # 检查必需函数
            local required_funcs=("configure_" "generate_.*_config" "generate_.*_link" "delete_")
            local all_funcs_found=true
            
            for func_pattern in "${required_funcs[@]}"; do
                if ! grep -qE "^(function )?${func_pattern}" "$module_path"; then
                    all_funcs_found=false
                    break
                fi
            done
            
            if $all_funcs_found; then
                pass_test "协议模块完整: $module"
            else
                fail_test "协议模块不完整: $module" "缺少必需函数"
            fi
        else
            fail_test "协议模块缺失: $module" "文件不存在"
        fi
    done
}

# 运行所有测试
run_all_tests() {
    test_file_structure
    test_script_syntax
    test_function_definitions
    test_dependencies
    test_config_format
    test_permissions
    test_documentation
    test_protocol_modules
}

# 显示测试结果
show_results() {
    echo -e "\n${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                      测试结果汇总                          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local pass_count=0
    local fail_count=0
    
    for result in "${TEST_RESULTS[@]}"; do
        if [[ "$result" =~ ^PASS ]]; then
            ((pass_count++))
        else
            ((fail_count++))
            echo -e "${RED}$result${NC}"
        fi
    done
    
    echo ""
    echo -e "总测试数: $((pass_count + fail_count))"
    echo -e "${GREEN}通过: $pass_count${NC}"
    echo -e "${RED}失败: $fail_count${NC}"
    
    if [[ $fail_count -eq 0 ]]; then
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                  所有测试通过！                            ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                  存在测试失败！                            ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
        return 1
    fi
}

# 主函数
main() {
    cd "$SCRIPT_DIR"
    
    run_all_tests
    show_results
    
    exit $?
}

# 运行测试
main "$@"
