#!/bin/bash

# ==================== 输入验证函数库 ====================
# 用于验证用户输入，防止注入攻击和非法输入

# 验证域名格式
validate_domain() {
    local domain=$1
    
    # 检查是否为空
    if [[ -z "$domain" ]]; then
        print_error "域名不能为空"
        return 1
    fi
    
    # 域名正则：只允许字母、数字、点、连字符
    # 格式：label.label.label (每个 label 最多 63 字符)
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        print_error "域名格式无效"
        return 1
    fi
    
    # 检查域名总长度（不超过 253 字符）
    if [[ ${#domain} -gt 253 ]]; then
        print_error "域名长度超过限制（最多 253 字符）"
        return 1
    fi
    
    # 检查是否包含连续的点
    if [[ "$domain" =~ \.\. ]]; then
        print_error "域名不能包含连续的点"
        return 1
    fi
    
    # 检查是否以点开头或结尾
    if [[ "$domain" =~ ^\. ]] || [[ "$domain" =~ \.$ ]]; then
        print_error "域名不能以点开头或结尾"
        return 1
    fi
    
    return 0
}

# 验证端口号
validate_port() {
    local port=$1
    
    # 检查是否为空
    if [[ -z "$port" ]]; then
        print_error "端口号不能为空"
        return 1
    fi
    
    # 检查是否为数字
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        print_error "端口号必须是数字"
        return 1
    fi
    
    # 检查端口范围（1-65535）
    if [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        print_error "端口号必须在 1-65535 之间"
        return 1
    fi
    
    return 0
}

# 验证文件路径
validate_file_path() {
    local file_path=$1
    shift
    local allowed_extensions=("$@")
    
    # 检查是否为空
    if [[ -z "$file_path" ]]; then
        print_error "文件路径不能为空"
        return 1
    fi
    
    # 检查路径遍历（不允许 ..）
    if [[ "$file_path" =~ \.\. ]]; then
        print_error "路径不能包含 .."
        return 1
    fi
    
    # 检查文件是否存在
    if [[ ! -f "$file_path" ]]; then
        print_error "文件不存在: ${file_path}"
        return 1
    fi
    
    # 检查文件是否可读
    if [[ ! -r "$file_path" ]]; then
        print_error "文件不可读: ${file_path}"
        return 1
    fi
    
    # 检查文件扩展名（如果提供了允许的扩展名列表）
    if [[ ${#allowed_extensions[@]} -gt 0 ]]; then
        local ext="${file_path##*.}"
        local valid=false
        
        for allowed_ext in "${allowed_extensions[@]}"; do
            if [[ "$ext" == "$allowed_ext" ]]; then
                valid=true
                break
            fi
        done
        
        if [[ "$valid" == "false" ]]; then
            print_error "文件扩展名无效，允许的扩展名: ${allowed_extensions[*]}"
            return 1
        fi
    fi
    
    return 0
}

# 验证 IP 地址
validate_ip() {
    local ip=$1
    
    # 检查是否为空
    if [[ -z "$ip" ]]; then
        print_error "IP 地址不能为空"
        return 1
    fi
    
    # IPv4 正则
    local ipv4_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ "$ip" =~ $ipv4_regex ]]; then
        # 验证每个八位组的范围（0-255）
        IFS='.' read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [[ "$octet" -gt 255 ]]; then
                print_error "IP 地址格式无效"
                return 1
            fi
        done
        return 0
    fi
    
    # IPv6 简单验证（完整验证较复杂）
    if [[ "$ip" =~ : ]]; then
        return 0
    fi
    
    print_error "IP 地址格式无效"
    return 1
}

# 验证 UUID
validate_uuid() {
    local uuid=$1
    
    # 检查是否为空
    if [[ -z "$uuid" ]]; then
        print_error "UUID 不能为空"
        return 1
    fi
    
    # UUID 格式：8-4-4-4-12
    if [[ ! "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
        print_error "UUID 格式无效"
        return 1
    fi
    
    return 0
}

# 验证密码强度
validate_password() {
    local password=$1
    local min_length=${2:-8}
    
    # 检查是否为空
    if [[ -z "$password" ]]; then
        print_error "密码不能为空"
        return 1
    fi
    
    # 检查最小长度
    if [[ ${#password} -lt $min_length ]]; then
        print_error "密码长度至少 ${min_length} 个字符"
        return 1
    fi
    
    return 0
}

# 创建安全的临时文件
create_secure_temp() {
    local temp_file=$(mktemp)
    chmod 600 "$temp_file"  # 只有所有者可读写
    echo "$temp_file"
}

# 创建安全的临时目录
create_secure_temp_dir() {
    local temp_dir=$(mktemp -d)
    chmod 700 "$temp_dir"  # 只有所有者可访问
    echo "$temp_dir"
}

# 安全地读取敏感输入（隐藏输入）
read_sensitive() {
    local prompt=$1
    local var_name=$2
    
    read -s -p "$prompt" "$var_name"
    echo ""  # 换行
}

# 验证 JSON 格式
validate_json() {
    local json_file=$1
    
    if [[ ! -f "$json_file" ]]; then
        print_error "JSON 文件不存在"
        return 1
    fi
    
    if ! jq empty "$json_file" 2>/dev/null; then
        print_error "JSON 格式错误"
        return 1
    fi
    
    return 0
}

# 验证配置文件
validate_config() {
    local config_file=$1
    
    # 验证 JSON 格式
    if ! validate_json "$config_file"; then
        return 1
    fi
    
    # 验证必需字段
    if ! jq -e '.inbounds' "$config_file" >/dev/null 2>&1; then
        print_error "配置文件缺少 inbounds 字段"
        return 1
    fi
    
    return 0
}
