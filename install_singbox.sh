#!/bin/bash

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"

# 版本信息
VERSION="1.11.4"
CONFIG_DIR="/etc/sing-box"
CONFIG_FILE="${CONFIG_DIR}/config.json"
SERVICE_FILE="/etc/systemd/system/sing-box.service"

# 检查是否为root用户
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 必须使用root用户运行此脚本!${PLAIN}"
        exit 1
    fi
}

# 检查系统
check_system() {
    if [ ! -f /etc/os-release ]; then
        echo -e "${RED}不支持的操作系统!${PLAIN}"
        exit 1
    fi
    
    if [ -f /etc/lsb-release ]; then
        source /etc/lsb-release
        if [ "${DISTRIB_ID}" != "Ubuntu" ]; then
            echo -e "${RED}不支持的操作系统，仅支持Ubuntu!${PLAIN}"
            exit 1
        fi
    else
        echo -e "${RED}不支持的操作系统，仅支持Ubuntu!${PLAIN}"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${GREEN}正在安装依赖...${PLAIN}"
    apt update
    apt install -y curl wget tar unzip net-tools
}

# 安装Sing-Box
install_singbox() {
    echo -e "${GREEN}正在安装Sing-Box...${PLAIN}"
    
    # 创建配置目录
    mkdir -p ${CONFIG_DIR}
    
    # 下载Sing-Box
    local ARCH=$(uname -m)
    local DOWNLOAD_URL=""
    
    case "${ARCH}" in
        "x86_64")
            DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-amd64.tar.gz"
            ;;
        "aarch64")
            DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-arm64.tar.gz"
            ;;
        *)
            echo -e "${RED}不支持的架构: ${ARCH}${PLAIN}"
            exit 1
            ;;
    esac
    
    # 下载并解压
    wget -O /tmp/sing-box.tar.gz ${DOWNLOAD_URL}
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载Sing-Box失败，请检查网络连接!${PLAIN}"
        exit 1
    fi
    
    tar -xzf /tmp/sing-box.tar.gz -C /tmp
    cp /tmp/sing-box-${VERSION}-linux-*/sing-box /usr/local/bin/
    chmod +x /usr/local/bin/sing-box
    
    # 清理临时文件
    rm -rf /tmp/sing-box*
    
    # 创建配置文件
    if [ ! -f ${CONFIG_FILE} ]; then
        # 生成随机密码
        local PASSWORD=$(tr -dc 'A-Za-z0-9!@#$%^&*()' < /dev/urandom | head -c 16)
        
        # 创建基本配置
        cat > ${CONFIG_FILE} << EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "shadowsocks",
      "tag": "ss-in",
      "listen": "::",
      "listen_port": 8388,
      "method": "aes-256-gcm",
      "password": "${PASSWORD}"
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct-out"
    },
    {
      "type": "block",
      "tag": "block-out"
    }
  ],
  "route": {
    "rules": [
      {
        "ip_cidr": [
          "10.0.0.0/8",
          "172.16.0.0/12",
          "192.168.0.0/16",
          "127.0.0.0/8",
          "fc00::/7"
        ],
        "outbound": "direct-out"
      }
    ],
    "final": "direct-out",
    "auto_detect_interface": true
  }
}
EOF
    fi
    
    # 创建systemd服务
    cat > ${SERVICE_FILE} << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.app
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=${CONFIG_DIR}
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/usr/local/bin/sing-box run -c ${CONFIG_FILE}
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd
    systemctl daemon-reload
    systemctl enable sing-box
    systemctl start sing-box
    
    # 检查是否启动成功
    sleep 2
    if systemctl is-active --quiet sing-box; then
        echo -e "${GREEN}Sing-Box 安装成功!${PLAIN}"
        show_config
    else
        echo -e "${RED}Sing-Box 安装失败，请检查日志!${PLAIN}"
        exit 1
    fi
}

