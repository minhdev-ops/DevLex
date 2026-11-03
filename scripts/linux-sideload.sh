#!/usr/bin/env bash
#
# linux-sideload.sh - chuan bi va huong dan cai app iOS len iPhone TU MAY LINUX.
#
# QUAN TRONG: iOS KHONG cho chay app chua ky (unsigned). File .ipa tu CI la
# unsigned, nen du copy vao may cung chi ra icon "ma" khong mo duoc.
# Tren Linux, voi tai khoan Apple ID mien phi, cach chay thuc te la:
#   (B) Sideloadly chay tren Wine  -  hoac
#   (A) Sidestore tren chinh iPhone (khong can PC, xem cuoi script).
#
# Yeu cau (cai mot lan):
#   sudo apt install -y wine64 usbmuxd libimobiledevice-utils
#   (Sideloadly.exe: tai tu https://sideloadly.io roi cai tren Wine)
#
# Dung:
#   ./scripts/linux-sideload.sh [duong-dan.ipa]
#   # bo trong duong-dan de tu tai artifact moi nhat tu GitHub.

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

echo ""
echo "=========================================================="
echo " FILE .ipa da san sang:"
echo "   $IPA"
echo ""
echo " CACH B (Sideloadly tren Wine) - khuyen dung cho Linux:"
echo "   1. Cai Wine + usbmuxd (len)."
echo "   2. Tai Sideloadly.exe tu https://sideloadly.io, cai bang:"
echo "        wine SideloadlySetup.exe"
echo "   3. Cam iPhone (mo khoa man hinh), chay:"
echo "        wine "$HOME/.wine/drive_c/Program Files/Sideloadly/Sideloadly.exe""
echo "   4. Keo file .ipa vao Sideloadly, nhap Apple ID, bam Start."
echo "   5. Tren iPhone: Cai dat > Cai dat chung > VPN & Quan ly thiet bi"
echo "      > tin cay Apple ID cua ban. Mo app DevLex nhu binh thuong."
echo ""
echo " CACH A (Sidestore - khong can PC, chi tren iPhone):"
echo "   1. Cai Sidestore tu https://sidestore.io (dung Apple ID mien phi)."
echo "   2. Mo file .ipa bang Safari > Chia se > Mo trong Sidestore."
echo "   3. Sidestore tu ky va cai. App het han sau 7 ngay (tu gia han khi cung WiFi)."
echo "=========================================================="
