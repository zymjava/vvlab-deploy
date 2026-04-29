# 部署与排障操作记录

本文档记录在阿里云实例（139.224.31.98）上完成 vvlab 展示应用的完整操作、原因说明以及排障过程，便于复现和理解。

---

## 一、整体架构与目标

**目标**：在单台机器上跑通「主机 Nginx → K3s → Nginx Ingress → 应用 Pod」的链路，用户通过 `http://vvlab.xyz` 或 `http://实例IP/` 访问到 K3s 里的欢迎页。

**架构**：

```
用户浏览器
    ↓ (80/443)
主机 Nginx（/etc/nginx/conf.d/vvlab-upstream.conf）
    ↓ 反代到 127.0.0.1:NodePort
K3s 集群内 Nginx Ingress Controller（NodePort 服务）
    ↓ 按 Host/Path 路由
Ingress 资源（如 welcome）
    ↓ 转发到 Service
Welcome Pod（nginx + 静态欢迎页）
```

---

## 二、按顺序执行的操作

### 1. 准备部署脚本（本地 deploy 目录）

在本地 `deploy/` 下已有或创建了这些文件：

| 文件 | 作用 |
|------|------|
| `01-install-nginx.sh` | 在实例上安装主机 Nginx（yum/apt），启用并启动，便于后面做反代 |
| `k3s-registries.yaml` | K3s 的镜像源配置：把 docker.io、registry.k8s.io 等指到阿里云/USTC，避免实例内拉国外镜像失败 |
| `02-install-k3s.sh` | 用 Rancher 中国镜像安装 K3s，并把上面 registries 写到 `/etc/rancher/k3s/registries.yaml` |
| `03-install-ingress.sh` | 在 K3s 里安装 Nginx Ingress Controller（baremetal 版，NodePort），镜像改为阿里云 |
| `04-setup-nginx-upstream.sh` | 生成 `/etc/nginx/conf.d/vvlab-upstream.conf`，把主机 80/8080 反代到 Ingress 的 NodePort |
| `example-welcome.yaml` | 示例应用：Namespace demo、Deployment welcome、Service、Ingress，用于验证整条链路 |
| `run-all.sh` | 可选：按顺序执行上述脚本的入口 |

**为何要主机 Nginx**：Ingress 的 NodePort 是随机高位端口（如 31550），直接暴露不友好；用主机 Nginx 监听 80/443，反代到 NodePort，对外只暴露 80/443。

**为何要 registries**：实例访问 docker.io 等国外源经常超时，用国内镜像站可提高拉取成功率。

---

### 2. 换行符与上传

- 所有 `.sh`、`.yaml` 在 Windows 下可能是 CRLF，在 Linux 上执行会报错，已统一转为 **LF**。
- 用 `pscp` 把整个 `deploy/` 上传到服务器 `/root/deploy`，后续在服务器上执行脚本。

---

### 3. 在实例上依次执行脚本

在实例上按顺序执行：

1. **01-install-nginx.sh**  
   安装并启动主机 Nginx，为后续反代做准备。

2. **02-install-k33.sh**  
   安装 K3s。过程中若遇到 SELinux 相关报错，脚本里通过参数（如 `--selinux` 相关）或环境变量做了规避，保证 K3s 能正常跑起来。

3. **03-install-ingress.sh**  
   在集群里部署 Nginx Ingress Controller（官方 baremetal 的 deploy.yaml，镜像换成阿里云）。  
   部署完成后会得到 **NodePort**（如 HTTP 31550、HTTPS 32589），供步骤 4 使用。

4. **04-setup-nginx-upstream.sh**  
   读取当前 Ingress 的 NodePort，生成主机 Nginx 配置：
   - 监听 **80** 和 **8080**，作为 default_server；
   - 把所有请求反代到 `127.0.0.1:NodePort`，并统一带上 `Host: vvlab.xyz`（因为 Ingress 规则按 Host 匹配）；
   - 这样用户用 IP 或 vvlab.xyz 访问都会走到同一条 Ingress 规则。  
   执行后 `nginx -t` 并 `systemctl reload nginx`。

5. **部署 welcome 示例应用**  
   执行 `kubectl apply -f example-welcome.yaml`：
   - 创建 Namespace `demo`；
   - Deployment `welcome`（镜像用 DaoCloud 的 nginx:alpine，国内可拉）；
   - ConfigMap `welcome-html` 挂成静态页；
   - Service `welcome`（ClusterIP 80）；
   - Ingress `welcome`：无 host / vvlab.xyz / www.vvlab.xyz 的 `/` 都指向 welcome Service。

**为何要统一 Host: vvlab.xyz**：用户可能用 `http://139.224.31.98/` 访问，Ingress 里没有「IP 作为 host」的规则；主机 Nginx 反代时改成 `Host: vvlab.xyz`，就能命中 Ingress 里为 vvlab.xyz 配置的后端。

---

### 4. 遇到的问题：80 端口返回 404

