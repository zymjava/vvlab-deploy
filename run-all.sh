#!/bin/bash
# 按顺序执行：Nginx -> K3s -> Ingress -> 主机 Nginx 反代
# 在实例上执行：sudo bash run-all.sh 或分步执行 01～04
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> 1/4 安装主机 Nginx"
sudo bash 01-install-nginx.sh

echo "==> 2/4 安装 K3s"
sudo bash 02-install-k3s.sh

echo "==> 3/4 安装 Nginx Ingress"
bash 03-install-ingress.sh

echo "==> 4/4 配置主机 Nginx 反代"
bash 04-setup-nginx-upstream.sh

echo "==> 全部完成。请放行 80/443，并通过 http://vvlab.xyz 访问。"
