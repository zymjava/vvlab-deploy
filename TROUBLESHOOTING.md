# 排障记录（zxy 站点部署过程）

本文档记录 2026-02 在服务器 139.224.31.98 上部署 zxy.vvlab.xyz（祝晓燕个人简介页）时遇到的问题、原因与解决方式，便于下次遇到类似情况时对照排查。

---

## 问题一：访问 zxy.vvlab.xyz 返回 502 Bad Gateway

### 现象

- 浏览器打开 **http://zxy.vvlab.xyz/** 或 **https://zxy.vvlab.xyz/** 显示「502 Bad Gateway」。
- 在服务器上执行：`curl -sI -H 'Host: zxy.vvlab.xyz' http://127.0.0.1:80/`，返回 `HTTP/1.1 502 Bad Gateway`。

### 原因

- **主机 Nginx** 的配置文件 `/etc/nginx/conf.d/vvlab-upstream.conf` 里，把请求反代到了 **127.0.0.1:30080**。
- 实际 **K3s Nginx Ingress Controller** 的 HTTP 端口是 **NodePort 31550**（不是 30080）。
- 30080 上没有服务在监听，Nginx 连不上后端，所以返回 502。

**为何会写错端口？**  
执行 `04-setup-nginx-upstream.sh` 时，脚本通过 `kubectl` 读取 Ingress 的 NodePort。脚本里原来用「端口名等于 http」来取端口号，而当前集群里该 Service 的端口名可能不是 `http`，导致取到的是默认值 30080，而不是实际的 31550。

### 解决步骤

1. **在服务器上查看 Ingress 实际 NodePort**：
   ```bash
   kubectl get svc -n ingress-nginx ingress-nginx-controller
   ```
   记下 HTTP 对应的一列，例如：`80:31550/TCP`，则 NodePort 为 **31550**。

2. **修改主机 Nginx 配置**：编辑 `/etc/nginx/conf.d/vvlab-upstream.conf`，把所有 **30080** 改成 **31550**，把所有 **30443** 改成 HTTPS 对应的 NodePort（如 **32589**）。保存后执行：
   ```bash
   sudo nginx -t
   sudo systemctl reload nginx
   ```

3. **（推荐）修复脚本避免以后再错**：在本地 `deploy/04-setup-nginx-upstream.sh` 里，把按「端口名」取 NodePort 改为按「端口号 80/443」取：
   - 原：`{.spec.ports[?(@.name=="http")].nodePort}`
   - 改：`{.spec.ports[?(@.port==80)].nodePort}`
   修改后重新上传到服务器，再执行一次 `04-setup-nginx-upstream.sh`，以后重跑脚本就会得到正确端口。

### 验证

在服务器上执行：  
`curl -sI -H 'Host: zxy.vvlab.xyz' http://127.0.0.1:80/`  
应返回 `HTTP/1.1 200 OK`。浏览器访问 **http://zxy.vvlab.xyz/** 应能打开页面。

---

## 问题二：zxy Pod 拉取镜像失败（authorization failed）

### 现象

- `kubectl get pods -n demo` 显示 zxy-site 的 Pod 状态为 **ErrImagePull** 或 **ImagePullBackOff**。
- `kubectl describe pod -n demo -l app=zxy-site` 的 Events 里有类似：
  - `pull access denied ... insufficient_scope: authorization failed`

### 原因

- 镜像仓库 **阿里云 ACR 上海个人版** 需要登录才能拉取。
- 集群里创建的拉取密钥 **acr-secret** 使用了错误的用户名或密码（或从未创建），导致 K3s 无法从 ACR 拉取镜像。

### 解决步骤

