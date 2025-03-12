#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

# 版本和架构
LATEST_VERSION="v2.6.1"
ARCH="amd64"
OS="linux"

# 下载目录
TEMP_DIR="/tmp/hysteria_install"
mkdir -p $TEMP_DIR

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 请使用 root 用户运行此脚本${PLAIN}"
        exit 1
    fi
}

# 检查系统
check_system() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        if [[ $ID != "ubuntu" && $ID != "debian" && $ID != "centos" && $ID != "fedora" ]]; then
            echo -e "${YELLOW}警告: 此脚本主要为 Ubuntu/Debian/CentOS/Fedora 设计，其他系统可能需要手动调整${PLAIN}"
        fi
    else
        echo -e "${YELLOW}警告: 无法确定系统类型，可能需要手动调整${PLAIN}"
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${BLUE}正在安装依赖...${PLAIN}"
    
    if [[ -f /etc/debian_version ]]; then
        # Debian/Ubuntu
        apt update -y
        apt install -y curl wget unzip net-tools ufw openssl
    elif [[ -f /etc/redhat-release ]]; then
        # CentOS/Fedora
        yum install -y curl wget unzip net-tools firewalld openssl
    else
        echo -e "${YELLOW}未知的系统类型，请手动安装依赖: curl wget unzip net-tools firewall-cmd/ufw openssl${PLAIN}"
    fi
    
    echo -e "${GREEN}依赖安装完成${PLAIN}"
}

# 下载函数 - 尝试多个源和加速器
download_hysteria() {
    echo -e "${BLUE}正在尝试从多个源下载 Hysteria...${PLAIN}"
    
    # 下载地址列表
    GITHUB_URL="https://github.com/apernet/hysteria/releases/download/app/${LATEST_VERSION}/hysteria-${OS}-${ARCH}"
    GHPROXY_URL="https://ghproxy.com/https://github.com/apernet/hysteria/releases/download/app/${LATEST_VERSION}/hysteria-${OS}-${ARCH}"
    MIRROR1_URL="https://hub.gitmirror.com/https://github.com/apernet/hysteria/releases/download/app/${LATEST_VERSION}/hysteria-${OS}-${ARCH}"
    MIRROR2_URL="https://gh.api.99988866.xyz/https://github.com/apernet/hysteria/releases/download/app/${LATEST_VERSION}/hysteria-${OS}-${ARCH}"
    
    # 尝试使用 gitmirror 加速
    echo -e "${YELLOW}尝试使用 gitmirror.com 加速下载...${PLAIN}"
    if curl -L -o "$TEMP_DIR/hysteria" "$MIRROR1_URL" --connect-timeout 10 -m 300; then
        echo -e "${GREEN}使用 gitmirror.com 下载成功${PLAIN}"
        return 0
    fi
    
    # 尝试使用 ghproxy 加速
    echo -e "${YELLOW}尝试使用 ghproxy.com 加速下载...${PLAIN}"
    if curl -L -o "$TEMP_DIR/hysteria" "$GHPROXY_URL" --connect-timeout 10 -m 300; then
        echo -e "${GREEN}使用 ghproxy.com 下载成功${PLAIN}"
        return 0
    fi
    
    # 尝试使用 99988866 加速
    echo -e "${YELLOW}尝试使用 99988866.xyz 加速下载...${PLAIN}"
    if curl -L -o "$TEMP_DIR/hysteria" "$MIRROR2_URL" --connect-timeout 10 -m 300; then
        echo -e "${GREEN}使用 99988866.xyz 下载成功${PLAIN}"
        return 0
    fi
    
    # 尝试直接从 GitHub 下载
    echo -e "${YELLOW}尝试直接从 GitHub 下载...${PLAIN}"
    if curl -L -o "$TEMP_DIR/hysteria" "$GITHUB_URL" --connect-timeout 10 -m 300; then
        echo -e "${GREEN}从 GitHub 下载成功${PLAIN}"
        return 0
    fi
    
    # 尝试使用 wget 下载
    echo -e "${YELLOW}尝试使用 wget 下载...${PLAIN}"
    if wget -O "$TEMP_DIR/hysteria" "$MIRROR1_URL" || wget -O "$TEMP_DIR/hysteria" "$GHPROXY_URL" || wget -O "$TEMP_DIR/hysteria" "$MIRROR2_URL" || wget -O "$TEMP_DIR/hysteria" "$GITHUB_URL"; then
        echo -e "${GREEN}使用 wget 下载成功${PLAIN}"
        return 0
    fi
    
    echo -e "${RED}所有下载方式均失败${PLAIN}"
    return 1
}

