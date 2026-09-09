# 小红书 API-first MCP Server

[English](README.md) | [简体中文](README_CN.md)

这是一个面向 AI Agent 的小红书 Model Context Protocol（MCP）服务，可以检查登录状态、发布图文笔记、搜索内容、读取笔记详情及查询用户资料。

本项目是基于 [`shanyang-me/xhs-mcp`](https://github.com/shanyang-me/xhs-mcp) 维护的私有部署分支，保留上游 MIT License，并增加了：

- 独立 Docker 部署
- 可配置 HTTP 监听地址
- 兼容包装格式的 Cookie 导入
- HTTPS CDN 图片安全下载
- 公开及私密图文发布
- GHCR 自动构建
- nginx、HTTPS 和迁移模板

## 工作方式

发布链路采用 API-first 方式：

1. Playwright 启动无头 Chromium。
2. 浏览器加载小红书 Cookie 和登录环境。
3. 在网页环境中调用 `window._webmsxyw()` 生成请求签名。
4. 通过 HTTP API 获取图片上传许可。
5. 直接上传图片到小红书 CDN。
6. 调用小红书 Internal API 创建笔记。

发布过程不依赖 Playwright 点击发布页面按钮。浏览器负责登录态和签名环境，Internal API 负责实际发布。

> 注意：本项目使用小红书网页 Internal API，不是官方开放发布 API。接口、签名或风控规则可能随时变化，正式使用前请自行确认平台规则并严格控制发布频率。

## MCP Tools

| Tool | 说明 |
|---|---|
| `check_login_status` | 检查当前登录状态 |
| `get_login_qrcode` | 获取小红书登录二维码 |
| `check_qrcode_status` | 查询二维码扫码及确认状态 |
| `reload_cookies` | 重新加载外部导入的 Cookie |
| `publish_content` | 发布单图或多图图文笔记 |
| `search_feeds` | 按关键词搜索小红书笔记 |
| `get_feed_detail` | 获取笔记详情及互动数据 |
| `user_profile` | 获取用户资料及互动统计 |

## 使用 Docker 部署

### 环境要求

- Linux amd64
- Docker Engine 和 Docker Compose
- 至少 3GB 可用磁盘空间
- 一个小红书账号
- 公网部署时需要域名、TCP 80/443、nginx 和 Certbot

### 使用 GHCR 镜像

当前版本镜像：

```text
ghcr.io/jasondu/xhs-mcp-api-first:v0.2.0
```

仓库和镜像为私有资源时，先使用具有 `read:packages` 权限的 GitHub Token 登录：

```bash
echo "$GHCR_TOKEN" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

部署：

```bash
git clone https://github.com/jasondu/xhs-mcp-api-first.git
cd xhs-mcp-api-first/deploy
cp .env.example .env
mkdir -p data/xhs-state data/publish-input
sudo chown -R 10001:10001 data/xhs-state
docker compose --env-file .env pull
docker compose --env-file .env up -d
docker compose ps
```

默认仅在宿主机监听：

```text
http://127.0.0.1:18061/mcp
```

不要直接将该端口无鉴权暴露到公网。

### 从源码构建

Dockerfile 已包含 Chromium 和对应 Linux 依赖，不依赖宿主机 Playwright 缓存：

```bash
docker build -t xhs-mcp-api-first:local .
```

## 登录与持久化

登录数据保存在：

```text
deploy/data/xhs-state/
```

该目录通过 bind mount 映射到容器的：

```text
/data/.xhs-mcp
```

登录流程：

1. 调用 `get_login_qrcode`。
2. 使用小红书 App 扫码并确认。
3. 调用 `check_qrcode_status`。
4. 调用 `check_login_status` 确认账号。

如果服务器出口 IP 无法获取有效二维码，可以通过安全渠道导入已有 `cookies.json`，然后调用：

```text
reload_cookies
check_login_status
```

Cookie、Browser Profile、Bearer Token 和证书私钥不得提交到 Git 或构建进镜像。

## 发布图文笔记

### 本地图片

将图片放入：

```text
deploy/data/publish-input/
```

容器内对应路径为：

```text
/data/publish-input/
```

调用示例：

```json
{
  "title": "小红书图文测试",
  "content": "这是一篇通过 XHS MCP 发布的图文笔记。",
  "images": [
    "/data/publish-input/example.jpg"
  ],
  "tags": ["AI", "技术"],
  "is_private": true,
  "post_time": null
}
```

### CDN 图片

`publish_content.images` 可以直接接收白名单内的 HTTPS CDN 图片：

```json
{
  "title": "CDN 图片测试",
  "content": "这是一篇使用 CDN 图片的测试笔记。",
  "images": [
    "https://tempfile.aiquickdraw.com/images/example.png"
  ],
  "is_private": true
}
```

默认 CDN 白名单：

```text
tempfile.aiquickdraw.com
```

通过 `.env` 修改允许的精确域名，多个域名使用英文逗号分隔：

```dotenv
XHS_MCP_IMAGE_HOSTS=tempfile.aiquickdraw.com,cdn.example.com
```

CDN 下载保护包括：

- 仅允许 HTTPS 和 443 端口
- 精确域名白名单
- DNS 解析地址必须全部为公网 IP
- 实际连接对端必须是公网 IP
- 最多跟随 3 次重定向，每一跳重新校验
- 仅支持有效 PNG/JPEG
- 同时校验 HTTP MIME 和文件魔数
- 默认单图最大 15MB
- 默认每篇最多 9 张图片
- 默认下载超时 15 秒
- 发布成功或失败后自动清理临时文件
- 拒绝 HTTP、内网/回环地址、`file://` 和白名单外域名

### 公开与私密发布

仅自己可见：

```json
{
  "is_private": true
}
```

公开发布：

```json
{
  "is_private": false
}
```

测试阶段建议始终使用 `is_private=true`。公开发布前应确认内容、账号权限和平台合规性。

成功返回示例：

```json
{
  "success": true,
  "note_id": "小红书笔记唯一标识",
  "url": "小红书笔记地址"
}
```

FastMCP 客户端可能将业务 JSON 包装在 `content[0].text` 或 `structuredContent.result` 字符串内，调用方需要再次解析。

如果调用超时、没有 `note_id` 或结果不明确，不要自动重试发布，否则可能产生重复笔记。

## 定时发布

`post_time` 格式：

```text
YYYY-MM-DD HH:mm:ss
```

例如：

```json
{
  "post_time": "2026-09-10 10:30:00"
}
```

Docker Compose 默认时区为 `Asia/Beijing`。

## 公网 HTTPS

生产环境推荐：

```text
Internet
  → HTTPS 443
  → nginx Bearer Token 校验
  → 127.0.0.1:18061/mcp
  → XHS MCP
```

仓库提供：

```text
deploy/nginx.conf.template
```

部署时替换：

- `__MCP_DOMAIN__`
- `__MCP_BEARER_TOKEN__`
- `__MCP_PORT__`

使用 Let’s Encrypt 申请证书后，必须验证：

1. 无 Token 返回 HTTP 401。
2. 正确 Token 可以执行 MCP `initialize`。
3. `tools/list` 返回 8 个 tools。
4. `check_login_status` 返回正确账号。

## 配置项

| 环境变量 | 默认值 | 说明 |
|---|---:|---|
| `XHS_MCP_HOST` | `127.0.0.1` | MCP 服务监听地址 |
| `XHS_MCP_IMAGE_HOSTS` | `tempfile.aiquickdraw.com` | CDN 精确域名白名单 |
| `XHS_MCP_LOCAL_IMAGE_ROOTS` | `/data/test-assets,/data/publish-input` | 允许读取的本地图片目录 |
| `XHS_MCP_IMAGE_MAX_BYTES` | `15728640` | 单张图片最大字节数 |
| `XHS_MCP_IMAGE_MAX_COUNT` | `9` | 每次发布最大图片数量 |
| `XHS_MCP_IMAGE_TIMEOUT` | `15` | CDN 下载超时秒数 |

## 升级与回滚

在 `deploy/.env` 固定版本：

```dotenv
XHS_MCP_VERSION=v0.2.0
```

升级：

```bash
docker compose --env-file .env pull
docker compose --env-file .env up -d
```

回滚时将 `XHS_MCP_VERSION` 改回上一版本并执行相同命令。

## 服务器迁移

新服务器需要迁移的核心数据只有登录态：

```text
deploy/data/xhs-state/
```

推荐流程：

1. 停止旧服务器 MCP 容器。
2. 通过加密通道传输登录态目录。
3. 在新服务器拉取固定版本 GHCR 镜像。
4. 恢复目录及权限。
5. 启动 MCP。
6. 调用 `reload_cookies` 和 `check_login_status`。
7. 完成私密测试发布后再切换正式流量。

不要将登录态备份存放在 GitHub 仓库中，即使仓库是私有的。

## 当前限制

- 仅支持图文发布，不支持视频发布
- 没有编辑或删除笔记工具
- 私密笔记可能无法通过 `get_feed_detail` 验证
- 尚未实现 `PublishTask/taskId`
- 尚未实现发布幂等
- 尚未实现自动发布结果 verify
- 尚未实现 `UNKNOWN` 状态处理
- 二维码登录可能受服务器出口 IP 风控影响
- Internal API 及网页签名可能随小红书更新而失效

## 开发与上游同步

仓库建议保留两个 remote：

```text
origin    你的私有仓库
upstream  https://github.com/shanyang-me/xhs-mcp.git
```

同步上游前应先审阅实际源码差异，并重新运行登录、单图、多图、CDN、连续发布及 Docker 重启测试。

## License

MIT。原始项目及版权信息见 [`LICENSE`](LICENSE) 和上游仓库。
