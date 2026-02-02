# 网站内容规划：三个子站 + 镜像与访问方式

三个内容与访问方式：

| 内容       | 二级域名           | 说明                     |
|------------|--------------------|--------------------------|
| 你的个人主页 | **zym.vvlab.xyz**  | 个人简历，美观展示       |
| 爱人个人主页 | **zxy.vvlab.xyz**  | 同上，独立站点           |
| 照片墙     | **photo.vvlab.xyz** | 照片展示/相册             |

下面按你的四个问题逐条回答，并给出推荐做法。

---

## 本地项目结构：vvlab 下三个目录分别关联三个 GitHub 仓库

**可以。** 在当前 **vvlab** 项目下建三个目录（如 `zym`、`zxy`、`photo`），每个目录各自是一个 **独立的 Git 仓库**，分别设置 `remote` 指向 GitHub 上的三个项目。这样你本地只有一个工作区（vvlab），但三个站点的代码分别推送到三个不同的 GitHub 仓库。

### 推荐目录结构

```text
vvlab/                    ← 当前项目（已有 deploy/ 等）
├── deploy/                 ← 部署脚本、文档（属于 vvlab 仓库）
├── zym/                    ← 你的个人主页，独立 git 仓库 → GitHub 仓库一
├── zxy/                    ← 爱人个人主页，独立 git 仓库 → GitHub 仓库二
└── photo/                  ← 照片墙，独立 git 仓库 → GitHub 仓库三
```

### 做法一：三个目录各自独立 Git 仓库（推荐）

1. **在 GitHub 上先建好三个仓库**，例如：`vvlab-zym`、`vvlab-zxy`、`vvlab-photo`（可先空仓库）。

2. **在 vvlab 根目录下建三个目录并初始化为独立仓库**：

   ```bash
   cd c:\Users\admin\vvlab

   # 你的个人主页
   mkdir zym
   cd zym
   git init
   git remote add origin https://github.com/你的用户名/vvlab-zym.git
   cd ..

   # 爱人个人主页
   mkdir zxy
   cd zxy
   git init
   git remote add origin https://github.com/你的用户名/vvlab-zxy.git
   cd ..

   # 照片墙
   mkdir photo
   cd photo
   git init
   git remote add origin https://github.com/你的用户名/vvlab-photo.git
   cd ..
   ```

3. **（可选）让 vvlab 主仓库忽略这三个目录**  
   这样 vvlab 的 commit 里不会包含三个站点里的文件，避免和子仓库混在一起。在 vvlab 根目录执行：

   ```bash
   # 在 vvlab 根目录
   echo zym/ >> .gitignore
   echo zxy/ >> .gitignore
   echo photo/ >> .gitignore
   ```
   然后 `git add .gitignore` 并提交。  
   之后你在 `zym/`、`zxy/`、`photo/` 里正常 `git add`、`git commit`、`git push`，都是推到各自对应的 GitHub 仓库；vvlab 仓库只关心 `deploy/` 等，不关心三个站点目录里的内容。

4. **日常使用**  
   - 改你的个人主页：进 `zym/`，改完 `git add`、`git commit`、`git push origin main` → 推到 vvlab-zym。  
   - 改爱人主页：进 `zxy/`，同样操作 → 推到 vvlab-zxy。  
   - 改照片墙：进 `photo/`，同样操作 → 推到 vvlab-photo。  
   - 改部署脚本/文档：在 vvlab 根目录或 `deploy/` 里改，提交到 vvlab 仓库。

### 做法二：用 Git 子模块（submodule）把三个 GitHub 仓库“挂”进 vvlab

若你希望「克隆 vvlab 时也能一并拿到三个站点的代码（且固定为某次提交）」，可以用子模块：

```bash
cd c:\Users\admin\vvlab

git submodule add https://github.com/你的用户名/vvlab-zym.git zym
git submodule add https://github.com/你的用户名/vvlab-zxy.git zxy
git submodule add https://github.com/你的用户名/vvlab-photo.git photo

git add .gitmodules zym zxy photo
git commit -m "Add three site repos as submodules"
```