# 安装 Hysteria
install_hysteria() {
    echo -e "${BLUE}开始安装 Hysteria...${PLAIN}"
    
    # 检查是否已安装
    if [ -f "/usr/local/bin/hysteria" ]; then
        echo -e "${YELLOW}检测到 Hysteria 已安装，将进行更新${PLAIN}"
        systemctl stop hysteria 2>/dev/null
    fi
    
    # 下载 Hysteria
    if ! download_hysteria; then
        echo -e "${RED}下载 Hysteria 失败，请检查网络连接或手动下载${PLAIN}"
        echo -e "${YELLOW}您可以尝试手动下载并安装：${PLAIN}"
        echo -e "wget -O /usr/local/bin/hysteria https://ghproxy.com/https://github.com/apernet/hysteria/releases/download/app/${LATEST_VERSION}/hysteria-${OS}-${ARCH}"
        echo -e "chmod +x /usr/local/bin/hysteria"
        exit 1
    fi
    
    # 安装 Hysteria
    chmod +x "$TEMP_DIR/hysteria"
    mv "$TEMP_DIR/hysteria" /usr/local/bin/
    
    # 验证安装
    if [ ! -f "/usr/local/bin/hysteria" ]; then
        echo -e "${RED}Hysteria 安装失败${PLAIN}"
        exit 1
    fi
    
    # 检查版本
    INSTALLED_VERSION=$(/usr/local/bin/hysteria version | grep Version | awk '{print $2}')
    echo -e "${GREEN}Hysteria ${INSTALLED_VERSION} 安装成功！${PLAIN}"
    
    # 清理临时文件
    rm -rf $TEMP_DIR
}

