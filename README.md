# 直播源本地缓冲代理

把不稳定的远程 HLS 直播源，变成「本机磁盘直读」的稳定播放源。

播放器直连上游时，每个切片都要自己去拉一次；上游一慢、一抖、一返回 5xx，播放器就卡住甚至断开。本代理在中间加一层**预取 + 落盘缓存**：后台持续把最新切片下载到本地，播放器只从本机读，抗抖动能力大幅提升。

只依赖 Node.js，无需 `npm install`。

> 本仓库只包含**播放侧**（缓冲代理 + 播放管理页）。
> 代理控制台（mihomo / 订阅 / 节点 / 测速 / 规则 / 流量）是另一个独立项目：mihomo 代理控制台。两者可以各自单独运行。

---

## 特性

- **切片本地缓冲**：后台预取 HLS 切片，播放器只读本机
- **缓冲池**：最新一段切片先扣在本地，播放器稳定落后直播一小段，上游抖动时用池子顶住
- **多源容错**：请求超时、重试、`curl` 兜底、自动跳过演示视频
- **播放管理页**：改配置、看频道状态、缓存与日志
- **可选走上游代理**：支持 HTTP 代理（例如 mihomo 的 `127.0.0.1:7890`）
- **自定义走代理域名**：可以只让指定域名经过代理
- **局域网共享**：播放列表可以共享给同网段设备
- **源体检**：`check.js` 逐条检测频道可用性

---

## 环境要求

- Node.js **18 以上**
- 可选：上游 HTTP 代理（mihomo / Clash 等）
- 可选：Linux 下用 systemd 常驻运行

---

## 快速开始

1. 下载或克隆本项目。
2. 准备配置：

   ```powershell
   copy config.example.json config.json
   ```

3. 启动播放服务：

   ```powershell
   node proxy.js
   ```

   也可以直接双击 `start.cmd`（Windows）或执行 `bash start.sh`（Linux）。

4. 终端会打印地址，例如：

   ```
   本机播放列表:       http://127.0.0.1:8317/list.m3u
   局域网播放列表:     http://192.168.1.10:8317/list.m3u
   管理页面:           http://127.0.0.1:8317/admin
   ```

5. 在播放器（PotPlayer / VLC / 电视端影视仓 / TiviMate 等）里添加：

   ```
   http://<本机IP>:8317/list.m3u
   ```

6. 浏览器打开 `http://<本机IP>:8317/admin` 可以修改配置、查看频道状态。

仓库里的 `config.json` 默认 **`proxyEnabled: false`（直连）**，不装 mihomo 也能启动。需要走代理时把 `proxyEnabled` 改成 `true` 并填写 `proxy`。

`config.json` 的 `source` 默认是示例地址，请换成你自己的 m3u 地址。仓库里的 `tv.m3u` 签名已打码，只作格式示例，**不能直接播放**。

手机或电视播放时必须使用**局域网地址**（不能用 `127.0.0.1`），并保证防火墙放行 8317 端口。

---

## 目录说明

| 文件 | 说明 |
| --- | --- |
| `proxy.js` | 播放服务主程序（默认 8317） |
| `admin.html` | 播放管理页面 |
| `check.js` | 源体检工具，逐条检测频道可用性 |
| `config.json` / `config.example.json` | 播放服务配置 |
| `tv.m3u` | 本地示例清单（签名已打码） |
| `start.cmd` / `start.sh` | Windows / Linux 启动脚本 |
| `install-service.sh` | Linux systemd 安装脚本 |
| `proxy-runtime.json` | 代理控制台推送的运行时状态（自动生成，可不存在） |
| `proxy-demo.json` | 演示源检测状态（自动生成） |
| `cache/` | 切片缓存目录（自动生成） |

运行时生成的数据已加入 `.gitignore`，不要提交。

---

## 配置项（`config.json`）