这样 vvlab 仓库会记录「当前用的三个站点分别是哪个 commit」。别人克隆 vvlab 后执行：

```bash
git submodule update --init --recursive
```

就会自动克隆三个 GitHub 仓库到 `zym/`、`zxy/`、`photo/`。  
在子目录里改完代码后，仍然要进对应目录 `git push` 到各自的 GitHub 仓库；若更新了子模块指向的 commit，要在 vvlab 根目录再 `git add zym zxy photo` 并提交一次。

### 小结

| 方式     | 适用场景 |
|----------|----------|
| **做法一**（三目录各自独立仓库 + .gitignore） | 只想本地一个 vvlab 工作区，三个目录分别推三个 GitHub，vvlab 仓库不包含站点代码。 |
| **做法二**（submodule） | 希望 vvlab 仓库“引用”三个站点，克隆 vvlab 时能一起拉下三个站点到固定 commit。 |

你已决定在 GitHub 建三个项目，本地用 **vvlab + 三个目录分别关联三个 GitHub 项目** 就按上面做法一或做法二即可。

---

## 1. 是否要在 GitHub 上创建三个不同的「应用」？

**结论：可以「三个仓库」或「一个仓库三个目录」，二选一即可。**

| 方式 | 做法 | 优点 | 缺点 |
|------|------|------|------|
| **三个独立仓库** | 如 `vvlab-zym`、`vvlab-zxy`、`vvlab-photo` | 权限/关注点分离，阿里云 ACR 每个仓库对应一个镜像构建触发最直观 | 要维护 3 个 repo |
| **一个仓库三个目录** | 如本仓库下 `sites/zym`、`sites/zxy`、`sites/photo`，每个目录一个前端项目 + Dockerfile | 一份代码、一次 clone、统一 CI 建三个镜像 | ACR 若只支持「一个仓库一个构建规则」则需用 GitHub Actions 自己建三个镜像 |

**推荐**：  
- 若你希望**在阿里云控制台里点「关联 GitHub」就能自动构建**，且每个站点独立更新频率高 → 用 **3 个 GitHub 仓库**，每个仓库对应一个 ACR 镜像，最简单。  
- 若你希望**在一个地方改三个站点、统一版本和 CI** → 用 **1 个仓库 + 3 个目录**，用 GitHub Actions 构建并推送 3 个镜像到 ACR（见下文镜像与 CI/CD）。

---

## 2. 是否需要三个不同的 Pod？

**结论：需要。三个站点 = 三个 Deployment（各带自己的 Pod）+ 三个 Service + 共用一套 Ingress 做按域名分流。**

- **Deployment**：每个站点一个（如 `zym-site`、`zxy-site`、`photo-wall`），镜像可不同（见下节）。
- **Service**：每个 Deployment 一个 ClusterIP Service，供 Ingress 转发。
- **Ingress**：可以**一个 Ingress 资源**里写多条规则，按 `host` 分流：
  - `host: zym.vvlab.xyz` → `zym-site:80`
  - `host: zxy.vvlab.xyz` → `zxy-site:80`
  - `host: photo.vvlab.xyz` → `photo-wall:80`

不必为每个站点起一个 Pod 副本以上，除非你后面要做多副本扩容。

---

## 3. 镜像如何管理？如何 CI/CD？阿里云个人镜像服务怎么用？

### 镜像放在哪

- 建议统一用 **阿里云 ACR（个人版/免费版）**：国内拉取快、和 K3s 同地域更稳。
- 三个站点 → 三个镜像，例如：
  - `registry.cn-hangzhou.aliyuncs.com/你的命名空间/zym-site:latest`
  - `registry.cn-hangzhou.aliyuncs.com/你的命名空间/zxy-site:latest`
  - `registry.cn-hangzhou.aliyuncs.com/你的命名空间/photo-wall:latest`

### 阿里云 ACR「关联 GitHub」的含义

