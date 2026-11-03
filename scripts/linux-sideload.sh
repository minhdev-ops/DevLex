#!/usr/bin/env bash
#
# linux-sideload.sh - ky (sign) va cai app iOS len iPhone TU MAY LINUX.
#
# iOS KHONG cho chay app chua ky (unsigned). File .ipa tu CI la unsigned,
# nen dù copy vao may cung chi ra icon "ma" khong mo duoc.
# Script nay dung Apple ID mien phi de ky (provisioning profile) roi cai qua USB.
#
# Yeu cau (cai mot lan):
#   sudo apt install -y ideviceinstaller libimobiledevice-utils usbmuxd
#   npm install -g applesign            # https://github.com/nowsecure/node-applesign
#
# Dung:
#   ./scripts/linux-sideload.sh DevLex-unsigned.ipa you@icloud.com
#
# App se hien ngoai man hinh chinh, chay nhu app thuong (het han sau 7 ngay
# voi tai khoan mien phi, sideload lai de gia han).

set -euo pipefail

IPA="${1:-}"
APPLE_ID="${2:-}"

if [ -z "$IPA" ] || [ -z "$APPLE_ID" ]; then
  echo "Dung: $0 <duong-dan.ipa> <apple-id>"
  exit 1
fi
if [ ! -f "$IPA" ]; then
  echo "::error::Khong tim thay file: $IPA"
  exit 1
fi

command -v ideviceinstaller >/dev/null 2>&1 || {
  echo "::error::Thieu ideviceinstaller. Chay: sudo apt install ideviceinstaller libimobiledevice-utils usbmuxd"
  exit 1
}
command -v applesign >/dev/null 2>&1 || {
  echo "::error::Thieu applesign. Chay: npm install -g applesign"
  exit 1
}

echo ">> Kiem tra thiet bi..."
if ! idevice_id -l | grep -q .; then
  echo "::error::Khong thay iPhone. Cam USB va mo khoa man hinh."
  exit 1
fi

SIGNED="$(mktemp -d)/DevLex-signed.ipa"
echo ">> Ky app bang Apple ID ($APPLE_ID)..."
applesign -i "$IPA" -o "$SIGNED" -e "$APPLE_ID"

echo ">> Cai dat len iPhone..."
ideviceinstaller -i "$SIGNED"

echo ">> Xong. Mo app DevLex tren iPhone."
echo "   (Lan dau: Cai dat > Cai dat chung > VPN & Quan ly thiet bi > tin cay Apple ID)"
