# Agent 会话摘要（改名 / 新窗口后恢复用）

**用途**：你把父目录从 `vivilab` 改名为 `vvlab` 并打开新窗口后，当前对话会断开；新 agent 或你本人可读本文档 + 下面列出的文件，快速恢复上下文。

---

## 当前项目状态（截至本次会话）

- **项目**：vvlab 展示应用，部署在阿里云实例 `139.224.31.98`。
- **架构**：主机 Nginx → K3s → Nginx Ingress → 应用 Pod；根域名 `vvlab.xyz`，欢迎页已通。
- **已做**：
  - 在 `deploy/` 下准备好 01～04 脚本、`example-welcome.yaml`、`k3s-registries.yaml` 等；已在实例上执行并装好主机 Nginx、K3s、Nginx Ingress、welcome Pod。
  - 解决 80 端口冲突：将 K3s 自带的 Traefik Service 改为 ClusterIP，释放 80 给主机 Nginx；`http://139.224.31.98/` 已返回欢迎页。
  - 规划三个子站：zym.vvlab.xyz（你的个人主页）、zxy.vvlab.xyz（爱人主页）、photo.vvlab.xyz（照片墙）；已在 GitHub 建四个仓库，本地 **vvlab** 下四目录分别关联：**zym**→zym-space、**zxy**→zxy-space、**photo**→photo-wall、**deploy**→vvlab-deploy。
  - 文档中「vivilab」已全部改为「vvlab」；根目录重复脚本（02、04）已删，只保留 `deploy/` 下脚本。

---

## 改名与 Reload 后建议

1. **父目录改名**：在资源管理器中把 `c:\Users\admin\vivilab` 重命名为 `vvlab`（或 PowerShell：`Rename-Item "c:\Users\admin\vivilab" "vvlab"`）。
2. **新窗口打开**：在 Cursor 里 **文件 → 打开文件夹** 选择 `c:\Users\admin\vvlab`。
3. **恢复上下文**：在新对话里可对 agent 说：「请先读 `deploy/AGENT-SESSION-NOTES.md`、`deploy/OPERATIONS.md`、`deploy/CONTENT-PLAN.md`，了解项目与规划，再继续。」这样新 agent 能接上之前的决策和待办。

---

## 重要文件索引

| 文件 | 内容 |
|------|------|
| `deploy/README.md` | 项目说明、执行顺序、文件说明 |
| `deploy/OPERATIONS.md` | 部署与排障的完整记录（架构、步骤、80 端口问题与修复） |
| `deploy/CONTENT-PLAN.md` | 三个子站规划、GitHub/镜像/CI/CD、本地 vvlab 下三目录关联三仓库、IP 访问方式 |
| `deploy/AGENT-SESSION-NOTES.md` | 本文件，会话摘要与改名后恢复指引 |

以上内容已写在仓库里，改名并打开 vvlab 后不会丢失；新窗口里读这些文件即可延续工作。
