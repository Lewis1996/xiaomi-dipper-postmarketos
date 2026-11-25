#!/bin/sh
# 镜像里的 ext4 只有 ~2.9G，分区却有 100G+。首次启动扩一次。
set -u
MARK=/var/lib/mi8-resized
[ -f "$MARK" ] && exit 0
ROOTDEV=$(findmnt -no SOURCE /)
[ -n "$ROOTDEV" ] || exit 0
/usr/sbin/resize2fs "$ROOTDEV" >/dev/null 2>&1 && touch "$MARK"
logger -t mi8-resize "resize2fs $ROOTDEV done"