| 配置 | 默认 | 说明 |
| --- | --- | --- |
| `port` | `8317` | 播放服务监听端口 |
| `host` | `0.0.0.0` | 允许局域网访问；只想本机用可改 `127.0.0.1` |
| `source` | 示例地址 | 源清单，支持 http(s) 地址或本地 `.m3u` 路径 |
| `sourceRefreshMinutes` | `30` | 定时重拉源清单（更新签名）。`0` = 关闭 |
| `defaultUserAgent` | `qqlive` | 默认上游 UA；单个频道带 `http-user-agent` 时优先用它 |
| `forceUserAgent` | 空 | 非空时覆盖所有频道 |
| `variantPreference` | `highest` | 多码率选择：`highest` / `lowest` / `720` 等 |
| `segmentsEnabled` | `true` | 切片本地缓冲总开关。关 = 清单和切片都直连上游 |
| `onlyCurrentChannel` | `true` | 只预热当前频道 |
| `liveDelaySegments` | `4` | 直播延迟按切片数计（配合起播位置） |
| `liveDelaySeconds` | `18` | 直播延迟按秒计 |
| `prefetchAhead` | `10` | 预先下载前方多少片 |
| `prefetchConcurrency` | `3` | 同时预取几个切片 |
| `bufferPoolSeconds` | `30` | 缓冲池秒数，越大越稳、延迟越高；`0` = 关闭 |
| `bufferSeconds` | `0` | 本地窗口额外保留的秒数；`0` = 只保留播放窗口 |
| `preloadChannels` | `3` | 同时预热几个频道：`0` = 只当前；`N` = 当前 + 最近 N 个；`-1` = 全部 |
| `idleStopMinutes` | `5` | 多久没请求就停止后台拉流 |
| `playlistWindow` | `18` | 播放列表保留的切片数 |
| `playlistRefreshSeconds` | `0` | 上游清单刷新间隔，`0` = 自动 |
| `requestTimeoutMs` | `10000` | 清单请求超时 |
| `segmentTimeoutMs` | `30000` | 切片请求超时 |
| `retries` / `playlistRetries` | `3` / `2` | 切片 / 清单重试次数 |
| `forceIPv4` | `true` | 强制 IPv4，避免 IPv6 半通时卡超时 |
| `curlFallback` | `true` | Node 解析失败时改用系统 `curl` |
| `autoFailover` | `false` | 当前源失败时是否换同名频道的其它源 |
| `rejectDemoSources` | `true` | 把上游返回的演示/广告片判为失败 |
| `debug` | `false` | 打印每个上游请求的状态与耗时 |
| `cacheDir` / `maxCacheMB` | `cache` / `4096` | 缓存目录与上限 |
| `adminPassword` | 空 | 管理页密码；空 = 局域网免密 |
| `proxyEnabled` | `false` | 播放服务是否走上游代理 |
| `proxy` | `http://127.0.0.1:7890` | 上游代理地址 |
| `proxyHosts` | `[]` | 走代理的域名，支持后缀匹配；留空 = 全部走代理 |

### 走代理的域名

- 在播放管理页「配置 → 代理域名」修改 `config.json` 的 `proxyHosts`
- 非空时只让这些域名走代理
- 留空 = 全部走上游代理（`proxyEnabled: true` 时）
- 支持后缀匹配：填 `example.com` 会匹配 `a.example.com`、`b.example.com`

---

## 与 mihomo 代理控制台配合（可选）

播放服务本身不依赖控制台。如果同时使用 mihomo 代理控制台，并且把两个项目放在**同一个目录**运行，控制台会把当前出口节点、端口等信息写入 `proxy-runtime.json`，播放服务的日志和管理页就能显示「当前走哪个节点」。

也可以只保留本仓库，在 `config.json` 里手动填写 `proxy` / `proxyEnabled` / `proxyHosts`，效果相同。

---

## Linux 部署（可选）

以下路径仅为示例，可换成任意目录。

1. 安装 Node.js 18+。
2. 把项目放到目标目录，例如 `/opt/live-buffer-proxy`。
3. 准备配置：

   ```bash
   cd /opt/live-buffer-proxy
   cp config.example.json config.json
   ```

4. 前台启动测试：

   ```bash
   ./start.sh
   ```

5. 安装为 systemd 服务：

   ```bash
   bash install-service.sh
   ```

   会创建 `m3u-proxy` 服务，工作目录就是脚本所在目录。

6. 查看日志：

   ```bash
   journalctl -u m3u-proxy -f
   ```

---

## 使用提示

- 首次播放某个频道时会立即出画面，之后后台继续攒缓冲池，播放器稳定落后直播约 N 秒。
- 缓存目录占用过大会自动清理最旧的切片；也可以手动清缓存。
- 管理页密码留空表示局域网免密。放到公网或不可信网络前，请设置 `adminPassword`。
- 仓库里的示例 `tv.m3u` 只用于展示格式，签名已打码；实际播放请使用自己的源。
- 源地址、管理密码、代理信息都属于敏感数据，不要提交到公开仓库。

---

## 常见问题

**能启动，但播放没有画面？**

先确认 `source` 里的地址仍有效、签名没有过期；再用 `check.js` 体检。上游返回演示视频、403、503 时也会表现为无法播放。

**不装 mihomo 能用吗？**

可以。播放服务默认直连，不依赖 mihomo；需要代理时再配置 `proxyEnabled` 和 `proxy`。

**局域网设备访问不了？**

播放器里要用本机局域网 IP，不能用 `127.0.0.1`；同时检查防火墙是否放行 8317 端口。

**缓存增长很慢？**

正常。上游通常每几秒才发布一片新切片，本地窗口按这个节奏增长；下载本身很快。

**想降低延迟？**

把 `bufferPoolSeconds` 调小或设为 `0`，代价是抗抖动能力下降。
