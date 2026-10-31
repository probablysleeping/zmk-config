#!/usr/bin/env bash
# Flash ZMK firmware from the latest GitHub Actions build.
#   ./flash.sh            dongle only (keymap changes live on the dongle)
#   ./flash.sh --all      dongle + both halves
#   ./flash.sh --reset    settings_reset each device first (clears pairing)
# Needs: github-cli (gh auth login), udisks2
set -euo pipefail
cd "$(dirname "$0")"

all=0 reset=0
for a in "$@"; do
    case $a in
        --all) all=1 ;;
        --reset) reset=1 ;;
        *) echo "unknown option: $a"; exit 1 ;;
    esac
done

fw=firmware
rm -rf "$fw"
run=$(gh run list --workflow build.yml --status success --limit 1 --json databaseId,headSha,displayTitle \
    --jq '.[0] | "\(.databaseId) \(.headSha[:7]) \(.displayTitle)"')
[ -n "$run" ] || { echo "No successful build found."; exit 1; }
echo "Using build: $run"
[ "$(echo "$run" | cut -d' ' -f2)" = "$(git rev-parse --short=7 HEAD)" ] ||
    echo "Warning: that build is not your local HEAD (pushed? CI finished?)"
gh run download "${run%% *}" -D "$fw"

uf2() { find "$fw" -name "$1.uf2" | head -1; }

wait_drive() {
    echo "  Double-tap reset on the $1..." >&2
    local dev mnt
    while :; do
        dev=$(lsblk -rpno NAME,LABEL | awk '$2=="NICENANO"{print $1; exit}')
        [ -n "$dev" ] && break
        sleep 0.5
    done
    mnt=$(lsblk -rno MOUNTPOINT "$dev")
    if [ -z "$mnt" ]; then
        udisksctl mount -b "$dev" >/dev/null
        mnt=$(lsblk -rno MOUNTPOINT "$dev")
    fi
    echo "$mnt"
}

flash() { # device-label firmware-name reset-name
    echo "--- $1 ---"
    local file mnt
    if [ $reset = 1 ]; then
        file=$(uf2 "$3"); mnt=$(wait_drive "$1")
        cp "$file" "$mnt/" && sync || true
        echo "  Reset done."
        sleep 3
    fi
    file=$(uf2 "$2")
    [ -n "$file" ] || { echo "  $2.uf2 not in build"; exit 1; }
    mnt=$(wait_drive "$1")
    cp "$file" "$mnt/" && sync || true   # board reboots mid-copy; that's normal
    echo "  Flashed $2."
    sleep 3
}

flash dongle eyelash_corne_dongle settings_reset_dongle
if [ $all = 1 ]; then
    flash "left half" eyelash_corne_left_peripheral settings_reset_left
    flash "right half" eyelash_corne_right_peripheral settings_reset_right
fi
echo "Done."
