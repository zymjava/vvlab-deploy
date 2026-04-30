# MySQL 8 部署（K3s / K8s）

目标：在现有 K3s 集群中安装一个可供后续业务使用的 MySQL（8.0）。

当前部署范围：`demo` 命名空间。

## 1. 这次写入到集群的资源

- `ConfigMap`：`mysql-config`（`my.cnf` 配置）
- `PersistentVolumeClaim`：`mysql-pvc`（数据持久化）
- `Secret`：`mysql-secret`（密码，仅在服务器创建，不建议写入仓库）
- `Deployment`：`mysql`（镜像 `docker.m.daocloud.io/library/mysql:8.0`，单实例 + `Recreate`，resources 已按 2C2G 机器做保守收缩）
- `Service`：`mysql`（ClusterIP，3306 端口）

对应文件：

- `01-mysql-configmap.yaml`
- `02-mysql-pvc.yaml`
- `03-mysql-deployment.yaml`
- `04-mysql-service.yaml`

## 2. 必填项：创建 Secret（密码）

因为 `Secret` 会包含密码，不建议提交到 GitHub。

请在服务器上执行以下命令创建 `mysql-secret`（把 `MYSQL_ROOT_PASSWORD` / `MYSQL_PASSWORD` 换成你希望的密码）。

```bash
kubectl -n demo delete secret mysql-secret --ignore-not-found=true

kubectl -n demo create secret generic mysql-secret \
  --from-literal=MYSQL_ROOT_PASSWORD='你的root密码' \
  --from-literal=MYSQL_PASSWORD='你的app密码'
```

说明：
- MySQL 容器会使用 `MYSQL_ROOT_PASSWORD` 创建 root；
- 容器环境变量里使用 `MYSQL_PASSWORD` 给 `MYSQL_USER=appuser` 设定 app 用户密码；
- 在当前 YAML 中，`MYSQL_USER` 写死为 `appuser`、`MYSQL_DATABASE` 写死为 `appdb`。

## 3. 应用 MySQL 资源

在服务器上（SSH 进入后）：

```bash
kubectl apply -f 01-mysql-configmap.yaml
kubectl apply -f 02-mysql-pvc.yaml
kubectl apply -f 03-mysql-deployment.yaml
kubectl apply -f 04-mysql-service.yaml
```

## 4. 等待启动与验证

```bash
kubectl -n demo get pods -l app=mysql
kubectl -n demo logs -l app=mysql --tail=200
kubectl -n demo get svc mysql
```

如果 Pod 不 Ready：
- 优先检查 `mysql-secret` 是否存在且 key 是否为 `MYSQL_ROOT_PASSWORD` / `MYSQL_PASSWORD`；
- 检查 PVC 是否绑定成功（`kubectl -n demo get pvc`）。

## 4.1 服务器内存占用观测（记录用）

你提供 / 现场复核过的观测信息如下（同一台 2C2G 机器，含 K3s、Ingress、站点 Pod、MySQL）：

- 安装 MySQL 前：内存已占用 `56.144%`
- 初次部署 MySQL 后（阿里云控制台查看）：内存占用 `78.049%`
- 调优后一次观测：内存占用 `65.895%`
- 集群继续精简后（禁用 `Traefik`、压缩 `ingress-nginx`、补齐静态站点资源限制），`kubectl top nodes` 视角约 `58%`

### 4.1.1 `78.049%` 对应的配置（调优前）

- 镜像：`docker.m.daocloud.io/library/mysql:8.0`
- Deployment 策略：默认滚动更新（未显式设置 `Recreate`）
- resources:
  - request：`cpu 250m` / `memory 256Mi`
  - limit：`cpu 500m` / `memory 512Mi`
- `my.cnf` 关键参数：
  - `innodb_buffer_pool_size = 512M`
  - `max_connections = 50`
  - `key_buffer_size = 32M`
  - `sort_buffer_size = 1M`
  - `join_buffer_size = 1M`
  - `read_buffer_size = 1M`
  - `read_rnd_buffer_size = 1M`
  - `tmp_table_size = 64M`
  - `max_heap_table_size = 64M`
  - `performance_schema = ON`（MySQL 默认）