- ACR 的「镜像构建」可以关联 **一个 GitHub 仓库**：当该仓库发生 push（或指定分支/目录）时，在 ACR 里用该仓库里的 **Dockerfile** 构建镜像并推送到 ACR 的某个命名空间/仓库。
- **一个关联 = 一个 GitHub 仓库 → 一个 ACR 仓库（一条构建规则）**。  
  所以：
  - 若用 **3 个 GitHub 仓库**：在 ACR 里建 3 个「镜像仓库」或 3 条构建规则，分别关联 3 个 GitHub 仓库，每个仓库一个 Dockerfile，推送到对应 ACR 地址（如 zym-site、zxy-site、photo-wall）。**这样不需要自己写 CI，全部在阿里云控制台完成。**
  - 若用 **1 个 GitHub 仓库 + 3 个目录**：ACR 一般只针对「一个仓库」触发一次构建，很难在控制台里为同一仓库配置「按目录建 3 个镜像」。这时用 **GitHub Actions** 更合适：在一个 workflow 里根据目录构建 3 个镜像并分别 push 到 ACR 的 3 个仓库。

### 推荐两种用法

**方式 A：三个 GitHub 仓库 + 阿里云控制台构建（零代码 CI）**

1. 在 GitHub 建 3 个仓库，例如：`vvlab-zym`、`vvlab-zxy`、`vvlab-photo`。
2. 每个仓库根目录放该站点的前端代码 + 一个 **Dockerfile**（例如用 nginx 托管静态文件，或 Node 构建后把 dist 给 nginx）。
3. 登录阿里云 ACR 控制台 → 镜像仓库 → 创建 3 个「镜像仓库」（或命名空间下 3 个仓库）→ 每个仓库选择「关联 GitHub」→ 选择对应 GitHub 仓库、分支、Dockerfile 路径、构建规则（如 push 到 main 就构建并打 tag latest）。
4. 构建完成后，在 K3s 里把三个 Deployment 的 `image` 分别改为上述三个 ACR 地址；更新时 `kubectl set image deployment/xxx ...` 或重新 apply，并可配合 `imagePullPolicy: Always` 或定时重启拉新镜像。

**方式 B：一个 GitHub 仓库 + GitHub Actions 构建 3 个镜像推 ACR**

1. 在本仓库（或新建一个 vvlab 仓库）下建目录，例如：`sites/zym`、`sites/zxy`、`sites/photo`，每个目录一个前端项目 + Dockerfile。
2. 在 `.github/workflows/build-and-push.yml` 里写一个 workflow：  
   - 监听 push 到 main（或指定路径变更）；  
   - 对 `sites/zym`、`sites/zxy`、`sites/photo` 分别执行 `docker build`，并 `docker push` 到 ACR 的 3 个镜像地址（需在 GitHub 仓库 Settings → Secrets 里配置 ACR 的登录账号密码或 AccessKey）。
3. 同上，K3s 里三个 Deployment 用这三个 ACR 镜像；每次 push 后 Actions 构建并推送，你在服务器上执行一次拉取/重启即可。

**总结**：  
- **「是否意味着需要三个不同的 GitHub 应用」**：若用 ACR 控制台「关联 GitHub」做自动构建，最直接是 **3 个 GitHub 仓库对应 3 个 ACR 镜像**；若用 1 个仓库，就用 GitHub Actions 建 3 个镜像，不必在 ACR 里关联 3 次 GitHub。  
- **如何使用**：在 ACR 控制台完成「创建命名空间 → 创建镜像仓库 → 关联 GitHub 仓库 → 设置构建规则（分支、Dockerfile 路径、镜像 tag）」；首次可手动触发「立即构建」验证，之后 push 即自动构建。

---

## 4. 短期内无法用域名，用 IP 如何访问这三个应用？

当前架构里，主机 Nginx 把请求转到 Ingress，Ingress 按 **Host** 区分站点。用 IP 访问时，浏览器发出的 Host 是 `139.224.31.98`，没有 `zym.vvlab.xyz` 等信息，Ingress 无法按 host 分流。

有两种实用做法：

### 做法一：用「路径」区分（推荐，无需改本机）

在 Ingress 里**同时**保留按域名分流，并**增加按路径分流**，使：

