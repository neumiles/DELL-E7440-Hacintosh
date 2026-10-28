#!/bin/sh
# 安装 ALCPlugFix 到系统卷（需 sudo）。
# 作用：登录后自动把 node 0x12 的输入放大器增益设为 1 档，并在唤醒时重发。
# 依赖：boot-args 里的 alcverbs=1（本仓库 EFI/OC/config.plist 已包含）。
set -e

if [ "$(id -u)" -ne 0 ]; then
	echo "请用 sudo 运行：sudo sh install.sh"
	exit 1
fi

SRC="$(cd "$(dirname "$0")" && pwd)"
DST="/usr/local/ALCPlugFix"
AGENT="/Library/LaunchAgents/com.black-dragon74.ALCPlugFix.plist"

mkdir -p "$DST"
cp "$SRC/ALCPlugFix" "$DST/ALCPlugFix"
cp "$SRC/config.plist" "$DST/config.plist"
cp "$SRC/com.black-dragon74.ALCPlugFix.plist" "$AGENT"

chown -R root:wheel "$DST"
chown root:wheel "$AGENT"
chmod 755 "$DST/ALCPlugFix"
chmod 644 "$DST/config.plist" "$AGENT"

# 已在运行的会话里立即生效；下次登录由 launchd 自动加载（plist 必须是 root:wheel）
launchctl bootout "gui/$(id -u "${SUDO_USER:-$(stat -f %Su /dev/console)}")" "$AGENT" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u "${SUDO_USER:-$(stat -f %Su /dev/console)}")" "$AGENT" 2>/dev/null || true

echo "已安装：$DST，LaunchAgent：$AGENT"
echo "验证：/tmp/alc-verb -q 0x12 0xb60 0 应输出 0x00000001"
