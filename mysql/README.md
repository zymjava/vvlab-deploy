# MySQL 8 部署（K3s / K8s）

目标：在现有 K3s 集群中安装一个可供后续业务使用的 MySQL（8.0）。

当前部署范围：`demo` 命名空间。

## 1. 这次写入到集群的资源

- `ConfigMap`：`mysql-config`（`my.cnf` 配置）
- `PersistentVolumeClaim`：`mysql-pvc`（数据持久化）
- `Secret`：`mysql-secret`（密码，仅在服务器创建，不建议写入仓库）
- `Deployment`：`mysql`（镜像 `mysql:8.0`，resources 按 2C2G 做了限制）
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

你提供的观测信息（用于后续评估资源是否需要调整）：

- 安装 MySQL 前：内存已占用 `56.144%`
- 安装 MySQL 后（阿里云控制台查看）：内存占用 `75.71%`

该数据用于提醒：后续若再部署更多服务，可能需要：
- 调小 `innodb_buffer_pool_size` / requests / limits；
- 或者将 MySQL 换到更大实例（按实际业务量）。

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

