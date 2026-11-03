#!/usr/bin/env bash
#
# linux-sideload.sh - tu dong tai .ipa va mo Sideloadly (Wine) de cai len iPhone.
#
# QUAN TRONG: iOS KHONG cho chay app chua ky (unsigned). File .ipa tu CI la
# unsigned, nen phai ky bang Apple ID mien phi qua Sideloadly truoc khi chay.
# Script nay: (1) tu tai .ipa moi nhat, (2) mo Sideloadly qua Wine voi file do.
# Ban chi viec nhap Apple ID trong cua so Sideloadly roi bam Start.
#
# Yeu cau (cai mot lan tren may Linux cua ban):
#   sudo apt install -y wine64 usbmuxd libimobiledevice-utils
#   Tai Sideloadly.exe tu https://sideloadly.io, cai: wine SideloadlySetup.exe
#
# Dung:
#   ./scripts/linux-sideload.sh [duong-dan.ipa]

set -euo pipefail

IPA="${1:-}"

echo ">> Kiem tra moi truong..."
for c in wine usbmuxd idevice_id; do
  command -v "$c" >/dev/null 2>&1 || echo "   [thieu] $c  (sudo apt install wine64)"
done

# Tu dong tai .ipa moi nhat neu khong truyen duong dan.
if [ -z "$IPA" ]; then
  echo ">> Tu dong tai .ipa moi nhat tu GitHub Actions..."
  TMPD="$(mktemp -d)"
  if gh run download -R minhdev-ops/DevLex -n ios-build-app -D "$TMPD" >/dev/null 2>&1; then
    IPA="$(find "$TMPD" -name 'DevLex-unsigned.ipa' | head -n1)"
  fi
  if [ -z "$IPA" ] || [ ! -f "$IPA" ]; then
    echo "::error::Khong tai duoc .ipa. Truyen duong dan thu cong: $0 DevLex-unsigned.ipa"
    exit 1
  fi
fi

if [ ! -f "$IPA" ]; then
  echo "::error::Khong tim thay file: $IPA"
  exit 1
fi

SIDE="$HOME/.wine/drive_c/Program Files/Sideloadly/Sideloadly.exe"

if [ ! -f "$SIDE" ]; then
  echo "::error::Chua thay Sideloadly.exe tai: $SIDE"
  echo "   Cai bang: wine SideloadlySetup.exe (tai tu https://sideloadly.io)"
  exit 1
fi

echo ">> Mo Sideloadly qua Wine voi file .ipa..."
echo "   File: $IPA"
echo "   (Trong cua so Sideloadly: nhap Apple ID, chon Device, bam Start)"
echo "   Sau do tren iPhone: Cai dat > Cai dat chung > VPN & Quan ly thiet bi > tin cay Apple ID"
wine "$SIDE" "$IPA" >/dev/null 2>&1 &
echo ">> Da mo Sideloadly. Hoan tat dang nhap Apple ID trong cua so do."
