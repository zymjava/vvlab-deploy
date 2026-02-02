#!/bin/bash
# 配置主机 Nginx 反代到 K3s Nginx Ingress（NodePort）
# 依赖：主机已装 Nginx，K3s 中已装 Nginx Ingress
set -e

# 若未设置，从集群读取 Ingress NodePort
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
if command -v kubectl &>/dev/null && kubectl get svc -n ingress-nginx ingress-nginx-controller &>/dev/null; then
    INGRESS_HTTP_PORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
    INGRESS_HTTPS_PORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
fi
INGRESS_HTTP_PORT="${INGRESS_HTTP_PORT:-30080}"
INGRESS_HTTPS_PORT="${INGRESS_HTTPS_PORT:-30443}"

echo "==> 使用 Ingress NodePort: HTTP=$INGRESS_HTTP_PORT HTTPS=$INGRESS_HTTPS_PORT"

NGINX_CONF="/etc/nginx/conf.d/vvlab-upstream.conf"
sudo tee "$NGINX_CONF" <<EOF
# vvlab.xyz 入口：反代到 K3s Nginx Ingress（由 04-setup-nginx-upstream.sh 生成）
upstream k3s_ingress_http {
    server 127.0.0.1:${INGRESS_HTTP_PORT};
}
upstream k3s_ingress_https {
    server 127.0.0.1:${INGRESS_HTTPS_PORT};
}

# 单一 default_server：所有 Host（含 IP 与域名）统一反代到 Ingress 并带 Host: vvlab.xyz
# 若 80 被占用，先改用 8080；备案后可在前面用 SLB/其他反代 80->8080
server {
    listen 80 default_server;
    listen 8080 default_server;
    server_name vvlab.xyz www.vvlab.xyz 139.224.31.98 _;
    location / {
        proxy_pass http://127.0.0.1:${INGRESS_HTTP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host vvlab.xyz;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

# 申请证书后取消注释并 nginx -t && systemctl reload nginx
# server {
#     listen 443 ssl;
#     server_name vvlab.xyz www.vvlab.xyz;
#     ssl_certificate     /etc/nginx/ssl/vvlab.xyz.pem;
#     ssl_certificate_key /etc/nginx/ssl/vvlab.xyz.key;
#     location / {
#         proxy_pass https://k3s_ingress_https;
#         proxy_set_header Host \$host;
#         proxy_set_header X-Real-IP \$remote_addr;
#         proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto \$scheme;
#         proxy_ssl_verify off;
#     }
# }
EOF

echo "==> 检查 Nginx 配置..."
sudo nginx -t

echo "==> 重载 Nginx..."
sudo systemctl reload nginx

echo "==> 主机 Nginx 已反代到 Ingress NodePort。可通过 http://vvlab.xyz 访问（需 Ingress 已配置后端）。"
