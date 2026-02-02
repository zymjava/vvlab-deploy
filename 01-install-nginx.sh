#!/bin/bash
# 在主机上安装 Nginx（作为入口，后续反代到 K3s Ingress NodePort）
set -e

echo "==> 检测系统类型..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "无法检测系统，请手动安装 Nginx"
    exit 1
fi

echo "==> 安装 Nginx..."
case "$OS" in
    almalinux|centos|rhel|rocky|alinux|amzn)
        # 阿里云 Linux / CentOS 等，用 nginx 官方源（避免 docker.io 拉取问题）
        RELEASE=7
        [[ "$VERSION_ID" =~ ^[38]$ ]] && RELEASE=8
        [[ "$VERSION_ID" = "3" ]] && RELEASE=8
        sudo yum install -y yum-utils
        sudo yum-config-manager -y --add-repo "https://nginx.org/packages/centos/${RELEASE}/x86_64/"
        sudo rpm --import https://nginx.org/keys/nginx_signing.key
        sudo yum install -y nginx
        ;;
    ubuntu|debian)
        sudo apt-get update
        sudo apt-get install -y curl gnupg2 ca-certificates lsb-release
        echo "deb http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
        curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg
        sudo apt-get update
        sudo apt-get install -y nginx
        ;;
    *)
        echo "未识别的系统: $OS，请手动安装 Nginx"
        exit 1
        ;;
esac

echo "==> 启用并启动 Nginx..."
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl status nginx --no-pager || true

echo "==> Nginx 安装完成。配置文件将稍后由 04-setup-nginx-upstream 步骤写入。"
echo "    默认站点已可访问，80/443 需在安全组放行。"