- `http://139.224.31.98/zym/`  → 你的个人主页
- `http://139.224.31.98/zxy/`  → 爱人个人主页  
- `http://139.224.31.98/photo/` → 照片墙

实现要点：

- Ingress 里为 **默认 host（或空 host）** 增加三条 path：`/zym`、`/zxy`、`/photo`，分别对应三个 Service；若前端是 SPA 或静态站，通常需要加 **rewrite** 或子路径支持（例如 nginx 里 `location /zym { alias /app; }` 或前端 base 设为 `/zym/`）。
- 主机 Nginx 当前是「把所有请求转到 Ingress 且带 `Host: vvlab.xyz`」。若要做「按 IP 访问时按路径分流」，可以：
  - **方案 A**：主机 Nginx 对 `Host: 139.224.31.98`（或默认 default_server）的请求，按 `location /zym`、`/zxy`、`/photo` 分别反代到 Ingress 的**同一个 NodePort**，但把 **Host** 改成不同的内部标识（如 `zym.vvlab.xyz`、`zxy.vvlab.xyz`、`photo.vvlab.xyz`），这样 Ingress 仍按 host 路由到对应后端；**或**
  - **方案 B**：Ingress 里除了按 host 的规则外，再写「无 host 或 default + path `/zym`、`/zxy`、`/photo`」三条规则，分别指向三个 Service。这样用 IP 访问时带路径即可。

路径方式需要前端支持「跑在子路径下」（例如 Vue/React 的 `base: '/zym/'`），部署时静态资源路径要对。

### 做法二：本机改 hosts，用「假域名」访问

在你自己的电脑上配置 hosts，把三个二级域名指到同一 IP：

```text
139.224.31.98  zym.vvlab.xyz zxy.vvlab.xyz photo.vvlab.xyz
```

然后浏览器访问 `http://zym.vvlab.xyz`、`http://zxy.vvlab.xyz`、`http://photo.vvlab.xyz`，请求里会带正确 Host，Ingress 按现有「按 host 分流」即可，无需改 Nginx/Ingress。  
缺点：只有在你改过 hosts 的这台电脑上有效，别人用 IP 访问仍然需要路径方案或后续域名解析。

**建议**：  
- 短期：**本机 hosts + 三个子域名**，最省事；  
- 同时或后续：在 Ingress（和必要时主机 Nginx）里**加上按路径 `/zym`、`/zxy`、`/photo` 的规则**，这样别人用 IP 也能通过 `http://IP/zym/` 等形式访问。

---

## 接下来可以做的具体步骤（建议顺序）

1. **DNS**：把 `zym.vvlab.xyz`、`zxy.vvlab.xyz`、`photo.vvlab.xyz` 解析到当前实例 IP（若暂时不用域名可跳过，用 hosts 或路径）。
2. **主机 Nginx**：把当前「统一带 `Host: vvlab.xyz`」改为**按请求的 Host 透传**（`proxy_set_header Host $host;`），这样 Ingress 才能按子域名区分三个站点；若保留根域名欢迎页，可单独为 `vvlab.xyz` 或默认写一条规则。
3. **GitHub**：选定「3 仓库」或「1 仓库 3 目录」，为每个站点写好 Dockerfile 和前端代码。
4. **ACR**：在阿里云创建 3 个镜像仓库（或 3 条构建），按上面方式 A 或 B 完成首次构建并拿到三个镜像地址。
5. **K3s**：写三个 Deployment + 三个 Service；在一个 Ingress 里写三条 `host` 规则分别指向三个 Service；若需要 IP 访问，再在同一 Ingress 里加 path 规则（/zym、/zxy、/photo）。
6. **短期访问**：本机 hosts 指向 IP，用 `http://zym.vvlab.xyz` 等访问；或提供 `http://IP/zym/`、`/zxy/`、`/photo/` 给他人使用。

如果你愿意，我可以下一步直接帮你写：  
- 主机 Nginx 的 `vvlab-upstream.conf` 修改示例（透传 Host），以及  
- 三个站点的 Ingress YAML 示例（含 host 规则，以及可选的 path 规则供 IP 访问）。
