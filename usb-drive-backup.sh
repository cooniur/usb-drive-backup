#!/usr/bin/env bash
set -euo pipefail

# macOS USB backup via dd (Bash 3.2 compatible)
# - Collects inputs up front
# - Uses /dev/rdisk for speed
# - Shows progress (status=progress if supported; otherwise Ctrl+T)
# - Optional gzip compression
# - Writes SHA-256 checksum

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
info() { printf "[INFO] %s\n" "$*"; }
warn() { printf "[WARN] %s\n" "$*"; }
err()  { printf "[ERROR] %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

require_cmd diskutil
require_cmd dd
require_cmd shasum
require_cmd awk
require_cmd tr
require_cmd date
require_cmd sync

bold "macOS USB Backup Script (dd) — Bash 3.2 compatible"
echo "This will create a raw, bit-for-bit image of a USB drive."
echo "WARNING: Selecting the wrong disk can destroy data."
echo

bold "Step 1) Available disks:"
diskutil list
echo

# ---- Collect inputs up front ----
read -r -p "Enter the SOURCE DISK identifier (e.g., disk2): " DISK_ID
[ -n "${DISK_ID}" ] || die "Disk identifier cannot be empty."
echo "${DISK_ID}" | egrep -q '^disk[0-9]+$' || die "Invalid disk identifier: ${DISK_ID} (expected like 'disk2')."

DISK_DEV="/dev/${DISK_ID}"
RDISK_DEV="/dev/r${DISK_ID}"

info "Validating ${DISK_DEV}..."
diskutil info "${DISK_DEV}" >/dev/null 2>&1 || die "Disk ${DISK_DEV} not found."

echo
bold "Selected source disk details:"
# Show some helpful fields; ignore failures if SMART etc. doesn't exist
diskutil info "${DISK_DEV}" | grep -Ei "Device Node|Media Name|Protocol|Disk Size|Removable Media|Internal|Device Location|Mount Point|Whole|Writable|SMART" || true
echo

# Safety hint: warn if it's internal
INTERNAL_LINE="$(diskutil info "${DISK_DEV}" | awk -F': ' '/Internal/ {print $2}' | tr -d '[:space:]' || true)"
if [ "${INTERNAL_LINE}" = "Yes" ]; then
  warn "This disk appears to be INTERNAL. That is unusual for a USB backup."
  warn "Proceeding could risk imaging your internal drive if you selected wrong."
fi

read -r -p "Type BACKUP to confirm you want to image ${DISK_DEV}: " CONFIRM
[ "${CONFIRM}" = "BACKUP" ] || die "Confirmation not received. Aborting."

echo
bold "Step 2) Backup output settings"
DEFAULT_OUTDIR="${HOME}/Desktop"
read -r -p "Output directory [${DEFAULT_OUTDIR}]: " OUTDIR
OUTDIR="${OUTDIR:-$DEFAULT_OUTDIR}"
mkdir -p "${OUTDIR}" || die "Failed to create output directory: ${OUTDIR}"

TS="$(date +"%Y%m%d_%H%M%S")"
DEFAULT_BASENAME="${DISK_ID}_backup_${TS}"
read -r -p "Base filename (no extension) [${DEFAULT_BASENAME}]: " BASENAME
BASENAME="${BASENAME:-$DEFAULT_BASENAME}"

read -r -p "Compress with gzip? (y/N): " DO_GZIP
DO_GZIP="${DO_GZIP:-N}"

# Normalize gzip choice using case (Bash 3.2 safe)
DO_GZIP_YES=0
case "${DO_GZIP}" in
  y|Y|yes|YES|Yes) DO_GZIP_YES=1 ;;
  *) DO_GZIP_YES=0 ;;
esac

# Check gzip availability only if requested
if [ "${DO_GZIP_YES}" -eq 1 ]; then
  require_cmd gzip
  OUTFILE="${OUTDIR}/${BASENAME}.img.gz"
else
  OUTFILE="${OUTDIR}/${BASENAME}.img"
fi

info "Backup will be written to: ${OUTFILE}"
echo

# Optional: detect dd progress support
DD_STATUS_ARGS=""
if dd if=/dev/zero of=/dev/null bs=1 count=1 status=progress 2>/dev/null; then
  DD_STATUS_ARGS="status=progress"
else
  warn "Your dd does not support 'status=progress'."
  warn "While dd runs, press Ctrl+T to display progress (bytes transferred)."
fi

# ---- Execute backup ----
echo
bold "Step 3) Unmounting source disk"
info "Running: diskutil unmountDisk ${DISK_DEV}"
diskutil unmountDisk "${DISK_DEV}" || die "Failed to unmount ${DISK_DEV}"

echo
bold "Step 4) Creating image (this can take a while)"
info "Using raw device for speed: ${RDISK_DEV}"
BS="4m"

if [ "${DO_GZIP_YES}" -eq 1 ]; then
  info "Compression: gzip enabled"
  if [ -n "${DD_STATUS_ARGS}" ]; then
    info "Command: sudo dd if=${RDISK_DEV} bs=${BS} ${DD_STATUS_ARGS} | gzip > \"${OUTFILE}\""
    sudo dd if="${RDISK_DEV}" bs="${BS}" ${DD_STATUS_ARGS} | gzip > "${OUTFILE}"
  else
    info "Command: sudo dd if=${RDISK_DEV} bs=${BS} | gzip > \"${OUTFILE}\""
    sudo dd if="${RDISK_DEV}" bs="${BS}" | gzip > "${OUTFILE}"
  fi
else
  if [ -n "${DD_STATUS_ARGS}" ]; then
    info "Command: sudo dd if=${RDISK_DEV} of=\"${OUTFILE}\" bs=${BS} ${DD_STATUS_ARGS}"
    sudo dd if="${RDISK_DEV}" of="${OUTFILE}" bs="${BS}" ${DD_STATUS_ARGS}
  else
    info "Command: sudo dd if=${RDISK_DEV} of=\"${OUTFILE}\" bs=${BS}"
    sudo dd if="${RDISK_DEV}" of="${OUTFILE}" bs="${BS}"
  fi
fi

echo
bold "Step 5) Syncing writes"
info "Flushing buffers..."
sync

echo
bold "Step 6) Re-mounting disk"
info "Running: diskutil mountDisk ${DISK_DEV}"
diskutil mountDisk "${DISK_DEV}" || warn "Could not re-mount automatically (you can unplug/replug)."

echo
bold "Step 7) Computing checksum"
CHECKFILE="${OUTFILE}.sha256"
info "Writing SHA-256 to: ${CHECKFILE}"
shasum -a 256 "${OUTFILE}" | tee "${CHECKFILE}" >/dev/null

echo
bold "Backup complete ✅"
info "Image:    ${OUTFILE}"
info "Checksum: ${CHECKFILE}"
echo
info "Restore examples:"
if [ "${DO_GZIP_YES}" -eq 1 ]; then
  echo "  diskutil unmountDisk /dev/diskX"
  echo "  gunzip -c \"${OUTFILE}\" | sudo dd of=/dev/rdiskX bs=${BS} ${DD_STATUS_ARGS:-}"
  echo "  diskutil eject /dev/diskX"
else
  echo "  diskutil unmountDisk /dev/diskX"
  echo "  sudo dd if=\"${OUTFILE}\" of=/dev/rdiskX bs=${BS} ${DD_STATUS_ARGS:-}"
  echo "  diskutil eject /dev/diskX"
fi
