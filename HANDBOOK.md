# 部署与发布总手册

本手册合并了原先多份部署文档，目标是让你在一个文件里完成这三类任务：

- 新机器部署与迁移
- 日常发布（含非开发可执行步骤）
- 常见故障排查

适用对象：`vvlab.xyz`、`zym.vvlab.xyz`、`zxy.vvlab.xyz`、`photo.vvlab.xyz`。

---

## 1. 关键文件与职责

| 文件 | 用途 |
|------|------|
| `01-install-nginx.sh` | 安装主机 Nginx |
| `02-install-k3s.sh` | 安装 K3s（含国内镜像源） |
| `03-install-ingress.sh` | 安装 Nginx Ingress |
| `04-setup-nginx-upstream.sh` | 生成主机 Nginx 反代配置（自动读取 Ingress NodePort） |
| `example-welcome.yaml` | 根域名 welcome 示例应用 |
| `vvlab-sites-zxy-only.yaml` | 仅 zxy 站点部署 |
| `vvlab-sites.yaml` | 三站点（zym/zxy/photo）部署 |
| `run-on-server.sh` | 服务器一键执行：更新 Nginx、重建 ACR 密钥、部署 zxy |
| `nginx/vvlab-upstream.conf.example` | 主机 Nginx 配置示例（迁移参考） |

---

## 2. 新服务器部署（迁移）

在新机器（例如替换 139.224.31.98）执行：

```bash
cd /root/deploy
sudo bash 01-install-nginx.sh
sudo bash 02-install-k3s.sh
bash 03-install-ingress.sh
sudo bash 04-setup-nginx-upstream.sh
```

然后部署应用：

```bash
kubectl apply -f example-welcome.yaml
kubectl apply -f vvlab-sites-zxy-only.yaml
# 三站点则用：kubectl apply -f vvlab-sites.yaml
```

### 必须重建的敏感配置（不入库）

ACR 拉取密钥 `acr-secret` 含密码，迁移到新机时必须重建：

```bash
kubectl create namespace demo --dry-run=client -o yaml | kubectl apply -f -
kubectl delete secret acr-secret -n demo --ignore-not-found=true
kubectl create secret docker-registry acr-secret \
  --docker-server=crpi-c87ddoa33spg7s3f.cn-shanghai.personal.cr.aliyuncs.com \
  --docker-username=你的ACR登录名 \
  --docker-password=你的ACR独立登录密码 \
  -n demo
```

---

## 3. 日常发布（非开发可照做）

以 zxy 站点为例。

### 步骤 1：改内容

- 文案：改 `zxy/data/content.json`
- 照片：放到 `zxy/assets/photos/`，并改 `zxy/data/photos.json`

### 步骤 2：推送代码

```bash
cd c:\Users\admin\vvlab\zxy
git add .
git commit -m "更新简历内容"
git push origin main
```

（若分支为 `master`，则用 `git push origin master`）

### 步骤 3：触发镜像构建

阿里云 ACR 个人版 → 镜像仓库 `zxy-repo` → 构建 → 立即构建。  
建议构建规则勾选“同时打 latest 标签”。

### 步骤 4：服务器上重启

```bash
kubectl rollout restart deployment/zxy-site -n demo
kubectl rollout status deployment/zxy-site -n demo --timeout=120s
```

### 步骤 5：浏览器验证

访问：`http://zxy.vvlab.xyz`  
（当前未配置 HTTPS，需用 `http`）

---

## 4. 常见故障排查

### 4.1 访问域名返回 502

常见原因：主机 Nginx 反代端口和 Ingress 实际 NodePort 不一致。

排查：

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

看 HTTP NodePort（如 `31550`），确认 `/etc/nginx/conf.d/vvlab-upstream.conf` 里 `proxy_pass` 指向同端口。  
改完执行：

```bash
sudo nginx -t
sudo systemctl reload nginx
```

### 4.2 Pod 报 ErrImagePull / authorization failed

原因：ACR 密钥用户名或密码不正确。  
处理：重建 `acr-secret`（见第 2 节）。

### 4.3 Pod 报 latest not found

原因：ACR 镜像仓库没有 `latest` 标签。  
处理：在 ACR 控制台给当前镜像（如 `zxy-2026`）追加标签 `latest`，再执行 rollout restart。

### 4.4 ACR 构建拉 nginx:alpine 超时

原因：构建环境访问 Docker Hub 超时。  
处理：Dockerfile 使用国内基础镜像，例如：

```dockerfile
FROM docker.m.daocloud.io/library/nginx:alpine
```

### 4.5 80 端口被 Traefik 占用（80 404、8080 正常）

```bash
kubectl patch svc traefik -n kube-system --type=merge -p '{"spec":{"type":"ClusterIP"}}'
```

---

## 5. 一键脚本用法（推荐）

服务器上执行：

```bash
export ACR_USER=你的ACR登录名
export ACR_PASS=你的ACR独立登录密码
bash run-on-server.sh
```

脚本会自动：

1) 更新 Nginx 反代配置  
2) 重建 `acr-secret`  
3) 应用 welcome 与 zxy 部署

