#!/bin/bash
# 安装播放服务为 systemd 服务：m3u-proxy
# 用法：bash install-service.sh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
NODE="$(command -v node)"
[ -z "$NODE" ] && { echo "找不到 node，请先安装 Node.js"; exit 1; }

cat > /etc/systemd/system/m3u-proxy.service <<EOF
[Unit]
Description=M3U Live Buffer Proxy (playback)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$DIR
ExecStart=$NODE $DIR/proxy.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now m3u-proxy
sleep 2
systemctl --no-pager --lines=12 status m3u-proxy
echo ""
echo "常用命令："
echo "  systemctl status m3u-proxy      # 播放服务状态"
echo "  systemctl restart m3u-proxy     # 重启播放服务"
echo "  journalctl -u m3u-proxy -f      # 播放服务日志"
