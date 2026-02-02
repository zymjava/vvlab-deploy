# 三站点部署步骤（域名已解析 + ACR 个人版）

域名已解析到 139.224.31.98 后，按以下顺序操作即可让 zym / zxy / photo 三个子站通过 zym.vvlab.xyz、zxy.vvlab.xyz、photo.vvlab.xyz 访问。

---

## 一、主机 Nginx：透传 Host

当前 Nginx 已改为**透传请求的 Host**（`proxy_set_header Host $host;`），Ingress 才能按子域名把请求分到不同站点。

**操作**：在服务器上重新执行 04 脚本（或手动改配置后重载）：

```bash
# 在服务器上，deploy 目录下
sudo bash 04-setup-nginx-upstream.sh
```

确认 `/etc/nginx/conf.d/vvlab-upstream.conf` 里是 `proxy_set_header Host $host;`（不是固定 `Host vvlab.xyz`）。

---

## 二、镜像从 GitHub 构建到 ACR（个人版不能同步外源镜像）

ACR 个人版不能直接“同步”Docker Hub 等外源镜像，需要**用你自己的仓库构建出镜像再推到 ACR**。

### 1. 每个站点仓库里要有 Dockerfile

- **zxy**：`vvlab/zxy` 下已有 `Dockerfile`（Nginx 托管当前目录静态文件），构建即得到 zxy 站点镜像。
- **zym、photo**：在各自仓库根目录放一个同结构的 Dockerfile（静态站用 Nginx 拷贝当前目录到 `/usr/share/nginx/html`），例如与 zxy 相同即可。

### 2. 在阿里云 ACR 创建三个「镜像仓库」

- 登录 [阿里云容器镜像服务](https://cr.console.aliyun.com/)
- 命名空间：用你的个人命名空间（或新建一个）
- 创建三个**公开**或**私有**仓库（名字与下面一致即可）：
  - `zym-space`
  - `zxy-space`
  - `photo-wall`

### 3. 构建并推送镜像（二选一）

**方式 A：ACR 控制台「关联 GitHub」自动构建（推荐）**

1. 在 ACR 每个镜像仓库里：**构建** → **添加构建规则** → **关联 GitHub**（授权阿里云访问你的 GitHub）。
2. 选择对应仓库：
   - `zym-space` 镜像 ← 关联 `zymjava/zym-space`
   - `zxy-space` 镜像 ← 关联 `zymjava/zxy-space`
   - `photo-wall` 镜像 ← 关联 `zymjava/photo-wall`
3. 构建规则：分支选 `main`（或你实际用的分支），Dockerfile 路径 `Dockerfile`，镜像版本填 `latest`。
4. 保存后触发一次「立即构建」，等构建成功，ACR 里就有三个镜像地址，例如：
   - `registry.cn-hangzhou.aliyuncs.com/<你的命名空间>/zym-space:latest`
   - `registry.cn-hangzhou.aliyuncs.com/<你的命名空间>/zxy-space:latest`
   - `registry.cn-hangzhou.aliyuncs.com/<你的命名空间>/photo-wall:latest`

**方式 B：本机 Docker 构建并推送**

```bash
# 登录 ACR（替换 <命名空间> 为你的）
docker login --username=你的ACR用户名 registry.cn-hangzhou.aliyuncs.com

# 以 zxy 为例，在 vvlab/zxy 目录
cd /path/to/vvlab/zxy
docker build -t registry.cn-hangzhou.aliyuncs.com/<命名空间>/zxy-space:latest .
docker push registry.cn-hangzhou.aliyuncs.com/<命名空间>/zxy-space:latest
```

zym、photo 同理，在各自目录构建并推送到对应镜像名。

---

## 三、K3s 部署三站点

### 1. 修改 `vvlab-sites.yaml` 中的镜像地址

把 `<ACR_命名空间>` 全部替换为你的 ACR 命名空间，例如 `myname`：

```bash
sed -i 's/<ACR_命名空间>/myname/g' vvlab-sites.yaml
```

（或手动编辑三处 `registry.cn-hangzhou.aliyuncs.com/<ACR_命名空间>/...`。）

### 2. 若 ACR 仓库是私有的：创建拉取密钥

在**执行 apply 的机器**上（能访问 K3s 的节点）：

```bash
kubectl create secret docker-registry acr-secret \
  --docker-server=registry.cn-hangzhou.aliyuncs.com \
  --docker-username=你的ACR用户名 \
  --docker-password=你的ACR密码 \
  -n demo
```

然后在 `vvlab-sites.yaml` 里，把三处 `imagePullSecrets: []` 改成：

```yaml
imagePullSecrets:
  - name: acr-secret
```

### 3. 应用配置

确保 welcome 已部署（根域名欢迎页）：

```bash
kubectl apply -f example-welcome.yaml
```

再部署三站点：

```bash
kubectl apply -f vvlab-sites.yaml
```

### 4. 检查

```bash
kubectl get pods -n demo
kubectl get svc -n demo
kubectl get ingress -n demo
```

若某个 Pod 是 `ImagePullBackOff`，检查镜像地址、命名空间、以及私有仓库时是否已建 `acr-secret` 并写上 `imagePullSecrets`。

---

## 四、验证访问

- 根域名：`http://vvlab.xyz` → 欢迎页  
- 三站点：  
  - `http://zym.vvlab.xyz`  
  - `http://zxy.vvlab.xyz`  
  - `http://photo.vvlab.xyz`  

若某站点尚未做内容，可先只部署 zxy（在 `vvlab-sites.yaml` 里注释掉 zym、photo 的 Deployment，只保留 zxy 的 Deployment + 三个 Service + Ingress），等 zym/photo 有镜像后再打开对应 Deployment 并重新 apply。

---

## 五、之后更新站点

- 代码更新后：在 GitHub 对应仓库 push，若用了 ACR「关联 GitHub」会自动重新构建并打 `latest`。
- 让 K3s 用新镜像：  
  ```bash
  kubectl rollout restart deployment/zxy-site -n demo
  ```  
  或重新 `kubectl apply -f vvlab-sites.yaml`（镜像用 `imagePullPolicy: Always` 时会拉新镜像）。
