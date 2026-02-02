#!/bin/bash
# 在 139.224.31.98 上执行：配置 Nginx 透传 Host、创建 ACR 拉取密钥、部署 zxy 站点
# 使用前：1) 将 deploy 目录上传到服务器；2) 在 ACR 控制台为 zxy-repo 构建并推送镜像；3) 下方填写 ACR 登录信息后执行
set -e

REGISTRY="crpi-c87ddoa33spg7s3f.cn-shanghai.personal.cr.aliyuncs.com"
# 阿里云 ACR 个人版：用户名为控制台「访问凭证」里的登录名（常为阿里云账号邮箱），密码为独立登录密码
# 迁移到新服务器时需重新设置 ACR_USER/ACR_PASS 并执行本脚本，密钥不入库（见 MIGRATION.md）
ACR_USER="${ACR_USER:-}"
ACR_PASS="${ACR_PASS:-}"

if [ -z "$ACR_PASS" ] || [ -z "$ACR_USER" ]; then
  echo "请设置 ACR 用户名和密码后执行（迁移新机时必设，密钥不入库）："
  echo "  export ACR_USER=你的ACR登录名"
  echo "  export ACR_PASS=你的ACR独立登录密码"
  echo "  bash run-on-server.sh"
  exit 1
fi

DEPLOY_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DEPLOY_DIR"

echo "==> 1. 配置主机 Nginx 透传 Host..."
sudo bash 04-setup-nginx-upstream.sh

echo "==> 2. 创建/更新 ACR 拉取密钥 (demo 命名空间)..."
kubectl create namespace demo --dry-run=client -o yaml | kubectl apply -f -
kubectl delete secret acr-secret -n demo --ignore-not-found
kubectl create secret docker-registry acr-secret \
  --docker-server="$REGISTRY" \
  --docker-username="$ACR_USER" \
  --docker-password="$ACR_PASS" \
  -n demo

echo "==> 3. 部署欢迎页（若尚未部署）..."
kubectl apply -f example-welcome.yaml

echo "==> 4. 部署 zxy 站点 (zxy.vvlab.xyz)..."
kubectl apply -f vvlab-sites-zxy-only.yaml

echo "==> 5. 等待 Pod 就绪..."
kubectl rollout status deployment/zxy-site -n demo --timeout=120s || true
kubectl get pods -n demo
kubectl get ingress -n demo

echo ""
echo "完成。请访问 http://zxy.vvlab.xyz 查看个人简介页。"
echo "若 Pod 为 ImagePullBackOff，请先在 ACR 控制台为 zxy-repo 构建并推送镜像。"