# 配置 Hysteria
configure_hysteria() {
    echo -e "${BLUE}正在配置 Hysteria...${PLAIN}"
    
    # 创建配置目录
    mkdir -p /etc/hysteria
    
    # 获取服务器 IP
    SERVER_IP=$(curl -s https://api.ipify.org || wget -qO- https://api.ipify.org)
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(hostname -I | awk '{print $1}')
    fi
    
    # 设置端口
    DEFAULT_PORT=443
    read -p "请输入 Hysteria 端口 [默认: $DEFAULT_PORT]: " PORT
    PORT=${PORT:-$DEFAULT_PORT}
    
    # 检查端口是否被占用
    if netstat -tuln | grep -q ":$PORT "; then
        echo -e "${YELLOW}警告: 端口 $PORT 已被占用，请选择其他端口${PLAIN}"
        read -p "请输入新的端口: " PORT
    fi
    
    # 生成密码
    DEFAULT_PASSWORD=$(openssl rand -base64 16)
    read -p "请输入认证密码 [默认: $DEFAULT_PASSWORD]: " PASSWORD
    PASSWORD=${PASSWORD:-$DEFAULT_PASSWORD}
    
    # 生成混淆密码
    DEFAULT_OBFS=$(openssl rand -base64 16)
    read -p "请输入混淆密码 [默认: $DEFAULT_OBFS]: " OBFS
    OBFS=${OBFS:-$DEFAULT_OBFS}
    
    # 设置上传下载速度
    read -p "请输入上传速度 (Mbps) [默认: 100]: " UP_MBPS
    UP_MBPS=${UP_MBPS:-100}
    
    read -p "请输入下载速度 (Mbps) [默认: 100]: " DOWN_MBPS
    DOWN_MBPS=${DOWN_MBPS:-100}
    
    # 创建配置文件
    cat > /etc/hysteria/config.yaml << EOF
listen: :$PORT

acme:
  domains:
    - $SERVER_IP
  email: admin@example.com

auth:
  type: password
  password: $PASSWORD

masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true

bandwidth:
  up: $UP_MBPS mbps
  down: $DOWN_MBPS mbps

obfs:
  type: salamander
  salamander:
    password: $OBFS
EOF

    # 保存配置信息到文件，方便后续读取
    cat > /etc/hysteria/info.txt << EOF
SERVER_IP=$SERVER_IP
PORT=$PORT
PASSWORD=$PASSWORD
OBFS=$OBFS
UP_MBPS=$UP_MBPS
DOWN_MBPS=$DOWN_MBPS
EOF

    # 创建 systemd 服务
    cat > /etc/systemd/system/hysteria.service << EOF
[Unit]
Description=Hysteria Server
After=network.target

[Service]
ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

    # 重载 systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}Hysteria 配置完成${PLAIN}"
}

# 配置防火墙
configure_firewall() {
    echo -e "${BLUE}正在配置防火墙...${PLAIN}"
    
    if command -v ufw &>/dev/null; then
        # Ubuntu/Debian
        ufw allow 22/tcp
        ufw allow $PORT/tcp
        ufw allow $PORT/udp
        
        if ! ufw status | grep -q "Status: active"; then
            echo "y" | ufw enable
        fi
    elif command -v firewall-cmd &>/dev/null; then
        # CentOS/Fedora
        firewall-cmd --permanent --add-port=22/tcp
        firewall-cmd --permanent --add-port=$PORT/tcp
        firewall-cmd --permanent --add-port=$PORT/udp
        firewall-cmd --reload
    else
        echo -e "${YELLOW}未检测到支持的防火墙，请手动配置防火墙规则${PLAIN}"
    fi
    
    echo -e "${GREEN}防火墙配置完成${PLAIN}"
}

# 启动 Hysteria
start_hysteria() {
    echo -e "${BLUE}正在启动 Hysteria...${PLAIN}"
    
    systemctl enable hysteria
    systemctl start hysteria
    
    # 检查是否启动成功
    sleep 2
    if systemctl is-active --quiet hysteria; then
        echo -e "${GREEN}Hysteria 启动成功${PLAIN}"
    else
        echo -e "${RED}Hysteria 启动失败，请检查日志${PLAIN}"
        journalctl -u hysteria -n 20
        exit 1
    fi
}

# 显示客户端配置
show_client_config() {
    # 如果配置文件存在，读取配置信息
    if [ -f "/etc/hysteria/info.txt" ]; then
        source /etc/hysteria/info.txt
    else
        echo -e "${RED}配置信息不存在，无法显示客户端配置${PLAIN}"
        return
    fi
    
    echo -e "${GREEN}============================================${PLAIN}"
    echo -e "${GREEN}Hysteria 客户端配置信息${PLAIN}"
    echo -e "${GREEN}============================================${PLAIN}"
    echo -e "${YELLOW}服务器信息:${PLAIN}"
    echo -e "${YELLOW}服务器地址: ${PLAIN}${SERVER_IP}"
    echo -e "${YELLOW}端口: ${PLAIN}${PORT}"
    echo -e "${YELLOW}认证密码: ${PLAIN}${PASSWORD}"
    echo -e "${YELLOW}混淆密码: ${PLAIN}${OBFS}"
    echo -e "${GREEN}============================================${PLAIN}"
    echo -e "${YELLOW}客户端配置示例:${PLAIN}"
    
    echo -e "${BLUE}Hysteria v2 客户端配置:${PLAIN}"
    cat << EOF
{
  "server": "${SERVER_IP}:${PORT}",
  "auth": "${PASSWORD}",
  "tls": {
    "sni": "${SERVER_IP}",
    "insecure": true
  },
  "obfs": {
    "type": "salamander",
    "salamander": {
      "password": "${OBFS}"
    }
  },
  "bandwidth": {
    "up": "10 mbps",
    "down": "50 mbps"
  },
  "socks5": {
    "listen": "127.0.0.1:1080"
  },
  "http": {
    "listen": "127.0.0.1:8080"
  }
}
EOF
    
    echo -e "${GREEN}============================================${PLAIN}"
}

# 检查 Hysteria 状态
check_hysteria_status() {
    if systemctl is-active --quiet hysteria; then
        echo -e "${GREEN}Hysteria 正在运行${PLAIN}"
        systemctl status hysteria --no-pager
    else
        echo -e "${RED}Hysteria 未运行${PLAIN}"
        echo -e "${YELLOW}正在尝试修复...${PLAIN}"
        
               # 检查配置文件
        if [ ! -f "/etc/hysteria/config.yaml" ]; then
            echo -e "${RED}配置文件不存在，需要重新配置${PLAIN}"
            configure_hysteria
        fi
        
        # 尝试重启服务
        systemctl restart hysteria
        sleep 2
        
        if systemctl is-active --quiet hysteria; then
            echo -e "${GREEN}Hysteria 修复成功${PLAIN}"
        else
            echo -e "${RED}修复失败，请查看日志${PLAIN}"
            journalctl -u hysteria -n 20
        fi
    fi
}

# 卸载 Hysteria
uninstall_hysteria() {
    echo -e "${YELLOW}正在卸载 Hysteria...${PLAIN}"
    
    # 停止并禁用服务
    systemctl stop hysteria 2>/dev/null
    systemctl disable hysteria 2>/dev/null
    
    # 删除文件
    rm -f /usr/local/bin/hysteria
    rm -f /etc/systemd/system/hysteria.service
    rm -rf /etc/hysteria
    
    # 重载 systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}Hysteria 卸载完成${PLAIN}"
}

# 优化系统性能
optimize_system() {
    echo -e "${BLUE}正在优化系统性能...${PLAIN}"
    
    # 调整内核参数
    cat > /etc/sysctl.d/99-hysteria.conf << EOF
# 增加 TCP 最大连接数
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# 增加 UDP 缓冲区大小
net.core.rmem_max = 26214400
net.core.wmem_max = 26214400
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576

# 启用 BBR 拥塞控制算法
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# 其他优化
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
EOF

    # 应用参数
    sysctl -p /etc/sysctl.d/99-hysteria.conf
    
    # 增加打开文件数限制
    cat > /etc/security/limits.d/99-hysteria.conf << EOF
* soft nofile 1000000
* hard nofile 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF

    echo -e "${GREEN}系统性能优化完成，将在下次重启后完全生效${PLAIN}"
}

# 加速 TCP 连接
accelerate_tcp() {
    echo -e "${BLUE}正在配置 TCP 加速...${PLAIN}"
    
    # 检查是否已启用 BBR
    if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
        echo -e "${GREEN}BBR 已经启用${PLAIN}"
    else
        # 启用 BBR
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p
        
        # 验证 BBR 是否启用
        if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
            echo -e "${GREEN}BBR 启用成功${PLAIN}"
        else
            echo -e "${YELLOW}BBR 启用失败，可能需要更新内核${PLAIN}"
            
            # 询问是否更新内核
            read -p "是否要更新内核以支持 BBR？(y/n): " update_kernel
            if [[ "$update_kernel" == "y" || "$update_kernel" == "Y" ]]; then
                if [[ -f /etc/debian_version ]]; then
                    # Debian/Ubuntu
                    apt update -y
                    apt install -y --install-recommends linux-generic
                    echo -e "${GREEN}内核已更新，请重启系统后再运行此脚本${PLAIN}"
                    exit 0
                elif [[ -f /etc/redhat-release ]]; then
                    # CentOS/Fedora
                    yum update -y kernel
                    echo -e "${GREEN}内核已更新，请重启系统后再运行此脚本${PLAIN}"
                    exit 0
                else
                    echo -e "${RED}未知的系统类型，无法自动更新内核${PLAIN}"
                fi
            fi
        fi
    fi
    
    echo -e "${GREEN}TCP 加速配置完成${PLAIN}"
}

# 主菜单
show_menu() {
    clear
    echo -e "${GREEN}============================================${PLAIN}"
    echo -e "${GREEN}      Hysteria 一键安装脚本 for Linux      ${PLAIN}"
    echo -e "${GREEN}============================================${PLAIN}"
    echo -e "${GREEN}1.${PLAIN} 安装 Hysteria"
    echo -e "${GREEN}2.${PLAIN} 卸载 Hysteria"
    echo -e "${GREEN}3.${PLAIN} 查看状态"
    echo -e "${GREEN}4.${PLAIN} 查看客户端配置"
    echo -e "${GREEN}5.${PLAIN} 重启 Hysteria"
    echo -e "${GREEN}6.${PLAIN} 优化系统性能"
    echo -e "${GREEN}7.${PLAIN} 配置 TCP 加速"
    echo -e "${GREEN}0.${PLAIN} 退出脚本"
    echo -e "${GREEN}============================================${PLAIN}"
    
    read -p "请输入选项 [0-7]: " option
    case $option in
        1)
            check_root
            check_system
            install_dependencies
            install_hysteria
            configure_hysteria
            configure_firewall
            start_hysteria
            show_client_config
            ;;
        2)
            check_root
            uninstall_hysteria
            ;;
        3)
            check_root
            check_hysteria_status
            ;;
        4)
            show_client_config
            ;;
        5)
            check_root
            systemctl restart hysteria
            check_hysteria_status
            ;;
        6)
            check_root
            optimize_system
            ;;
        7)
            check_root
            accelerate_tcp
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选项${PLAIN}"
            ;;
    esac
    
    # 按任意键返回主菜单
    read -n 1 -s -r -p "按任意键返回主菜单..."
    show_menu
}

# 运行主菜单
show_menu
