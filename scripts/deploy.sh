#!/bin/bash

# --- OpenClaw Linux Server 部署脚本 ---
# 适用系统: Ubuntu / Debian / CentOS / RHEL
set -e # 遇到错误立即停止执行

# 自动检测包管理器
if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt-get"
    INSTALL_CMD="sudo apt-get install -y"
    UPDATE_CMD="sudo apt-get update -y"
    NODE_SETUP_URL="https://deb.nodesource.com/setup_22.x"
    BUILD_TOOLS="build-essential"
elif command -v yum &> /dev/null; then
    PKG_MANAGER="yum"
    INSTALL_CMD="sudo yum install -y"
    UPDATE_CMD="sudo yum update -y"
    NODE_SETUP_URL="https://rpm.nodesource.com/setup_22.x"
    BUILD_TOOLS="gcc-c++ make"
else
    echo "错误: 未能识别的包管理器 (仅支持 apt 或 yum)"
    exit 1
fi

echo ">>> 检测到系统包管理器: $PKG_MANAGER"

# 1. 更新系统并安装基础工具
echo ">>> 更新系统并安装基础工具 (curl, git, $BUILD_TOOLS)..."

# 解决 Ubuntu apt 锁占用问题
if [ "$PKG_MANAGER" == "apt-get" ]; then
    echo ">>> 正在检查 apt 锁状态..."
    while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        echo ">>> 系统正在进行后台更新 (unattended-upgrades)，等待 5 秒重试..."
        sleep 5
    done
fi

$UPDATE_CMD
$INSTALL_CMD curl git $BUILD_TOOLS

# 2. 安装 Node.js v22 (LTS)
if command -v node &> /dev/null; then
    echo ">>> Node.js 已安装: $(node -v)"
else
    echo ">>> 正在安装 Node.js v22..."
    if [ "$PKG_MANAGER" == "apt-get" ]; then
        curl -fsSL $NODE_SETUP_URL | sudo -E bash -
        sudo apt-get install -y nodejs
    else
        # CentOS/RHEL 特殊处理：先清理缓存
        sudo yum clean all
        curl -fsSL $NODE_SETUP_URL | sudo bash -
        sudo yum install -y nodejs
    fi
fi

# 再次验证 Node.js 是否安装成功
if ! command -v node &> /dev/null; then
    echo "错误: Node.js 安装失败。请尝试手动安装 Node.js v22+ 后再运行此脚本。"
    exit 1
fi

node_version=$(node -v)
echo ">>> Node.js 版本验证成功: $node_version"

# 3. 安装 pnpm (更快的包管理器)
echo ">>> 安装 pnpm..."
if ! command -v pnpm &> /dev/null; then
    sudo npm install -g pnpm
    # 解决 pnpm 首次安装可能存在的路径问题
    sudo pnpm setup || true
    export PNPM_HOME="/usr/local/share/pnpm"
    export PATH="$PNPM_HOME:$PATH"
fi

# 4. 安装 OpenClaw CLI 和相关工具
echo ">>> 安装 OpenClaw CLI, dotenv-cli 和 pm2..."
# 显式指定全局安装路径，避免 ERR_PNPM_NO_GLOBAL_BIN_DIR
sudo pnpm add -g openclaw dotenv-cli pm2 --global-dir=/usr/local/share/pnpm-global

# 5. 检查 OpenClaw 安装
if command -v openclaw &> /dev/null
then
    echo "OpenClaw CLI 安装成功: $(openclaw --version)"
else
    echo "错误: OpenClaw CLI 安装失败，请检查 npm/pnpm 全局路径是否在 PATH 中。"
    exit 1
fi

# 6. 同步 main 路由提示词到运行时目录（可选）
PROJECT_ROOT="$(pwd)"
MAIN_ROUTER_PROMPT_FILE="$PROJECT_ROOT/prompts/main_router_prompt.md"
MAIN_AGENT_DIR="$HOME/.openclaw/agents/main/agent"
MAIN_AGENT_PROMPT_FILE="$MAIN_AGENT_DIR/AGENTS.md"

if [ -f "$MAIN_ROUTER_PROMPT_FILE" ]; then
    echo ">>> 检测到 main 路由提示词，正在同步到运行时目录..."
    mkdir -p "$MAIN_AGENT_DIR"
    cp "$MAIN_ROUTER_PROMPT_FILE" "$MAIN_AGENT_PROMPT_FILE"
    echo ">>> 已同步: $MAIN_ROUTER_PROMPT_FILE -> $MAIN_AGENT_PROMPT_FILE"
else
    echo ">>> 未检测到 prompts/main_router_prompt.md，跳过 main 路由提示词同步"
fi

# 7. 项目初始化提示
echo ""
echo "===================================================="
echo "环境部署完成！接下来请按照以下步骤操作："
echo ""
echo "1. 将项目上传到服务器 (git clone 或 scp)"
echo "2. 复制环境变量文件: cp .env.example .env"
echo "3. 编辑 .env 并填入你的 API Keys: nano .env"
echo "4. 初始化项目配置 (指定当前目录的 openclaw.json):"
echo "   OPENCLAW_CONFIG_PATH=\"$(pwd)/openclaw.json\" openclaw doctor --fix"
echo "5. 启动网关 (使用 PM2 后台运行):"
echo "   OPENCLAW_CONFIG_PATH=\"$(pwd)/openclaw.json\" dotenv -- pm2 start openclaw --name \"openclaw-gateway\" -- gateway start --no-daemon"
echo "6. 如需强制刷新 main 路由提示词，可手动执行:"
echo "   cp \"$(pwd)/prompts/main_router_prompt.md\" \"$HOME/.openclaw/agents/main/agent/AGENTS.md\""
echo ""
echo "查看日志命令: pm2 logs openclaw-gateway"
echo "===================================================="
