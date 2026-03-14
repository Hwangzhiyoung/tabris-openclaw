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
fi

# 4. 安装 OpenClaw CLI 和相关工具
echo ">>> 安装 OpenClaw CLI, dotenv-cli 和 pm2..."
sudo pnpm add -g openclaw dotenv-cli pm2

# 5. 检查 OpenClaw 安装
if command -v openclaw &> /dev/null
then
    echo "OpenClaw CLI 安装成功: $(openclaw --version)"
else
    echo "错误: OpenClaw CLI 安装失败，请检查 npm/pnpm 全局路径是否在 PATH 中。"
    exit 1
fi

# 6. 项目初始化提示
echo ""
echo "===================================================="
echo "环境部署完成！接下来请按照以下步骤操作："
echo ""
echo "1. 将项目上传到服务器 (git clone 或 scp)"
echo "2. 复制环境变量文件: cp .env.example .env"
echo "3. 编辑 .env 并填入你的 API Keys: nano .env"
echo "4. 初始化 OpenClaw 目录: openclaw doctor --fix"
echo "5. 启动网关 (使用 PM2 后台运行):"
echo "   dotenv -- pm2 start openclaw --name \"openclaw-gateway\" -- gateway start --config ./openclaw.json"
echo ""
echo "查看日志命令: pm2 logs openclaw-gateway"
echo "===================================================="