# 卸载Sing-Box
uninstall_singbox() {
    echo -e "${YELLOW}正在卸载Sing-Box...${PLAIN}"
    
    # 停止并禁用服务
    systemctl stop sing-box
    systemctl disable sing-box
    
    # 删除文件
    rm -f /usr/local/bin/sing-box
    rm -f ${SERVICE_FILE}
    rm -rf ${CONFIG_DIR}
    
    # 重新加载systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}Sing-Box 已成功卸载!${PLAIN}"
}

# 重启服务
restart_service() {
    echo -e "${BLUE}正在重启Sing-Box服务...${PLAIN}"
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        echo -e "${GREEN}Sing-Box 服务已重启!${PLAIN}"
    else
        echo -e "${RED}Sing-Box 服务重启失败，请检查日志!${PLAIN}"
    fi
}

# 停止服务
stop_service() {
    echo -e "${BLUE}正在停止Sing-Box服务...${PLAIN}"
    systemctl stop sing-box
    
    if ! systemctl is-active --quiet sing-box; then
        echo -e "${GREEN}Sing-Box 服务已停止!${PLAIN}"
    else
        echo -e "${RED}Sing-Box 服务停止失败!${PLAIN}"
    fi
}

# 查看服务状态
check_status() {
    echo -e "${BLUE}Sing-Box 服务状态:${PLAIN}"
    systemctl status sing-box
}

# 显示配置信息
show_config() {
    if [ -f ${CONFIG_FILE} ]; then
        local SERVER_IP=$(curl -s https://api.ipify.org || curl -s https://api64.ipify.org)
        local PORT=$(grep -o '"listen_port": [0-9]*' ${CONFIG_FILE} | awk '{print $2}')
        local METHOD=$(grep -o '"method": "[^"]*"' ${CONFIG_FILE} | awk -F'"' '{print $4}')
        local PASSWORD=$(grep -o '"password": "[^"]*"' ${CONFIG_FILE} | awk -F'"' '{print $4}')
        
        echo -e "${GREEN}====== Sing-Box 配置信息 ======${PLAIN}"
        echo -e "${YELLOW}服务器地址: ${PLAIN}${SERVER_IP}"
        echo -e "${YELLOW}端口: ${PLAIN}${PORT}"
        echo -e "${YELLOW}加密方式: ${PLAIN}${METHOD}"
        echo -e "${YELLOW}密码: ${PLAIN}${PASSWORD}"
        echo -e "${GREEN}=============================${PLAIN}"
    else
        echo -e "${RED}配置文件不存在!${PLAIN}"
    fi
}

# 显示菜单
show_menu() {
    echo -e "${GREEN}====== Sing-Box 管理脚本 ======${PLAIN}"
    echo -e "${GREEN}1.${PLAIN} 安装 Sing-Box"
    echo -e "${GREEN}2.${PLAIN} 卸载 Sing-Box"
    echo -e "${GREEN}3.${PLAIN} 重启 Sing-Box 服务"
    echo -e "${GREEN}4.${PLAIN} 停止 Sing-Box 服务"
    echo -e "${GREEN}5.${PLAIN} 查看 Sing-Box 服务状态"
    echo -e "${GREEN}6.${PLAIN} 查看 Sing-Box 配置信息"
    echo -e "${GREEN}0.${PLAIN} 退出脚本"
    echo -e "${GREEN}=============================${PLAIN}"
    
    read -p "请输入选项 [0-6]: " option
    
    case "${option}" in
        1)
            check_root
            check_system
            install_dependencies
            install_singbox
            ;;
        2)
            check_root
            uninstall_singbox
            ;;
        3)
            check_root
            restart_service
            ;;
        4)
            check_root
            stop_service
            ;;
        5)
            check_root
            check_status
            ;;
        6)
            check_root
            show_config
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选项!${PLAIN}"
            ;;
    esac
}

# 主函数
main() {
    show_menu
}

# 执行主函数
main
