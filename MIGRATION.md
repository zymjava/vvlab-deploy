# 服务器迁移说明

本文档说明**当前服务器（139.224.31.98）上直接创建或修改的配置**有哪些，以及**迁移到新服务器时如何在本项目中完整复现**，避免配置只存在于单机、迁移后无法恢复。

---

## 一、服务器上直接创建/修改的配置清单

| 配置项 | 所在位置 | 是否在项目里 | 说明 |
|--------|----------|--------------|------|
| **主机 Nginx 反代配置** | `/etc/nginx/conf.d/vvlab-upstream.conf` | ✅ 由脚本生成，结构见 `nginx/vvlab-upstream.conf.example` | 由 `04-setup-nginx-upstream.sh` 根据当前 Ingress NodePort 生成；端口随集群变化，新机需重新执行 04 脚本 |
| **ACR 拉取密钥** | K8s 命名空间 demo，Secret 名 `acr-secret` | ❌ 不含密码，不能入库 | 用于从阿里云 ACR 拉取 zxy/zym/photo 镜像；迁移时需在新机用相同参数重新创建（密码由运维保管） |
| **K8s 资源（demo 命名空间）** | 集群内 | ✅ 由 YAML 定义 | `example-welcome.yaml`、`vvlab-sites-zxy-only.yaml`（或 `vvlab-sites.yaml`）在项目中，在新机 `kubectl apply` 即可 |
| **Traefik 改为 ClusterIP** | 集群内 kube-system/traefik | ✅ 操作见 `OPERATIONS.md` + `traefik-svc-patch.json` | 若新机 K3s 仍带 Traefik 且占 80/443，需再次执行 patch |

**未在项目中的敏感信息**：ACR 登录密码、服务器 SSH 密码等，仅由运维本地保管，不写入仓库。

---

## 二、新服务器上复现步骤（迁移清单）

按下面顺序在新服务器上执行，即可复现当前环境（域名、镜像地址等需按新环境替换）。

### 1. 准备本仓库

- 将 **vvlab-deploy** 仓库 clone 或上传到新服务器，例如 `/root/deploy`。
- 确保脚本为 LF 换行（Windows 编辑过的用 `dos2unix` 或编辑器改为 LF）。

### 2. 安装基础组件（与当前实例一致）

```bash
cd /root/deploy
sudo bash 01-install-nginx.sh
sudo bash 02-install-k3s.sh
bash 03-install-ingress.sh
```

### 3. 生成主机 Nginx 配置（反代到 Ingress）

```bash
sudo bash 04-setup-nginx-upstream.sh
```

脚本会从当前集群读取 Ingress 的 NodePort（如 31550/32589），生成 `/etc/nginx/conf.d/vvlab-upstream.conf`。  
若脚本执行失败，可参考 **nginx/vvlab-upstream.conf.example** 手动创建该文件，端口用 `kubectl get svc -n ingress-nginx ingress-nginx-controller` 查看后替换。

### 4. 释放 80 端口（若新机 K3s 自带 Traefik 占用 80/443）

若访问 80 返回 404 而 8080 正常，说明 Traefik 占用了 80，需执行（见 OPERATIONS.md）：

```bash
kubectl patch svc traefik -n kube-system --type=merge -p '{"spec":{"type":"ClusterIP"}}'
```

### 5. 创建 ACR 拉取密钥（必须，且不能从仓库还原）

ACR 密钥含密码，**不会也不应**提交到仓库。在新机上用**当前使用的 ACR 账号与密码**执行：

```bash
kubectl create namespace demo --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret docker-registry acr-secret \
  --docker-server=crpi-c87ddoa33spg7s3f.cn-shanghai.personal.cr.aliyuncs.com \
  --docker-username=你的ACR登录名 \
  --docker-password=你的ACR独立登录密码 \
  -n demo
```

或使用项目中的脚本（需预先设置密码环境变量，且不提交密码到仓库）：

```bash
export ACR_USER=你的ACR登录名   # 如 1550974736@qq.com
export ACR_PASS=你的ACR密码
bash run-on-server.sh
```

`run-on-server.sh` 会顺带执行 04 脚本、创建 acr-secret、apply welcome 与 zxy 的 YAML。

### 6. 部署应用（K8s 资源均在项目中）

```bash
kubectl apply -f example-welcome.yaml
kubectl apply -f vvlab-sites-zxy-only.yaml
# 若部署三站：kubectl apply -f vvlab-sites.yaml
```

### 7. 校验

- `kubectl get pods -n demo`：Pod 应为 Running。
- 本机：`curl -sI -H 'Host: zxy.vvlab.xyz' http://127.0.0.1:80/` 应返回 200。
- 将域名解析指向新服务器 IP 后，浏览器访问 http://vvlab.xyz、http://zxy.vvlab.xyz 等验证。

---

## 三、项目中与“服务器独有配置”对应的文件

| 服务器上的配置 | 项目中的来源/参考 |
|----------------|--------------------|
| `/etc/nginx/conf.d/vvlab-upstream.conf` | **04-setup-nginx-upstream.sh**（生成）；**nginx/vvlab-upstream.conf.example**（示例，端口 31550/32589 仅作参考） |
| K8s demo 命名空间下的 Deployment/Service/Ingress | **example-welcome.yaml**、**vvlab-sites-zxy-only.yaml**、**vvlab-sites.yaml** |
| ACR 拉取密钥 acr-secret | **不入库**；创建方式见上文 + **run-on-server.sh**（需设 ACR_PASS） |
| Traefik 改为 ClusterIP | **OPERATIONS.md** 中的说明 + **traefik-svc-patch.json**（可选） |

---

## 四、小结

- **能完全从项目恢复的**：主机 Nginx 配置（通过 04 脚本）、K8s 应用与 Ingress、Traefik 的 patch 操作说明。
- **不能入库、迁移时必须在新机重建的**：ACR 的 **acr-secret**（用户名/密码由运维保管，在新机按本文或 run-on-server.sh 重建）。
- 迁移时按 **二、新服务器上复现步骤** 执行即可；若有 502、镜像拉取失败等问题，见 **TROUBLESHOOTING.md**。
