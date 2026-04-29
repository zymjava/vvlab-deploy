# vvlab 实例部署：Nginx + K3s + Nginx Ingress

在阿里云 2C2G 实例上按顺序安装：**主机 Nginx** → **K3s** → **Nginx Ingress**，并配置主机 Nginx 反代到 Ingress。  
实例内访问 docker.io 受限，脚本已使用 **阿里云镜像站** 与 **Rancher 中国镜像**。

## 前提

- 已 SSH 登录实例（root 或 sudo 用户）
- 将本目录 `deploy/` 上传到实例（如 `/root/deploy`），或在实例上 git clone 本仓库后进入 `deploy/`

## 执行顺序（在实例上）

```bash
cd /root/deploy   # 或你的 deploy 目录

# 1. 安装主机 Nginx
sudo bash 01-install-nginx.sh

# 2. 安装 K3s（会读取同目录 k3s-registries.yaml 作为镜像源）
sudo bash 02-install-k3s.sh

# 3. 安装 Nginx Ingress（使用阿里云等国内镜像）
bash 03-install-ingress.sh

# 4. 配置主机 Nginx 反代到 Ingress NodePort
bash 04-setup-nginx-upstream.sh
```

## 文件说明

| 文件 | 说明 |
|------|------|
| `01-install-nginx.sh` | 安装主机 Nginx（yum/apt），启用并启动 |
| `k3s-registries.yaml` | K3s 镜像源：docker.io → 杭州阿里云，registry.k8s.io → 阿里云 google_containers |
| `02-install-k3s.sh` | 使用 Rancher 中国镜像安装 K3s，并写入上述 registries |
| `03-install-ingress.sh` | 在 K3s 中安装 Nginx Ingress，镜像改为阿里云 |
| `04-setup-nginx-upstream.sh` | 写 `/etc/nginx/conf.d/vvlab-upstream.conf`，反代到 Ingress NodePort（透传 Host 支持多域名） |
| `vvlab-sites.yaml` | 三站点 zym/zxy/photo 的 Deployment + Service + Ingress |
| `vvlab-sites-zxy-only.yaml` | 仅 zxy 站点（zxy.vvlab.xyz）的 Deployment + Service + Ingress |
| **HANDBOOK.md** | **部署与发布总手册**：部署、迁移、发布、排障一体化说明（非开发可照做） |
| **nginx/vvlab-upstream.conf.example** | 主机 Nginx 反代配置示例（端口以 04 脚本生成为准，本文件供迁移参考） |

## 镜像与网络说明

- **K3s 安装**：使用 `INSTALL_K3S_MIRROR=cn` 与 Rancher 中国镜像安装脚本，避免直连国外。
- **K3s 拉镜象**：`/etc/rancher/k3s/registries.yaml` 将 `docker.io`、`registry.k8s.io` 等指向阿里云/USTC，减少拉取失败。
- **Nginx Ingress**：若存在同目录 `ingress-nginx-deploy-aliyun.yaml` 则直接 apply；否则脚本会尝试从 GitHub/Gitee 下载官方 manifest 并将镜像替换为 `registry.aliyuncs.com/google_containers/...` 后 apply。

## 安全组与域名

- 实例安全组放行：**80、443**（以及 SSH 22）。
- 域名 **vvlab.xyz** 已解析到实例 IP 时，完成上述步骤后可通过 `http://vvlab.xyz` 访问；具体站点需在集群内创建 Ingress 资源指向对应 Service。

## 可选：固定 Ingress NodePort

若希望主机 Nginx 配置固定端口，可在安装 Ingress 前修改其 Service 为固定 NodePort（如 30080/30443），再执行 `04-setup-nginx-upstream.sh`；脚本也会自动从集群读取当前 NodePort 并写入配置。

## 示例欢迎页（example-welcome.yaml）

- 已创建命名空间 `demo`、Deployment `welcome`、Service、Ingress（host: vvlab.xyz, www.vvlab.xyz, path: /）。
- 当前使用镜像：`docker.m.daocloud.io/library/nginx:alpine`（DaoCloud 镜像，国内可拉取）。若仍拉取失败，可：
  1. **本机预拉取**：在能访问 Docker Hub 的机器上 `docker pull nginx:alpine`，`docker save nginx:alpine | gzip > nginx.tar.gz`，传到实例后 `sudo ctr -n k8s.io image import nginx.tar.gz`，再把 `example-welcome.yaml` 里 `image` 改为 `nginx:alpine` 后 `kubectl apply -f example-welcome.yaml`。
  2. **阿里云 ACR**：在 ACR 创建命名空间并同步 nginx 镜像，把 YAML 里 `image` 改为你的 ACR 地址后 apply。
- 访问：浏览器打开 **http://vvlab.xyz**。若 welcome Pod 已 Running，会看到欢迎页；若 Pod 未就绪，会看到 Ingress 默认 404（说明主机 Nginx → Ingress 已通）。

## 详细说明与排障

- **安装步骤、架构、80 端口冲突等**：**[OPERATIONS.md](./OPERATIONS.md)**。
- **部署、迁移、发布、排障总手册**：**[HANDBOOK.md](./HANDBOOK.md)**。
