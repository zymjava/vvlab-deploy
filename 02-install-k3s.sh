#!/bin/bash
# 在主机上安装 K3s，使用国内镜像（Rancher 中国镜像 + 阿里云镜像站）
# 依赖：已创建 /etc/rancher/k3s/registries.yaml（见 k3s-registries.yaml）
set -e

REGISTRIES_SOURCE="$(dirname "$(readlink -f "$0")")/k3s-registries.yaml"
REGISTRIES_DEST="/etc/rancher/k3s/registries.yaml"

echo "==> 安装 K3s 依赖（若缺少）..."
if command -v yum &>/dev/null; then
    sudo yum install -y curl
elif command -v apt-get &>/dev/null; then
    sudo apt-get update && sudo apt-get install -y curl
fi

echo "==> 配置 K3s 镜像源（阿里云等）..."
sudo mkdir -p /etc/rancher/k3s
if [ -f "$REGISTRIES_SOURCE" ]; then
    sudo cp -f "$REGISTRIES_SOURCE" "$REGISTRIES_DEST"
    echo "    已复制 registries.yaml -> $REGISTRIES_DEST"
else
    echo "    未找到 $REGISTRIES_SOURCE，写入默认 registries.yaml"
    sudo tee "$REGISTRIES_DEST" > /dev/null <<'YAML'
mirrors:
  "docker.io":
    endpoint:
      - "https://registry.cn-hangzhou.aliyuncs.com"
  "registry.k8s.io":
    endpoint:
      - "https://registry.aliyuncs.com/google_containers"
  "quay.io":
    endpoint:
      - "https://quay.mirrors.ustc.edu.cn"
YAML
fi

echo "==> 使用 Rancher 中国镜像安装 K3s..."
# 使用国内镜像安装脚本与 K3s 组件镜像；跳过 selinux 包（避免阿里云 Linux 依赖冲突）
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
    INSTALL_K3S_MIRROR=cn \
    INSTALL_K3S_SKIP_SELINUX_RPM=true \
    sh -s - \
    --write-kubeconfig-mode 644 \
    --disable traefik

echo "==> 等待 K3s 就绪..."
sleep 5
sudo systemctl enable k3s
sudo systemctl status k3s --no-pager || true

echo "==> 配置 kubectl..."
mkdir -p ~/.kube
sudo cp -f /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$(id -u):$(id -g)" ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc 2>/dev/null || true

echo "==> 验证节点..."
kubectl get nodes

echo "==> K3s 安装完成。接下来在集群中安装 Nginx Ingress（见 03-install-ingress.sh）。"
