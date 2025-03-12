#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

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
        if [[ $ID != "ubuntu" ]]; then
            echo -e "${RED}错误: 此脚本仅支持 Ubuntu 系统${PLAIN}"
            exit 1
        fi
    else
        echo -e "${RED}错误: 无法确定系统类型${PLAIN}"
        exit 1
    fi
}

# 检查并安装依赖
install_dependencies() {
    echo -e "${BLUE}正在检查并安装依赖...${PLAIN}"
    apt update -y
    apt install -y curl wget unzip net-tools ufw
    if [ $? -ne 0 ]; then
        echo -e "${RED}依赖安装失败，请检查网络连接${PLAIN}"
        exit 1
    fi
    echo -e "${GREEN}依赖安装完成${PLAIN}"
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if netstat -tuln | grep -q ":$port "; then
        echo -e "${YELLOW}警告: 端口 $port 已被占用${PLAIN}"
        return 1
    fi
    return 0
}

# 生成随机密码
generate_password() {
    openssl rand -base64 16
}

# 安装 Hysteria
install_hysteria() {
    echo -e "${BLUE}正在安装 Hysteria...${PLAIN}"
    
    # 检查是否已安装
    if [ -f "/usr/local/bin/hysteria" ]; then
        echo -e "${YELLOW}Hysteria 已安装，正在检查更新...${PLAIN}"
        bash <(curl -fsSL https://get.hy2.sh/) --version latest
    else
        bash <(curl -fsSL https://get.hy2.sh/)
    fi
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Hysteria 安装失败${PLAIN}"
        exit 1
    fi
    
    # 检查是否安装成功
    if [ ! -f "/usr/local/bin/hysteria" ]; then
        echo -e "${RED}Hysteria 安装失败，文件不存在${PLAIN}"
        exit 1
    fi
    
    echo -e "${GREEN}Hysteria 安装成功${PLAIN}"
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
    while ! check_port $PORT; do
        read -p "请输入其他端口: " PORT
    done
    
    # 生成密码
    DEFAULT_PASSWORD=$(generate_password)
    read -p "请输入认证密码 [默认: $DEFAULT_PASSWORD]: " PASSWORD
    PASSWORD=${PASSWORD:-$DEFAULT_PASSWORD}
    
    # 生成混淆密码
    DEFAULT_OBFS=$(generate_password)
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
    
    # 检查防火墙状态
    if ! command -v ufw &> /dev/null; then
        echo -e "${YELLOW}未检测到 ufw，正在安装...${PLAIN}"
        apt install -y ufw
    fi
    
    # 允许 SSH 和 Hysteria 端口
    ufw allow 22/tcp
    ufw allow $PORT/tcp
    ufw allow $PORT/udp
    
    # 如果防火墙未启用，则启用
    if ! ufw status | grep -q "Status: active"; then
        echo "y" | ufw enable
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
    echo -e "${GREEN}============================================${PLAIN}"
    echo -e "${GREEN}Hysteria 安装成功！${PLAIN}"
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
    echo -e "${YELLOW}状态管理命令:${PLAIN}"
    echo -e "  启动: ${GREEN}systemctl start hysteria${PLAIN}"
    echo -e "  停止: ${GREEN}systemctl stop hysteria${PLAIN}"
    echo -e "  重启: ${GREEN}systemctl restart hysteria${PLAIN}"
    echo -e "  状态: ${GREEN}systemctl status hysteria${PLAIN}"
    echo -e "  查看日志: ${GREEN}journalctl -u hysteria -f${PLAIN}"
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
            echo -e "${RED}配置文件不存在，重新配置${PLAIN}"
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
    systemctl stop hysteria
    systemctl disable hysteria
    
    # 删除文件
    rm -f /usr/local/bin/hysteria
    rm -f /etc/systemd/system/hysteria.service
    rm -rf /etc/hysteria
    
    # 重载 systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}Hysteria 卸载完成${PLAIN}"
}

# 主菜单
show_menu() {
    echo -e "${GREEN}============================================${PLAIN}"
    echo -e "${GREEN}      Hysteria 一键安装脚本 for Ubuntu      ${PLAIN}"
    echo -e "${GREEN}============================================${PLAIN}"
    echo -e "${GREEN}1.${PLAIN} 安装 Hysteria"
    echo -e "${GREEN}2.${PLAIN} 卸载 Hysteria"
    echo -e "${GREEN}3.${PLAIN} 查看状态"
    echo -e "${GREEN}4.${PLAIN} 查看客户端配置"
    echo -e "${GREEN}5.${PLAIN} 重启 Hysteria"
    echo -e "${GREEN}0.${PLAIN} 退出脚本"
    echo -e "${GREEN}============================================${PLAIN}"
    
    read -p "请输入选项 [0-5]: " option
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
            if [ -f "/etc/hysteria/config.yaml" ]; then
                source <(grep -E 'PORT=|PASSWORD=|OBFS=|SERVER_IP=' /etc/hysteria/config.yaml 2>/dev/null || echo "配置文件解析失败")
                show_client_config
            else
                echo -e "${RED}配置文件不存在${PLAIN}"
            fi
            ;;
        5)
            check_root
            systemctl restart hysteria
            check_hysteria_status
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选项${PLAIN}"
            ;;
    esac
}

# 运行主菜单
show_menu
