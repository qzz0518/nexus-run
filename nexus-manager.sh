#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VERSION="0.5.0"

NEXUS_HOME="$HOME/.nexus"
NODE_ID_FILE="$NEXUS_HOME/node-id"
SESSION_NAME="nexus-network"
ARCH=$(uname -m)
OS=$(uname -s)

check_and_install_git() {
    if ! command -v git &> /dev/null; then
        if [ "$OS" = "Darwin" ]; then
            if ! command -v brew &> /dev/null; then
                echo -e "${RED}请先安装 Homebrew: https://brew.sh${NC}"
                exit 1
            fi
            brew install git
        elif [ "$OS" = "Linux" ]; then
            if command -v apt &> /dev/null; then
                echo -e "${YELLOW}正在安装 git...${NC}"
                sudo apt update && sudo apt install -y git
            elif command -v yum &> /dev/null; then
                echo -e "${YELLOW}正在安装 git...${NC}"
                sudo yum install -y git
            else
                echo -e "${RED}未能识别的包管理器，请手动安装 git${NC}"
                exit 1
            fi
        else
            echo -e "${RED}不支持的操作系统${NC}"
            exit 1
        fi
    fi
}

check_and_install_rust() {
    # 检查是否存在 cargo env 文件并激活环境
    if [ -f "$HOME/.cargo/env" ]; then
        echo -e "${YELLOW}检测到已安装 Rust，正在激活环境...${NC}"
        source "$HOME/.cargo/env"
    elif ! command -v rustc &> /dev/null; then
        echo -e "${YELLOW}Rust未安装，正在安装...${NC}"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        source "$HOME/.cargo/env"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Rust安装失败${NC}"
            exit 1
        fi
    fi
}

setup_directories() {
    if [ ! -d "$NEXUS_HOME" ]; then
        echo -e "${YELLOW}创建 $NEXUS_HOME 目录...${NC}"
        mkdir -p "$NEXUS_HOME"
    fi

    if [ ! -d "$NEXUS_HOME/network-api" ]; then
        echo -e "${YELLOW}克隆network-api仓库...${NC}"
        cd "$NEXUS_HOME"
        git clone https://github.com/nexus-xyz/network-api.git
        if [ $? -ne 0 ]; then
            echo -e "${RED}仓库克隆失败${NC}"
            exit 1
        fi
    fi
}

check_system_compatibility() {
    local is_compatible=false
    if [ "$OS" = "Linux" ] && [ "$ARCH" = "x86_64" ]; then
        is_compatible=true
        BINARY_URL="https://github.com/qzz0518/nexus-run/releases/download/v$VERSION/nexus-network-linux-x86"
        EXAMPLE_URL="https://github.com/qzz0518/nexus-run/releases/download/v$VERSION/example-linux-x86"
    elif [ "$OS" = "Darwin" ] && [ "$ARCH" = "arm64" ]; then
        is_compatible=true
        BINARY_URL="https://github.com/qzz0518/nexus-run/releases/download/v$VERSION/nexus-network-macos-arm64"
        EXAMPLE_URL="https://github.com/qzz0518/nexus-run/releases/download/v$VERSION/example-macos-arm64"
    fi

    if [ "$is_compatible" = false ]; then
        echo -e "${RED}不支持的系统或架构: $OS $ARCH${NC}"
        exit 1
    fi
}

download_binary() {
    local binary_path="$NEXUS_HOME/network-api/clients/cli/nexus-network"
    local example_path="$NEXUS_HOME/network-api/clients/cli/example"
    
    if [ ! -f "$binary_path" ]; then
        echo -e "${YELLOW}下载主程序...${NC}"
        curl -L "$BINARY_URL" -o "$binary_path"
        if [ $? -eq 0 ]; then
            chmod +x "$binary_path"
            echo -e "${GREEN}主程序下载完成${NC}"
        else
            echo -e "${RED}主程序下载失败${NC}"
            exit 1
        fi
    fi

    if [ ! -f "$example_path" ]; then
        echo -e "${YELLOW}下载 example 程序...${NC}"
        curl -L "$EXAMPLE_URL" -o "$example_path"
        if [ $? -eq 0 ]; then
            chmod +x "$example_path"
            echo -e "${GREEN}example 程序下载完成${NC}"
        else
            echo -e "${RED}example 程序下载失败${NC}"
            exit 1
        fi
    fi
}

