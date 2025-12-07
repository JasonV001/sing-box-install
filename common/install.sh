#!/bin/bash

# ==================== Sing-box 安装模块 ====================

# 安装 sing-box
install_sing_box() {
    if [[ -f "/usr/local/bin/sing-box" ]]; then
        local version=$(sing-box version 2>&1 | grep -oP 'sing-box version \K[0-9.]+' || echo "unknown")
        print_success "sing-box 已安装 (版本: ${version})"
        
        read -p "是否重新安装? [y/N]: " reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    print_info "开始安装 sing-box..."
    
    # 选择安装方式
    echo ""
    echo "请选择 sing-box 的安装方式："
    echo "1) 下载安装 (Latest 版本)"
    echo "2) 下载安装 (Beta 版本)"
    echo "3) 编译安装 (完整功能版本)"
    read -p "请选择 [1-3] (默认1): " install_option
    install_option=${install_option:-1}
    
    case $install_option in
        1)
            install_latest_sing_box
            ;;
        2)
            install_beta_sing_box
            ;;
        3)
            install_go
            compile_sing_box
            ;;
        *)
            print_error "无效的选择"
            return 1
            ;;
    esac
    
    # 配置服务
    configure_sing_box_service
    
    # 创建配置目录
    mkdir -p "${CONFIG_DIR}" "${CERT_DIR}"
    
    print_success "sing-box 安装完成"
}

# 安装最新版本
install_latest_sing_box() {
    local arch=$(uname -m)
    local url="https://api.github.com/repos/SagerNet/sing-box/releases/latest"
    local download_url
    
    case $arch in
        x86_64|amd64)
            download_url=$(curl -s $url | grep -o "https://github.com[^\"']*linux-amd64.tar.gz")
            ;;
        aarch64|arm64)
            download_url=$(curl -s $url | grep -o "https://github.com[^\"']*linux-arm64.tar.gz")
            ;;
        armv7l)
            download_url=$(curl -s $url | grep -o "https://github.com[^\"']*linux-armv7.tar.gz")
            ;;
        *)
            print_error "不支持的架构：$arch"
            return 1
            ;;
    esac
    
    if [[ -n "$download_url" ]]; then
        print_info "下载 Sing-Box..."
        wget -qO sing-box.tar.gz "$download_url"
        tar -xzf sing-box.tar.gz -C /usr/local/bin --strip-components=1
        rm sing-box.tar.gz
        chmod +x /usr/local/bin/sing-box
        print_success "Sing-Box 安装成功"
    else
        print_error "无法获取下载链接"
        return 1
    fi
}

# 安装Beta版本
install_beta_sing_box() {
    local arch=$(uname -m)
    local url="https://api.github.com/repos/SagerNet/sing-box/releases"
    local download_url
    
    case $arch in
        x86_64|amd64)
            download_url=$(curl -s "$url" | jq -r '.[] | select(.prerelease == true) | .assets[] | select(.browser_download_url | contains("linux-amd64.tar.gz")) | .browser_download_url' | head -n 1)
            ;;
        aarch64|arm64)
            download_url=$(curl -s "$url" | jq -r '.[] | select(.prerelease == true) | .assets[] | select(.browser_download_url | contains("linux-arm64.tar.gz")) | .browser_download_url' | head -n 1)
            ;;
        *)
            print_error "不支持的架构：$arch"
            return 1
            ;;
    esac
    
    if [[ -n "$download_url" ]]; then
        print_info "下载 Sing-Box Beta 版本..."
        wget -qO sing-box.tar.gz "$download_url"
        tar -xzf sing-box.tar.gz -C /usr/local/bin --strip-components=1
        rm sing-box.tar.gz
        chmod +x /usr/local/bin/sing-box
        print_success "Sing-Box Beta 版本安装成功"
    else
        print_error "无法获取下载链接"
        return 1
    fi
}

# 安装Go
install_go() {
    # 检查 Go 是否已安装
    if command -v go &> /dev/null; then
        local go_version=$(go version | grep -oP 'go\K[0-9]+\.[0-9]+\.[0-9]+')
        print_success "Go 已安装 (版本: ${go_version})"
        return 0
    fi
    
    # 检查是否已有 Go 但未在 PATH 中
    if [[ -d "/usr/local/go/bin" ]]; then
        export PATH=$PATH:/usr/local/go/bin
        if command -v go &> /dev/null; then
            print_success "Go 已存在，已添加到 PATH"
            return 0
        fi
    fi
    
    print_info "安装 Go..."
    local go_arch
    
    case $(uname -m) in
        x86_64) go_arch="amd64" ;;
        aarch64) go_arch="arm64" ;;
        armv6l) go_arch="armv6l" ;;
        *) print_error "不支持的架构"; return 1 ;;
    esac
    
    local go_version=$(curl -sL "https://golang.org/VERSION?m=text" | grep -o 'go[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
    if [[ -z "$go_version" ]]; then
        print_error "无法获取 Go 版本信息"
        return 1
    fi
    
    local go_url="https://go.dev/dl/$go_version.linux-$go_arch.tar.gz"
    
    print_info "下载 Go ${go_version}..."
    wget -qO- "$go_url" | tar -xz -C /usr/local
    
    # 添加到 PATH
    if ! grep -q '/usr/local/go/bin' /etc/profile; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    fi
    export PATH=$PATH:/usr/local/go/bin
    
    print_success "Go 安装完成"
}

# 编译安装
compile_sing_box() {
    print_info "编译安装 sing-box (需要较长时间)..."
    
    go install -v -tags \
with_quic,\
with_grpc,\
with_dhcp,\
with_wireguard,\
with_utls,\
with_acme,\
with_clash_api,\
with_v2ray_api,\
with_gvisor,\
with_embedded_tor,\
with_tailscale \
github.com/sagernet/sing-box/cmd/sing-box@latest
    
    if [[ $? -eq 0 ]]; then
        mv ~/go/bin/sing-box /usr/local/bin/
        chmod +x /usr/local/bin/sing-box
        print_success "编译安装成功"
    else
        print_error "编译失败"
        return 1
    fi
}

# 配置服务
configure_sing_box_service() {
    print_info "配置 sing-box 服务..."
    
    cat > /etc/systemd/system/sing-box.service << 'EOF'
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/usr/local/bin/sing-box run -c /usr/local/etc/sing-box/config.json
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable sing-box
    
    print_success "服务配置完成"
}
