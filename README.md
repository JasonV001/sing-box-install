# Sing-box 模块化脚本 - 使用指南

## 快速开始

### 一键安装

```bash
bash <(curl -sSL https://your-domain/install.sh)
```

### 运行脚本

```bash
sb
```

---

## 主菜单说明

运行 `sb` 后会看到主菜单：

```
╔════════════════════════════════════════════════════════════╗
║         Sing-box 一键安装管理脚本 v2.0                    ║
║         模块化版本 - 支持多协议 + 中转 + Argo             ║
╚════════════════════════════════════════════════════════════╝

═══════════════════ 主菜单 ═══════════════════

  1.  安装 Sing-box
  2.  配置节点
  3.  查看节点信息
  4.  配置中转
  5.  配置 Argo 隧道
  6.  管理服务
  7.  卸载
  0.  退出
```

---

## 功能详解

### 1. 安装 Sing-box

选择 `1` 后，会提示选择安装方式：

- **Latest 版本** - 稳定版本，推荐
- **Beta 版本** - 测试版本，包含新功能
- **编译安装** - 完整功能版本，需要时间较长

### 2. 配置节点

选择 `2` 后，会显示协议列表：

```
═══════════════════ 协议选择 ═══════════════════

  1.  SOCKS5
  2.  HTTP
  3.  AnyTLS
  4.  TUIC V5
  5.  Juicity
  6.  Hysteria2
  7.  VLESS 系列
  8.  Trojan 系列
  9.  VMess 系列
  10. ShadowTLS V3
  11. Shadowsocks
  0.  返回主菜单
```

#### 协议系列说明

**VLESS 系列** 包含：
- VLESS+TCP
- VLESS+WebSocket
- VLESS+gRPC
- VLESS+HTTPUpgrade
- VLESS+H2C+REALITY
- VLESS+gRPC+REALITY

**Trojan 系列** 包含：
- Trojan+TCP
- Trojan+WebSocket
- Trojan+gRPC
- Trojan+HTTPUpgrade
- Trojan+TCP+TLS
- Trojan+WebSocket+TLS
- Trojan+gRPC+TLS

**VMess 系列** 包含：
- VMess+TCP
- VMess+WebSocket
- VMess+gRPC
- VMess+HTTPUpgrade
- VMess+TCP+TLS
- VMess+WebSocket+TLS
- VMess+gRPC+TLS

### 3. 查看节点信息

选择 `3` 后，可以：
- 查看所有节点列表
- 查看详细配置
- 查看分享链接
- 导出所有链接
- 生成订阅链接

### 4. 配置中转

选择 `4` 后，可以配置四种中转方式：

#### iptables 端口转发
- 性能最好
- 适合简单转发

#### DNAT 转发
- 支持 NAT 转换
- 适合复杂网络

#### Socat 转发
- 灵活配置
- 支持 TCP/UDP

#### Gost 转发
- 功能最强大
- 支持链式代理

### 5. 配置 Argo 隧道

选择 `5` 后，可以配置三种 Argo 隧道：

#### Quick Tunnel
- 无需域名
- 自动生成临时域名
- 适合测试

#### Token 认证
- 需要 Cloudflare 账号
- 在 Zero Trust 创建隧道
- 获取 Token

#### JSON 认证
- 需要 Cloudflare 账号
- 下载 JSON 凭证
- 支持自定义域名

### 6. 管理服务

选择 `6` 后，可以：
- 启动服务
- 停止服务
- 重启服务
- 查看状态
- 查看日志
- 启用/禁用开机自启
- 重载配置

### 7. 卸载

选择 `7` 后，可以：
- 完全卸载（删除所有）
- 部分卸载（保留配置）

---

## 常用操作示例

### 示例1: 配置 Hysteria2 节点

```bash
# 1. 运行脚本
sb

# 2. 选择配置节点
输入: 2

# 3. 选择 Hysteria2
输入: 6

# 4. 输入端口（或使用默认）
输入: 443 或直接回车

# 5. 输入域名（或使用默认）
输入: example.com 或直接回车

# 6. 等待配置完成
# 7. 查看生成的分享链接
```

### 示例2: 配置 VLESS+Reality 节点

```bash
# 1. 运行脚本
sb

# 2. 选择配置节点
输入: 2

# 3. 选择 VLESS 系列
输入: 7

# 4. 选择 VLESS+Vision+REALITY
输入: 5

# 5. 按提示输入参数
# 6. 查看生成的配置
```