**现象**：

- 访问 `http://127.0.0.1:8080/` 正常返回欢迎页（200）；
- 访问 `http://127.0.0.1:80/` 返回 404，且响应头里没有「Server: nginx」，是「404 page not found」这种 Go 风格文案。

**排查过程简述**：

1. 用 `ss -tlnp` 看 80 端口：显示是 nginx（主机 Nginx）在监听。
2. 在主机 Nginx 的 `location /` 里加了 `add_header X-Via-Port $server_port always;` 并重载，再分别 curl 80 和 8080：
   - **8080** 的响应里能看到 `X-Via-Port`，说明请求确实经过了主机 Nginx 的 vvlab 配置；
   - **80** 的响应里没有 `X-Via-Port`，说明 80 上的请求**没有**经过我们配的那个 server 块。
3. 停止主机 Nginx 后，再 curl `http://127.0.0.1:80/` 仍然返回 404，说明 **80 端口上还有别的进程在响应**。
4. 查 K3s 相关 Pod：发现有 **svclb-traefik**（ServiceLB 为 Traefik 创建的 Pod），且该 Pod 的 spec 里对 80/443 使用了 **hostPort: 80** 和 **hostPort: 443**。  
   也就是说：K3s 自带的 **Traefik** 使用 LoadBalancer 类型 Service，K3s 的 ServiceLB（Klipper）会为它在**主机**上绑定 80/443；和主机 Nginx 抢同一个端口。

**结论**：  
占用 80（以及 443）的「另一个进程」是 **K3s 为 Traefik 创建的 ServiceLB Pod（svclb-traefik）**，不是主机 Nginx。  
当前方案已经用 Nginx Ingress 做入口，不需要 Traefik 再占主机 80/443，所以可以释放 80 给主机 Nginx 用。

---

### 5. 修复：释放 80 给主机 Nginx

把 Traefik 的 Service 从 **LoadBalancer** 改成 **ClusterIP**：

```bash
# 在实例上执行（或把下面 JSON 存成 patch 文件用 -p 传入）
kubectl patch svc traefik -n kube-system --type=merge -p '{"spec":{"type":"ClusterIP"}}'
```

效果：

- Traefik 不再通过 LoadBalancer 向主机申请 80/443；
- K3s 会删掉对应的 **svclb-traefik** Pod，主机上的 80/443 不再被占用；
- 主机 Nginx 成为 80 上唯一的监听者，访问 `http://139.224.31.98/` 或 `http://vvlab.xyz/` 即可正常得到欢迎页（200）。

**Traefik 本身**：仍保留在集群内，只是不再对外暴露 80/443；若以后需要再用 Traefik 直接对外，可把 Service 改回 `LoadBalancer`（会再次占用主机 80/443）。

---

### 6. 收尾

- 去掉主机 Nginx 里之前加的调试用 `add_header X-Via-Port ...`，只保留反代与 `Host: vvlab.xyz` 等必要配置，然后 `nginx -t && systemctl reload nginx`。
- 再次用浏览器或 curl 验证：  
  `http://139.224.31.98/`、`http://139.224.31.98:8080/`、`http://vvlab.xyz/` 均应返回 200 和欢迎页。

---

## 三、故障排查速查（详细在本文档）

| 现象 | 可能原因 | 处理思路 |
|------|----------|----------|
| K3s 拉镜像失败 | registries 未生效或写错 | 检查 `/etc/rancher/k3s/registries.yaml`，重启 K3s |
| Ingress 镜像拉取失败 | 镜像地址或网络 | 用 `ctr -n k8s.io image pull ...` 在节点上试拉，或改用 ACR 等国内源 |
| **主机 Nginx 502**（访问 vvlab.xyz 或 zxy.vvlab.xyz 等） | Ingress 未就绪或 **NodePort 与 vvlab-upstream.conf 不一致** | 执行 `kubectl get svc -n ingress-nginx ingress-nginx-controller` 看实际 NodePort（如 31550）；把 `/etc/nginx/conf.d/vvlab-upstream.conf` 里 30080 改为该端口，`nginx -t && systemctl reload nginx`。详见 **HANDBOOK.md** |
| **80 返回 404，8080 正常** | Traefik 的 ServiceLB 占用主机 80/443 | 执行上面「修复」里的 `kubectl patch`，把 traefik 改为 ClusterIP |
| welcome Pod 一直 ImagePullBackOff | 镜像拉不到 | 换镜像（如 DaoCloud/ACR），或本机导出镜像再 `ctr image import`，见 README 示例欢迎页说明 |
| zxy/zym/photo Pod ErrImagePull、authorization failed | ACR 拉取密钥错误或未创建 | 见 **HANDBOOK.md**（ACR 密钥重建章节）；在服务器上重建 acr-secret 并 rollout restart |

更多细节以本仓库脚本和配置为准。**部署、迁移、发布与排障一体化说明** 见 **[HANDBOOK.md](./HANDBOOK.md)**。