### 4.1.2 `63.672%` / `65.895%` 对应的配置（调优后）

- 镜像：`docker.m.daocloud.io/library/mysql:8.0`
- Deployment 策略：`Recreate`
- resources:
  - request：`cpu 250m` / `memory 192Mi`
  - limit：`cpu 500m` / `memory 384Mi`
- `my.cnf` 关键参数：
  - `innodb_buffer_pool_size = 256M`
  - `max_connections = 30`
  - `key_buffer_size = 8M`
  - `sort_buffer_size = 512K`
  - `join_buffer_size = 512K`
  - `read_buffer_size = 512K`
  - `read_rnd_buffer_size = 512K`
  - `tmp_table_size = 32M`
  - `max_heap_table_size = 32M`
  - `performance_schema = OFF`

说明：
- `63.672%` 与 `65.895%` 都属于调优后区间，差异通常来自内核 page cache、K3s 组件瞬时波动、镜像/日志/监控采样时点不同；
- 当前这套参数已经明显低于最初的 `78.049%`，更适合这台 2C2G 机器长期运行。

### 4.1.3 `58%`（K8s 节点视角）查看命令

```bash
kubectl top nodes
kubectl top pods -A --sort-by=memory
free -h
ps -eo pid,ppid,comm,%mem,rss,args --sort=-rss | grep -E 'k3s|nginx|containerd' | grep -v grep | head -n 20
```

说明：
- `kubectl top nodes` 是这次“节点视角压到 58%”的直接来源；
- `free -h` 看的是主机整体内存，不同于 K8s metrics-server 的统计口径；
- 继续压低内存的动作不是只改 MySQL，还包括禁用 K3s 自带 `Traefik`、把 `ingress-nginx` 调成单 worker、以及给 `welcome` / `zxy-site` 补 `requests` / `limits`。

该数据用于提醒：后续若再部署更多服务，仍优先考虑：
- 继续约束非数据库 Pod 的 `requests` / `limits`；
- 避免启用不必要的 K3s 组件；
- 若业务量显著上升，再考虑回调 MySQL 参数或升级实例规格。

## 5. 后续服务连接 MySQL

同命名空间 `demo` 下，连接地址：

- Host：`mysql`（Service 名）
- Port：`3306`
- Database：`appdb`
- User：`appuser`
- Password：你在 Secret 里设置的 `MYSQL_PASSWORD`

若后续服务在其他命名空间，则用全限定域名：

- `mysql.demo.svc.cluster.local`

## 6. 外网用 DBeaver 直连（需要额外 Service）

当前的 `04-mysql-service.yaml` 是 `ClusterIP`，只能在集群内部访问；如果你希望从外网（DBeaver 所在电脑）直接连接，需要再创建一个面向外网的 Service（通常用 `NodePort`）。

建议做法：应用 `05-mysql-nodeport.yaml`（新增文件，创建的是 `mysql-external` Service），并在**服务器安全组**放行 `NodePort` 端口。

### 6.1 创建 NodePort Service

```bash
kubectl -n demo apply -f 05-mysql-nodeport.yaml
kubectl -n demo get svc mysql-external
```

### 6.2 DBeaver 连接方式（外网）

- Host：`139.224.31.98`
- Port：`30306`（对应 `mysql-external` 的固定 nodePort；若你改了 nodePort，请以实际为准）
- Database：`appdb`
- User：`appuser`
- Password：从 `mysql-secret` 读取（见下一节）

### 6.3 查看 `mysql-secret` 里的 `MYSQL_PASSWORD`（得到明文）

在服务器上执行：

```bash
kubectl -n demo get secret mysql-secret -o jsonpath='{.data.MYSQL_PASSWORD}' | base64 -d
```

如果你也想看 root 密码：

```bash
kubectl -n demo get secret mysql-secret -o jsonpath='{.data.MYSQL_ROOT_PASSWORD}' | base64 -d
```

