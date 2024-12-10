#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NEXUS_HOME="$HOME/.nexus"
PROVER_ID_FILE="$NEXUS_HOME/prover-id"
SESSION_NAME="nexus-prover"
PROGRAM_DIR="$NEXUS_HOME/src/generated"
ARCH=$(uname -m)
OS=$(uname -s)
REPO_BASE="https://github.com/nexus-xyz/network-api/raw/refs/tags/0.4.2/clients/cli"

check_openssl_version() {
    # 仅在Linux系统下检查OpenSSL版本
    if [ "$OS" = "Linux" ]; then
        if ! command -v openssl &> /dev/null; then
            echo -e "${RED}未安装 OpenSSL${NC}"
            return 1
        fi

        local version=$(openssl version | cut -d' ' -f2)
        local major_version=$(echo $version | cut -d'.' -f1)

        if [ "$major_version" -lt "3" ]; then
            if command -v apt &> /dev/null; then
                echo -e "${YELLOW}当前 OpenSSL 版本过低，正在升级...${NC}"
                sudo apt update
                sudo apt install -y openssl
                if [ $? -ne 0 ]; then
                    echo -e "${RED}OpenSSL 升级失败，请手动升级至 3.0 或更高版本${NC}"
                    return 1
                fi
            elif command -v yum &> /dev/null; then
                echo -e "${YELLOW}当前 OpenSSL 版本过低，正在升级...${NC}"
                sudo yum update -y openssl
                if [ $? -ne 0 ]; then
                    echo -e "${RED}OpenSSL 升级失败，请手动升级至 3.0 或更高版本${NC}"
                    return 1
                fi
            else
                echo -e "${RED}请手动升级 OpenSSL 至 3.0 或更高版本${NC}"
                return 1
            fi
        fi
        echo -e "${GREEN}OpenSSL 版本检查通过${NC}"
    fi
    return 0
}

setup_directories() {
    mkdir -p "$PROGRAM_DIR"
    ln -sf "$PROGRAM_DIR" "$NEXUS_HOME/src/generated"
}

check_dependencies() {
    # 添加OpenSSL检查
    check_openssl_version || exit 1

    if ! command -v tmux &> /dev/null; then
        echo -e "${YELLOW}tmux 未安装, 正在安装...${NC}"
        if [ "$OS" = "Darwin" ]; then
            if ! command -v brew &> /dev/null; then
                echo -e "${RED}请先安装 Homebrew: https://brew.sh${NC}"
                exit 1
            fi
            brew install tmux
        elif [ "$OS" = "Linux" ]; then
            if command -v apt &> /dev/null; then
                sudo apt update && sudo apt install -y tmux
            elif command -v yum &> /dev/null; then
                sudo yum install -y tmux
            else
                echo -e "${RED}未能识别的包管理器，请手动安装 tmux${NC}"
                exit 1
            fi
        fi
    fi
}

download_program_files() {
    local files="cancer-diagnostic fast-fib"

    for file in $files; do
        local target_path="$PROGRAM_DIR/$file"
        if [ ! -f "$target_path" ]; then
            echo -e "${YELLOW}下载 $file...${NC}"
            curl -L "$REPO_BASE/src/generated/$file" -o "$target_path"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}$file 下载完成${NC}"
                chmod +x "$target_path"
            else
                echo -e "${RED}$file 下载失败${NC}"
            fi
        fi
    done
}

download_prover() {
    local prover_path="$NEXUS_HOME/prover"
    if [ ! -f "$prover_path" ]; then
        if [ "$OS" = "Darwin" ]; then
            if [ "$ARCH" = "x86_64" ]; then
                echo -e "${YELLOW}下载 macOS Intel 架构 Prover...${NC}"
                curl -L "https://github.com/qzz0518/nexus-run/releases/download/v0.4.2/prover-macos-amd64" -o "$prover_path"
            elif [ "$ARCH" = "arm64" ]; then
                echo -e "${YELLOW}下载 macOS ARM64 架构 Prover...${NC}"
                curl -L "https://github.com/qzz0518/nexus-run/releases/download/v0.4.2/prover-arm64" -o "$prover_path"
            else
                echo -e "${RED}不支持的 macOS 架构: $ARCH${NC}"
                exit 1
            fi
        elif [ "$OS" = "Linux" ]; then
            if [ "$ARCH" = "x86_64" ]; then
                echo -e "${YELLOW}下载 Linux AMD64 架构 Prover...${NC}"
                curl -L "https://github.com/qzz0518/nexus-run/releases/download/v0.4.2/prover-amd64" -o "$prover_path"
            else
                echo -e "${RED}不支持的 Linux 架构: $ARCH${NC}"
                exit 1
            fi
        else
            echo -e "${RED}不支持的操作系统: $OS${NC}"
            exit 1
        fi
        chmod +x "$prover_path"
        echo -e "${GREEN}Prover 下载完成${NC}"
    fi
}

