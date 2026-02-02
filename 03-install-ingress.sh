#!/bin/bash
# 在 K3s 集群中安装 Nginx Ingress Controller，使用阿里云等国内镜像
# 依赖：K3s 已安装，kubectl 可用
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_YAML="$SCRIPT_DIR/ingress-nginx-deploy-aliyun.yaml"

echo "==> 检查 kubectl 与集群..."
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
if ! kubectl get nodes &>/dev/null; then
    echo "无法连接集群，请先安装 K3s 并配置 KUBECONFIG"
    exit 1
fi

echo "==> 安装 Nginx Ingress（使用国内镜像）..."
if [ -f "$DEPLOY_YAML" ]; then
    kubectl apply -f "$DEPLOY_YAML"
else
    echo "未找到 $DEPLOY_YAML，尝试从 manifest 下载并替换为阿里云镜像后安装..."
    CONTROLLER_IMAGE="registry.aliyuncs.com/google_containers/nginx-ingress-controller:v1.9.4"
    WEBHOOK_IMAGE="registry.aliyuncs.com/google_containers/kube-webhook-certgen:v20231011-8b53cabe0"
    for URL in \
        "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/baremetal/deploy.yaml" \
        "https://gitee.com/mirrors/ingress-nginx/raw/controller-v1.9.4/deploy/static/provider/baremetal/deploy.yaml"; do
        if curl -sfSLo /tmp/ingress-nginx-deploy.yaml "$URL"; then
            break
        fi
    done
    if [ ! -s /tmp/ingress-nginx-deploy.yaml ]; then
        echo "无法下载 deploy.yaml，请将 deploy/ingress-nginx-deploy-aliyun.yaml 放到当前目录或从可访问地址下载后重试"
        exit 1
    fi
    sed -i.bak \
        -e "s|image: registry.k8s.io/ingress-nginx/controller:.*|image: ${CONTROLLER_IMAGE}|g" \
        -e "s|image: registry.k8s.io/ingress-nginx/kube-webhook-certgen:.*|image: ${WEBHOOK_IMAGE}|g" \
        /tmp/ingress-nginx-deploy.yaml
    kubectl apply -f /tmp/ingress-nginx-deploy.yaml
    rm -f /tmp/ingress-nginx-deploy.yaml /tmp/ingress-nginx-deploy.yaml.bak
fi

echo "==> 等待 Ingress Controller 就绪..."
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=120s

echo "==> 查看 Ingress NodePort（供主机 Nginx 反代）..."
kubectl get svc -n ingress-nginx ingress-nginx-controller -o wide
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' && echo " (HTTP)"
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}' && echo " (HTTPS)"

echo "==> Nginx Ingress 安装完成。请记下上述 NodePort，用于 04-setup-nginx-upstream 配置主机 Nginx 反代。"
