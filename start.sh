#!/bin/bash
# 启动直播源本地缓冲代理（默认 8317）
cd "$(dirname "$0")" || exit 1
exec node proxy.js