download_files() {
    download_prover
    download_program_files
}

generate_prover_id() {
    local temp_output=$(mktemp)
    tail -f "$temp_output" &
    local tail_pid=$!

    "./prover" beta.orchestrator.nexus.xyz > "$temp_output" 2>&1 &
    local prover_pid=$!

    # 等待直到看到成功连接的消息
    while ! grep -q "Success! Connection complete!" "$temp_output" 2>/dev/null; do
        if ! kill -0 $prover_pid 2>/dev/null; then
            break
        fi
        sleep 1
    done

    kill $prover_pid 2>/dev/null
    kill $tail_pid 2>/dev/null

    local prover_id=$(grep -o 'Your current prover identifier is [^ ]*' "$temp_output" | cut -d' ' -f6)
    if [ -n "$prover_id" ]; then
        echo "$prover_id" > "$PROVER_ID_FILE"
        echo -e "${GREEN}已生成并保存新的 Prover ID: $prover_id${NC}"
    else
        echo -e "${RED}生成 Prover ID 失败${NC}"
    fi
    rm "$temp_output"
}

start_prover() {
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo -e "${YELLOW}Prover 已在运行中，请选择2查看运行日志${NC}"
        return
    fi

    cd "$NEXUS_HOME" || exit

    if [ ! -f "$PROVER_ID_FILE" ]; then
        echo -e "${YELLOW}请输入您的 Prover ID${NC}"
        echo -e "${YELLOW}如果您还没有 Prover ID，直接按回车将自动生成${NC}"
        read -p "Prover ID > " input_id

        if [ -n "$input_id" ]; then
            echo "$input_id" > "$PROVER_ID_FILE"
            echo -e "${GREEN}已保存 Prover ID: $input_id${NC}"
        else
            echo -e "${YELLOW}将自动生成新的 Prover ID...${NC}"
        fi
    fi

    tmux new-session -d -s "$SESSION_NAME" "cd '$NEXUS_HOME' && ./prover beta.orchestrator.nexus.xyz"
    echo -e "${GREEN}Prover 已启动，选择2可查看运行日志${NC}"
}

check_status() {
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo -e "${GREEN}Prover 正在运行中. 正在打开日志窗口...${NC}"
        echo -e "${YELLOW}提示: 查看完成后直接关闭终端即可，不要使用 Ctrl+C${NC}"
        sleep 2
        tmux attach-session -t "$SESSION_NAME"
    else
        echo -e "${RED}Prover 未运行${NC}"
    fi
}

show_prover_id() {
    if [ -f "$PROVER_ID_FILE" ]; then
        local id=$(cat "$PROVER_ID_FILE")
        echo -e "${GREEN}当前 Prover ID: $id${NC}"
    else
        echo -e "${RED}未找到 Prover ID${NC}"
    fi
}

set_prover_id() {
    read -p "请输入新的 Prover ID: " new_id
    if [ -n "$new_id" ]; then
        echo "$new_id" > "$PROVER_ID_FILE"
        echo -e "${GREEN}Prover ID 已更新${NC}"
    else
        echo -e "${RED}Prover ID 不能为空${NC}"
    fi
}

stop_prover() {
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        tmux kill-session -t "$SESSION_NAME"
        echo -e "${GREEN}Prover 已停止${NC}"
    else
        echo -e "${RED}Prover 未运行${NC}"
    fi
}

cleanup() {
    echo -e "\n${YELLOW}正在清理...${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM

while true; do
    echo -e "\n${YELLOW}=== Nexus Prover 管理工具 ===${NC}"
    echo -e "${GREEN}Twitter: ${NC}https://x.com/zerah_eth"
    echo -e "${GREEN}Github: ${NC}https://github.com/qzz0518/nexus-run"
    echo -e "${GREEN}推荐工具: ${NC}SOL 回收神器 - https://solback.app/\n"

    echo "1. 安装并启动 Nexus"
    echo "2. 查看当前运行状态"
    echo "3. 查看 Prover ID"
    echo "4. 设置 Prover ID"
    echo "5. 停止 Nexus"
    echo "6. 退出"

    read -p "请选择操作 [1-6]: " choice
    case $choice in
        1)
            setup_directories
            check_dependencies
            download_files
            start_prover
            ;;
        2)
            check_status
            ;;
        3)
            show_prover_id
            ;;
        4)
            set_prover_id
            ;;
        5)
            stop_prover
            ;;
        6)
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