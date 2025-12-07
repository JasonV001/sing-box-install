#!/bin/bash

# 清理 acme.sh 配置脚本

echo "清理 acme.sh 配置..."

# 读取域名
read -p "请输入要清理的域名（留空清理所有）: " domain

if [[ -z "$domain" ]]; then
    # 清理所有
    echo "清理所有 acme.sh 配置..."
    
    # 删除所有域名配置
    if [[ -f ~/.acme.sh/acme.sh ]]; then
        for domain_dir in ~/.acme.sh/*/; do
            if [[ -d "$domain_dir" ]]; then
                local_domain=$(basename "$domain_dir")
                if [[ "$local_domain" != "ca" && "$local_domain" != "http.header" && "$local_domain" != "dnsapi" ]]; then
                    echo "删除: $local_domain"
                    ~/.acme.sh/acme.sh --remove -d "$local_domain" 2>/dev/null
                    rm -rf "$domain_dir"
                fi
            fi
        done
    fi
    
    echo "✓ 所有配置已清理"
else
    # 清理指定域名
    echo "清理域名: $domain"
    
    if [[ -f ~/.acme.sh/acme.sh ]]; then
        ~/.acme.sh/acme.sh --remove -d "$domain" 2>/dev/null
    fi
    
    rm -rf ~/.acme.sh/${domain} 2>/dev/null
    rm -rf ~/.acme.sh/${domain}_ecc 2>/dev/null
    
    echo "✓ 域名配置已清理"
fi

echo ""
echo "现在可以重新申请证书了"
