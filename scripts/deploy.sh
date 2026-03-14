#!/bin/bash

# --- OpenClaw Linux Server 部署脚本 ---
# 适用系统: Ubuntu / Debian / CentOS (建议使用 Ubuntu 22.04+ 或 Debian 12+)

# 1. 更新系统并安装基础工具
echo ">>> 更新系统并安装基础工具..."
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y curl git build-essential

# 2. 安装 Node.js v22 (LTS)
echo ">>> 安装 Node.js v22..."
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# 验证 Node.js 版本
node_version=$(node -v)
echo "Node.js 版本: $node_version"

# 3. 安装 pnpm (更快的包管理器)
echo ">>> 安装 pnpm..."
sudo npm install -g pnpm

# 4. 安装 OpenClaw CLI 和相关工具
echo ">>> 安装 OpenClaw CLI 和 dotenv-cli..."
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