1. **在阿里云控制台获取正确登录信息**：
   - 打开 [阿里云容器镜像服务](https://cr.console.aliyun.com/) → 个人版 → **访问凭证**（或「设置Registry登录密码」）。
   - 若未设置过，先**设置独立登录密码**并记住。
   - 页面上会显示登录命令，例如：`docker login ... -u 用户名 -p 密码`，记下**用户名**和**密码**。

2. **在服务器上删除旧密钥并创建新密钥**（把下面的用户名、密码换成你在控制台看到的）：
   ```bash
   kubectl delete secret acr-secret -n demo --ignore-not-found=true
   kubectl create secret docker-registry acr-secret \
     --docker-server=crpi-c87ddoa33spg7s3f.cn-shanghai.personal.cr.aliyuncs.com \
     --docker-username=你的ACR用户名 \
     --docker-password=你的ACR密码 \
     -n demo
   ```

3. **重启 zxy 部署**，让 Pod 用新密钥重新拉取镜像：
   ```bash
   kubectl rollout restart deployment/zxy-site -n demo
   kubectl rollout status deployment/zxy-site -n demo --timeout=120s
   ```

### 验证

`kubectl get pods -n demo -l app=zxy-site` 应显示 `1/1 Running`。

---

## 问题三：镜像标签 latest 不存在（not found）

### 现象

- Pod 的 Events 里出现：`.../zxy-repo:latest: not found`。
- 说明 ACR 里该仓库**没有**名为 **latest** 的镜像标签。

### 原因

- 部署 YAML 里写的是 `.../zxy-repo:latest`，但阿里云 ACR 构建时只打了**版本号标签**（如 `zxy-2026`），没有同时打 **latest**。

### 解决方式（二选一）

**方式 A：临时让线上用已有版本标签**

在服务器上把当前使用的镜像改成已有标签（例如 zxy-2026）：
```bash
kubectl set image deployment/zxy-site site=crpi-c87ddoa33spg7s3f.cn-shanghai.personal.cr.aliyuncs.com/zzlab_imagespace/zxy-repo:zxy-2026 -n demo
kubectl rollout status deployment/zxy-site -n demo --timeout=90s
```
这样站点会先跑起来。后续若希望用 `latest`，需在 ACR 里给该镜像再打一个 **latest** 标签（见方式 B）。

**方式 B：在 ACR 里给镜像打上 latest 标签（推荐）**

- 登录 [阿里云 ACR 控制台](https://cr.console.aliyun.com/) → 个人版 → 镜像仓库 **zxy-repo** → **镜像版本**。
- 找到已构建成功的版本（如 **zxy-2026**），在操作里选择「**添加标签**」或「**标记为 latest**」，为该镜像再打一个标签 **latest**。
- 之后在服务器上执行：`kubectl rollout restart deployment/zxy-site -n demo`，即可拉取到 latest。

**预防**：在 ACR 的「构建规则」里勾选「**同时打 latest 标签**」，以后每次构建都会自动更新 latest，线上只需执行 `kubectl rollout restart` 即可更新。

---

## 问题四：阿里云 ACR 构建时拉取 nginx:alpine 超时

### 现象

- 在 ACR 控制台对 zxy-repo 触发构建时，构建日志里出现类似：
  - `failed to solve: ... nginx:alpine: failed to do request: Head "https://registry-1.docker.io/...": dial tcp ... i/o timeout`

### 原因

- 阿里云构建环境访问 **Docker Hub**（registry-1.docker.io）经常超时或不稳定，导致拉取基础镜像 `nginx:alpine` 失败。

### 解决步骤

- 在 **zxy 仓库**的 **Dockerfile** 里，把第一行的基础镜像从 Docker Hub 改为**国内镜像**，例如：
  - 原：`FROM nginx:alpine`
  - 改：`FROM docker.m.daocloud.io/library/nginx:alpine`
- 保存后提交并推送到 GitHub，再在 ACR 重新触发构建。

### 验证

ACR 构建日志中应能正常拉取基础镜像并完成构建，镜像版本列表里出现新版本。

---

## 问题五：请用 HTTP 访问，不要用 HTTPS

### 现象

- 打开 **https://zxy.vvlab.xyz/** 无法访问或报错。

### 原因

- 当前未配置 SSL 证书，只提供 **80 端口**的 HTTP 服务，没有 443 端口的 HTTPS。

### 解决方式

- 在浏览器中访问：**http://zxy.vvlab.xyz/**（注意是 **http** 不是 https）。
- 若以后需要 HTTPS，需在主机 Nginx 或 Ingress 上配置证书（参见 `04-setup-nginx-upstream.sh` 里注释掉的 443 示例）。

---

## 速查表

| 现象 | 可能原因 | 见上文 |
|------|----------|--------|
| 访问 zxy.vvlab.xyz 502 | 主机 Nginx 反代端口与 Ingress NodePort 不一致（如写了 30080 实际是 31550） | 问题一 |
| Pod ErrImagePull / authorization failed | ACR 拉取密钥用户名或密码错误 | 问题二 |
| Pod 报 latest: not found | ACR 仓库没有 latest 标签 | 问题三 |
| ACR 构建拉 nginx 超时 | 构建环境访问 Docker Hub 超时，需改用国内基础镜像 | 问题四 |
| https 打不开 | 未配置 HTTPS，请用 http | 问题五 |