start_network() {
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo -e "${YELLOW}Network已在运行中，请选择3查看运行日志${NC}"
        return
    fi

    cd "$NEXUS_HOME/network-api/clients/cli" || exit

    tmux new-session -d -s "$SESSION_NAME" "cd '$NEXUS_HOME/network-api/clients/cli' && ./nexus-network --start --beta"
    echo -e "${GREEN}Network已启动，选择3可查看运行日志${NC}"
}

check_status() {
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo -e "${GREEN}Network正在运行中. 正在打开日志窗口...${NC}"
        echo -e "${YELLOW}提示: 查看完成后直接关闭终端即可，不要使用 Ctrl+C${NC}"
        sleep 2
        tmux attach-session -t "$SESSION_NAME"
    else
        echo -e "${RED}Network未运行${NC}"
    fi
}

show_node_id() {
    if [ -f "$NODE_ID_FILE" ]; then
        local id=$(cat "$NODE_ID_FILE")
        echo -e "${GREEN}当前 Node ID: $id${NC}"
    else
        echo -e "${RED}未找到 Node ID${NC}"
    fi
}

set_node_id() {
    read -p "请输入新的 Node ID: " new_id
    if [ -n "$new_id" ]; then
        echo "$new_id" > "$NODE_ID_FILE"
        echo -e "${GREEN}Node ID 已更新${NC}"
    else
        echo -e "${RED}Node ID 不能为空${NC}"
    fi
}

stop_network() {
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        tmux kill-session -t "$SESSION_NAME"
        echo -e "${GREEN}Network已停止${NC}"
    else
        echo -e "${RED}Network未运行${NC}"
    fi
}

update_nexus() {
    echo -e "${YELLOW}开始更新 Nexus...${NC}"

    stop_network

    cd "$NEXUS_HOME/network-api"
    git pull

    rm -f "$NEXUS_HOME/network-api/clients/cli/nexus-network"
    rm -f "$NEXUS_HOME/network-api/clients/cli/example"
    download_binary

    echo -e "${GREEN}更新完成！正在启动 Network...${NC}"
    start_network
}

cleanup() {
    echo -e "\n${YELLOW}正在清理...${NC}"
    exit 0
}

install_network() {
    echo -e "${YELLOW}开始安装 Nexus Network...${NC}"
    check_system_compatibility
    check_and_install_git
    check_and_install_rust
    setup_directories
    download_binary
    echo -e "${GREEN}安装完成！${NC}"
}

trap cleanup SIGINT SIGTERM

while true; do
    echo -e "\n${YELLOW}=== Nexus Network 管理工具 ===${NC}"
    echo -e "${GREEN}当前版本: ${NC}v$VERSION"
    echo -e "${GREEN}Twitter: ${NC}https://x.com/zerah_eth"
    echo -e "${GREEN}Github: ${NC}https://github.com/qzz0518/nexus-run"
    echo -e "${GREEN}免费领SOL: ${NC}SOL 回血神器 - https://solback.app/\n"

    echo "1. 安装 Network"
    echo "2. 启动 Network"
    echo "3. 查看当前运行状态"
    echo "4. 查看 Node ID"
    echo "5. 设置 Node ID"
    echo "6. 停止 Network"
    echo "7. 更新 Network"
    echo "8. 退出"

    read -p "请选择操作 [1-8]: " choice
    case $choice in
        1)
            install_network
            ;;
        2)
            if [ ! -f "$NEXUS_HOME/network-api/clients/cli/nexus-network" ]; then
                echo -e "${RED}请先安装 Network（选项1）${NC}"
            else
                if [ ! -f "$NODE_ID_FILE" ]; then
                    echo -e "${YELLOW}未检测到 Node ID，请先设置${NC}"
                    set_node_id
                fi
                if [ -f "$NODE_ID_FILE" ]; then
                    start_network
                fi
            fi
            ;;
        3)
            check_status
            ;;
        4)
            show_node_id
            ;;
        5)
            set_node_id
            ;;
        6)
            stop_network
            ;;
        7)
            update_nexus
            ;;
        8)
            echo -e "\n${GREEN}感谢使用！${NC}"
            echo -e "${YELLOW}更多工具请关注 Twitter: ${NC}https://x.com/zerah_eth"
            echo -e "${YELLOW}SOL 代币回收工具: ${NC}https://solback.app/\n"
            cleanup
            ;;
        *)
            echo -e "${RED}无效的选择${NC}"
            ;;
    esac
done