### 示例3: 配置端口转发

```bash
# 1. 运行脚本
sb

# 2. 选择配置中转
输入: 4

# 3. 选择添加中转规则
输入: 1

# 4. 选择 iptables 转发
输入: 1

# 5. 输入本地端口
输入: 10000

# 6. 输入目标IP
输入: 1.2.3.4

# 7. 输入目标端口
输入: 443

# 8. 选择协议
输入: both
```

### 示例4: 配置 Argo Quick Tunnel

```bash
# 1. 运行脚本
sb

# 2. 选择配置 Argo 隧道
输入: 5

# 3. 选择 Quick Tunnel
输入: 1

# 4. 输入本地端口
输入: 443

# 5. 选择 IP 版本
输入: 4

# 6. 等待获取临时域名
```

---

## 配置文件位置

### 主配置文件
```
/usr/local/etc/sing-box/config.json
```

### 证书文件
```
/etc/ssl/private/
```

### 链接文件
```
/usr/local/etc/sing-box/links/
```

### 中转配置
```
/usr/local/etc/sing-box/relays/relay.json
```

---

## 服务管理命令

### 使用脚本管理
```bash
sb
# 选择: 6. 管理服务
```

### 使用 systemctl 命令
```bash
# 启动
systemctl start sing-box

# 停止
systemctl stop sing-box

# 重启
systemctl restart sing-box

# 状态
systemctl status sing-box

# 日志
journalctl -u sing-box -f

# 开机自启
systemctl enable sing-box
```

---

## 常见问题

### Q1: 端口被占用怎么办？

```bash
# 查看端口占用
ss -tuln | grep :443

# 杀死进程
kill -9 $(lsof -t -i:443)
```

### Q2: 服务启动失败怎么办？

```bash
# 检查配置
sing-box check -c /usr/local/etc/sing-box/config.json

# 查看日志
journalctl -u sing-box -n 100
```

### Q3: 如何查看分享链接？

```bash
# 方法1: 使用脚本
sb
# 选择: 3. 查看节点信息
# 选择: 2. 查看分享链接

# 方法2: 直接查看文件
cat /usr/local/etc/sing-box/links/*.txt
```

### Q4: 如何生成订阅链接？

```bash
sb
# 选择: 3. 查看节点信息
# 选择: 4. 生成订阅链接
```

### Q5: 如何卸载？

```bash
sb
# 选择: 7. 卸载
# 输入: yes
```

---

## 高级技巧

### 1. 批量配置节点

可以通过修改脚本或使用配置文件批量添加节点。

### 2. 自定义配置

可以直接编辑 `/usr/local/etc/sing-box/config.json` 进行高级配置。

### 3. 配置备份

```bash
# 备份配置
cp /usr/local/etc/sing-box/config.json ~/config.json.bak

# 恢复配置
cp ~/config.json.bak /usr/local/etc/sing-box/config.json
systemctl restart sing-box
```

### 4. 日志分析

```bash
# 查看错误日志
journalctl -u sing-box -p err

# 查看最近100行
journalctl -u sing-box -n 100

# 实时查看
journalctl -u sing-box -f
```

---

## 性能优化建议

### 1. BBR 加速

脚本会提示是否开启 BBR，建议开启。

### 2. 端口选择

- Hysteria2: 建议使用 443 或 8443
- VLESS: 建议使用 443
- Trojan: 建议使用 443
- Shadowsocks: 建议使用 8388

### 3. 加密方式

- Shadowsocks: 推荐 2022-blake3-aes-128-gcm
- VMess: 推荐 auto
- VLESS: 推荐 none

---

## 安全建议

### 1. 定期更新

```bash
# 更新 Sing-box
sb
# 选择: 1. 安装 Sing-box
# 选择重新安装
```

### 2. 使用强密码

脚本会自动生成强密码，建议不要修改。

### 3. 定期备份

定期备份配置文件和证书。

### 4. 防火墙配置

脚本会自动配置防火墙，但建议检查规则。

---

## 获取帮助

### 文档
- 完整文档: `README.md`
- 快速指南: `QUICK_START.md`
- 项目总结: `PROJECT_SUMMARY.md`

### 在线资源
- GitHub: https://github.com/your-repo
- Telegram: https://t.me/your-group
- Sing-box 官方: https://sing-box.sagernet.org/

### 问题反馈
- GitHub Issues: https://github.com/your-repo/issues
- Telegram 群组: https://t.me/your-group

---

**祝使用愉快！** 🎉
